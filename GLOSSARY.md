# 术语表

设计目标见 `docs/Cut-001b.md`。代码列写的是仓库里现在的名字。还没落地的标成「尚未实现」。

## 当前代码

这些行描述现在能玩的循环，避免和验收编号打架。

| 术语 | 代码里的名字 | 含义 |
| --- | --- | --- |
| 一局 | Run，`RunState` | 从第 1 个战区开始，到死亡或胜利结束。死亡后所有增益清空。 |
| Pride 开场 | `ui/game_start.tscn`、`ui/pride_opening/opening.tscn` | 普通启动自动播放的五句引导，可逐句推进、观察和跳过；确认后进入原开局三选一。每次启动播放一次，死亡重开和 fixture 不重播。 |
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
| 阶段 | `ZoneDirector.Phase` | 第一关先 `BUFF_SELECT`，再 `CLEAR_GUARDS` → `HAMMER_POINT` → `FLAG_PLANTED`。小关 2 进场直接 `CLEAR_GUARDS`，Boss 进场直接 `HAMMER_POINT`。两个小关在增益台按 F 后再进入 `BUFF_SELECT`。 |
| 节拍条、调试条 | `StrikeBar`、`CaptureDebug`（F3） | 节拍条在锤程内显示金色窗口和移动的标记。调试条显示阶段、进度、配置文件路径和三个数、上一击（AC-03 的证明）。 |
| 插旗 | `CapturePoint` 的 `Flag` 节点 | 进度 100% 时旗杆从建筑顶部升起。小关同时播冲击波并亮出增益台；Boss 等 1.4 秒后直接胜利。 |
| 增益 | `Buff`，`BuffPool.ALL` | 当前九卡：枪械、刀具、技能各三张；独特图标、稳定 id 和叠层说明，只修改 Stats。旧六张通用卡保留为历史资源及 fixture 兼容。 |
| 发牌袋 | `BuffPool.reset()` / `pick()` | 每次每派一张，先核心再另两张，用完重洗；全局随机受战区种子控制，新局及 fixture 重开清袋。 |
| 选择历史 | `RunState.selection_history` | 关卡、enter/clear、卡片 id 和名称。完整获胜是开局进一、过一、过二，共三条。小关 2 和 Boss 进场不选。（原为进一、过一、进二、过二、进 Boss，共五条。） |
| 刀具增益 | `Stats.MELEE_DAMAGE` / `MELEE_SPEED` / `MELEE_RANGE` | 叠在当前 `MeleeWeapon` 上。基数都是 1，没选刀具卡时三把近战保持 `.tres` 原值。 |
| 主动护盾 | `PlayerShield`，`shield` 动作（G） | 任意技能卡解锁，基础 1 秒无敌，结束后冷却 8 秒；分层紫色盾缘保留中心视野，挡伤时亮闪，反击卡同时蓄能。Q 是切近战。F 是 `interact`，小关插旗后在增益台读取。 |
| 护盾反击波 | `CombatTraits`，`PlayerShield.show_counter_pulse()`，`ReloadCharge.blast()` | 反击卡挡伤后到期结算每层 25 BODY、7 米球形范围及墙体遮挡。第一人称有 0.72 秒双层外扩波纹，世界波前到水平半径 7 米后淡出并配能量声；余波不延长无敌，也不再次伤害。 |
| 冲刺 | `PlayerDash`，`dash` 动作（Shift） | 沿面朝方向（含俯仰）冲 5 米：无输入时取镜头前方，有输入时在镜头基下合成方向并归一化，A/D 仍沿水平轴。持续 0.18 秒；速度 = 距离 ÷ 持续时间，冲刺期间接管完整 `velocity`（含 y，不受重力），结束时交还水平走路速度并把 `velocity.y` 归零。2 格充能，每 1.5 秒按顺序回 1 格，HUD 左下的两个小格显示剩余与回充进度。空中每次离地只能冲 1 次，落地恢复。冲刺期间 `Health.dash_invulnerable` 提供 0.18 秒无敌；它和护盾的 `invulnerable` 分开记，所以两者同时生效时互不覆盖。冲刺打断开镜，不打断换弹；视野短暂外扩后回落，死亡时取消。 |
| 三张核心卡 | `CombatTraits` | 危险弹匣为空仓换弹完成后储存一枚、C 主动投掷；子弹收藏家为挥刀弹反、下次开枪释放收藏；反击护盾为挡伤后到期在 7 米内固定反击。详见当前九增益说明。 |
| 危险弹匣 | `CombatTraits`，`ReloadCharge`，`throw_magazine` 动作（C） | 对应增益解锁；成功完成空仓换弹后最多储存一枚，持有不计引信。切枪保留已储存枚，取消换弹不发放；C 投出时消耗库存并读取当前 Stats。投速 24 米/秒，投出后引信 1.5 秒；每层在 1 米内造成 120 伤害，向 3.5 米边缘衰减至 60，墙体阻挡。死亡或换关清除临时库存。 |
| 能力槽 | `AbilityBar`，`AbilitySlot` | 图形 HUD 右下方的 G 护盾、V 近战、C 弹匣方槽。C 无增益时锁定，有增益但未储存时暗态 `0/1`，储存后亮态 `1/1`，投出回暗态；不在护盾槽重复画危险弹匣角标。 |
| 受击反馈 | `Health.damaged`，`HUD`，`DamageIndicator` | 玩家中枪时的呈现：边缘红色暗角（中心不填色）、受击音效（0.06 秒内的命中合成一次）、指向攻击者的屏幕边缘弧线（存命中时的世界位置，按玩家朝向每帧重算）、只晃渲染相机的镜头后坐，以及 30% 生命以下的脉冲暗角与心跳（35% 以上退出）。格挡和弹反不是掉血，没有这套反馈。 |
| 击杀反馈 | `HitReaction`，`HUD.KillText`，`DebrisBurst.spawn_death()` | 击杀时的呈现：模型向射击者反方向偏 23°（只动 mesh，不动 CharacterBody 和 hitbox），胸口（爆头在头部、Boss 2.5 倍）爆出体块与 0.12 秒亮光，准星下方显示「击杀」/「爆头击杀」/「双杀」/「三杀」/「连杀 ×N」；爆头击杀的 hitstop 是 0.075 秒，普通击杀 0.05 秒。 |
| 数值 | `Stats` | 基础数值加上增益修正。新的 9 条也只走这里。 |
| 战区控制 | `ZoneDirector` | 管阶段、开放据点、增援、冲击波、增益台、弹出选择或结算、切场景。 |
| 掩体点 | `CoverPoint` | 掩体旁的地面标记。敌人会去看不到玩家的点蹲一会儿。 |
| 射击位 | `Enemy.State.SEEK`，`Enemy.firing_position`，`FiringPositionBoard` | 交火时站的、能看到玩家的位置。候选是现有掩体点加玩家周围固定方向的两圈采样点（8 / 20 米），只保留导航可达、从眼睛高度到玩家不被世界挡住的点；离自己近的优先，挨着掩体减分。多个敌人共用一个 `FiringPositionBoard`，3.5 米内别人已订的点不再选。走到后进入交火；看不见玩家 0.5 秒或离玩家近于 6 米就重找。找不到才退回朝玩家追。增援出生即寻位，不抽随机数。 |
| 敌人 | `Enemy` | 状态机：待机、追击、交火、掩体、死亡、逃跑、找射击位（SEEK）。Boss 是它的大号版本（`actors/enemy/boss.tscn`），换用 Hazmat 模型（`Enemy.model_scene`），爆头倍率降到 1.25。 |

## 设计目标（Cut-001b）

| 术语 | 代码里的名字 | 含义 |
| --- | --- | --- |
| 小关 / 两段关 | `ZoneDirector.Phase` | 清守卫 → 占点（增援从后方持续来）→ 插旗冲击波 → 增益台（AC-01）。MVP 有两关。 |
| 增援 | `ReinforcementConfig`，`reinforcement_spawn` | 据点开放时从后方刷出的 `Enemy`。默认每 8 秒 2 只，场上最多 6 只，插旗后停止。不回退进度，只造成生命压力。数在 `zone/reinforcement_config.tres`。 |
| 冲击波 | `ZoneDirector._play_shockwave` | 小关插旗时触发。不造成伤害。存活小怪进入逃跑，沿导航去后方刷怪点，到达或超时后消失，不算击杀。 |
| 增益台 | `BuffPedestal` | 小关插旗后出现在旗旁的灰盒。走近按 F（`interact`）才打开通关三选一。开局那次仍是弹窗。 |
| 逃跑 | `Enemy.State.FLEE`，`begin_retreat` | 冲击波之后的状态：不再攻击，跑向后方刷怪点。移除时不发 `Events.enemy_killed`。 |
| 三流派 | `School`，`SchoolCatalog`，`SchoolBadge` | 当前按用户已有改进为枪械、刀具、技能；历史狂战士/军火大亨/鹰眼图标与设计保留。取舍见 ADR 0006。 |
| 九条增益 | `BuffPool.ALL` | 每派 3 条，共 9 条，图标不同（AC-08）；当前效果为可调试玩默认，非最终平衡锁定。 |
| 进关选择 | `ZoneDirector._offer_buff("enter")` | 只在一局第一关（`RunState.zone_index == 0`）开打前选 1 条。小关 2 和 Boss 进场不选。按是不是一局的第一关判断，不按 fixture 起点（AC-04）。 |
| 关末再选 | `ZoneDirector._offer_buff("clear")`，`BuffPedestal` | 两个小关插旗后，到旗旁增益台按 F 才各选 1 条，本局叠加；Boss 结束后不选（AC-04）。 |
| Boss 关 / 城市核心 | `maps/boss.tscn`，`ZoneDirector.is_boss_zone` | 只有一波：1 个大敌人（Boss）、2 名护卫（2–6 米内）和 4 名放在前沿 / 中段的小敌人。Boss 活着时核心关闭，目标「打倒 Boss」。Boss 倒下后核心开放，一锤击碎（`boss_capture_config.tres` 的 `progress_per_swing = 1`），不必清完小怪。没有增援、冲击波和增益台。Boss 有血条。插旗即胜，死亡即负（AC-02）。见 ADR 0004 文末修订。 |
| 关卡选择 | 尚未实现 | 只切换已解锁的关。顺序：小关 1 → 小关 2 → Boss。这是规则，不是 AC-01。 |
| Cut-001b | 文档，不是脚本 | MVP 的 IN/OUT、解锁顺序和 AC-01 至 AC-08。 |

## 红晶体敌人新增术语

| 术语 | 代码里的名字 | 含义 |
| --- | --- | --- |
| 红晶体敌人 | `red_crystal_enemy_*.glb` | 低模红衣敌人素材：11 件网格、24 骨、23 个剪辑、56 片碎屑。素材已入库，还没接进 `actors/enemy/`。 |
| 部位 | `PART_BONE`、`GEO_m_<部位>` | 身体分成的 11 块：`head`、`torso`、`hips`、`upper_arm_L/R`、`forearm_L/R`、`thigh_L/R`、`shin_L/R`。每个部位对应一根主骨。 |
| 碎屑 | `SHARD_m_<部位>_<序号>`、`red_crystal_enemy_shards.glb` | 每个部位预切好的刚性碎片（合计 56 片），枢轴在自己质心，可直接做成 `RigidBody3D`。 |
| 按部位碎裂 | `shatter_part(part)`、`shatter_parts([...])` | 把一个部位换成它的碎屑刚体，其余部位继续跟动画走。预览场 `tools/crystal_enemy/anim_shatter.tscn`。 |
| 骨骼增量 | `_bone_delta(part)` | 碎屑按 T-pose 模型空间导出，贴到当前动画姿势要乘 `bone_global_pose · bone_global_rest⁻¹`。 |
