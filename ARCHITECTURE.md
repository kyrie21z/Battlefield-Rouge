# 架构与依赖规则

引擎：Godot 4.7.2，Forward+，Jolt 物理。所有人必须用同一个版本。

## 目录

| 目录 | 放什么 |
| --- | --- |
| `autoload/` | 全局单例：`Events`（信号总线）、`RunState`（本局状态）、`InputMapSetup`（按键） |
| `components/` | 可复用的小部件：生命值、受击判定、数值（Stats） |
| `weapons/` | 黑晶手枪的数据与 `Weapon`，以及 `weapons/mind_blade/` 的意志短刃；`weapons/melee/` 保留短刃数据类型与 `MeleeWeapon` 实现 |
| `actors/` | 玩家、敌人 |
| `zone/` | 战区控制（zone director）、据点、占点配置（`capture_config.tres`） |
| `fixtures/` | 可复现的起点（`RunFixture` 资源，一个 id 一个 `.tres`），AC-07 |
| `buffs/` | 增益，每个增益一个 `.tres`。流派身份是 `School`（图标和方向，不含效果数值） |
| `ui/` | HUD、三选一增益界面、结算界面 |
| `maps/` | 战区场景，由 `tools/gen_zones.py` 生成 |
| `environments/sloth/` | 整合草稿的纯场景几何、碰撞、掩体点与材质，不控制关卡进度 |
| `tools/` | 编辑器外的辅助脚本 |
| `docs/` | 设计文档。游戏方向以 `docs/CREATIVE_VISION.md` 为准；本轮范围和验收看 `docs/Cut-002.md`，它未改动的玩法规则沿用 `docs/Cut-001b.md`、`docs/MVP_Scope.md` |
| `docs/adr/` | 架构决策记录 |

## 依赖规则

1. `components/`、`weapons/`、`actors/` 只向 `Events` 发信号，不读写 `RunState`，也不通过路径或分组去找别的系统。
2. 只有 `RunState` 和 `zone/` 下的战区控制可以改本局状态。
3. 增益只修改 `Stats`，不直接改玩家或武器脚本。已有能力的新卡通过 `.tres` 定义并加入 `BuffPool.ALL`；新增能力由组件读取对应 Stats，`Buff.extra_adds` 可附带共享能力解锁。
4. 依赖方向只能是 `ui → zone → actors → components`，反过来要用信号。
5. 战区里的玩法代码可复现（AC-07）：不读墙钟，时间用 `SimClock`；不 `randomize()`，随机数用全局的 `randf()` 等，战区开头已经 `seed()`。细则见 `docs/adr/0005-reproducible-runs.md`。
6. 从 `../origin/sheji` 迁移代码时，先删掉对 `GameState`、`VoiceManager`、突破模式、载具、商店的引用，再放进来。

## 一个战区的流程

普通项目入口先到 `ui/game_start.tscn`。`GameStart` 只加载 Pride 开场并监听单次完成信号，再读取 `RunState.zone_scene()` 进入原有战区；它不改种子、增益、战区序号或战斗规则。开场期间不实例化玩家、敌人、战区控制和战斗 HUD。fixture 与 `--skip-opening` 直接进战区；已有 `RunState` 延迟重定向与启动器均检查当前场景，先加载的一方完成交接，避免重复预热导航。死亡重开仍由原 `ZoneDirector` 直接载入战区，不返回开场。见 [ADR 0009](docs/adr/0009-pride-opening-bootstrap.md)。

赐福每清完一个房间领一次（4 领域 × 3 房，最多 12 次），开局另有一次三选一；这对应 AC-04 的后续修订（D-002 于 2026-10-27 改为三次，现为每房一次）。发牌从全部 54 张里抽，不再按房间领域过滤；强化（特性）卡必须先拥有同系核心，双重卡要求两系核心同时在场；一轮最多给一张「会替换现有核心」的卡，其余名额留给特性，三张全是替换时可以直接放弃。九张不同图标的卡对应 AC-08，见 [ADR 0006](docs/adr/0006-nine-buffs-and-entry-choices.md)。占点仍为窗口 ±150ms、普通敲钟 +10%、完美 ×2.0，配置是 `zone/capture_config.tres`。紧凑版两小关入口为 z=14/16、据点 z=-8，恢复旧灰盒 22/24 米目标距离；40×48 米可走战斗核心之外的宏大柱廊/浮岛为纯景观。据点开放后按 `zone/reinforcement_config.tres` 从后方及侧翼刷增援（每批4、间隔10秒、最多8），插旗冲击波让小怪逃向刷怪点后消失，通关增益在旗旁增益台按 F 打开。见 [ADR 0007](docs/adr/0007-reinforcements-shockwave-pedestal.md)、[ADR 0011](docs/adr/0011-sloth-playable-integration.md) 与 [ADR 0012](docs/adr/0012-compact-combat-scenic-surroundings.md)。节拍见 ADR 0003，Boss 见 ADR 0004。Boss 关没有增援、冲击波和增益台。

由 `zone/zone_director.gd` 执行，场景里的节点顺序是：几何 → 掩体点 → 据点 → 玩家 → 敌人 → `ZoneDirector` → `HUD`。HUD 放在最后，保证它 `_ready` 时战区控制已经准备好。敌人排在 `ZoneDirector` 前面，所以战区控制 `_ready` 时敌人已经 ready。Boss 关的核心在 Boss 倒下前关闭，倒下后一刃击碎，见 [ADR 0004](docs/adr/0004-boss-wave-and-core.md) 文末修订。

1. 保留战区随机种子、`SimClock` 与同步导航烘焙。把已有卡应用到玩家 Stats，收集敌人与掩体。只有 `zone_index == 0` 进入 `BUFF_SELECT` 并暂停；此时敌人还没有玩家目标。小关 2 和 Boss（以及从 Boss 起步的 fixture）解除暂停后直接开打，敌人立刻拿到目标。
2. 确认 `enter` 卡后记录选择历史，发 `Events.buff_chosen`，立即应用新卡，再给敌人设置目标。小关进入 `CLEAR_GUARDS`。Boss 关（`is_boss_zone`）进入 `BOSS_STANDING`，核心保持关闭，目标是「打倒 Boss」。
3. 小关守卫全灭开放据点，并开始从后方刷增援。增援不回退进度，也不把据点重新锁上。V 短刃命中仍按原节拍配置计进度（+10%，完美 ×2.0）。100% 插旗时冲击波让存活小怪停止攻击并逃向后方刷怪点，到达或超时后移除，不算击杀。旗旁出现增益台，走近按 F 才提供 `clear` 卡；选完暂停并载入下一关。下一关不再发 `enter` 卡，进场时自己解除暂停。Boss 不加这些。Boss 的 `enemy_killed` 才 `capture_point.open()`，目标改为「砸碎城市核心，按 V」；9只小怪不参与开关。这一刃用 `boss_capture_config.tres` 的 `progress_per_swing = 1`，完美与否都到 100%。插旗 1.4 秒后直接胜利，不再发牌。
4. 死亡清空本局增益、选择历史与卡袋，显示阵亡界面。普通重开回第一关；fixture 模式仍回到同一 fixture 的关卡、预设卡和种子。选择提交、占点回调和场景推进均有防重保护。

### 坠落边界

四个领域共用 `environments/realm_void.gd`：低于地图原点 −12 米、或进入下方兜底体积即算坠落。玩家扣固定 **30 点真实生命**（绕过护盾、无敌与减伤），并送回上一次整块稳定地面，扣到 0 才死；其它角色走 `environmental_fatal` 直接死亡，不消耗护盾也不留残血。0.3 秒防连触发；落点必须脚下有支撑、法线朝上且胶囊不与世界或敌人重叠，否则退回出生点九宫格。`FearRealm` 原本自带一份等价实现，现已并入该组件，只把 `abyss` 体积转发给既有诊断与测试。

新增战区：在 `tools/gen_zones.py` 里加一个布局，生成后把场景路径加到 `RunState.ZONE_SCENES`。

### Sloth 整合草稿的场景与敌人

三张生成地图仍使用原 `RunState.ZONE_SCENES` 路径。`Geometry` 在 `_ready` 构造纯环境，再由 `ZoneDirector` 同步烘焙 `navigation_geometry` 组内的 WORLD 静态碰撞；漂浮装饰和 BOUNDARY 防坠墙不参加。可走地面带 `sloth_walkable` 组及 `walkable_surface` 元数据，小地图递归读取嵌套实体掩体，过滤可走地面与退化裁剪多边形。导航网格 cell=0.5、height=0.25、agent height=2.0、radius=0.5、climb=0.25。Boss 低台座保留浅坡物理，用连续底板作导航代理，避免机器人在小台阶边界往复；核心实体仍为导航障碍。

紧凑修订中，环境用 `combat_bounds`（小关x±20/z±24）或 `combat_radius`（Boss25米）声明实际战斗范围；`_scenery_building` 在构造外围时直接抑制碰撞创建，避免纯景观的柱顶、桥面进入烘焙。`sloth_scenery` 组用于验证景观没有 PhysicsBody。低栏与高差提示边界，高 BOUNDARY 仅拦玩家冲刺，不参与导航；增援点与掩体全部在核心内。地板、掩体和坡道按米重排，未通过整体缩放改变角色或武器比例。

`SlothEnemy extends Enemy` 保留 `setup`、Health、State、`begin_hunt`、`begin_retreat`、`departed` 契约，`ZoneDirector.reinforcement_scene` 由地图选择迟滞者场景，默认仍为旧 Enemy，防止独立测试场景被隐式换种。增援位置在 `add_child` 前设置。`SlothAttack` 使用物理步长管理预警/四连发/结束；暂停冻结、死亡/撤退/换关取消。锚定减速通过 Player 的弱引用来源列表取最强值，最多减速 25%，不影响冲刺；攻击移除会清理来源。`Hitbox.apply_hit_at` 的同步上下文把真实命中点交给闪避和碎裂，已有 `apply_hit` 保持兼容。

波次微调为每批4名、最多8名后，两小关使用9个生成marker。选择与最远fallback均用缓存的2米高/0.6米半径胶囊查询ENEMIES层占位，避免下一批刷到仍在射击的上一批身上；无空位本批少刷，下一间隔再尝试，不强行堆叠。查询仅刷新时发生，不逐帧执行、不消耗随机数；满场及按空位补充规则保持。

服饰几何/56片碎屑继续缓存，但每个演员独立材质与姿态；地面预警建造时投射到所在楼层并缓存高度，不逐帧射线。敌人不读取 RunState。旧独立备用包保持隔离，不作为运行时依赖。

## Epic 1：一枪一刃与第一人称身躯

当前武器系统以 `docs/NARRATIVE_FOUNDATION.md` 第 8 节及 issues #101–#106 为范围，以黑晶手枪和意志短刃替换了早期三枪三刀一锤原型。

- `Weapon` 仅持有一份 `WeaponData`，默认 `weapons/obsidian_pistol/obsidian_pistol.tres`：8 发、35 伤、半自动 0.18 秒、30 米后衰减。无槽位、切枪或狙击倍率状态；右键从 75° 平滑聚焦至 58°，灵敏度按实际 FOV 比例缩放，HUD 显示菱形准星。
- 手枪由 Blender 制作的四个独立 Mesh 对象构成，GLB 保留各部件中心枢轴与握把根原点；手枪尺寸为 220×135×32mm，短刃全长 400mm、刃宽 40mm、厚 15mm。面数按质感需要配置，源多边形与导出三角形分别记录于 `tools/epic1_models/manifest.json`。二者采用参考 SUPERHOT 的不规则矿物切面与 Shade Flat，Godot 只加载模型、赋材质和驱动动画。空匣自动或 R 主动重组，满匣无效；基础 0.85 秒（0.35 绽放、0.30 悬浮、0.20 合拢）。既有 `Stats.RELOAD_SPEED` 仍作用于整体时间，动画从同一进度驱动；冲刺平滑继续重组。合拢帧先归位，再补弹并发 `ammo_refilled`，无限能量重组，HUD 显示当前/容量。
- `MeleeWeapon` 仅持有 `blade_data`，默认意志短刃：55 伤、0.08/0.12/0.15 秒三段、4.5 米 ±40° 磁吸、0.45 米前冲。挥刃只让手枪右偏，保留持枪与射击。旧多刀循环已移除。
- 短刃生效期启用自有 `BladeParryArea`。敌方 `Projectile` 扫掠 `PARRY` 层，成功时原子移交 source/exclude 与方向，阻止高速弹穿过检测区；`Events.blade_parried` 由 HUD 请求 0.05 秒 hitstop。fixture 不执行影响回放的 hitstop。
- `CapturePoint` 在玩家进入/离开时连接/断开 `melee.struck`，只在生效帧、面向据点且无遮挡时结算。普通 10%、完美 20%、±150ms 保留；Boss 核心仍为一击 100%。噪音信号改为 `Events.clock_struck`，流程阶段为 `CLOCK_POINT`。
- `ShadowBody` 在现有完整 24 骨主角模型上提供第一人称身躯感知：头部只投影，胸腹、双臂、双腿可见，保留原有待机与跑动动画。视角采用头骨眼睛位置，右手对应手枪握把。全身 `fracture_level` 沿真实晶体接缝从左腕细裂扩展到胸锁骨、胸臂剥片及全身深缝；裂缝统一黑色，以覆盖、宽度和剥离程度区分等级，使用原材质与预切碎片，不构造替代人体。监听 `Events.sin_defeated(count)`；本 Epic 预留事件，不虚构尚未实现的四心魔流程。数字键仅在调试测试台启用。
- `tests/combat_bench.tscn` 是可直接运行的独立测试台，使用生产 Player、Health/Hitbox、Projectile 与 CapturePoint。不使用 ZoneDirector、不改变正式关卡；慢弹、移动靶、木桩、节拍钟和裂痕按钮可循环操作。

取舍与验收入口见 [ADR 0014](docs/adr/0014-epic1-mind-arsenal.md)。

## 九增益与能力组件

2026-11-08反击盾改为持续容量模式：Health提供可选`damage_absorber`返回未吸收伤害，并以嵌套结算深度保证仅最外层发`damage_resolved`；PlayerShield按100基础容量吸收，满盾或再次G通过`counter_released(absorbed)`交给CombatTraits反击。HP/溢出/死亡先完成，致命溢出取消反击；基础限时盾与其他保护分开。UI用`is_active()/charge_fraction()`，不把持续盾当倒计时。持久屏障通过Stats同时提供普通盾+0.5秒/反击盾容量+25。见[ADR0013](docs/adr/0013-persistent-counter-and-active-pressure.md)。

`BuffPool.ALL` 为 `firearm`、`blade`、`skill` 每派三张。每次每派各一张，前三次覆盖九张，用完重洗；发牌只使用战区已播种的全局随机，重开清袋。`Buff` 含稳定 id、独特图标、说明和 Stats 修改，School 只含流派身份。

Stats 按 `(base + Σadd) × Πmul` 计算。`MeleeWeapon` 读取刀具伤害/速度/距离，`PlayerShield`读取护盾解锁/持续/冷却/容量，普通盾限时，反击卡为持续容量模式（G开盾/手动释放，Q无默认动作），`CombatTraits` 监听刀、盾、枪与 Health 的信号执行三张核心卡机制。`ReloadCharge` 只做带遮挡、按 Health 去重的爆炸及短暂特效，不访问 RunState。数值与边界见 [当前九增益](docs/Buff当前实现.md)。所有新能力随暂停冻结，死亡清理临时状态。危险弹匣监听真实成功射击的 `Weapon.fired`，当扣弹后的 `ammo == 0`、增益已解锁且库存未满时，同帧储存一枚；不等待换弹完成，也不依赖备用弹。单次成功射击最多储存一枚；空仓扣扳机、重复启动或完成晶体重组都不额外发放。`throw_magazine`（C）消耗库存，投出时读取当前 Stats 伤害；手持视觉与库存独立于手枪重组动画，死亡或换关清空。弹匣 6 米与护盾 7 米使用独立范围。当前取舍见 [ADR 0010](docs/adr/0010-empty-magazine-blast.md)；[ADR 0008](docs/adr/0008-held-magazine-and-shield-radius.md) 保留此前获取时机的历史。

## 图形 HUD 与能力状态

`ui/hud.gd` 在 `AbilityBar` 中连接三个 `AbilitySlot`：G 读取护盾解锁、生效和冷却，V 读取当前近战与弹反收藏，C 读取 `Stats.RELOAD_BLAST_DAMAGE` 和 `CombatTraits.has_reload_charge()`。C 未解锁时锁定；解锁后无库存是暗态 `0/1`，最后一发打空获得弹匣后立即亮起为 `1/1`，投出后刷新回暗态。危险弹匣使用独立 C 槽；HUD 继续只读玩法组件，不修改库存，也不恢复旧的能力长文字面板。已有目标标记、Boss 血条、增益图标栏、生命和冲刺充能仍走当前组件。

`PlayerShield` 自己持有 `ShieldFeedback` 屏幕反馈：分层盾缘、挡伤亮闪与蓄能由护盾过程推进，暂停同步冻结，`cancel()` 清空并隐藏。反馈的 CanvasLayer 位于 HUD 下方，中心不填色；`CombatTraits` 成功结算反击后调用 `show_counter_pulse()`，显示 0.72 秒第一人称余波，不改变无敌状态。`ReloadCharge` 负责双面开口世界波前、厚环和专用合成能量声，世界波前在水平 7 米处停留后于 0.82 秒释放；视觉和声音不消费玩法全局随机数，也不读写 RunState。

## 碰撞层

定义在 `components/collision_layers.gd`，代码里不要直接写数字。

| 层 | 常量 | 放什么 |
| --- | --- | --- |
| 1 | `WORLD` | 场景几何和道具 |
| 2 | `ACTORS` | 玩家的移动碰撞体 |
| 3 | `ENEMIES` | 敌人的移动碰撞体。敌人的 mask 不含这一层，所以敌人之间不互相推挤 |
| 4 | `HITBOXES` | 受击判定 |
| 5 | `BOUNDARY` | 玩家防坠边界，不进入导航或武器射线 |
| 6 | `PARRY` | 短刃弹反 Area，由敌弹扫掠检测 |

玩家射线检测 `WORLD | HITBOXES`；敌方慢弹另检测第 6 层 `PARRY` 的 Area，成功弹反后仅检测世界与敌方 Hitbox。角色的移动碰撞体和受击判定位置重叠，子弹如果检测 `ACTORS`，会先打在移动碰撞体上而打不到受击判定。

## 从旧工程迁移

旧工程在 `../origin/sheji`，只当参考，不修改。迁移顺序和原因见 `docs/adr/0001-rebuild-on-clean-skeleton.md`。

## 第一人称完整身躯（#105）

`Player/ShadowBody` 是唯一的 `ProtagonistBody`，复用 `protagonist_body.tscn` 与 24 骨角色。头部仅投影，胸腹、双臂和双腿可见。原待机/跑动剪辑驱动腿部。`BodyPose` 在动画之后处理上身与双臂。腰射和瞄准时，两手各自跟随 `Weapon.grip_transform()` 上的腕部偏移。Blender 制作的双手握姿仍绑定在原手骨上。挥刃期间左手跟随 `MeleeWeapon.grip_transform()` 并切到短刃手型，收刀后手型与手腕一起用 0.14 秒回握。单一角色骨架和武器模型同时提供第一人称和投影。

眼位来自头骨位置与固定眼睛偏移；低头时采用确定性的上身前倾，跑步动画不驱动逻辑眼位。实际 `Head` 同时带动瞄准相机和渲染子相机，既有受击/开火震动仍仅作用于渲染相机。两相机 near=0.025，保留近处手臂和胸部。

`BodyFracture` 只管理表现。`Events.sin_defeated(count)` 驱动 0..4 级，0 为原白晶材质，1 从左腕开始，2 到手背/胸锁骨，3 胸臂局部剥落，4 全身深缝；全部裂缝为黑色。`CrystalSeams` 派生渲染网格，只添加原非共面晶体边的距离属性，保留原三角形、蒙皮、形态键、顶点位置和法线；0 级恢复原资源。56 个碎片随对应骨骼，替换部位隐藏原网格，材质参数逐实例隔离。两块手部碎片沿用 Blender 握姿和挥刃手型。退出场景时断开骨骼回调和事件。事件预留给四心魔流程，本阶段不增加尚未实现的剧情状态；数字 0..4 仅在显式开启调试的场景消费。

验收与原生截图见 [#105 记录](docs/proof/issue-105/README.md)。

## Epic 2：动作槽位赐福管道（#114）

`Player/BoonManager` 是玩家拥有的组件。`BoonData` 资源描述 GUN / BLADE / DASH / OTHER 核心槽与不限槽的次级特质；一个槽最多一张核心卡，`request_equip` 的冲突必须经过 `replacement_requested` / `confirm_replace`。`BoonCatalog` 只加载已存在的 `buffs/resources/{sin}/pool.tres`，前置检查共用 `BoonManager.can_equip`。恢复已获得的卡不重新要求当前仍持有旧前置。

数值通过 Stats 的 source modifier 层叠加到原 Buff 层；换卡精确移除 `boon:<id>` 来源，临时能力按来源到期。这里将依赖规则 3 扩展为：赐福数值仍只写 Stats；有状态技能由每 Script 唯一的 `BoonEffect` 通过组件接口处理动作事件，不直接改写玩家、武器或世界控制脚本。装备数据与技能运行态分离，不把资源 `.tres` 当可变状态。

枪击、刀击与弹反飞弹使用同步可改写的 before/after 上下文，Health 在队伍、弹反及无敌检查后提供扣血前拦截，旧反击盾吸收器后接独立赐福屏障。衍生伤害带 tag/proc_depth，通过 Health/Hitbox 结算，深度上限 4；技能仍需自己的触发过滤。敌人和弹丸通过 Events 生命周期注册，Zone 为已存在敌人补注入；范围查询过滤同队、死亡与 WORLD 遮挡。敌人移动、动画、SlothAttack 和弹丸支持局部时间，恢复计时在玩家组件上运行，不修改 Engine.time_scale。暂停冻结临时计时，死亡和场景退出释放临时效果；退出不会发空装备保存事件。

只有 Zone 接线 `RunState.boons` 的恢复、种子与保存；BoonManager 不读取 RunState。赐福随机使用独立并注入种子的 RNG，不装备卡时不消耗旧 fixture 的全局随机序列。#114 基础 PR 保留旧 BuffPicker；#124 已在此基础上接入下述正式选择界面。

### 门扉与选卡（#124）

正式进场及插旗后 F 交互使用 `ui/boon_picker/boon_picker.tscn`。初始给枪/刃/冲刺各一个核心候选，通关给与浮空心魔徽记一致的三张候选；替换需要确认。`BoonOffers` 使用 Zone 独立 RNG 和 `BoonManager.can_equip`，门扉可选到符合双系条件的双重卡。RunState 管理每局 2 次重抽与选卡历史；UI不直接扣费或推进关卡。暂停只冻结战斗，入场动画和确认交互继续；死亡界面接管暂停，空池仍可继续。

`BoonIdentity` 是图标/主题数据，世界标识不依赖 UI Control。七种门扉标识均可配置，当前生产小关实际发放四系赐福；石榴/血量/商店图标为后续房间配置预留，未新增经济或房间流程。HUD显示当前赐福，历史 fixture Buff仍可恢复。领域机制说明挂在每张卡的悬浮栏上（`BoonPresentation.realm_help_inline`），不再有选卡前的一次性面板；当前每次清房一次选择，完整传奇成型需要后续增加房间循环；见 [ADR 0017](docs/adr/0017-boon-door-rewards.md)。

## Epic 3：领域约束接口（#138）

Epic 3 的领域临时约束通过玩家持有的 `RealmPlayerEffects` 注入；施法者持有玩家引用，用稳定来源键设置或清除效果，不查询世界控制器。移动、跳跃、冲刺距离由 Player 读取组件聚合值，换弹/冷却通过 Stats 来源层实现。约束在真实冲刺消耗充能前生效，强制位移仍由 Player 的物理碰撞负责。恐惧玩家坠落使用 Health 的 `environmental_penalty` 分支扣30点实际生命，绕过战斗护盾、无敌与复活拦截，扣至0生命时才发正常死亡信号；敌人和其他明确致死边界继续使用 `environmental_fatal`。

`FearRealm` 通过注入的Player弱引用每0.15秒保存稳定静态地面落点，检查脚下及四侧支撑，排除翻转板。深渊Area与高度-12米判定汇入同一个延迟恢复回调及0.3秒防重；恢复前检查支撑与角色胶囊占位，受阻时查入口九个候选。Player取消冲刺、吸附和外部冲量、清零速度并重置物理插值后才扣生命；HUD只消费真实伤害信号显示扣血/返回提示。

`OculusVisual` 加载准备并复用 `FearShatter` 的56份不可变凸碰撞形状；死亡仍保留独立刚体与当前姿态。`WrathSpire` 拥有齐射弹体与 `SpireEruption` 的弱引用列表，死亡、目标死亡或退出时清理；晶刺自己推进局部时间、预警和单次范围/遮挡/跳跃判定，不读取战役单例。

### 四领域组合根（#146）

2026-11-11当前修订：`randomize_realm_order` 恢复默认true，正式新局使用私有RNG按run_seed洗牌四领域，不重复；`PLAYTEST_ORDER=[1,0,2,3]`仅用于显式固定路线诊断。RealmHUD通过注入的Stage调用`retry()`，Stage发`retry_requested`交给RunDirector，不由HUD访问战役单例。恐惧几何通过已有`set_player`接口接收弱引用，-12米高度边界补足有限Area之外或高速穿过的坠落，并和Area共用上述30点生命恢复规则。

`RealmHUD` 在悲伤全屏单色层之后、读数/准星/菜单之前创建 `RealmHurtFeedback`，显式注入Health，只消费实际 `damaged`/`died`信号。它复用既有damage_vignette shader，以帧delta合并并淡出红边，保持中心透明、鼠标穿透及暂停冻结；不读取RunDirector，也不因预警剥夺丢失实际受伤反馈，不额外生成枪声或伤害。

`FearShatter.prepare_templates()`在FearRealmVisual构建时预先缓存56份凸碰撞资源；每次死亡仍创建独立RigidBody、材质和实时骨骼变换，只共享不变的形状。昂贵的凸形生成不再发生在击杀伤害回调中。门扉显示和HUD方向提示只读取`exit_ready`，不绕过选卡、碎片、距离与WORLD视线检查。

`autoload/RunDirector` 与旧 `RunState` 同属允许拥有对局状态的组合根；正式入口选择前者，旧 fixture 继续选择后者。`RealmStage` 不读取 RunDirector，通过 configure_run 及信号组成流程。四种 Enemy 派生、Boss、PsycheFragments 和 CrownRadiance 都只接收注入的引用与值，不寻找对局控制器。新地图由 gen_zones.py 调用 gen_realms.py 生成，旧地图逐字保持。

`PsycheFragments` 管理独立碎片运行态，BoonManager 管理可替换的赐福；两者不混存。普通击退经 Enemy.apply_impact，独立脉冲经 apply_fragment_impact；普通防御受 Health.unbuffered 关闭，fragment_absorber 仍单独结算实际吸收与 HP 溢出。数值增益通过 Stats，实际位移保留物理碰撞，所有能力暂停冻结。原始黑晶素材及黑接缝保持，终局金缮由后续演出显式启用。状态边界及验证见 [ADR 0018](docs/adr/0018-realms-and-independent-fragments.md)。


局外成长由 `MetaProgression` autoload保存，`RunDirector` 组合真实Stage信号与钱包事务：Actor只经Health/Stage上报死亡，不操作货币。`GameStart`在入战前开放Forge，关闭后一次性准备初始赐福/HP/重抽；新Player先注入Meta Stats，再恢复跨房HP和碎片。死亡/结局将收入与历史同次提交，历史再注入CrownVoiceSystem。测试入口在autoload初始化时使用独立档；存档格式、去重与验证见[152证据](docs/proof/issue-152/README.md)。

### 领域音频组合（#176 / #179）

`RealmStage` 完成玩家、几何与 HUD 初始化后安装领域音频组件，并注入房间引用；没有专属声景脚本时仍安装通用 `RealmAudioDirector`。音频只消费注入状态、真实技能事件和 Stage 生命周期，不读取 RunDirector/RunState，不参与伤害或进度结算。环境交叉淡出和空间音源池随暂停、死亡、退出停止或释放。

`SorrowSoundBank` 的rain由独立固定种子生成连续双层滤波噪声，4秒PCM循环使用额外0.25秒尾部与开头平滑重叠，消除旧循环接缝及13个规律短促共鸣。涉水音色由私有种子的_motion_water生成：滤波噪声与缓变液体共鸣，当前轻柔版75ms淡入/180ms淡出、增益0.38并额外平滑高频，不读录音数据。正式SorrowAudioDirector和独立几何fallback共用MOTION_VOLUME_DB=-17dB；房间加载时预热两种缓存。音频路由、涉水触发和真实武器播放仍由原组件管理，其他五种音色PCM字节不变。

`SorrowAudioDirector` 负责本房间水声；独立 `SorrowBoonAudio` 在每个领域监听已装备赐福的真实泪晶事件。`SorrowRealm.set_audio_managed(true)` 显式关闭旧 splash 音源，保留涟漪及独立场景默认行为。玻璃反馈通过公开 `PsycheFragments.set_brittle_audio` 替换已有伤害音源，避免重复 Health 监听。`SorrowEffect` 仅在实际消费成功后派发 `sorrow_tear_collected`，视觉和音频可以分别订阅。

恐惧声音表现由 `RealmStage` 注入演员和玩家；`FearAudioDirector` 只读取真实蓄力、预警与成功瞬移状态，使用固定 8 个持续声部。短音复用 `RealmAudioDirector` 的 16 个声部，动态音库把跨领域赐福语义事件映射到声效。`fear_flaw_audio_managed` 在同步事件分发中声明音频接管，没有接管者时保留原暴击声音，避免独立入口丢声或正式房间双播。

愤怒声景复用固定演员声音池和瞬态池。`WrathRealm.set_audio_managed(true)` 公开移交环境音频，剥夺刷新不会重启旧炉鸣；独立几何默认保留原行为。`wall_slam` 的实际碰撞事件由音库映射，尖刺只在真实 `Events.projectile_registered` 且 source 为注入玩家时播放。穿刺者自毁的撞墙增量在既有 `enemy_defeated` 信号里同步消耗，早于选卡暂停；轮询共用同一计数，恢复后不补播。旧 WrathBoons 回退在延迟回调读取同步接管标记，并检查玩家存活、暂停、效果归属；回退只有一个声音节点，卸卡/死亡/退出随效果 cleanup 释放。

## Epic 7：赐福图鉴（#174）

`DualBoonCodex` 通过 `setup(manager, discovered)` 接收真实装备与发现快照，只读查询 `BoonManager.can_equip`。父级 `BuildInspector` 持有暂停和页面生命周期，子页面只在可见时处理肩键和内部焦点，隐藏后不截获战斗输入。

`MetaProgression` 在成功选卡事件上记录发现，`RunDirector` 在恢复装备时补录；新增 `discovered_boons` 是兼容 v1 旧档的可选字段，随原校验和及原子写盘保存。失败时保留待写知识，下次打开检视或成功存档重试；UI 不发放赐福、不修改战斗装备。

## Epic 6：接触光照与瞄准景深（#171）

`environments/default_env.tres` 是共享 SSAO/SSIL 参数资源。RealmStage、四领域环境与演出组合根复制此资源后保留各自氛围，不共享可变 Environment 实例。Forward+ 高质量屏幕空间接触光照用于增强白色建筑的尺度和交界可读性。

`ADSFocus` 是 Player 的呈现组件，仅给渲染用 ViewCamera 注入私有 `CameraAttributesPractical`；瞄准和伤害仍由原逻辑相机完成。它以至多 20 Hz 的物理查询获取焦点并平滑收敛，瞄准时使用轻度前后景模糊；死亡、禁用和退出释放或恢复相机状态，不修改武器、命中或移动数值。

### 心象日记与双面档案（#175）

`RunDirector` 在实际安装领域房间、收到玩家死亡或领域 Boss 击败信号时记录 `MetaProgression` 的 `visited_realms` / `defeated_realms`，最终 `ReconciliationSequence.finished` 才记录 `reconciled`。领域索引取当前编排，不从挑战次数或死亡深度猜测。`archive` 是 v1 存档新增的可选字段；旧档缺字段默认全部锁定，读档验证领域范围、去重与 defeated ⊆ visited，失败写盘保留内存并随后续成功保存重试。

`LoreEntries.project(archive)` 只投影已解锁文案：访问或死亡开放该领域手记和皇冠评论，击败再开放其人性保护价值，和解开放终章。未解锁标题、正文及另一面评语不放进 UI 控件、tooltip 或 metadata。`LoreDiary.setup(archive)` 接收上层传入的快照；`MetaProgression.archive_snapshot()` 复制数组，阅读与滚动不改变真实进度。

战斗入口由 `BuildInspector` 的第三页托管，继续由父级拥有暂停、鼠标及 TAB / ESC。结局菜单以 `ArchiveReader` 复用同一日记组件，打开时隐藏底层菜单以隔离手柄焦点，关闭后恢复菜单；阅读不创建新挑战，也不要求 Player。`LoreDiary` 不读写 RunDirector，不拥有暂停。进度和原生布局证据见 [#175 集成验收](docs/proof/issue-175/integration.md)。

### 皇冠与终局音频（#180）

`CrownVoiceDSP` 只接受真实 AudioStreamPlayer/3D 引用与发光值，为每个来源复制效果并创建独立总线。CrownVoiceSystem 注入 radiance_changed；开场只在 ENCOUNTER 安装处理；DoppelgangerSpawn 用实际皇冠材质状态更新处理，并在玩家死亡时停止语音。退出恢复原发送总线并移除自有总线。

`BodyReassembly` 保持原阶段/台词事件及时间，由 `ClimaxAudio` 订阅，预热原创 PCM 后执行100ms `AudioVacuum`、爆碎、原语音声像、重组共鸣和钢琴。AudioVacuum 的静音租约支持重叠、暂停、死亡与提前退出，原 Master 静音状态可恢复且不写 Master 音量。组件不推进剧情。最终Boss组合根通过 `setup_combat(player)` 安装通用技能音频，只有有效Stage才连接领域事件和设置；音频不读取战役单例。
