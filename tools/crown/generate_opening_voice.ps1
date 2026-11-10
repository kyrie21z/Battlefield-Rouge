param([string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
throw 'Desktop SAPI output is superseded. Use tools/cinematic/generate_voice_assets.py with the pinned external Kokoro model; see tools/cinematic/voice_assets.md.'
Add-Type -AssemblyName System.Speech
$voice = New-Object System.Speech.Synthesis.SpeechSynthesizer
$voice.SelectVoice('Microsoft Huihui Desktop')
$voice.Rate = -1
$voice.Volume = 86
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$voice.SetOutputToWaveFile((Join-Path $OutputDirectory 'interview.wav'))
$voice.Speak('请用一分钟解释，为什么我们应该选你？你的方案有什么不可替代的价值？')
$voice.SetOutputToNull()
$voice.SetOutputToWaveFile((Join-Path $OutputDirectory 'wake.wav'))
$voice.Speak('醒了吗？感觉好点了吗？别怕，我在这里。')
$voice.SetOutputToNull()
$voice.SetOutputToWaveFile((Join-Path $OutputDirectory 'care.wav'))
$voice.Speak('别去想刚才的意外。那不是你的水平。你比任何人以为的，都要优秀。')
$voice.SetOutputToNull()
$voice.SetOutputToWaveFile((Join-Path $OutputDirectory 'obstacle.wav'))
$voice.Speak('只是那些潜伏在深处的老毛病，又在关键时刻绊了我们一跤。')
$voice.SetOutputToNull()
$voice.SetOutputToWaveFile((Join-Path $OutputDirectory 'better.wav'))
$voice.Speak('听我说，你可以做到更好。你生来就是属于顶峰的。')
$voice.SetOutputToNull()
$voice.SetOutputToWaveFile((Join-Path $OutputDirectory 'invitation.wav'))
$voice.Speak('来，我们一起把那些拖慢脚步的心魔清理干净。下一次，让他们心服口服。')
$voice.SetOutputToNull()
$voice.Dispose()
