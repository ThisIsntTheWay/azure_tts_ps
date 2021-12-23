@echo off
powershell -command "[string](Get-Content .\sample.txt -encoding UTF8) | .\main.ps1 -apiKey .\secret\apiKey -voice 'Nanami' -codec 'audio' -codecQuality 10"