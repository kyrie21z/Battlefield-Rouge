# #170 光固化打印扫描

生产入口仍为 `DoppelgangerSpawn`。真实地面接触、原中文对白和皇冠上升结束后，`PRINT_DURATION = 2.5` 秒的模拟时间线同时驱动身体扫描面、扫描环、皇冠圆柱光锥与 GPU 微粒。光束从悬浮的简洁无眼手皇冠向下展开；未打印部分是半透明冷蓝全息网格，扫描面为白金/冷蓝激光，成型部分为镜面白壳。实体化结束恢复原不透明战斗材质；戴冠归位后才开启 Hitbox 和 AI。暂停不消耗打印时钟。

- `levels/climax/shaders/print_slice.gdshader`：`print_progress` 为 0..1，从头至脚；`origin_y` 支持生产终局的世界高度偏移；所有动画使用注入的 `visual_time`，没有 `TIME`。
- `PrintProjection`：一个低面数光锥、48 个短寿命 GPU 火星；与真实扫描面同高。GPU emitter 仅在演出 setup 构造一次（Godot 构造会消费一次全局 RNG；fixed_seed 只固定发射，不能宣称构造无 RNG 消费），战斗内不构造。退出/完成停止音效和发射，减少移动 (`CrownVoiceSystem.reduced_motion`) 禁用火星及网格/光束移动。
- 音频为本 issue 原创确定性 PCM，2.5 秒激光双音、步进机械节奏及末尾锁合，无下载素材、无新语音，不消费玩法全局 RNG。复用 `ProceduralAudio` 的 PCM 归一化输出。
- 原角色 GLB、24 骨、武器模型与 CrownModel 保持；只替换逐实例材质，完成后撤销。未改 `actors/player/player.gd`。

## 验证入口

`tests/doppelganger_spawn_test.tscn` 使用真实生产 Player、DoppelgangerSpawn、世界碰撞和暂停菜单；新增 2.5 秒、原骨骼/武器材质、扫描环/微粒同步、暂停时钟、减少移动、战斗材质回收与存档隔离断言。`tests/print_slice_proof.tscn` 用外部审阅相机捕获同一生产流程的头/中/脚扫描阶段和最终战斗材质。

Godot 4.7.2 / Forward+ / RTX 4060 原生验证：`spawn-test.log` 37/37、`combat-test.log` 21/21；`native.log` 四张截图成功，最终四图均已逐张打开检查。`final-import.log` 无脚本错误/警告。

命令：`godot --headless --path . res://tests/doppelganger_spawn_test.tscn`、`godot --headless --path . res://tests/flawless_combat_test.tscn`、`flock /tmp/epic675-native.lock godot --path . res://tests/print_slice_proof.tscn`。godot 实际为 `/tmp/epic34-plan/godot-wsl` wrapper。

画面依次为 [头部成型](01-print-head.png)、[中段扫描](02-print-middle.png)、[脚部收束](03-print-feet.png)、[完成后战斗材质](04-combat-material.png)。原生运行持有 `/tmp/epic675-native.lock`，不与其他 Agent 的原生截图并发。测试入口由 MetaProgression autoload 自动选择独立 `meta_test_*` 存档，设置测试使用独立 cfg。

## 登记与验收边界

按本次负责人约束，ARCHITECTURE/GLOSSARY/ASSETS 不在子任务修改范围；新增术语与资源先登记于此：光固化打印 (`print_progress`)、全息未成型网格、皇冠投影光锥 (`PrintProjection`)、原创激光步进 PCM。无外部素材许可新增。

截图证明生产节点的原生渲染，流程测试证明计时及战斗交接。音频验证限于 PCM、时长和引擎播放；不声称人工听感验收。性能设计限定一个光束、一个扫描环、48 GPU 微粒；无目标设备全面性能验收或人工完整通关结论。
