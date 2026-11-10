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
| 据点 | `CapturePoint` | 占点建筑（灰盒方块）。清守卫前锁定；开放后用挥刃敲击，进度到 100% 插旗。进度只增不减。 |
| 黑晶手枪 | `Weapon` / `obsidian_pistol.tres` | 唯一远程武器，8 发半自动；右键 ADS 聚焦至 58°。 |
| 晶体重组 | `Weapon.try_reload()` / `ammo_refilled` | 空匣自动或 R 主动，基础 0.85 秒绽放、悬浮、合拢后恢复弹匣。 |
| 意志短刃 | `MeleeWeapon` / `mind_blade.tres` | V 或侧键瞬发，斩击、弹反、敲钟合一；无切刀循环。 |
| 短刃弹反 | `BladeParryArea` / `Projectile` | 生效窗口反转敌弹归属与方向，配合 UI 0.05 秒 hitstop。 |
| 身躯感知与裂痕 | `ShadowBody` / `fracture_level` | 完整白晶人体；低头可见胸腹和行走双腿，0–4 级裂痕从手腕蔓延全身；监听 `Events.sin_defeated(count)`。 |
| 战斗测试台 | `tests/combat_bench.tscn` | 独立可玩验收场，0–4 或按钮切换裂痕。 |
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
| 命中时刻 | `CapturePoint.BEAT_PERIOD`，`beat_offset()` | 据点开放后每 1 秒出现一次，首次在 0.5 秒后。短刃命中时刻离最近的命中时刻有多远，决定是不是完美打击。见 ADR 0003。 |
| 完美打击 | `CapturePoint.struck(perfect=true)` | 刀锋命中落在命中时刻 ±`perfect_window_ms` 内：本次进度 ×`perfect_multiplier`，金色音效、闪光和屏幕闪（AC-03）。窗口外是普通敲钟：钝响，短促白光，只记普通进度。 |
| 占点配置 | `CaptureConfig`，`zone/capture_config.tres` | AC-03 的三个数：窗口 150ms、普通 +10%、完美 ×2.0。试玩只改这个文件。节拍周期和冷却是规则，写在代码常量里。 |
| 起点 | Fixture，`RunFixture`，`fixtures/*.tres` | 一局的可命名起点：开始的战区、已有增益、随机种子（AC-07）。现有 FX-001（新开一局）、FX-002（Boss 起点）。死亡或胜利后重开回到同一起点。`--fixture=<id>` 从命令行进入。见 ADR 0005。 |
| 种子 | `RunState.run_seed`，`zone_seed()` | 一局所有随机数的来源。战区开头 `seed(zone_seed())`。普通局每次新开换一个，fixture 局固定。 |
| 游戏时间 | `SimClock` | 从战区开头数起的物理 tick 时间，不读墙钟。节拍和掩体冷却用它，固定步长下每次运行相同。 |
| 复现检查 | `tests/fixture_test.tscn`，`FixtureBot` | 机器人把每个 fixture 打若干遍，比较记录的哈希（AC-07 的证明）。需要 `--fixed-fps 60`。 |
| 阶段 | `ZoneDirector.Phase` | 第一关先 `BUFF_SELECT`，再 `CLEAR_GUARDS` → `HAMMER_POINT` → `FLAG_PLANTED`。小关 2 进场直接 `CLEAR_GUARDS`，Boss 进场直接 `HAMMER_POINT`。两个小关在增益台按 F 后再进入 `BUFF_SELECT`。 |
| 节拍条、调试条 | `StrikeBar`、`CaptureDebug`（F3） | 节拍条在挥刃可及范围内显示金色窗口和移动的标记。调试条显示阶段、进度、配置文件路径和三个数、上一击（AC-03 的证明）。 |
| 插旗 | `CapturePoint` 的 `Flag` 节点 | 进度 100% 时旗杆从建筑顶部升起。小关同时播冲击波并亮出增益台；Boss 等 1.4 秒后直接胜利。 |
| 增益 | `Buff`，`BuffPool.ALL` | 当前九卡：枪械、刀具、技能各三张；独特图标、稳定 id 和叠层说明，只修改 Stats。旧六张通用卡保留为历史资源及 fixture 兼容。 |
| 发牌袋 | `BuffPool.reset()` / `pick()` | 每次每派一张，先核心再另两张，用完重洗；全局随机受战区种子控制，新局及 fixture 重开清袋。 |
| 选择历史 | `RunState.selection_history` | 关卡、enter/clear、卡片 id 和名称。完整获胜是开局进一、过一、过二，共三条。小关 2 和 Boss 进场不选。（原为进一、过一、进二、过二、进 Boss，共五条。） |
| 刀具增益 | `Stats.MELEE_DAMAGE` / `MELEE_SPEED` / `MELEE_RANGE` | 叠在当前 `MeleeWeapon` 上。基数都是 1，没选刀具卡时三把近战保持 `.tres` 原值。 |
| 主动护盾 | `PlayerShield`，`shield` 动作（G） | 任意技能卡解锁，未选反击卡时为2秒无敌/8秒冷却。反击卡改容量模式：G开启后持续，默认100点，满盾自动/再次G手动释放，释放后8秒冷却；分层紫色盾缘保留中心视野，G槽显示吸收/容量，生命上方紫条显示剩余容量。Q 是切近战。F 是 `interact`，小关插旗后在增益台读取。 |
| 护盾反击波 | `CombatTraits`，`PlayerShield.show_counter_pulse()`，`ReloadCharge.blast()` | 满容量或再次G时，按实际吸收伤害×卡层数结算7米球形BODY反击，墙体阻挡；破盾超额伤害扣血，致命溢出不死后反击，冲刺/弹反/友伤/外部无敌不充能。第一人称有 0.72 秒双层外扩波纹，世界波前到水平半径 7 米后淡出并配能量声；余波不延长保护，也不再次伤害。 |
| 冲刺 | `PlayerDash`，`dash` 动作（Shift） | 沿面朝方向（含俯仰）冲 5 米：无输入时取镜头前方，有输入时在镜头基下合成方向并归一化，A/D 仍沿水平轴。持续 0.18 秒；速度 = 距离 ÷ 持续时间，冲刺期间接管完整 `velocity`（含 y，不受重力），结束时交还水平走路速度并把 `velocity.y` 归零。2 格充能，每 1.5 秒按顺序回 1 格，HUD 左下的两个小格显示剩余与回充进度。空中每次离地只能冲 1 次，落地恢复。冲刺期间 `Health.dash_invulnerable` 提供 0.18 秒无敌；它和护盾的 `invulnerable` 分开记，所以两者同时生效时互不覆盖。冲刺打断开镜，不打断换弹；视野短暂外扩后回落，死亡时取消。 |
| 三张核心卡 | `CombatTraits` | 危险弹匣为最后一发耗尽时立即获得一枚、C 主动投掷；子弹收藏家为挥刀弹反、下次开枪释放收藏；反击护盾为持续吸收后满盾自动/再次G手动在7米内反击。详见当前九增益说明。 |
| 危险弹匣 | `CombatTraits`，`Weapon.fired`，`ReloadCharge`，`throw_magazine` 动作（C） | 对应增益解锁；成功射击耗尽弹匣的同一帧储存一枚，无需等待换弹，无备用弹仍发放，上限一枚。切枪保留、持有不计引信，C 投出时消耗库存并读取当前 Stats。投速 24 米/秒，投出后引信 1.5 秒；离敌人 0.5 米内、碰墙或地面提前引爆。每层在 1.5 米内造成 120 伤害，向 6 米边缘线性衰减至 60；墙体阻挡、按 Health 去重，无自伤、友伤或爆头倍率。空仓扣扳机、切枪、取消或完成换弹不额外发放；死亡或换关清除库存。 |
| 能力槽 | `AbilityBar`，`AbilitySlot` | 图形 HUD 右下方的 G 护盾、V 近战、C 弹匣方槽。C 无增益时锁定，有增益但未持有弹匣时暗态 `0/1`，最后一发打空获得后立即亮态 `1/1`，投出回暗态；不在护盾槽重复画危险弹匣角标。 |
| 受击反馈 | `Health.damaged`，`HUD`，`DamageIndicator` | 玩家中枪时的呈现：边缘红色暗角（中心不填色）、受击音效（0.06 秒内的命中合成一次）、指向攻击者的屏幕边缘弧线（存命中时的世界位置，按玩家朝向每帧重算）、只晃渲染相机的镜头后坐，以及 30% 生命以下的脉冲暗角与心跳（35% 以上退出）。格挡和弹反不是掉血，没有这套反馈。 |
| 击杀反馈 | `HitReaction`，`HUD.KillText`，`DebrisBurst.spawn_death()` | 击杀时的呈现：模型向射击者反方向偏 23°（只动 mesh，不动 CharacterBody 和 hitbox），胸口（爆头在头部、Boss 2.5 倍）爆出体块与 0.12 秒亮光，准星下方显示「击杀」/「爆头击杀」/「双杀」/「三杀」/「连杀 ×N」；爆头击杀的 hitstop 是 0.075 秒，普通击杀 0.05 秒。 |
| 敲钟反馈 | `CapturePoint.struck` / `fractured` / `captured`，`clock_hit` / `clock_perfect` / `clock_break` | 挥刃敲钟时的呈现：每次命中晃渲染相机（普通 0.45°、完美 0.9° 加 0.035 秒 hitstop），未碎方块挤压回弹，普通/完美分别爆 14 / 30 片石屑和尘雾，准星上方浮出白色「+10%」/ 金色「+20%」（打击条只显示「完美打击」或「偏早/偏晚 N ms」）；每 25% 掉落一组方块并爆中号碎屑；100% 时炸出黄铜齿轮、齿圈、细杆等钟表零件，配暖光、尘环和一声重碎的 `clock_break`。 |
| 小地图 | `Minimap`，`ZoneDirector.living_enemies()`，`reinforcement_spawned` | HUD 右上角的圆形小地图（200 px）：玩家居中、随朝向旋转，28 米范围；`Geometry` 下的方块缓存成俯视多边形，敌人红点（逃跑的变淡）、Boss 大暗红菱形、据点/增益台按 WorldMarker 配色，超出范围的目标钳到边缘成小三角；增援出生时在对应方向闪 1.2 秒红脉冲；开镜时隐藏。 |
| 阶段横幅 | `PhaseBanner`，`HUD/PhaseBanner` | 每次阶段变化在画面 24% 高度处弹出一条大标题 + 副标题：战斗开始、据点开放、增援来袭（每关只一次，排在据点开放之后）、据点已占领、Boss 现身、砸碎城市核心。弹出 0.15 秒、停留约 2.8 秒、淡出 0.4 秒；开镜、增益选择和死亡时隐藏。左上角目标面板仍是常驻提醒，横幅标题不照抄面板原句。 |
| 数值 | `Stats` | 基础数值加上增益修正。新的 9 条也只走这里。 |
| 战区控制 | `ZoneDirector` | 管阶段、开放据点、增援、冲击波、增益台、弹出选择或结算、切场景。 |
| 掩体点 | `CoverPoint` | 掩体旁的地面标记。敌人会去看不到玩家的点蹲一会儿。 |
| 射击位 | `Enemy.State.SEEK`，`Enemy.firing_position`，`FiringPositionBoard` | 交火时站的、能看到玩家的位置。候选是现有掩体点加玩家周围固定方向的两圈采样点（8 / 20 米），只保留导航可达、从眼睛高度到玩家不被世界挡住的点；离自己近的优先，挨着掩体减分。多个敌人共用一个 `FiringPositionBoard`，3.5 米内别人已订的点不再选。走到后进入交火；看不见玩家 0.5 秒或离玩家近于 6 米就重找。找不到才退回朝玩家追。增援出生即寻位，不抽随机数。 |
| 敌人 | `Enemy` / `SlothEnemy` | 共用待机、追击、交火、掩体、死亡、逃跑、找射击位（SEEK）契约。整合草稿的小怪为 SlothEnemy 三变体；Boss 暂沿用旧 Enemy 大号版本（`actors/enemy/boss.tscn`），Hazmat 模型，900 HP、爆头倍率 1.25。 |
| 增援刷新 | `ZoneDirector._pick_spawn_marker()`，`MIN_SPAWN_DISTANCE` / `SPAWN_VIEW_HALF_ANGLE_DEG` | 每波优先选离玩家至少14米且看不见的刷新点（前方65°+WORLD视线）；不合格时退回最远未用空位，不抽额外随机数。候选与fallback都用ENEMIES胶囊排除占位，全部被占就等待；同波不重用。zone_1/zone_2各有后方、侧翼/高台共9点。 |

## 设计目标（Cut-001b）

| 术语 | 代码里的名字 | 含义 |
| --- | --- | --- |
| 小关 / 两段关 | `ZoneDirector.Phase` | 清守卫 → 占点（增援从后方持续来）→ 插旗冲击波 → 增益台（AC-01）。MVP 有两关。 |
| 增援 | `ReinforcementConfig`，`reinforcement_spawn` | 据点开放时从后方刷出的 `Enemy`。默认每10秒4只，场上最多8只，插旗后停止。不回退进度，只造成生命压力。数在 `zone/reinforcement_config.tres`。 |
| 冲击波 | `ZoneDirector._play_shockwave` | 小关插旗时触发。不造成伤害。存活小怪进入逃跑，沿导航去后方刷怪点，到达或超时后消失，不算击杀。 |
| 增益台 | `BuffPedestal` | 小关插旗后出现在旗旁的灰盒。走近按 F（`interact`）才打开通关三选一。开局那次仍是弹窗。 |
| 逃跑 | `Enemy.State.FLEE`，`begin_retreat` | 冲击波之后的状态：不再攻击，跑向后方刷怪点。移除时不发 `Events.enemy_killed`。 |
| 三流派 | `School`，`SchoolCatalog`，`SchoolBadge` | 当前按用户已有改进为枪械、刀具、技能；历史狂战士/军火大亨/鹰眼图标与设计保留。取舍见 ADR 0006。 |
| 九条增益 | `BuffPool.ALL` | 每派 3 条，共 9 条，图标不同（AC-08）；当前效果为可调试玩默认，非最终平衡锁定。 |
| 进关选择 | `ZoneDirector._offer_buff("enter")` | 只在一局第一关（`RunState.zone_index == 0`）开打前选 1 条。小关 2 和 Boss 进场不选。按是不是一局的第一关判断，不按 fixture 起点（AC-04）。 |
| 关末再选 | `ZoneDirector._offer_buff("clear")`，`BuffPedestal` | 两个小关插旗后，到旗旁增益台按 F 才各选 1 条，本局叠加；Boss 结束后不选（AC-04）。 |
| Boss 关 / 城市核心 | `maps/boss.tscn`，`ZoneDirector.is_boss_zone` | 只有一波：1 个大敌人（Boss）、2 名护卫（2–6 米内）和7名放在前沿/中段及侧翼的小敌人。Boss 活着时核心关闭，目标「打倒 Boss」。Boss 倒下后核心开放，一刃击碎（`boss_capture_config.tres` 的 `progress_per_swing = 1`），不必清完小怪。没有增援、冲击波和增益台。Boss 有血条。插旗即胜，死亡即负（AC-02）。见 ADR 0004 文末修订。 |
| 关卡选择 | 尚未实现 | 只切换已解锁的关。顺序：小关 1 → 小关 2 → Boss。这是规则，不是 AC-01。 |
| Cut-001b | 文档，不是脚本 | MVP 的 IN/OUT、解锁顺序和 AC-01 至 AC-08。 |

## 红晶体敌人新增术语

| 术语 | 代码里的名字 | 含义 |
| --- | --- | --- |
| 红晶体敌人 | `red_crystal_enemy_*.glb` | 低模晶体素材：11 件网格、24 骨、23 个剪辑、56 片碎屑。Sloth 整合草稿已复用到 `actors/enemy/sloth/`，实例改藏青，原红材质保留。 |
| 部位 | `PART_BONE`、`GEO_m_<部位>` | 身体分成的 11 块：`head`、`torso`、`hips`、`upper_arm_L/R`、`forearm_L/R`、`thigh_L/R`、`shin_L/R`。每个部位对应一根主骨。 |
| 碎屑 | `SHARD_m_<部位>_<序号>`、`red_crystal_enemy_shards.glb` | 每个部位预切好的刚性碎片（合计 56 片），枢轴在自己质心，可直接做成 `RigidBody3D`。 |
| 按部位碎裂 | `shatter_part(part)`、`shatter_parts([...])` | 把一个部位换成它的碎屑刚体，其余部位继续跟动画走。预览场 `tools/crystal_enemy/anim_shatter.tscn`。 |
| 骨骼增量 | `_bone_delta(part)` | 碎屑按 T-pose 模型空间导出，贴到当前动画姿势要乘 `bone_global_pose · bone_global_rest⁻¹`。 |

## Sloth 可玩整合草稿（2026-11-08）

同日战斗强化：三关初始小怪5/9/9（前轮7/11/11各减2，Boss本体仍1）；Sloth绑定目标后主动搜敌，初始0.25–0.70秒错峰，跑速迟滞/锚定/退缩2.8/2.1/2.4m/s，锚定/退缩施法周期4.4/3.6秒。四连弹的预警、伤害与恢复窗口不改；增援每批4只/10秒、最多8只。反击盾当前容量规则见上方主动护盾/反击波条目和ADR0013。

| 术语 | 代码里的名字 | 当前试玩含义 |
| --- | --- | --- |
| 迟滞者 / 披风敌人 | `SlothEnemy.Kind.LINGERER` | 90 HP，闭篷单弹 30% 闪避、成功冷却 2.5 秒。2 秒凝聚，最后 0.45 秒锁向，一次 4 发（间隔 0.18 秒、40 米/秒、9 伤/发），结束后 1 秒暴露；不追踪玩家。 |
| 锚定者 | `SlothEnemy.Kind.ANCHOR` | 140 HP，0.95 秒预警后形成半径 3.2 米的 2.6 秒减速场；最多减速 25%，多来源取最强，墙体阻挡，不改冲刺。 |
| 退缩者 | `SlothEnemy.Kind.RECLUSE` | 180 HP，0.95 秒预警后向外扩散低位冲击波；最大半径 7 米、14 伤，留有安全扇口，可用跳跃、掩体或冲刺规避。 |
| 复层庭院 | `environments/sloth/courtyard.gd` | 紧凑修订的两小关共用 40×48 米可走核心，出生→据点 22/24 米；下沉庭与两侧高台保留，原尺度外围柱廊/浮岛为景观。旧 96×128 米宽场保留在历史备用包中。 |
| 云海圣殿 | `environments/sloth/architecture.gd` | 紧凑修订为直径 50 米实际战斗台，92 米圣殿外环与巨环/钟摆/浮岛保留宏观观感；用旧 Boss 及核心规则验证流程。 |
| 运行时提取 | `environments/sloth/`、`actors/enemy/sloth/` | 与 `.gdignore` 隔离的历史备用包分开，当前主入口直接加载这些运行文件；备用包本身不参与运行。 |
