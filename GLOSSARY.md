# 术语表

设计目标见 `docs/Cut-001b.md`。代码列写的是仓库里现在的名字。还没落地的标成「尚未实现」。

## 当前代码

这些行描述现在能玩的循环，避免和验收编号打架。

| 术语 | 代码里的名字 | 含义 |
| --- | --- | --- |
| 一局 | Run，`RunState` | 从第 1 个战区开始，到死亡或胜利结束。死亡后所有增益清空。 |
| 战区 | Zone | 一张场景，有一组敌人和一个据点。现在 `RunState.ZONE_SCENES` 里是三张图：两张小关和 Boss 关。 |
| 清敌 | `Events.zone_cleared` | 战区内的守卫全部被消灭，据点建筑随之开放。 |
| 据点 | `CapturePoint` | 占点建筑（灰盒方块）。清守卫前锁定；开放后用锤砸，进度到 100% 插旗。进度只增不减。 |
| 锤 | `Hammer`，`hammer` 动作（E，临时） | 占点工具。按键后挥一次，冷却 0.9 秒。只发 `swung`，砸没砸中由据点判定。不是第四把养成近战。 |
| 命中时刻 | `CapturePoint.BEAT_PERIOD`，`beat_offset()` | 据点开放后每 1 秒出现一次，首次在 0.5 秒后。挥锤时刻离最近的命中时刻有多远，决定是不是完美打击。见 ADR 0003。 |
| 完美打击 | `CapturePoint.struck(perfect=true)` | 挥锤落在命中时刻 ±`perfect_window_ms` 内：本次进度 ×`perfect_multiplier`，金色音效、闪光和屏幕闪（AC-03）。窗口外是普通锤击：钝响，短促白光，只记普通进度。 |
| 占点配置 | `CaptureConfig`，`zone/capture_config.tres` | AC-03 的三个数：窗口 150ms、普通 +8%、完美 ×1.5。试玩只改这个文件。节拍周期和冷却是规则，写在代码常量里。 |
| 阶段 | `ZoneDirector.Phase` | `CLEAR_GUARDS` → `HAMMER_POINT` → `FLAG_PLANTED`，AC-01 的状态机。 |
| 节拍条、调试条 | `StrikeBar`、`CaptureDebug`（F3） | 节拍条在锤程内显示金色窗口和移动的标记。调试条显示阶段、进度、配置文件路径和三个数、上一击（AC-03 的证明）。 |
| 插旗 | `CapturePoint` 的 `Flag` 节点 | 进度 100% 时旗杆从建筑顶部升起，1.4 秒后才弹出选择或胜利界面。冲击波尚未实现。 |
| 增益 | `Buff`，`BuffPool.ALL` | 当前代码：六条通用增益（快速扳机、空尖弹、野战护甲、轻装上阵、扩容弹匣、快手），占点后三选一，只改 `Stats`。 |
| 数值 | `Stats` | 基础数值加上增益修正。新的 9 条也只走这里。 |
| 战区控制 | `ZoneDirector` | 管阶段、开放据点、弹出选择或结算、切场景。 |
| 掩体点 | `CoverPoint` | 掩体旁的地面标记。敌人会去看不到玩家的点蹲一会儿。 |
| 敌人 | `Enemy` | 状态机：待机、追击、交火、掩体、死亡。Boss 是它的大号版本（`actors/enemy/boss.tscn`）。 |

## 设计目标（Cut-001b）

| 术语 | 代码里的名字 | 含义 |
| --- | --- | --- |
| 小关 / 两段关 | `ZoneDirector.Phase`（增援尚未实现） | 清守卫 → 占点 → 插旗（AC-01）已可玩。增援没有做，所以现在只有“守卫”一波。MVP 有两关。 |
| 冲击波 | 尚未实现 | 插旗时推开剩余敌人。距离未定。 |
| 增援 | 尚未实现 | 占点阶段到来的敌人。不回退进度，只造成生命压力。 |
| 三流派 | `School`，`SchoolCatalog`，`SchoolBadge` | 狂战士（近战）、军火大亨（弹药特性）、鹰眼（爆头收益）。身份图标在 `assets/ui/schools/`。选择增益时 `SchoolBadge` 摆出剪影和方向。效果数值仍 Design-TBD。九条增益尚未实现。 |
| 九条增益 | 尚未实现 | 每派至少 3 条，共 9 条，图标不同（AC-08）。效果 Design-TBD。占位名见 `docs/bible/03_rules.md`。 |
| 进关选择 | 尚未实现 | 进入每一关之前选 1 条，含 Boss（AC-04）。 |
| 关末再选 | 尚未实现 | 小关结束后再选 1 条，本局叠加。Boss 结束后不选（AC-04）。 |
| Boss 关 / 城市核心 | `maps/boss.tscn`，`ZoneDirector.open_at_start` | 只有一波：1 个大敌人（Boss）加周围 6 个小敌人。城市核心开局就能砸，用同一套 `capture_config.tres`；敌人清不清零都不影响核心。Boss 有血条（HUD，不改胜负）。占满即胜，死亡即负（AC-02）。见 ADR 0004。 |
| 关卡选择 | 尚未实现 | 只切换已解锁的关。顺序：小关 1 → 小关 2 → Boss。这是规则，不是 AC-01。 |
| Cut-001b | 文档，不是脚本 | MVP 的 IN/OUT、解锁顺序和 AC-01 至 AC-08。 |
