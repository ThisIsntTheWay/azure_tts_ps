# azure_tts_ps
PowerShell script to interface with the TTS API endpoint of Azure Speech Services.

### Simple text
```PowerShell
.\main.ps1 -apiKey .\secret\apiKey -voice "Natasha" -text "Hello world" -codec "webm" -codecQuality "max" -quiet $false
```

### Multi line document
```PowerShell
$text = (Get-Content .\sample.txt -encoding UTF8)
.\main.ps1 -apiKey .\secret\apiKey -voice "Natasha" -text $text -codec "audio" -codecQuality "max" -quiet $false
```

### Piped text
```PowerShell
'Hello World' | .\main.ps1 -apiKey .\secret\apiKey -voice "Natasha" -codec "webm" -codecQuality "max" -quiet $false
```

### Piped multi line document
```PowerShell
$text = [string](Get-Content .\sample.txt -encoding UTF8)
$text | .\main.ps1 -apiKey .\secret\apiKey -voice "Natasha" -codec "webm" -codecQuality "max" -quiet $false
```
