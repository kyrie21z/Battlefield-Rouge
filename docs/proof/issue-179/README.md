# #179 悲伤音频

## 实现与接线

- `SorrowAudioDirector extends RealmAudioDirector`：本领域环境，不改变战斗规则。实际脚底在镜潭范围内、着地且有位移才涉水；平台/空中/静止/传送不响。冲刺事件只切换水滑音色，仍须实际涉水移动。
- 原创 `SorrowSoundBank`：4 秒雨滴背景、涉水/滑水、回流水波、三股泪晶喷射、水钟、薄冰/玻璃碎响；固定局部 RNG、缓存 16-bit PCM，无外部素材。
- `SorrowRealm.set_audio_managed(true)` 关闭旧 splash 播放，保留涟漪与独立场景 fallback。
- 父框架在**每个领域**安装 `SorrowBoonAudio.setup(player: Player, realm_index := -1)`，传真实 realm。拾取/破碎不限定 realm；旧 `clock_struck` 水钟兼容限定 realm 3 且未失去悲伤；正式地图没有可敲钟据点，生产水钟绑定下述真实潮汐释放。8 槽有界复用，死亡停止。
- 成功 `consume()` 后 `SorrowEffect` 才派发 `sorrow_tear_collected {position: origin}`，失败或重复拾取不响。视觉可以复用该事件。
- 玻璃音复用 `PsycheFragments._after_damage` 单源，经公开 `set_brittle_audio(stream)` 替换音色；对任意有效 unbuffered HP 损失响一次，不添加 damage listener。被闪避/屏障完全吸收不会误响。该规则跨领域继续存在。
- Boss 剥夺后立即停止雨与所有环境水音（无潮湿 crossfade 尾音）。后续真实卡牌泪晶事件仍可响。
- 未知音色回退父类 `get_sound`，事件先调用父类，保证悲伤房间中的跨领域馈赠仍有原音色。

共享 `RealmAudioDirector` / `RealmSoundBank` / `RealmStage` 属父任务，仅复制前两者用于本地验证，不属于本提交。完整运行须先集成共享 #176 框架及每领域 SorrowBoonAudio 接线。

## 验证

自动场景：`res://tests/sorrow_audio_test.tscn`（Godot 4.7.2）。headless 与加锁 Forward+ 原生运行均为 **16 checks, 0 failed**，无脚本错误（`headless.log` / `native.log`）。

```sh
flock /tmp/epic675-headless.lock /tmp/epic34-plan/godot-wsl --headless --path . --quit-after 900 res://tests/sorrow_audio_test.tscn
flock /tmp/epic675-native.lock /tmp/epic34-plan/godot-wsl --path . --quit-after 900 res://tests/sorrow_audio_test.tscn
```

覆盖真实水面移动、平台、冲刺、消费去重、跨领域泪晶、钟、暂停、蒸干、连续 HP 损伤与死亡、声部上限。

自动测试证明触发和生命周期，不代表人工听感验收。空灵温润、科技感与玻璃痛感需在有音频输出的设备上试听。

## 父提交统一补充文档

ARCHITECTURE：`audio/realms` 由房间注入玩家/几何，环境和跨领域馈赠反馈分离，不读 RunState。
GLOSSARY：镜潭声景、`sorrow_tear_collected` 成功拾取反馈。
ASSETS：以上为本仓库原创程序合成音频，无下载/旧工程素材。

## 集中生产集成

`tests/sorrow_audio_integration_test.tscn` 在真实 Sloth/Fear/Wrath/Sorrow 房间验证自动安装、跨域泪晶、玻璃单源，以及真实 Sorrow Boss 死亡后雨声停止：**8 checks, 0 failures**（`integration.log`），Godot 4.7.2 headless，无脚本错误或退出警告。缺少专属环境 director 的房间由 RealmStage 安装通用 RealmAudioDirector，确保跨域馈赠不会依赖其他声景 issue 的合并顺序。

## 正式水钟触发修复

当前正式地图不包含 CapturePoint。水钟作为哀泣巨碑真实径向潮汐（SorrowTide）释放的共鸣层，由注入的 SorrowAudioDirector 观察 `tides_released`：只有实际 `_release` 创建水波后才递增，不修改 Boss 节拍/攻击，不伪造 `clock_struck`。旧敲钟事件只保留兼容。

真实 sorrow_boss 场景中，begin_move(TIDE) 的预警不响；物理蓄力完成产生一个 SorrowTide 和一个水钟；重复观察不重播；下一次蓄力中 Boss 死亡后停止所有水声、没有补播。连同四领域生产接线共 **12 checks, 0 failures**（`tide-integration.log`），Godot 4.7.2 headless，无脚本错误或退出警告。

统一术语应将正式“水钟”说明为巨碑径向潮汐释放的共鸣；旧敲钟事件是兼容入口，不代表正式地图有可交互钟据点。
