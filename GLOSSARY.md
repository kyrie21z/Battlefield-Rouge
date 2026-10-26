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
| 枪 | `Weapon`，`weapons/rifle.tres` / `shotgun.tres` / `sniper.tres` | 一个节点扛三把枪，`data_set` 就是滚轮顺序。`data` 永远指向手里那把，开火、换弹、扩散都照它算。 |
| 切换枪 | `weapon_next` / `weapon_prev` 动作（滚轮上 / 下），`Weapon.select()` | 突击步枪 → 霰弹枪 → 狙击枪，循环。换枪会中断正在进行的换弹，但每把枪的弹匣和备弹分开记，换回来还是原样。开镜时这对动作改成换倍率（见「镜」）。 |
| 弹丸 | `WeaponData.pellets` | 一次扳机打几条射线。步枪 1 条，霰弹枪 9 条，每条都在同一个扩散锥里取方向、各自结算。`damage` 是**单颗**的伤害。 |
| 变焦 | `WeaponData.ads_fov`，`Weapon.fov_for()` | 机瞄时相机插值到的视野角：突击步枪 54°、霰弹枪 62°。有镜的枪不看 `ads_fov`，走「基础视野 ÷ 倍率」。 |
| 镜、开镜 | `WeaponData.scope_zoom_levels`，`Weapon.is_scoped()` | 有倍率表的枪瞄准时是开镜：视图模型隐藏、视野 = 75° ÷ 倍率、`ui/scope.gd` 在整屏上画分划和倍率读数（不遮黑，镜的身份靠变焦和分划）。狙击枪 2× / 4× / 8×。 |
| 倍率 | `Weapon.zoom_index` / `zoom_level()`，`cycle_zoom()` | 镜的放大倍数。开镜时滚轮上下换一档（越界回绕），并发 `zoom_changed` 让 HUD 重画读数；鼠标灵敏度同时除以倍率。 |
| 近战 | `MeleeWeapon`，`melee` 动作（V） | 当前近战武器挥一次。起手 → 生效窗口 → 收招三段；刀尖按屏幕上的两个点扫过去。视图模型只在挥砍时出现，同时收枪。 |
| 近战数据 | `MeleeData`，`weapons/melee/*.tres` | 一把近战的全部手感：伤害、距离、弧宽、命中目标数、起手/生效/收招时间、前冲、击退、握法、屏幕上的起止瞄准点、视图模型亮度。 |
| 切换近战 | `switch_melee` 动作（Q），`MeleePool.ALL` | 匕首 → 斧 → 太刀循环。挥砍中不允许切换。 |
| 击退 | `Enemy.apply_impact(direction, force, stagger)` | 近战命中时把身体推开，`stagger` 内敌人自己的 AI 不接管速度。 |
| 前冲、吸附 | `MeleeWeapon.lunge` 信号，`MeleeData.magnet_range` | 挥砍开始先找 `magnet_range` 内、`magnet_arc_degrees` 锥里**最近的敌人**：朝**它**冲 `lunge` 米（匕首 0.35 / 斧 0.45 / 太刀 0.55，0.1~0.12 秒），冲的时候覆盖玩家自己的速度，所以**不按方向键也会冲**；同一个敌人还会被当成这一刀的命中弧心（见下条），所以准星偏一点也算命中。空挥不动；敌人已在 `stop_distance` 内（贴脸）也不冲；超过 `magnet_range` 只砍不冲。每把的 `magnet_range` 都略短于自己的 `reach`。 |
| 弧心吸附 | `MeleeWeapon._magnet`，`_advance_phase()` | 吸附到的那个人在生效窗口开始时被记下来，锥形判定的中心从「准星方向」改成「指向那个人的方向」，所以 43° 偏角的敌人也能劈中（匕首的弧只有 ±35°）。没有目标时弧心就是准星。 |
| 握法 | `MeleeData.swing_style` | `CHOP` 双手过顶、中线往下劈（斧）；`RISING_CUT` 右手正握，屏幕左下扫到右上（匕首）；`FALLING_CUT` 右手正手，屏幕左上砍到右下（太刀）。 |
| 屏幕瞄准 | `MeleeData.cut_from_aim` / `cut_to_aim` | 归一化屏幕坐标（-1..1，+y 向上）里刀尖在起手和落点的位置。刀尖走两点之间的直线，所以 (-1.0,-0.98) → (1.0,0.98) 就是整屏对角。 |
| 刀尖深度 | `MeleeWeapon.tip_depth()`，`MIN_TIP_DEPTH` | 刀尖在眼睛前方多少米。屏幕坐标分不出「在画面里」和「在相机后面」，所以刀尖至少留在眼前 0.28 米，测试两端各查一次。 |
| 刀面朝向 | `MeleeWeapon.blade_facing()`，`MeleeData.edge_side`，`*_roll` | 0 = 刀刃正对镜头（屏幕上只有一条线），1 = 刀面正对镜头。刀尖瞄准只定住两个自由度，剩下的「绕刀轴转多少」由 `_roll_for()` 定：**挥砍方向横过刀刃时（`across` > 0.5）直接用「刃口领先」**，只有刀沿着自己走的时候才退回「刀面朝镜头」。模型刃在哪一侧写在 `edge_side`：不看几何（顶点太少、读不出凸面），看贴图上画亮的那条线——把模型摆平两个面各拍一张对照，太刀的亮边在 +Y，所以是 `+1`（匕首仍是 `-1`，没做过同样的对照）。写反了就是拿刀背砍，而「刃口领先」这个数写反了照样读正数，只有对照图和手感能抓。斧是对称双刃，`edge_side = 0`，只留刀面朝镜头那一项。 |
| 斧的板面 | `MeleeData.*_roll`（斧 75°） | 竖着往下劈时，斧头的板面要落在挥砍自己的竖直平面里，从眼睛看过去接近侧对镜头——斧刃先着地。板面正对镜头（`*_roll = 0`）就是拿斧子的平面往下拍，被试玩否掉了。75° 离纯侧对差 15°，留一点斧头的体量；测试查 `blade_facing()` < 0.45。 |
| 斧的握把 | `MeleeData.cut_from_hand` / `cut_to_hand`（斧 x = 0.05） | 两手放在中线附近、胸口前方，斧头走中线：双手举着、从最中间往下劈，刀尖 (0,0.79) → (0,-0.95) 从画面上缘劈到下缘。 |
| 视图模型亮度 | `MeleeData.view_brightness` | 视图模型不受光，材质亮度只能在这里提。斧头是深炭色，1.6 才看得清；匕首和太刀保持 1.0。 |
| 命中时刻 | `CapturePoint.BEAT_PERIOD`，`beat_offset()` | 据点开放后每 1 秒出现一次，首次在 0.5 秒后。挥锤时刻离最近的命中时刻有多远，决定是不是完美打击。见 ADR 0003。 |
| 完美打击 | `CapturePoint.struck(perfect=true)` | 挥锤落在命中时刻 ±`perfect_window_ms` 内：本次进度 ×`perfect_multiplier`，金色音效、闪光和屏幕闪（AC-03）。窗口外是普通锤击：钝响，短促白光，只记普通进度。 |
| 占点配置 | `CaptureConfig`，`zone/capture_config.tres` | AC-03 的三个数：窗口 150ms、普通 +8%、完美 ×1.5。试玩只改这个文件。节拍周期和冷却是规则，写在代码常量里。 |
| 起点 | Fixture，`RunFixture`，`fixtures/*.tres` | 一局的可命名起点：开始的战区、已有增益、随机种子（AC-07）。现有 FX-001（新开一局）、FX-002（Boss 起点）。死亡或胜利后重开回到同一起点。`--fixture=<id>` 从命令行进入。见 ADR 0005。 |
| 种子 | `RunState.run_seed`，`zone_seed()` | 一局所有随机数的来源。战区开头 `seed(zone_seed())`。普通局每次新开换一个，fixture 局固定。 |
| 游戏时间 | `SimClock` | 从战区开头数起的物理 tick 时间，不读墙钟。节拍和掩体冷却用它，固定步长下每次运行相同。 |
| 复现检查 | `tests/fixture_test.tscn`，`FixtureBot` | 机器人把每个 fixture 打若干遍，比较记录的哈希（AC-07 的证明）。需要 `--fixed-fps 60`。 |
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
