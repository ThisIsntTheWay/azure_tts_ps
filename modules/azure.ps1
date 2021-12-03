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

function Get-AzureTTSToken {
    $token = Invoke-RestMethod ($cognitiveURL + "/sts/v1.0/issueToken") -Method POST -Headers @{
        'Ocp-Apim-Subscription-Key' = $apiKey
        'Content-Type' = 'application/x-www-form-urlencoded'
    }

    if (!($?)) {
        Show-Notification -Title "OAuth token acquisition failure" -Text $error[0].exception.Message -Level "Error"
        return
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

function Get-AzureTTSVoices {
    Param(
        $onlyNeural = $true
    )

    $a = Invoke-RestMethod ($ttsURL + "/cognitiveservices/voices/list") -Method GET -Headers @{ 'Ocp-Apim-Subscription-Key' = $apiKey }
    if (!($?)) {
        Show-Notification -Title "Voice list acquisition failure" -Text $error[0].exception.Message -Level "Error"
        return
    }

    if ($onlyNeural) {
        return ($a | ? VoiceType -eq "Neural")
    } else {
        return $a
    }
}

function Create-AzureTTSAudio {
    Param(
        [parameter(Mandatory = $true)]
            [PSCustomObject]$VoiceInfo
    )

    [XML]$SSML = (Get-Content .\xmlTemplate.xml) `
        -Replace "%LOCALE%", $voiceInfo.Locale `
        -Replace "%NAME%", $voiceInfo.Name `
        -Replace "%GENDER%", $voiceInfo.Gender `
        -Replace "%TEXT%", $voiceInfo.Text
    if(!($?)) {
        Show-Notification -Title "Unable to parse voice XML template" -Text $error[0].exception.Message -Level "Error"
        return
    }

    $a = Invoke-WebRequest ($ttsURL + "/cognitiveservices/v1") -Method POST -Body $SSML -Headers @{
        'Authorization' = (Get-AzureTTSToken).Auth
        'Content-Type' = 'application/ssml+xml'
        'X-Microsoft-OutputFormat' = $voiceInfo.Codec
    }
    if (!($?)) {
        Show-Notification -Title "Voice acquisition failure" -Text $error[0].exception.Message -Level "Error"
        return
    } else {
        return $a.content
    }
}