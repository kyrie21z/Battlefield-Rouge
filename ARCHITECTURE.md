# 架构与依赖规则

引擎：Godot 4.7.2，Forward+，Jolt 物理。所有人必须用同一个版本。

## 目录

| 目录 | 放什么 |
| --- | --- |
| `autoload/` | 全局单例：`Events`（信号总线）、`RunState`（本局状态）、`InputMapSetup`（按键） |
| `components/` | 可复用的小部件：生命值、受击判定、数值（Stats） |
| `weapons/` | 枪的数据（`rifle` / `shotgun` / `sniper` 的 `.tres`）和开火逻辑 `Weapon`。`weapons/melee/` 是三把近战的数据和 `MeleeWeapon` |
| `actors/` | 玩家、敌人 |
| `zone/` | 战区控制（zone director）、据点、占点配置（`capture_config.tres`） |
| `fixtures/` | 可复现的起点（`RunFixture` 资源，一个 id 一个 `.tres`），AC-07 |
| `buffs/` | 增益，每个增益一个 `.tres`。流派身份是 `School`（图标和方向，不含效果数值） |
| `ui/` | HUD、三选一增益界面、结算界面 |
| `maps/` | 战区场景，由 `tools/gen_zones.py` 生成 |
| `tools/` | 编辑器外的辅助脚本 |
| `docs/` | 设计文档。范围和验收以 `docs/Cut-001b.md`、`docs/MVP_Scope.md` 为准 |
| `docs/adr/` | 架构决策记录 |

## 依赖规则

1. `components/`、`weapons/`、`actors/` 只向 `Events` 发信号，不读写 `RunState`，也不通过路径或分组去找别的系统。
2. 只有 `RunState` 和 `zone/` 下的战区控制可以改本局状态。
3. 增益只修改 `Stats`，不直接改玩家或武器脚本。已有能力的新卡通过 `.tres` 定义并加入 `BuffPool.ALL`；新增能力由组件读取对应 Stats，`Buff.extra_adds` 可附带共享能力解锁。
4. 依赖方向只能是 `ui → zone → actors → components`，反过来要用信号。
5. 战区里的玩法代码可复现（AC-07）：不读墙钟，时间用 `SimClock`；不 `randomize()`，随机数用全局的 `randf()` 等，战区开头已经 `seed()`。细则见 `docs/adr/0005-reproducible-runs.md`。
6. 从 `../origin/sheji` 迁移代码时，先删掉对 `GameState`、`VoiceManager`、突破模式、载具、商店的引用，再放进来。

## 一个战区的流程

一局 3 次选择：开局前 1 次 + 两个小关结束各 1 次；小关 2 和 Boss 进场不选；Boss 后不选。这对应 AC-04（D-002 于 2026-10-27 修订，原为每关先选、一局五次）。九张不同图标的卡对应 AC-08，见 [ADR 0006](docs/adr/0006-nine-buffs-and-entry-choices.md)。占点仍为窗口 ±150ms、普通锤 +8%、完美 ×1.5，配置是 `zone/capture_config.tres`。小关据点在 z≈-8（靠近后方增援）；据点开放后按 `zone/reinforcement_config.tres` 从后方刷增援，插旗冲击波让小怪逃向刷怪点后消失，通关增益在旗旁增益台按 F 打开。见 [ADR 0007](docs/adr/0007-reinforcements-shockwave-pedestal.md)。节拍见 ADR 0003，Boss 见 ADR 0004。Boss 关没有增援、冲击波和增益台。

由 `zone/zone_director.gd` 执行，场景里的节点顺序是：几何 → 掩体点 → 据点 → 玩家 → 敌人 → `ZoneDirector` → `HUD`。HUD 放在最后，保证它 `_ready` 时战区控制已经准备好。敌人排在 `ZoneDirector` 前面，所以战区控制 `_ready` 时敌人已经 ready。

1. 保留战区随机种子、`SimClock` 与同步导航烘焙。把已有卡应用到玩家 Stats，收集敌人与掩体。只有 `zone_index == 0` 进入 `BUFF_SELECT` 并暂停；此时敌人还没有玩家目标。小关 2 和 Boss（以及从 Boss 起步的 fixture）解除暂停后直接开打，敌人立刻拿到目标。
2. 确认 `enter` 卡后记录选择历史，发 `Events.buff_chosen`，立即应用新卡，再给敌人设置目标。小关进入 `CLEAR_GUARDS`；Boss 保留 `open_at_start`，直接进入 `HAMMER_POINT`。
3. 小关守卫全灭开放据点，并开始从后方刷增援。增援不回退进度，也不把据点重新锁上。E 锤命中仍按原节拍配置计进度。100% 插旗时冲击波让存活小怪停止攻击并逃向后方刷怪点，到达或超时后移除，不算击杀。旗旁出现增益台，走近按 F 才提供 `clear` 卡；选完暂停并载入下一关。下一关不再发 `enter` 卡，进场时自己解除暂停。Boss 不加这些，插旗 1.4 秒后直接胜利，不再发牌。
4. 死亡清空本局增益、选择历史与卡袋，显示阵亡界面。普通重开回第一关；fixture 模式仍回到同一 fixture 的关卡、预设卡和种子。选择提交、占点回调和场景推进均有防重保护。

新增战区：在 `tools/gen_zones.py` 里加一个布局，生成后把场景路径加到 `RunState.ZONE_SCENES`。

## 三把枪怎么切换

`Player/Head/Camera3D/Weapon` 是一个 `Weapon` 节点，它扛**一整套枪**：`data_set` 是三份 `WeaponData`（`weapons/rifle.tres` → `shotgun.tres` → `sniper.tres`，就是滚轮的顺序）。数据和逻辑分开这一条不变，变的只是「一次只显示一把」。

- `_ready()` 给每份数据实例化一个 view scene，全挂在自己身上、先全部隐藏，并按各自的 `magazine_size` / `reserve_ammo` 建一份弹匣状态。
- `select(index)` 换枪：存下当前枪的弹匣和备弹、把新枪的那份取出来、只显示自己的模型、重置冷却和扩散、中断正在进行的换弹（手离开了枪，子弹不会自己上膛）。
- `data` 永远指向手里那把，所以 `Player` 和 HUD 不用知道槽位：`player.gd` 读 `weapon.data.ads_fov` 来变焦，HUD 读 `weapon.ammo` / `reserve`，换枪时 `Weapon` 补发一次 `ammo_changed` 和 `selected`。
- 滚轮在 `Weapon._process()` 里读 `weapon_next` / `weapon_prev`（`autoload/input_map_setup.gd` 绑到滚轮上/下），近战挥砍时也不拦——只是枪被 `set_drawn(false)` 藏着，换到的枪同样保持隐藏。开镜时同一对动作改去调倍率，见下一节。

三把枪共用一套开火代码，差别全在数据里：`fire_mode`、`fire_interval`、`damage`、`pellets`、衰减、扩散、后坐、弹匣、`ads_fov`。**霰弹枪就是 `pellets > 1`**：一次扳机打出 N 条射线，每条都在同一扩散锥里取方向，各自用 `Hitbox.apply_hit()` 结算，所以「一发九颗、每颗 11 伤害」不需要另写一套武器。

## 狙击镜

镜不是「把 FOV 调小」而已，是三件事一起换：

1. **倍率表**：`WeaponData.scope_zoom_levels`（狙击枪 = [2, 4, 8]，别的枪是空数组）。空数组就是机瞄，走 `ads_fov`；非空就是开镜，走 `Weapon.fov_for()`：视野 = 基础视野 ÷ 倍率（75° → 37.5 / 18.8 / 9.4）。`Player._process` 照旧把相机 FOV 插值到这个目标，所以变焦是平滑的。
2. **滚轮改道**：`Weapon._cycle_wheel()` 先问 `is_scoped()`——开镜时滚轮调 `zoom_index` 并发 `zoom_changed`，没开镜才 `select_next()` 换枪。这样「滚轮换枪」和「滚轮换倍率」不打架，也不用新按键。
3. **只画分划，不遮黑**：`ui/scope.gd`（`ScopeReticle`）把准星、密位刻线和倍率读数直接画在整屏上，没有任何遮罩——前两版分别是「圆形窗口 + 四周全黑」和「整帧椭圆」，都吃掉玩家正在瞄的那块画面。现在镜的身份由**变焦 + 分划 + HUD 收起准星**三件事表达（HUD 的普通准星本来就只在不开镜时显示）。同一时刻 `Weapon._apply_view_visibility()` 把枪的视图模型藏起来，否则枪身正好挡在镜里。鼠标灵敏度也除以倍率，不然 8 倍时手一抖就飞出画面。

判定没有变：开镜打的还是 `ads_spread`（狙击枪 0.05°），镜只是让玩家看得见目标。

## 近战怎么打

由 `weapons/melee/melee_weapon.gd` 执行，挂在 `Player/Head/Camera3D/Melee` 上。数据和逻辑分开：每把近战是一份 `MeleeData`（`weapons/melee/*.tres`），`MeleePool.ALL` 决定 Q 的循环顺序（匕首 → 斧 → 太刀）。

挥砍写在屏幕上，不是写欧拉角：`.tres` 给的是刀尖在**起手**和**落点**的归一化屏幕坐标（-1..1，+y 向上），`_tip_direction()` 解一个二次方程，把刀刃转到「刀尖正好落在那个屏幕点」的方向；短兵器加手的位置够不着时退化成朝那个方向指。刀尖在生效窗口里沿两点的直线扫过去，所以匕首写 (-1.0,-0.98) → (1.0,0.98) 就是整屏对角，斧写 (0,0.64) → (0,-0.60) 就是中线竖劈。

1. 按 V：当前近战的 `windup` 起手，视图模型出现并开始挥砍动画，同时收枪（`Weapon.set_drawn(false)`）。
2. 起手的同时判一次「吸附」：`magnet_range` 内、`magnet_arc_degrees` 锥里最近的敌人存在，就发 `lunge`——朝**那个敌人**冲 `lunge` 米（匕首 0.35 / 斧 0.45 / 太刀 0.55），耗时 `lunge_time`。冲刺直接覆盖玩家的速度，所以**不按方向键也会冲**；每把的 `magnet_range` 都略短于自己的 `reach`，贴脸（`stop_distance` 内）和空挥都不动。三把都有，数值不同。
3. 生效窗口开始时把命中弧心转到那个敌人身上（`_advance_phase()` 里改 `_swing_forward`），所以准星偏几十度也照样劈中它——这是「把攻击吸附到敌人身上」的另一半，只位移不转弧的话偏角大一点就会空。之后走到 `STRIKE_AT`（80%）做一次锥形判定（球查询 `HITBOXES` 层，按 `reach` 和 `arc_degrees` 过滤，再做一次 `WORLD` 视线检查），窗口关闭时再判一次。命中的身体用 `Hitbox.apply_hit()` 结算，同一个 `Health` 一次挥砍只吃一次，`max_targets` 按身体数算而不是按 hitbox 数。
4. 命中同时发 `recoil`（相机后坐）、`hit_landed`（HUD 命中标记），并调用敌人的 `apply_impact()` 做击退。
5. 收招回到 rest 姿态、隐藏视图模型、枪重新出现。

视图模型的姿态由相位计时器逐帧算（`_setup_pose` / `_update_pose`），不用 Tween：两套时钟会让刀的位置落后于判定。生效窗口用 smoothstep 走，来回都不打滑，挥砍才看得清。绕刀轴那个自由度由 `_roll_for()` 定：挥砍方向横过刀刃时（`across` > 0.5）直接用「刃口领先」，只有刀沿着自己走的时候才退回「刀面朝镜头」——两半对半混的版本在中段会剩一点刀背在前，正好是看得出来的那一段。刃在模型哪一侧由 `MeleeData.edge_side` 说明：不看几何（顶点太少，读不出凸面），看贴图上画亮的那条线，摆平两个面各拍一张对照，太刀是 +1。

斧是对称双刃（`edge_side = 0`），没有刃口可挑，但它有「哪一面对着地面」的问题：**竖着往下劈时，斧头的板面应该落在挥砍自己的竖直平面里，从眼睛看过去是接近侧对镜头的**（斧刃先着地）；板面正对镜头就是拿斧子的平面往下拍。所以斧的 `*_roll` 写 75°（离纯侧对差 15°，留一点斧头的体量在画面里），而不是默认的 0。这一条用 `.tres` 里的数字表达，`blade_facing()` 会量出来，测试查它「不是平板朝镜头」（< 0.45）。

两只手和刀尖一起决定幅度：斧的 `cut_*_hand` 写在**中线附近**（x = 0.05 米）、胸口前方，刀尖从画面上缘劈到下缘（(0,0.79) → (0,-0.95)），所以是「双手举着、从最中间往下劈」。改这几个数会同时改幅度和姿态，`tests/melee_test.tscn` 会重新量。

视图模型的材质是逐实例改的（`_flat_shade`）：不受光（`UNSHADED`）、双面（导出的刃是单面板），再加 `view_brightness` 提亮（斧头是深炭色，不提亮在画面里就是一坨黑）。

近战不读 `RunState`，只发信号；伤害和节奏从 `Stats` 读。枪的 `DAMAGE`、`FIRE_RATE` 仍乘到近战上。刀具卡另外乘 `MELEE_DAMAGE`、`MELEE_SPEED`、`MELEE_RANGE`，基数都是 1，所以没选刀具卡时三把近战保持 `.tres` 原值。`tests/melee_test.gd` 用投影量刀尖：起手和落点实际落在屏幕哪里、两点连起来跨不跨屏、刀尖在不在眼睛前面、刀面朝不朝镜头。

## 九增益与能力组件

`BuffPool.ALL` 为 `firearm`、`blade`、`skill` 每派三张。每次每派各一张，前三次覆盖九张，用完重洗；发牌只使用战区已播种的全局随机，重开清袋。`Buff` 含稳定 id、独特图标、说明和 Stats 修改，School 只含流派身份。

Stats 按 `(base + Σadd) × Πmul` 计算。`MeleeWeapon` 读取刀具伤害/速度/距离，`PlayerShield` 读取护盾解锁/持续/冷却（按键是 G，Q 留给切近战），`CombatTraits` 监听刀、盾、枪与 Health 的信号执行三张核心卡机制。`ReloadCharge` 只做带遮挡、按 Health 去重的爆炸及短暂特效，不访问 RunState。数值与边界见 [当前九增益](docs/Buff当前实现.md)。所有新能力随暂停冻结，死亡清理临时状态。

## 碰撞层

定义在 `components/collision_layers.gd`，代码里不要直接写数字。

| 层 | 常量 | 放什么 |
| --- | --- | --- |
| 1 | `WORLD` | 场景几何和道具 |
| 2 | `ACTORS` | 玩家的移动碰撞体 |
| 3 | `ENEMIES` | 敌人的移动碰撞体。敌人的 mask 不含这一层，所以敌人之间不互相推挤 |
| 4 | `HITBOXES` | 受击判定 |

子弹（玩家的射线、敌人的慢速弹）只检测 `WORLD | HITBOXES`。角色的移动碰撞体和受击判定位置重叠，子弹如果检测 `ACTORS`，会先打在移动碰撞体上而打不到受击判定。

## 从旧工程迁移

旧工程在 `../origin/sheji`，只当参考，不修改。迁移顺序和原因见 `docs/adr/0001-rebuild-on-clean-skeleton.md`。
