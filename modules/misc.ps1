function Show-Notification {
    [cmdletbinding()]
    Param(
        [parameter(Mandatory = $true)]
            [string]$text,
        [string]$title = "Alert",
        [string]$level = "Info",
        [int]$expiry = 60
    )

    [string]$iconFile = ".\toast\" + $level + ".png"

    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
    $Template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastImageAndText02)
    #[Windows.UI.Notifications.ToastTemplateType] | Get-Member -Static -Type Property

    $RawXml = [xml] $Template.GetXml()
    ($rawxml.GetElementsByTagName("text") | ? id -eq "1").AppendChild($RawXml.CreateTextNode($Title)) > $null
    ($rawxml.GetElementsByTagName("text") | ? id -eq "2").AppendChild($RawXml.CreateTextNode($Text)) > $null
    ($rawxml.GetElementsByTagName("image") | ? id -eq "1").src = (Get-Item $iconFile).Fullname

    $SerializedXml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $SerializedXml.LoadXml($RawXml.OuterXml)

    $Toast = [Windows.UI.Notifications.ToastNotification]::new($SerializedXml)
    $Toast.Tag = "PowerShell"
    $Toast.Group = "PowerShell"
    $Toast.ExpirationTime = [DateTimeOffset]::Now.AddSeconds($expiry)

    $Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Azure TTS Services")
    $Notifier.Show($Toast);
}

function Write-Log {
    Param(
        [parameter(Mandatory = $true)]
            [string]$text,
        [parameter(Mandatory = $false)]
            [bool]$omitDateTime = $false
    )

    $now = get-date -format "dd/mm/yyyy HH:mm:ss"
    $outFile = ".\log\log_$(Get-Date -f "ddMMyyyy").txt"

    if (!(Test-Path ".\log")) { 
        mkdir .\log | out-null
    }

    if ($omitDateTime) {
        Write-Output $text | out-file $outfile -append
    } else {
        Write-Output "[$now] - $text" | out-file $outfile -append
    }
}