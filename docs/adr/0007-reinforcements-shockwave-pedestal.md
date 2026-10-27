# ADR 0007：小关据点居中、后方增援、插旗冲击波与增益台

日期：2026-10-27　状态：已采纳（实现 Issue #25；节奏和超时是临时默认，待试玩）

## 背景

[Cut-001b](../Cut-001b.md)、[ADR 0002](0002-mvp-deadzone-occupy.md) 和 [Core_Loop](../Core_Loop.md) 写了小关要在增援里砸据点，插旗时用冲击波处理剩下的敌人。此前小关只有一波守卫，据点放在关卡尽头（玩家出生在 z=+22，据点在 z≈-22）。通关增益在插旗 1.4 秒后自动弹出（[ADR 0003](0003-hammer-capture-timing.md) 第 7 条）。Boss 关不在这次范围，仍按 [ADR 0004](0004-boss-wave-and-core.md)。

## 决定

1. **小关据点在中央。** `tools/gen_zones.py` 把小关 1、2 的据点放在 z=0。玩家仍从 +z 进场。守卫站在据点周围。增援标记 `reinforcement_spawn` 放在据点后方 z≈-24 到 -25，每关三个。中线走廊不放掩体，出生点和刷怪点都能走到据点。Boss 关的布局不改，也不放刷怪点。
2. **增援只在小关、只在据点开放之后。** 守卫清完的同一时刻刷第一波，之后每 `interval_seconds` 再刷一波。默认每波 2 只，场上同时存在的增援最多 6 只（含已经在逃跑的）。插旗后停止。这些数在 `zone/reinforcement_config.tres`，`ZoneDirector.reinforcement_config` 引用它。Boss 关这个资源为空。
3. **增援不碰进度。** 它们不在守卫名单里。击杀、刷出、逃跑都不开关据点，也不改 `CapturePoint.progress`。清守卫的 `Events.zone_cleared` 仍只在守卫归零时发一次。
4. **刷怪点用全局随机数。** 每只增援从本关标记里 `pick_random()`。战区开头的 `seed(zone_seed())` 已经把全局随机数定住（[ADR 0005](0005-reproducible-runs.md)）。计时用 `_physics_process` 累加 delta，不读墙钟。标记按名字手排，避免 `sort_custom` 在两次加载里排出不同顺序、把同一种子的序列带偏。
5. **冲击波不造成伤害。** 小关插旗时放一个扩散的环和一声 `shockwave` 音效，并让场上每个存活小怪（守卫或增援，不含 Boss）进入 `Enemy.State.FLEE`：停止攻击，沿导航跑向最近的后方刷怪点。到达 `FLEE_ARRIVE`（1.25 米）或超过 `flee_timeout_seconds`（默认 14 秒）后 `queue_free`。这条移除不发 `Events.enemy_killed`，不算击杀。逃跑途中若被玩家打死，仍算击杀。Boss 关不播冲击波。
6. **通关增益改为增益台。** 小关插旗后不暂停、不自动弹出选择。旗旁出现 `BuffPedestal`（灰盒，提示「按 F 领取增益」）。玩家在 2.4 米内按 `interact`（F）才走原来的 `_offer_buff("clear")`。选完仍暂停并载入下一关。开局那次（`zone_index == 0` 的 `enter`）保持现在的弹窗。Boss 关没有增益台，插旗 1.4 秒后仍直接胜利。
7. **目标文字。** 小关插旗后 HUD 目标为「旗已插上，到增益台按 F 领取增益」。

## 对复现的影响

增援的时机和落点都从战区种子和物理 tick 来，所以 fixture 仍可复现。玩法变了，FX-001 的哈希会变。FX-002 从 Boss 关起步，本决定不改 Boss 的流程；若哈希仍和改前相同，是因为这条路径没走到增援、冲击波和增益台。新哈希记在 [issue #14 证明](../proof/issue-14/README.md)，不写进 ADR 0005。

## 后果

- 默认 8 秒、每波 2 只、上限 6 只、逃跑 14 秒都是试玩前的临时数。调手感只改 `zone/reinforcement_config.tres`。
- 冲击波没有击退米数。剩余敌人是跑去后方消失，不是被震飞一段距离。
- 没有开窗口试玩。增援的压力和增益台的位置是否好用，这次没有手感结论。
- ADR 0003 第 7 条的「插旗 1.4 秒后弹出选择」只还适用于 Boss 的胜利界面。小关改由增益台打开选择。
