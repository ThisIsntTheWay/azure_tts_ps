Param(
    [parameter(Mandatory = $true)]
        [string]$apiRegion
)

[string]$cognitiveURL = "https://$apiRegion.api.cognitive.microsoft.com"
[string]$ttsURL = "https://$apiRegion.tts.speech.microsoft.com"
[PSCustomObject]$azureTTSAudio = @{
    "riff" = @{
        "suffix" = "riff"
        "types" = @(
            "riff-16khz-16bit-mono-pcm"
            "riff-24khz-16bit-mono-pcm"
            "riff-48khz-16bit-mono-pcm"
            "riff-8khz-8bit-mono-mulaw"
            "riff-8khz-8bit-mono-alaw"   
        )
    }
    "audio" = @{
        "suffix" = "mp3"
        "types" = @(
            "audio-16khz-32kbitrate-mono-mp3"
            "audio-16khz-64kbitrate-mono-mp3"
            "audio-16khz-128kbitrate-mono-mp3"
            "audio-24khz-48kbitrate-mono-mp3"
            "audio-24khz-96kbitrate-mono-mp3"
            "audio-24khz-160kbitrate-mono-mp3"
            "audio-48khz-96kbitrate-mono-mp3"
            "audio-48khz-192kbitrate-mono-mp3"
        )
    }
    "raw" = @{
        "suffix" = "raw"
        "types" = @(
            "raw-16khz-16bit-mono-pcm"
            "raw-24khz-16bit-mono-pcm"
            "raw-48khz-16bit-mono-pcm"
            "raw-16khz-16bit-mono-truesilk"
            "raw-24khz-16bit-mono-truesilk"
            "raw-8khz-8bit-mono-mulaw"
            "raw-8khz-8bit-mono-alaw"
        )
    }
    "webm" = @{
        "suffix" = "webm"
        "types" = @(
            "webm-16khz-16bit-mono-opus"
            "webm-24khz-16bit-mono-opus"
        )
    }
    "ogg" = @{
        "suffix" = "ogg"
        "types" = @(
            "ogg-16khz-16bit-mono-opus"
            "ogg-24khz-16bit-mono-opus"
            "ogg-48khz-16bit-mono-opus"
        )
    }
}

# Ref: https://docs.microsoft.com/en-us/azure/cognitive-services/speech-service/rest-text-to-speech

<#
    .SYNOPSIS
        Obtains an OAuth token for Azure Speech Services.
    .OUTPUTS
        Returns a [PSCustomObject] with the following values:
        - Expiration date of token ("Expriy")
        - Token in format for authorization header ("Auth")
        - Raw token ("Value")
        - Method for determining validy of token (isExpired())
            > Returns a [bool]
#>
function Get-AzureSpeechServiceToken {
    $token = Invoke-RestMethod ($cognitiveURL + "/sts/v1.0/issueToken") -Method POST -Headers @{
        'Ocp-Apim-Subscription-Key' = $apiKey
        'Content-Type' = 'application/x-www-form-urlencoded'
    }
    if (!($?)) {
        Show-Notification -Title "OAuth token acquisition failure" -Text $error[0].exception.Message -Level "Error"
        exit
    }

    $returnObj = [PSCustomObject]@{
        'Expiry' = [DateTimeOffset]::Now.AddMinutes(9)
        'Value' = $token
        'Auth' = "Bearer " + $token
    }

    Add-Member -memberType ScriptMethod -InputObject $returnObj -Name "isExpired" -Force -Value {
        if (($this.Expiry - [DateTimeOffset]::Now).Ticks -lt 0) {
            return $true
        } else {
            return $false
        }
    }

    return $returnObj
}

<#
    .SYNOPSIS
        Obtains a list of valid voices for the Azure TTS service.
    .PARAMETER onlyNeural
        Only returns "neural" voices.
        Defaults to $true.
#>
function Get-AzureTTSVoices {
    Param(
        $onlyNeural = $true
    )

    $a = Invoke-RestMethod ($ttsURL + "/cognitiveservices/voices/list") -Method GET -Headers @{ 'Ocp-Apim-Subscription-Key' = $apiKey }
    if (!($?)) {
        Show-Notification -Title "Voice list acquisition failure" -Text $error[0].exception.Message -Level "Error"
        exit
    }

    if ($onlyNeural) {
        return ($a | ? VoiceType -eq "Neural")
    } else {
        return $a
    }
}

<#
    .SYNOPSIS
        Creates a TTS voice file.
    .PARAMETER VoiceInfo
        [PSCustomObject] of voice information for the Azure TTS service.
    .OUTPUTS
        Returns byte[] data of the audio.
#>
function Create-AzureTTSAudio {
    Param(
        [parameter(Mandatory = $true)]
            [PSCustomObject]$VoiceInfo
    )

    begin {
    # Assemble SSML
        $xml = @"
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="%LOCALE%">
    <voice name="%NAME%">
        %TEXT%
    </voice>
</speak>
"@
        $SSML = $xml -Replace "%LOCALE%", $VoiceInfo.Locale `
                    -Replace "%NAME%", $VoiceInfo.Name `
                    -Replace "%TEXT%", $VoiceInfo.Text

        $body = [System.Text.Encoding]::UTF8.GetBytes($SSML)
    } process {
        $a = Invoke-WebRequest ($ttsURL + "/cognitiveservices/v1") -Method POST -Body $body -Headers @{
            'Authorization' = (Get-AzureSpeechServiceToken).Auth
            'Content-Type' = 'application/ssml+xml'
            'X-Microsoft-OutputFormat' = $voiceInfo.Codec
        }
        if (!($?)) {
            Show-Notification -Title "Voice acquisition failure" -Text $error[0].exception.Message -Level "Error"
            exit
        } else {
            return $a.content
        }
    }
}