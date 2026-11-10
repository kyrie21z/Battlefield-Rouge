# #180 皇冠与终局音频

## 运行链

`CrownVoiceSystem` 为实际语音播放器安装 `CrownVoiceDSP`；不会新增第二条语音。公开接线接口：

```gdscript
var dsp := CrownVoiceDSP.new()
dsp.setup(source, 0.5) # AudioStreamPlayer 或 AudioStreamPlayer3D
add_child(dsp)
radiance_changed.connect(dsp.set_radiance) # (level: int, strength: float)
```

- `audio/crown/crown_audio_filter.tres` 是实际使用的处理链配置：300Hz high-pass → 3500Hz low-pass → 轻微非线性泛音 → 高频 presence → 金属板风格混响。使用 Godot 原生算法混响，无外部脉冲响应素材。
- 自发光强度 0.5→16.5888 提升 wet 0.12→0.43、harmonic drive 0.04→0.22、presence gain 1→2.2，混响阻尼降低。每个来源复制效果，避免多皇冠互相修改。
- 每实例独立总线 send 到来源原总线；退出移除自己的总线，原总线若先被上层移除则安全回到 Master。停止/替换语音、禁用和暂停时清空混响延迟线，避免不可见来源的残响。
- 正式接入随行 CrownVoiceSystem、开场 ENCOUNTER 的皇冠，以及 doppelganger-spawn 的 3D 皇冠；保留原开场 interview 音频链。原始中文 WAV 未改写。

`BodyReassembly` 仅移交音频所有权和计算相同的台词时长，物理、字幕、阶段时长、玩家移动锁定逻辑不变。`ClimaxAudio` 监听真实 `phase_changed` / `line_started`：

1. SHATTER：`AudioVacuum` 立刻租借 Master 静音，0.1 秒有效模拟时间后先恢复原值再播放原创立体声宽频爆碎。仅改 mute，不动 Master volume。暂停释放并冻结剩余时长；恢复后继续剩余时长；死亡、组件/场景提前退出即取消。静态租约支持重叠来源最后一个退出时恢复初值，包括原本已静音。
2. CRIES：复用原 `slumber/fear/spite/sorrow/acceptance.wav`，保留原 pitch 与语音时长。四声 pan 为 -0.8/+0.65/-0.35/+0.85，接受自我回到中心，单语音声部不叠播。
3. REBUILD：原创暗金流体立体声共鸣 + 原创钢琴单音 D4、A4、E5、D5，每 0.8 秒一音。钢琴通过敲击瞬态、非整数倍微调的钢弦泛音和分层衰减合成，无采样来源。四音各一有界声部。

## 验证与审听材料

Godot **4.7.2**，`crown_climax_audio_test.tscn`：headless 与加锁原生 Forward+ 均 **25 checks, 0 failed**。覆盖真实身体爆碎触发、暂停释放、100ms 真空、原始中文语音、五句顺序与声像、完整重组、钢琴、死亡/退出、原静音状态、重叠租约、原总线提前删除，以及总线数量无泄漏。

```sh
flock /tmp/epic675-headless.lock /tmp/epic34-plan/godot-wsl --headless --path . --max-fps 60 --quit-after 900 res://tests/crown_climax_audio_test.tscn
flock /tmp/epic675-native.lock /tmp/epic34-plan/godot-wsl --path . --max-fps 60 --quit-after 900 res://tests/crown_climax_audio_test.tscn
flock /tmp/epic675-native.lock /tmp/epic34-plan/godot-wsl --path . --max-fps 60 --quit-after 1200 res://tests/crown_audio_render_proof.tscn
```

`audio/crown_soft.wav` 与 `audio/crown_blazing.wav`：原生 Godot 混音器通过**真实 DSP 总线**、AudioEffectRecord 捕获的同一原始台词前三秒及残响。`shatter.wav`、`gold_flow.wav`、`piano.wav`：生产合成器直接输出。它们是审听材料，无运行时依赖；现有 `docs/proof/.gdignore` 使引擎不导入这些预听文件，因此未生成 `.import`；`audio-analysis.json` 记录长度、峰值、RMS、声道差异与 SHA-256。`original-voice-sha256.json` 核对全部原始中文语音与基准 Git 内容一致。

原有皇冠语音 **29/29**、完整身体重组 **14/14**（`--max-fps 60` 跑完整个真实时长）、温柔碎片 **14/14** 与悲伤馈赠核心 **ALL PASSED**；结果见同目录日志。最终资源导入无脚本错误或警告。自动验证只证明接线、时序、信号和音频内容存在，**没有人工听感验收**；神圣辨识度、电影冲击力与温暖释然仍需在耳机/音箱上试听。

## 父提交统一登记

ARCHITECTURE：独立 Crown DSP 生命周期；ClimaxAudio 仅消费身体阶段信号，AudioVacuum 用可释放租约恢复全局静音。
GLOSSARY：皇冠收音机声、声音真空、四声心声、暗金重组声。
ASSETS：所有新声效为本仓库原创程序合成；预听声效是其 PCM 导出，皇冠预听复用现有已授权中文语音并原生 DSP 录制；原始语音保持原文件和许可。无下载、无旧工程素材、无新增 TTS。

## 集中生产接线验收

- 开场仅在 ENCOUNTER 开始收音机处理，现实采访仍走原链；提前跳过和皇冠演出中跳过均停止声音，场景退出释放两层专属总线。
- 最终 Boss 皇冠 DSP 跟随实际模型自发光；死亡停止语音且后续真实落地 DROP→RANT 不会重播。
- 组合根以 `setup_combat(player)` 注入通用 RealmAudioDirector，终局没有领域环境底噪，但保留跨领域技能声音。真实 Weapon 射线命中 Boss 实际破绽，HP、critical_weak_hits 与晶面破裂都成立，且只产生一个受控晶碎声；真实泪晶拾取也有声音。
- 新 `crown_audio_integration_test.tscn` **13 checks, 0 failures**；已有 `opening_sequence_test` **16/16**、`doppelganger_spawn_test` **28/28**。集中 Godot 4.7.2 headless 日志无脚本错误或退出警告，分别见 `integration.log` / `opening-regression.log` / `doppelganger-regression.log`。
- 独立复核 Crown/climax 原始 WAV 共 **23** 个，与 b9457c7 字节完全一致；5 个预听 WAV 均可解析为16位立体声。没有人工听感验收。
