param([string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
throw 'Desktop SAPI output is superseded. Use tools/cinematic/generate_voice_assets.py with the pinned external Kokoro model; see tools/cinematic/voice_assets.md.'
Add-Type -AssemblyName System.Speech
$voice = New-Object System.Speech.Synthesis.SpeechSynthesizer
$voice.SelectVoice('Microsoft Huihui Desktop')
$voice.Volume = 86
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$voice.Rate = -1
$voice.SetOutputToWaveFile((Join-Path $OutputDirectory 'first.wav'))
$voice.Speak('别怕。刚才的意外不是你的全部。你可以做到更好，跟着我往前走。')
$voice.SetOutputToNull()
$voice.Rate = 0
$voice.SetOutputToWaveFile((Join-Path $OutputDirectory 'early.wav'))
$voice.Speak('没关系，站起来。刚才只是节奏乱了一点。看清它的动作，再快一点。')
$voice.SetOutputToNull()
$voice.Rate = 0
$voice.SetOutputToWaveFile((Join-Path $OutputDirectory 'early_abyss.wav'))
$voice.Speak('先站稳。刚才是桥面翻转了，不是你不够优秀。下一次，把边缘记牢。')
$voice.SetOutputToNull()
$voice.Rate = 1
$voice.SetOutputToWaveFile((Join-Path $OutputDirectory 'deep.wav'))
$voice.Speak('只差一点点了！别让那些软弱，把好不容易夺回的阵地抢回去。继续！')
$voice.SetOutputToNull()
$voice.Rate = 1
$voice.SetOutputToWaveFile((Join-Path $OutputDirectory 'deep_abyss.wav'))
$voice.Speak('已经走到这里，怎么还能掉下去？看住脚下。我们不能再浪费这次机会。')
$voice.SetOutputToNull()
$voice.Rate = 1
$voice.SetOutputToWaveFile((Join-Path $OutputDirectory 'veteran.wav'))
$voice.Speak('深呼吸。路线记住了。行动。')
$voice.SetOutputToNull()
$voice.Rate = 1
$voice.SetOutputToWaveFile((Join-Path $OutputDirectory 'veteran_abyss.wav'))
$voice.Speak('远离边缘。不要重复失误。行动。')
$voice.SetOutputToNull()
$voice.Rate = -1
$voice.SetOutputToWaveFile((Join-Path $OutputDirectory 'floor2.wav'))
$voice.Speak('安静下来了，对吗？现在，不必再被恐惧拖慢。')
$voice.SetOutputToNull()
$voice.Rate = 0
$voice.SetOutputToWaveFile((Join-Path $OutputDirectory 'floor3.wav'))
$voice.Speak('你已经不再犹豫。继续，把那些愤怒也清理干净。')
$voice.SetOutputToNull()
$voice.Rate = 1
$voice.SetOutputToWaveFile((Join-Path $OutputDirectory 'floor4.wav'))
$voice.Speak('不要停。悲伤只会让你回头。顶峰就在前面。')
$voice.SetOutputToNull()
$voice.Rate = 1
$voice.SetOutputToWaveFile((Join-Path $OutputDirectory 'floor5.wav'))
$voice.Speak('终于，没有什么能拖住你了。抬头，看看完美的自己。')
$voice.SetOutputToNull()
$voice.Dispose()
