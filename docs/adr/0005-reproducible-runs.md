# ADR 0005：同一起点可复现一局（AC-07）

日期：2026-10-25　状态：已采纳（实现 Issue #14）

## 背景

[Cut-001b](../Cut-001b.md) 的 AC-07：同一起点可以复现一局，不许口头通过，证明是 fixture id 或录屏路径。[03_rules.md](../bible/03_rules.md) 和 [99_decisions.md](../bible/99_decisions.md) 一直写“本文不编造 fixture id”，因为仓库里还没有 fixture。

以前每一局都不一样：敌人的横移、开火间隔、散布、进掩体的判断都用没播种的随机数，占点的节拍和敌人的掩体冷却读的是墙钟，所以“再跑一局”没法检查，只能口头说“应该差不多”。

## 决定

1. **起点叫 fixture。** `fixtures/<id 小写>.tres`，类型 `RunFixture`，字段：`id`、`description`、`run_seed`、`start_zone`（`RunState.ZONE_SCENES` 的下标）、`buffs`（开局已有的增益）。现在有两个：

   | id | 起点 | 种子 |
   | --- | --- | --- |
   | `FX-001` | 新开一局：战区 1，没有增益 | 1001 |
   | `FX-002` | Boss 起点：直接进 Boss 关，带急速射击和扩容弹匣 | 2002 |

   FX-001 一路打到胜利，会经过小关 1 → 开局弹窗选增益 → 清守卫 → 后方增援里砸点 → 插旗冲击波 → 增益台按 F 再选 → 小关 2（进场不选，同样的增援和增益台）→ Boss（进场不选，无增援无冲击波；先打倒 Boss，再一锤击碎核心），也就是和 AC-02 串测。FX-002 从 Boss 关起步，进场不选，直接打 Boss，再一锤击碎核心。（原为：小关 1 → 选增益 → 小关 2 → 选增益 → Boss，且 Boss 进场再选一次。2026-10-27 issue #22 改为 3 次：开局前 1 次 + 两个小关结束各 1 次。同日 issue #25 加上增援、冲击波和增益台，见 [ADR 0007](0007-reinforcements-shockwave-pedestal.md)。同日的试玩修订把小关据点挪到 z≈-8，并让敌人不再互相推挤；碎块不抽全局随机数，见本决定末尾的例外。同日 issue #26 把 Boss 核心改成倒下后一锤击碎，见 [ADR 0004](0004-boss-wave-and-core.md)。issue #40 加了敌人找射击位、增援出生即寻位和锤击据点的噪声：寻位只用固定方向采样和射线，不抽随机数，但仍然改变敌人的移动与开火时刻。issue #42 把小关守卫和 Boss 关小兵从战场后方摊到前中后三段：位置和朝向写死在生成器里，不用随机数，但改变了每一局的走位和击杀顺序。）增援的刷出用本关 `seed()` 之后的全局 `pick_random()`，计时用物理 tick。Boss 的一锤不另抽随机数。所以仍在这条复现规则里。这次实跑的哈希写在 [issue #14 证明](../proof/issue-14/README.md)；玩法改了之后要重跑，不把哈希写进本决定。
2. **一局的随机数都来自 `run_seed`。** `ZoneDirector._ready` 在任何节点抽随机数之前调用 `seed(RunState.zone_seed())`，`zone_seed()` 是 `"<run_seed>/<战区号>"` 的哈希。这样一个战区的随机不取决于前面的战区抽了多少次。普通局每次新开都抽一个新的 `run_seed`，所以普通局仍然每局不同。
3. **重开回到同一起点。** `RunState.fixture` 不为空时，死亡或胜利后的 `start_new_run()` 重新套用这个 fixture（战区、增益、种子），不再随机。这就是 Priority_Backlog 里“阵亡重开保证 AC-07 的同一起点”。普通局重开不变：第 1 关、无增益、新种子。
4. **游戏时间用 `SimClock`，不读墙钟。** `SimClock.now()` 是从战区开头数起的物理 tick 数除以 tick 率。`CapturePoint.beat_time()`（命中时刻）和 `Enemy` 的掩体冷却改用它。从战区开头归零，是因为两个很大的时间相减，舍入结果会随绝对值不同而差最后几位，节拍偏移差最后一位也会让记录里的一行不同，哈希就变了（实际遇到过）。
5. **要求固定步长。** 复现只在 `--fixed-fps 60` 下成立：每帧 delta 恰好 1/60，每帧恰好一个物理 tick。正常游玩不受影响，`SimClock` 在正常游玩时会把当前 tick 已过去的那部分加上，节拍照样平滑。
6. **关掉导航的异步迭代**（`project.godot` 的 `[navigation]`：`world/map_use_async_iterations=false`、`world/region_use_async_iterations=false`）。开着时路径查询的结果取决于线程调度，同一个 fixture 在不同进程里偶尔会分叉（遇到过：同一起点一次 875 tick、一次 806 tick）。
7. **起点可以从命令行指定，也看得见。** `godot --path . -- --fixture=FX-002` 从该 fixture 起点开始游戏。F3 调试条多一行“起点 FX-002  种子 2002”，普通局显示“普通局（无 fixture）”和它的种子。命令行入口只改正常启动（当前场景是项目主场景）的场景；`fixture_test.tscn` 这类以别的场景启动的情况由该场景自己启动每一局，否则首轮会先跑一局做预热，导航图已经同步，和新进程后续轮次的首帧不同（#39）。
8. **证明用机器人玩一遍，再比较记录的哈希。** `tests/fixture_test.tscn` 对每个 fixture 用 `FixtureBot` 走真实流程（战区场景、选增益、结算界面、重开按钮）打若干遍，每遍写一份记录（击杀、占点、增益、每一锤、死亡/胜利，以及每隔 `--sample-every` 个 tick 一次玩家、敌人和占点的状态快照），取 sha256 前 16 位。检查：
   - 同一 fixture 的每一遍哈希、结果、tick 数都相同；
   - 起点确实是 fixture 规定的（战区、增益、种子）；
   - 种子加 1 的对照局哈希不同；
   - 不是超时。
   
   机器人不读时钟、不用随机数，只看场景和自己数的 tick。它用真实的输入动作移动、瞄准镜、挥锤；转向用 `Player.aim_at()`（等价于鼠标转动）；**射击用 `Weapon.try_fire()` 而不是 `fire` 动作**，因为无界面运行抓不到鼠标，`fire` 动作只在鼠标被抓取时生效。

## 怎么跑

```bash
godot --headless --fixed-fps 60 --path . res://tests/fixture_test.tscn -- [--fixture=FX-001] [--runs=3] [--trace-dir=<目录>] [--sample-every=30]
```

退出码 0 全部通过，1 有失败或没打完。哈希写在最后的 `== hashes` 里，记录写进 `--trace-dir`，文件名 `<ID>_run<N>.txt`，对照局 `<ID>_seed<种子>.txt`。可以拿两份记录 `diff`，第一处不同就是分叉点。单独跑一个 fixture（`--fixture=FX-002 --runs=3`）时，第一轮就是新进程的第一局；`== the session starts every zone` 一项检查没有别的节点提前启动战区，各轮哈希也必须相同。

## 不保证

- **只保证同一台机器、同一个 Godot 版本（4.7.2）、固定步长下的复现。** 不同机器、不同显卡驱动、不同 CPU 的浮点和物理结果有没有区别，没有验证，所以哈希**不写进 fixture 文件，也不跨机器强制比较**。换机器后要重新跑一遍，以那台机器上的各遍相同为准。
- **哈希依赖 `--sample-every`。** 默认 30 的哈希和 `--sample-every=1` 的不同，比较时两边要同样的参数。
- **人手玩不可能逐帧一样。** 人玩只保证同起点：同一个战区、同样的增益、同一个种子。录屏不在这次做，没有真人录屏。
- **玩法改了哈希就变。** 改敌人、武器、地图、抽随机数的次数（包括只影响视觉的，比如枪口闪光的旋转也从同一个全局随机数序列抽）都会让记录变化。这是预期的：它是回归报警，不是 bug。改完重新跑一遍，确认各遍之间仍然一致即可。
- 机器人是一个简单的玩家，不代表真人的打法。FX-001 能赢，只说明这个机器人在这个种子下能赢，不说明难度合适（难度见 TODO）。

## 给以后改动的规则

- 战区里的玩法代码不要读墙钟（`Time.*`、`OS.get_ticks_*`），要时间用 `SimClock.now()`，要延时用 `SceneTreeTimer` 或 `_physics_process` 里累加 delta。
- 不要在玩法里 `randomize()`，也不要用自己 `new()` 的 `RandomNumberGenerator`，用全局的 `randf()`、`randi()`、`pick_random()`、`shuffle()`，它们已经被战区的 `seed()` 管住。两处例外只做表现、不碰玩法随机序列：`weapons/procedural_audio.gd` 的独立随机数只合成音效波形；`zone/capture_point.gd` 的碎块用块序号算偏移，碎屑粒子用 `CPUParticles3D` 的 `use_fixed_seed`，都不调用全局 `randf()`。
- 新的战区场景上线时，把它加进某个 fixture（或新建一个）并跑 `fixture_test`。
- 新增 `RunState` 里会影响战区的状态，要放进 `RunFixture`，否则 fixture 就不是完整的起点。
