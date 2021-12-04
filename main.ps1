<#
    .SYNOPSIS
        Synthesizes text to speech using Azure Speech Services.
        This synthesized text will then be stored as a file under '.\output\<filename>'.
    .OUTPUTS
        Returns an object with the following properties:
        > "filePath" - Path to the file that was created
        > "requestTime" - Amount of time that was spent creating the TTS file.
            > This only includes the time spent REQUESTING and fully RECEIVING TTS data.
        > "rawAudio" - Byte[] of the audio returned by Azure.
        > "metadata" - Data such as speaker, locale, text etc.
#>
Param(
    [parameter(Mandatory = $true, HelpMessage = "Path to API key.", Position = 0)]
        [string]$apiKeyPath,

    [parameter(Mandatory = $true, HelpMessage = "Name of voice to use. Uses 'DisplayName' param of .\voiceList.json.", Position = 1)]
        [string]$voice,

    [parameter(Mandatory = $true, HelpMessage = "Text to synthesize, can be pipelined", ValueFromPipeline = $true, Position = 2)]
        $text,

    [parameter(Mandatory = $false, HelpMessage = "Audio codec type. (audio, webm, riff, ogg, raw)", Position = 3)]
    [ValidateSet("audio","webm","riff","ogg","raw")]
        [string]$Codec = "audio",

    [parameter(Mandatory = $false, HelpMessage = "Audio codec quality level. (Zero-indexed)", Position = 4)]
        [int]$CodecQuality = 0,

    [parameter(Mandatory = $false, HelpMessage = "Show notification bubbles or not.", Position = 5)]
        [bool]$Quiet = $false,
        
    [parameter(Mandatory = $false, HelpMessage = "API region", Position = 6)]
        [string]$apiRegion = "northeurope"
)

# ------------------------
# Module loading
# ------------------------
.".\modules\azure.ps1" -apiRegion "northeurope"
if (!($?)) { Write-Host "Could not load Azure ps1 module:" -fore red; throw $($error[0].Exception.Message) }

.".\modules\misc.ps1" -quiet $Quiet
if (!($?)) { Write-Host "Could not load auxilliary ps1 module:" -fore red; throw $($error[0].Exception.Message) }

# ------------------------
# Variables
# ------------------------
$scriptRegData = "HKCU:\SOFTWARE\AzureSpeechServices\"

# ------------------------
# Main
# ------------------------
# Set up registry data
if (!(Test-path $scriptRegData)) {
    mkdir $scriptRegData | Out-Null
}

if ((Get-ItemProperty $scriptRegData).billingCurrency -eq $null) {
    Set-ItemProperty $scriptRegData -name "billingCurrency" -value "USD" -type String -Force | Out-Null
}

if ((Get-ItemProperty $scriptRegData).billableCharactersNeural -eq $null) {
    Set-ItemProperty $scriptRegData -name "billableCharactersNeural" -value 0 -type Dword -Force | Out-Null
}

if ((Get-ItemProperty $scriptRegData).billableCharactersStandard -eq $null) {
    Set-ItemProperty $scriptRegData -name "billableCharactersStandard" -value 0 -type Dword -Force | Out-Null
}

[string]$apiKey = Get-Content $apiKeyPath
if(!($?)) {
    Create-Notifications -text "Could not read API key: $($error[0].exception.Message)" -title "Error" -notificationLevel "error" -noBubble $true
    Show-Notification -text $error[0].exception.Message -Title "Could not read API key" -level "error"
    return
}

# Get voice list
if (!(Test-Path ".\voiceList.json")) {
    Write-Log "'.\voiceList.json' does not yet exist, creating..."
    $a = (Get-AzureTTSVoices | convertto-json -Depth 5)
    if ($?) {
        $a | out-file .\voiceList.json
    } else {
        throw "Voice list acquisition failure: $($error[0].Exception.Message)"
    }
}

$voiceList = Get-Content ".\voiceList.json" | ConvertFrom-Json
$voiceChoice = $voiceList | where DisplayName -like $voice
if ($voiceChoice -eq $null) {
    Create-Notifications -text "Could not locate voice info for '$voice'." -title "Error" -notificationLevel "error"
    exit
}

# Validate voice codec
$voiceCodec = $azureTTSAudio.$Codec
if ($CodecQuality -gt ($voiceCodec.types.count - 1)) {
    Create-Notifications "Specified codec quality level ($codecQuality) does not resolve to a type of codec '$Codec'." -title Error -notificationLevel "error"
    Write-Host "Permitted values are: " -fore red
    for ($i = 0; $i -lt $voiceCodec.types.count; $i++) {
        Write-Host " $i -> $($voiceCodec.types[$i])" -fore red
    }
}

Write-Host "Validation OK, requesting TTS content..." -fore cyan

# --------------
# Request TTS
$voiceInfo = [PSCustomObject]@{
    "Locale" = $voiceChoice.locale
    "Gender" = $voiceChoice.gender
    "Name" = $voiceChoice.ShortName
    "Codec" = $voiceCodec.types[$CodecQuality]
    "Text" = [string]$text
}

Write-Log "[i] Requesting content with the following info:"
Write-Log "$($voiceInfo | convertto-json)" $true

$timer =  [system.diagnostics.stopwatch]::StartNew()

$a = Create-AzureTTSAudio $voiceInfo
if ($?) {
    $timer.Stop()

    # Update registry
    $charCount = $voiceInfo.Text.Length
    if ($voiceChoice.VoiceType -eq "Neural") {
        $e = (Get-ItemProperty $scriptRegData)."billableCharactersNeural"
        Set-ItemProperty $scriptRegData -name "billableCharactersNeural" -value ($e + $charCount) -type Dword -Force | Out-Null
    } else {
        $e = (Get-ItemProperty $scriptRegData)."billableCharactersStandard"
        Set-ItemProperty $scriptRegData -name "billableCharactersStandard" -value ($e + $charCount) -type Dword -Force | Out-Null
    }

    $count = 0 + ((gci .\output).count + 1)

    if (!(Test-Path ".\output")) { mkdir .\output | out-null }
    $outFile = ".\output\tts${count}_$($voiceInfo.Name).$($voiceCodec.suffix)"

    [io.file]::WriteAllBytes((gci .\).directory[0].fullname + "\$outFile", $a)
    if ($?) {
        Show-Notification -title "Request OK" -text "TTS generation successful." -filePath (gci $outFile)
        Write-Log "Successfully wrote '$outfile'."

        Write-Host "Done" -fore green
    } else {
        Show-Notification -title "Could not write file" -text $error[0].exception.message -level "Error"
        Write-Log "Unable to write '$outfile': $($error[0].exception.message)"
    }
} else {
    Write-Log "Request failed: $($error[0].exception.message)"
}

return @{
    "filePath" = (gci $outFile)
    "requestTime" = $timer.elapsed
    "rawAudio" = $a
    "metadata" = $voiceInfo
}