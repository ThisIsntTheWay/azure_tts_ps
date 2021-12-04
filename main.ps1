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
        [bool]$Quiet = $false
)

# ------------------------
# Module loading
# ------------------------
.".\modules\azure.ps1" -apiRegion "northeurope"
if (!($?)) { Write-Host "Could not load Azure ps1 module:" -fore red; throw $($error[0].Exception.Message) }

.".\modules\misc.ps1" -quiet $Quiet
if (!($?)) { Write-Host "Could not load auxilliary ps1 module:" -fore red; throw $($error[0].Exception.Message) }

# ------------------------
# Main
# ------------------------
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
    "Text" = $text
}

Write-Log "[i] Requesting content with the following info:"
Write-Log "$($voiceInfo | convertto-json)" $true

$timer =  [system.diagnostics.stopwatch]::StartNew()

$a = Create-AzureTTSAudio $voiceInfo
if ($?) {
    $timer.Stop()

    $count = 0 + ((gci .\output).count + 1)

    if (!(Test-Path ".\output")) { mkdir .\output | out-null }
    $outFile = ".\output\tts${count}_$($voiceInfo.Name).$($voiceCodec.suffix)"

    [io.file]::WriteAllBytes($outFile, $a)
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
    "requestTime" = $timer | select @{N = "Time"; E = {$_.Elapsed}},
        @{N = "Millis"; E = {$_.ElapsedMilliseconds}},
        @{N = "Ticks"; E = {$_.ElapsedTicks}}
    "rawAudio" = $a
    "metadata" = $voiceInfo
}