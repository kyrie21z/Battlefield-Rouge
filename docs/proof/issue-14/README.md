# Issue #14 Proof（AC-07）

同一起点可以复现一局。证明是 **fixture id**：`FX-001`、`FX-002`（`fixtures/fx-001.tres`、`fixtures/fx-002.tres`）。做法、规则和限制见 `docs/adr/0005-reproducible-runs.md`。

由 `tests/fixture_test.tscn` 检查：机器人（`tests/fixture_bot.gd`）通过真实的游戏流程把每个 fixture 打若干遍（战区场景、选增益、结算界面、重开按钮），每遍写一份记录（击杀、占点、选增益、每一锤、胜负，以及每 30 个 tick 一次玩家、敌人和占点的状态快照），取 sha256 前 16 位。

```bash
godot --headless --fixed-fps 60 --path . res://tests/fixture_test.tscn -- --runs=3 --trace-dir=<目录>
```

要加 `--fixed-fps 60`，不加会在第一项检查就失败。退出码 0 为全部通过。

## 结果

`run.log` 和 `traces/` 是 issue #14 当时的证据，这次没有覆盖。下面的表是 #25 改完小关据点、增援、冲击波和增益台之后，用 Godot 4.7.2、`--fixed-fps 60`、`--runs=3` 新跑的。哈希因 #25 改了小关流程而变化。新哈希与引入这次修订的提交是同一次工作区；提交 SHA 就是包含本文件的那次提交。

两个独立进程各跑一次。每个进程里每个 fixture 打三遍（第一遍从 fixture 起点进入，后两遍按结算界面的重开按钮），再各打一遍种子 +1。两进程的 `== hashes` 相同，八份记录（三遍加种子 +1，两个 fixture）跨进程 `cmp` 逐字节相同。

| fixture | 起点 | 种子 | 结果 | 长度 | 哈希（两进程、每进程三遍全部相同） | 种子 +1 的对照局 |
| --- | --- | --- | --- | --- | --- | --- |
| `FX-001` | 战区 1，没有增益 | 1001 | 胜利 | 3053 tick（50.9 秒） | `981599f0236f2a55` | 种子 1002：胜利，2989 tick，`1690347621de618a` |
| `FX-002` | Boss 关，急速射击 + 扩容弹匣 | 2002 | 胜利 | 1434 tick（23.9 秒） | `bb9162c8424ff945` | 种子 2003：胜利，1314 tick，`282bdcc8eb7623f3` |

#14 当时公布、并且仍留在 `run.log` / `traces/` 里的数字是：FX-001 胜利，3671 tick，`8306f3301da22b35`（种子 1002：3953 tick，`76e4b0a74847397c`）；FX-002 胜利，1434 tick，`bb9162c8424ff945`（种子 2003：1314 tick，`282bdcc8eb7623f3`）。#21 接入每关入场选择之后，[AC-04 证明](../ac-04-ac-08/README.md) 里记过另一组：FX-001 3875 tick、`faf979e483061388`，FX-002 1375 tick、`9afe0ddb9ac0b983`。#22 改完选择时机之后记过：FX-001 胜利，3887 tick，`b8ce9783842e8153`（种子 1002：3853 tick，`fe4de49c4771afc2`）；FX-002 仍与 #14 相同。

这次 FX-002 的哈希、tick 和种子 +1 对照与 #14 公布值相同，而且新记录和 `traces/FX-002_run1.txt`、`traces/FX-002_seed2003.txt` **逐字节相同**。记录里没有 `buff` 事件：FX-002 从 Boss 关起步，按 `zone_index == 0` 判断，进场不选，机器人从第一下就打。#25 不给 Boss 增援、冲击波或增益台，所以这条路径没变。#21 那次要先选卡，所以当时的哈希不同。FX-001 从第一行就和 `traces/FX-001_run1.txt` 不同，也和 #22 的 `b8ce9783842e8153` 不同。

- 种子加 1 后整局不同，说明种子确实在起作用。
- 每遍都检查了起点确实是 fixture 规定的（战区、增益条数和内容、种子）。

`FX-001` 一路走到胜利，和 AC-02 串测。选择仍是 3 次，通关那两次改成走到增益台再按 F。种子 1001 的记录：tick 1 选 `firearm_damage.tres`；清掉 Enemy1、Enemy2、Enemy4、Enemy3，tick 65 `zone_cleared 0`；增援击杀在 428、442、552；tick 815 `point_captured 0`；tick 817 选 `firearm_rate.tres`；小关 2 清完六名守卫，tick 914 `zone_cleared 1`；增援击杀在 1330、1571；tick 1664 `point_captured 1`；tick 1679 选 `firearm_magazine.tres`；Boss 关 tick 1926 击倒 Boss，tick 2129 击倒 Enemy5；tick 2969 `point_captured 2`；tick 3052 `run_won`；tick 3053 `end 胜利`。全程 27 次 `strike perfect`，0 次 `strike ordinary`。#14 原文写的是 `light_boots` / `rapid_fire` 和 3671 tick，那是当时的记录，见 `traces/`，不是这次的路径。#22 的 3887 tick 同样留在上一段，不是这次的路径。

| 文件 | 内容 |
| --- | --- |
| `run.log` | #14 当时三个进程的完整输出，加记录文件的 `cmp` 对比和对照局的 `diff`。#22 和 #25 都没有重写它 |
| `traces/FX-001_run1.txt`、`traces/FX-002_run1.txt` | #14 的起点局记录。FX-002 与 #25 这次实跑逐字节相同；FX-001 从第一行就不同 |
| `traces/FX-001_seed1002.txt`、`traces/FX-002_seed2003.txt` | #14 的种子 +1 对照。FX-002 的对照与这次实跑逐字节相同；FX-001 的对照不是这次的 `1690347621de618a` |

自己复现：在项目根目录跑上面的命令，结果里的哈希应与上面的新表相同（同一台机器、Godot 4.7.2、`--fixed-fps 60`）。不要拿新的 FX-001 记录去和 `traces/FX-001_run1.txt` 比逐字节，那份是 #14 的。FX-002 可以比，这次是相同的。默认每 30 tick 取一次快照，哈希依赖 `--sample-every`，所以比较时别改它。游戏里 `godot --path . -- --fixture=FX-002` 从该起点开始，F3 调试条显示“起点 FX-002  种子 2002”。

## 局限

- **只证明了本机复现。** 哈希是在这台机器上算的，换机器（CPU、驱动）后物理和浮点结果有没有区别没有验证，所以哈希没有写进 fixture 文件，也不跨机器强制比较。换机器后要自己跑一遍，以那台机器上各遍相同为准。
- **没有真人录屏。** 机器人是简单玩家，不代表真人打法；FX-001 能赢只说明这个机器人在这个种子下能赢，不说明难度合适。
- **机器人用 `Weapon.try_fire()` 开火，不是 `fire` 动作。** 无界面运行抓不到鼠标，`fire` 动作只在鼠标被抓取时生效。移动、瞄准镜、挥锤走的是真实输入动作，转向用 `Player.aim_at()`（等价于鼠标转动）。射线、散布和伤害是游戏本来的。
- **人手玩做不到逐帧一样，** 人玩只保证同起点：同战区、同增益、同种子。
- 记录文件由测试在运行中写出，没有后处理。`run.log` 末尾的 `ObjectDB instances were leaked` 和 `resources still in use` 是退出时仍有音频流在播放，每个测试进程都会有，与复现无关；`run.log` 里也保留着。
- 为了让复现成立改了几处游戏代码：节拍和掩体冷却改用 `SimClock`（战区开头归零的 tick 时间）、战区开头 `seed()`、关掉导航的异步迭代（`project.godot`）。已用 `tests/capture_hammer_test.tscn`、`boss_test.tscn`、`school_icons_test.tscn` 确认没有改坏原有行为。
