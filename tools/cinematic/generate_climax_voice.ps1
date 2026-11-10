param([string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
throw 'Desktop SAPI output is superseded. Use tools/cinematic/generate_voice_assets.py with the pinned external Kokoro model; see tools/cinematic/voice_assets.md.'
Add-Type -AssemblyName System.Speech
$linesPath = Join-Path $PSScriptRoot 'climax_lines.json'
$lines = [System.IO.File]::ReadAllText($linesPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$voice = New-Object System.Speech.Synthesis.SpeechSynthesizer
$voice.SelectVoice('Microsoft Huihui Desktop')
$voice.Rate = -1
$voice.Volume = 90
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
foreach ($line in $lines.PSObject.Properties) {
    $voice.SetOutputToWaveFile((Join-Path $OutputDirectory ($line.Name + '.wav')))
    $voice.Speak([string]$line.Value)
    $voice.SetOutputToNull()
}
$voice.Dispose()
