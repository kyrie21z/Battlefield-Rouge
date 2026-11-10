# Epic 4 中文语音来源替换

官方 Kokoro-82M-v1.1-zh 模型及标准声线离线生成23段原始项目台词。权重已匹配发布方SHA-256，模型不进入仓库。完整参数、文本、音素与哈希见 tools/cinematic/voice_assets_manifest.json；来源及许可见 tools/cinematic/voice_assets.md。

Godot 4.7.2真实读取23个导入资源，每条检查24kHz单声道及清单时长，再同时低音量启动23个AudioStreamPlayer，验证播放进度和每条唯一finished：**48项全部通过**，日志 playback.log。这是一项解码与播放生命周期检查，不是人工听感验收。

完整Epic4组装后复测：
`godot --headless --path <repo> --script res://tools/cinematic/verify_voice_assets.gd`

23段素材分别归属#147六段、#148十一段、#149五段、#150一段；相应WAV与来源记录按各issue单独提交。

独立 PR 前缀验证只加载该 issue 的清单条目，不要求后续 PR 文件已经存在：

```sh
godot --headless --path <repo> --script res://tools/cinematic/verify_voice_assets.gd -- --issue=147
godot --headless --path <repo> --script res://tools/cinematic/verify_voice_assets.gd -- --issue=148
godot --headless --path <repo> --script res://tools/cinematic/verify_voice_assets.gd -- --issue=149
godot --headless --path <repo> --script res://tools/cinematic/verify_voice_assets.gd -- --issue=150
```

本次实际运行 #147 子集：六段真实解码、格式/时长、播放进度和 finished 共 14 项通过，见 `issue-147-playback.log`。本次未重复完整 23 段检查；默认全量模式仍保留。
