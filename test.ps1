[string]$apiRegion = "northeurope"
[string]$cognitiveURL = "https://$apiRegion.api.cognitive.microsoft.com"
[string]$ttsURL = "https://$apiRegion.tts.speech.microsoft.com"

[string]$apiKey = Get-Content .\secret\apiKeyd
if(!($?)) {
    Show-Notification -Title "Could not read API key" -Text $error[0].exception.Message -Level "Error"
    return
}

# ------------------------
# Module loading
# ------------------------
.".\modules\azure.ps1"
.".\modules\misc.ps1"

# ------------------------
# Main
# ------------------------
$voiceList = Get-AzureTTSVoices
$voiceChoice = $voiceList | where DisplayName -match "Natasha"
$voiceCodec = $azureTTSAudio.webm

$voiceInfo = [PSCustomObject]@{
    "Locale" = $voiceChoice.locale
    "Gender" = $voiceChoice.gender
    "Name" = $voiceChoice.ShortName
    "Codec" = $voiceCodec.types[0]
    "Text" = "Hello World"
}

Write-Log "[i] Requesting content with the following info:"
Write-Log "$($voiceInfo | convertto-json)" $true

$a = Create-AzureTTSAudio $voiceInfo
if ($?) {
    Show-Notification -title "Request OK" -text "TTS generation successful."

    $count = 0 + ((gci .\output).count + 1)

    if (!(Test-Path ".\output")) { mkdir .\output | out-null }
    $outFile = ".\output\tts${count}_$($voiceInfo.Name).$($voiceCodec.suffix)"

    [io.file]::WriteAllBytes($outFile, $a)
    if ($?) {
        Write-Log "Unable to write '$outfile': $($error[0].exception.message)"
    } else {
        Write-Log "Successfully wrote '$outfile'."
    }
} else {
    Write-Log "Request failed: $($error[0].exception.message)"
}

# Ref: https://docs.microsoft.com/en-us/azure/cognitive-services/speech-service/rest-text-to-speech