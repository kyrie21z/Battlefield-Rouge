param([string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
throw 'Desktop SAPI output is superseded. Use tools/cinematic/generate_voice_assets.py with the pinned external Kokoro model; see tools/cinematic/voice_assets.md.'
Add-Type -AssemblyName System.Speech
$voice = New-Object System.Speech.Synthesis.SpeechSynthesizer
$voice.SelectVoice('Microsoft Huihui Desktop')
$voice.Rate = 1
$voice.Volume = 95
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$voice.SetOutputToWaveFile((Join-Path $OutputDirectory 'crown_breakdown.wav'))
$voice.Speak('你简直无药可救了！！')
$voice.SetOutputToNull()
$voice.Dispose()
