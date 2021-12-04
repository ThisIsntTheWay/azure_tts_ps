Param(
    [parameter(Mandatory = $true)]
        [bool]$quiet
)

<#
    .SYNOPSIS
        Creates a notification bubble.
    .PARAMETER text
        Text of the notification.
    .PARAMETER title
        Title of the notification.
        Defaults to "Alert".
    .PARAMETER level
        Depending on the value, the notification bubble will have a different appearance.
        Defaults to "Info".
    .PARAMETER expiry
        Expiration time of the notification bubble in seconds.
        Defaults to 60.
    .PARAMETER filePath
        If specified, adds two buttons to the notification bubble ("Open file", "Open folder").
        These buttons allow the user to directly open the file as specified in the path or its corresponding root folder.
        Warning: Assumes a 'Get-ChildItem' object as its input.
#>
function Show-Notification {
    Param(
        [parameter(Mandatory = $true)]
            [string]$text,
        [string]$title = "Alert",
        [string]$level = "Info",
        [int]$expiry = 60,
        $filePath
    )

    [string]$iconFile = ".\toast\" + $level + ".png"

    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
    $Template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastImageAndText02)
    #[Windows.UI.Notifications.ToastTemplateType] | Get-Member -Static -Type Property

    $RawXml = [xml] $Template.GetXml()
    ($rawxml.GetElementsByTagName("text") | ? id -eq "1").AppendChild($RawXml.CreateTextNode($Title)) > $null
    ($rawxml.GetElementsByTagName("text") | ? id -eq "2").AppendChild($RawXml.CreateTextNode($Text)) > $null
    ($rawxml.GetElementsByTagName("image") | ? id -eq "1").src = (Get-Item $iconFile).Fullname

    if ($filePath) {
        # Convert path to # file:///
        $fileURI = $filePath.fullname -replace "\\", "/" -replace " ", "%20"
        $fileURI = "file:///" + $fileURI
        
        $dirURI = $filePath.directory[0].fullname -replace "\\", "/" -replace " ", "%20"
        $dirURI = "file:///" + $dirURI

        #https://docs.microsoft.com/en-us/windows/apps/design/shell/tiles-and-notifications/toast-schema#itoastactions
        $actions = $rawXML.CreateNode("element", "actions", "")
            $action = $rawXML.CreateNode("element", "action", "")
            $action.SetAttribute("activationType", "protocol")
            $action.SetAttribute("arguments", $fileURI)
            $action.SetAttribute("content", "Open file")
            
            $action2 = $rawXML.CreateNode("element", "action", "")
            $action2.SetAttribute("activationType", "protocol")
            $action2.SetAttribute("arguments", $dirURI)
            $action2.SetAttribute("content", "Open folder")

        $actions.AppendChild($action) | Out-Null
        $actions.AppendChild($action2) | Out-Null
        ($rawXML.toast).AppendChild($actions) | Out-Null
    }

    $SerializedXml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $SerializedXml.LoadXml($RawXml.OuterXml)

    $Toast = [Windows.UI.Notifications.ToastNotification]::new($SerializedXml)
    $Toast.Tag = "Azure Speech Services"
    $Toast.Group = "Azure Speech Services"
    $Toast.ExpirationTime = [DateTimeOffset]::Now.AddSeconds($expiry)

    $Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Azure Speech Services")
    if (!($quiet)) {
        $Notifier.Show($Toast);
    }
}

function Write-Log {
    Param(
        [parameter(Mandatory = $true)]
            [string]$text,
        [parameter(Mandatory = $false)]
            [bool]$omitDateTime = $false
    )

    $now = get-date -format "dd/mm/yyyy HH:mm:ss"
    $outFile = ".\log\log_$(Get-Date -f "yyyyMMdd").txt"

    if (!(Test-Path ".\log")) { 
        mkdir .\log | out-null
    }

    if ($omitDateTime) {
        Write-Output $text | out-file $outfile -append
    } else {
        Write-Output "[$now] - $text" | out-file $outfile -append
    }
}

<#
    .SYNOPSIS
        Creates output to three things: The console, a log file and (optionally) a notification bubble.
    .PARAMETER text
        Text of the notification.
        This text will be written to console, the log and the notification.
    .PARAMETER title
        Title of the notification bubble.
    .PARAMETER notificationLevel
        Depending on the value, the console output and the notification bubble will have a different appearance.
    .PARAMETER noBubble
        If set to $true, no notification bubble will be created.
#>
function Create-Notifications {
    Param(
        [parameter(Mandatory = $true)]
            [string]$text,
        [parameter(Mandatory = $true)]
            [string]$title,
        [parameter(Mandatory = $true)]
        [ValidateSet("error","warn","info")]
            [string]$notificationLevel,
        [parameter(Mandatory = $false)]
            [bool]$noBubble = $false
    )

    if (!($noBubble)) {
        Show-Notification -text $text -title $title -level $notificationLevel
    }

    Write-Log $text

    switch ($notificationLevel) {
        "error"  {
            Write-Host $text -fore red
        } "warn" {
            Write-Warning $text
        } "info" {
            Write-Host $text -fore cyan
        }
    }
}