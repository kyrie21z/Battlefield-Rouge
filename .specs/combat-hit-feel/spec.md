# Spec: 战斗打击感重塑与敌人头顶血条（Combat Hit Feel & Enemy Overhead Health Bars）

## Problem Statement

当前正式战役（四领域 `RealmStage` 与终局战）的战斗打击感显著不足，玩家开枪与挥刃普遍出现“打空气 / 打木桩 / 枪软刀轻 / 看不清剩余血量”的体验问题。代码排查表明这并非单一数值偏轻，而是三层结构性缺口叠加所致：

1. **正式战役 HUD 反馈大断链（P0）**：旧原型 `HUD` 中已完备的命中标记（Hitmarker）、命中/爆头/击杀叠层音效、击杀与弹反顿帧（HitStop）、连杀确认文字、玩家受击重音与低血心跳，均未接入正式战役使用的 `RealmHUD` 与 `ClimaxCombatHUD`。
2. **绝大多数正式敌人缺少受击反应（P0）**：全仓库 14 类敌人中，12 类正式敌人（恐惧/愤怒/悲伤领域小怪、怠惰新怪与全部 5 个正式 Boss）未挂载 `HitReaction`，挨打时无受击闪白、无模型后仰、无爆头火花；叠加 `CrystalImpact` 硬编码同一 RNG 种子，每次命中碎屑轨迹完全相同。
3. **枪刃本体表现与音频偏轻（P1/P2）**：
   - 黑晶手枪震屏幅度仅 `0.08°`、FOV 脉冲仅 `0.8%`，4 块黑晶部件开火时完全静止，枪口闪光极小且无瞬态动态光照，曳光弹过快（`320 m/s`）难以建立弹道连接感。
   - 意志短刃挥砍缺少 3D 刀光拖尾、挥砍曲线平滑缺乏爆发力、命中无镜头震动与近战微顿帧、实际物理击退位移不足 `0.09 m`（且受击特效仍使用与晶体美学割裂的旧版暗红血雾）。
   - `ProceduralAudio` 运行在 `22050 Hz` 单声道，11kHz 以上晶体高频泛音截断，枪声偏闷、近战命中仅为单薄白噪；盾牌格挡（如愤怒领域 Accumulator 正面挡弹）缺少专属弹反火花与钝响。
4. **敌人血量可读性缺失（P1）**：普通敌人头顶没有血条，玩家无法直观判断单发伤害占比与补刀时机；正式战役 Boss 顶部血条仅是裸进度条，未接入仓库既有的 `HealthTrail` 扣血白条拖尾。

---

## Solution

在不破坏既有玩法规则、AC-07 确定性回放与 Mind Freak 极简抽象晶体美学的前提下，构建一套跨旧原型、四领域正式战役与终局战**统一共享的战斗打击感反馈层**，并新增面向全部非 Boss 敌人的**屏幕空间头顶血条**：

1. **抽离并统一 HUD 战斗反馈层（`CombatFeedbackLayer`）**：
   - 将命中标记（普通白 / 爆头金 / 击杀红三态缩放弹出）、命中/爆头/击杀与玩家受击叠层音频、低血量心跳、击杀/爆头/弹反/近战顿帧、连杀确认提示抽成独立 UI 呈现组件，统一接入 `HUD`、`RealmHUD` 与 `ClimaxCombatHUD`。
   - 为 `RealmHUD` 顶部 Boss 血条接入既有 `HealthTrail` 扣血白条拖尾与受击微抖，提升高血量目标的“咬肉感”。
2. **新增敌人头顶血条（`EnemyHealthBars`）**：
   - 在 HUD 侧新增轻量 2D 屏幕空间投影层，统一追踪当前房间存活的非 Boss 敌人，自动在头顶上方绘制极简高对比血条与 `HealthTrail` 掉血白条拖尾。
   - 智能过滤 Boss（由顶部大血条负责）、未激活/潜水/死亡/背面/超距/被实体墙遮挡的敌人，并响应暂停冻结与无中心准星遮挡原则。
3. **全敌人接入晶体受击反应（`HitReaction` 覆盖全阵营）**：
   - 确保四领域所有小怪、`FearReaper`、`FearWisp`、`SlothMire` 以及全部 5 个 Boss 均具备受击视觉响应（80ms 高亮闪白 + 方向性模型后仰 + 爆头金色火花），Boss 采用温和后仰倍率（`< 0.5`）并保留既有晶屑/预切碎裂死亡演出。
   - 修复 `CrystalImpact` 固定种子问题（改用私有递增种子）并加入短寿命命中亮斑。
4. **重塑黑晶手枪与意志短刃本体手感**：
   - **黑晶手枪**：提升表现层震屏与 FOV 脉冲（不改逻辑后坐力契约）；开火瞬间驱动 `slide_block` 后坐复进与 `core_crystal` 能量爆闪；在枪口增加瞬态 `OmniLight3D` 照亮枪身与白墙；微调曳光弹速度与亮度以增强弹道可读性。
   - **意志短刃**：增加 3D 弧形挥砍刀光拖尾；改用先蓄后爆的挥砍速度曲线；命中敌人触发定向微震屏、轻量微顿帧与晶体斩裂特效（替代旧血雾）；提高近战 `impact_force` 与 `impact_stagger` 使非免疫敌人获得可见的半步击退；支持对盾牌格挡输出专属金属钝响与弹开火花。
5. **升级战斗音频清晰度与冲击层**：
   - `ProceduralAudio` 升级至 `44100 Hz`，重塑黑晶手枪（加强低频胸腔下潜 + 高频晶体脆裂瞬态）与意志短刃命中（低频重击 + 晶体切裂泛音），并支持手枪低弹量（剩余 ≤ 2 发）轻微高频金属提示音与连续命中细微音高递进。

---

## User Stories

1. **As a** 正式战役玩家，**I want** 在四领域与终局战中每次枪击或挥刃命中、爆头、击杀、弹反时立刻获得准星命中标记、层次分明的命中/击杀音效、连杀提示与短暂顿帧，**so that** 每一发子弹和每一刀都有明确的命中确认与击杀爽感。
2. **As a** 玩家，**I want** 射中或斩中任意领域的普通敌人与 Boss 时，目标立刻出现明显的受击闪白、受击后仰、爆头火花以及每次角度各异的晶体碎屑，**so that** 攻击目标有扎实的实体感，而不是在打静态雕塑。
3. **As a** 玩家，**I want** 在所有存活普通敌人的头顶看到简洁清晰的血条与扣血拖尾，并在 Boss 顶部血条上看到扣血拖尾，**so that** 我能直观判断单发伤害与剩余血量、做出切换短刃补刀或换目标的决策。
4. **As a** 玩家，**I want** 敌人处于潜伏/未激活、死亡、被墙体完全遮挡或位于视野后方时不显示头顶血条，**so that** 屏幕保持极简整洁且不泄露掩体后敌人的位置。
5. **As a** 玩家，**I want** 黑晶手枪开火时感受到更扎实的震屏、枪身晶体滑套复进、核心爆闪、枪口瞬态光照与清晰的弹道连接，并在弹匣快打空时听到细微音色提示，**so that** 半自动点射富有节奏感与力量感。
6. **As a** 玩家，**I want** 挥舞意志短刃时看到利落的晶体刀光轨迹，砍中敌人时感受到明显的击退位移、镜头冲击、微顿帧与晶体斩裂特效，且挥空与命中有清晰的手感反差，**so that** 近战切入与终结富有重量感。
7. **As a** 玩家，**I want** 子弹命中愤怒领域蓄压者（Accumulator）正面护盾或被敌人闪避时听到专属格挡/闪避反馈、不误播真实命中提示，**so that** 我能立刻理解该击被挡下并调整走位或武器。
8. **As a** 玩家，**I want** 在正式战役中自身掉血时获得与红边同步的轻/重受击音效与低血心跳，且在护盾/无敌挡伤时绝不误触发受击反馈，**so that** 战斗危机的听觉与视觉提示一致。
9. **As a** 自动化回放与测试运行者，**I want** 所有打击感表现与血条渲染在暂停时完全冻结、在 `fixture` 与 `headless` 模式下安全跳过顿帧、且绝不消耗全局模拟 RNG 或移动敌人碰撞体/Hitbox，**so that** AC-07 可复现性与既有战斗数值保持 100% 稳定。

---

## Implementation Decisions

### 1. 架构边界与单向依赖

严格遵守 `ui → zone → actors → components` 依赖方向：
- 新增 UI 呈现组件只订阅注入的 `Player` / `Weapon` / `MeleeWeapon` / `Health` 与全局只读信号 `Events`，**绝不读写 `RunState` 或 `RunDirector`**（是否禁用 HitStop 沿用既有 `RunState.fixture != null` 检查规则）。
- 优先通过 GDScript 代码组合组件，**避免批量修改现有 `.tscn` 场景文件**，防止 Godot 场景合并冲突。

### 2. 模块与接口契约

#### A. 共享 HUD 战斗反馈层（`CombatFeedbackLayer`）
- **职责**：统一托管 Hitmarker、KillText、命中/爆头/击杀/受击/心跳音频播放器，以及击杀/弹反/近战命中顿帧调度。
- **接入方式**：提供 `setup(player: Player, options := {})` 接口，由 `HUD`、`RealmHUD`、`ClimaxCombatHUD` 共同挂接；`HUD` 保留既有公开属性/节点名兼容（保证 `hit_feel_test` 与 `gun_feel_test` 零破坏）。
- **核心契约**：
  - 订阅 `player.weapon.hit_landed`、`player.melee.hit_landed`、`Events.blade_parried`、`player.health.damaged`、`player.health.died`。
  - 新增 `weapon.hit_blocked`（或由受击上下文透出 `blocked_by_enemy_shield` 信号）用于盾牌格挡专属金属钝音 + 灰色/火花视觉，不触发普通白/金 Hitmarker。
  - HitStop 时长分级：普通击杀 `0.05s`、爆头击杀 `0.075s`、短刃弹反 `0.05s`、近战非致命命中 `0.025s`；当 `RunState.fixture != null`、`get_tree().paused`、`player.health.is_dead()` 或 headless 未显式开启时全部跳过。
  - 受击音效合并窗口 `0.06s`，重击阈值 `>= 20% max_health` 或爆头播放 `player_hurt_heavy`；低血进入 `< 30%`、退出 `> 35%` 驱动心跳；暂停冻结，玩家死亡立刻静音并清空状态。

#### B. 敌人头顶血条层（`EnemyHealthBars`）与 Boss 血条增强
- **职责**：作为 HUD 子 `Control`（`mouse_filter = IGNORE`，层级在十字准星之下、世界之上），维护活跃非 Boss 敌人的投影状态与各自独立的 `HealthTrail` 实例。
- **目标发现**：初始化时读取 `stage.enemies`（或场景内现有 `Enemy` 节点），并订阅 `Events.enemy_registered` 动态纳管后续生成的敌人（如增援与激活后的 `FearWisp`）。
- **可见性与过滤规则**：
  - 排除：`is_boss == true`、`health.is_dead()`、未激活 `dormant == true`、悲伤潜行者 `submerged`（无 `HITBOXES` 碰撞层）、距离超过展示上限（默认 `32 m`）、处于相机后方、或从相机到血条锚点被 `CollisionLayers.WORLD` 遮挡。
  - **显示策略**：**受击后常显或进入瞄准/近距范围显示**——具体为：满血敌人默认在进入近中距（`<= 18 m`）或处于准星小锥角（`<= 8°`）时淡入显示，一旦掉血即保持清晰可见直至死亡（避免满屏杂乱，同时保证玩家瞄准任何目标都能立刻读到血量）。
  - **锚点计算**：优先取敌人头部 `Hitbox` 顶部或 `eye_height + 0.55 m` 作为世界锚点，投影到 2D 屏幕坐标；宽 `54–64 px`、高 `5–6 px`，深色细描边 + 领域/敌方主题填充色 + `HealthTrail` 白色延迟扣血条；若敌人拥有 `max_shield > 0` 或残余护盾，在血条上方叠加 `2 px` 护盾细条。
  - **状态生命周期**：死亡当帧隐藏并移除追踪条目；暂停时 `HealthTrail` 停止推进；退出场景清理弱引用缓存。
- **Boss 血条升级**：`RealmHUD` 顶部 Boss 血条替换为支持 `HealthTrail` 扣血白条拖尾与受击短促横抖（`0.12s`）的自定义绘制控件（沿用既有 `BossHealth` / `HealthTrail` 设计语言，保留领域配色与 Boss 名称）。

#### C. 全敌人受击视觉反应（统一 `HitReaction`）
- **统一覆盖机制**：在 `Enemy` 基类提供幂等安装方法（或在 `RealmStage._register_actor` 与各领域敌人 `_ready()` 兜底挂载 `HitReaction`），自动为缺少 `HitReaction` 的全部非旧版敌人与 5 个 Boss 挂载轻量版 `HitReaction`（死亡保留各敌人原有的 `SlothShatter` / `FearShatter` / `WrathShatter` / 溶解演出，不叠旧版红肉块 `DebrisBurst.spawn_death`）。
- **视觉与安全不变量**：
  - 闪白：80ms 高反差白色/晶莹高亮覆盖（`FLASH_ALPHA = 0.75~0.85`），仅通过 `material_overlay` 叠加，**绝不修改 Mesh 原始 `material_override` 或共享材质**，结束后还原为 `null`。
  - 后仰：普通小怪 `flinch_degrees = 7.5°`、`flinch_shove = 0.08 m`；Boss 统一 `flinch_scale = 0.30`（有厚重反馈但稳重不滑稽）；爆头倍率 `1.4×` 并触发晶体金色火花。
  - 严格只变换可视网格节点，**绝不触碰 `CharacterBody3D.global_transform`、`Hitbox` transform、AI 状态或全局 RNG**。
  - **动态模型兼容**：`HitReaction._acquire_model()` 在网格列表为空时支持延迟采集（兼容在 `_ready()` 中异步/动态构造子网格的程序化敌人视觉体）。

#### D. 枪刃本体手感与特效升级
- **黑晶手枪（`Weapon` + `ObsidianPistolView` + `obsidian_pistol.tres`）**：
  - 保留逻辑后坐力契约：`camera_kick = 1.2`、`camera_yaw = 0.3`、`camera_return_time = 0.12`、`aim_feel_scale < 1.0`。
  - 强化表现参数：`shake_degrees` 由 `0.08` 提升至 `0.38`、`shake_fov_punch` 由 `0.008` 提升至 `0.020`、`shake_duration = 0.13`；`view_kick_back = 0.042`、`view_kick_pitch = 3.4`、`view_kick_roll = 1.4`、`view_spring_stiffness = 520`、`view_spring_damping = 28`（微欠阻尼产生清脆回弹，且 150 帧内完全归静）。
  - 零件联结动画：`ObsidianPistolView` 新增 `kick_fire()` 接口——开火瞬间 `slide_block` 沿 `+Z` 瞬退并快速复进、`core_crystal` 发射强度瞬时脉冲提亮（`1.5 → 5.5` 并在 `0.10s` 内衰减）；不影响换弹重组进度时钟。
  - 枪口光照与曳光：`Muzzle/Flash` 略放大并配对一个 `0.045s` 衰减的瞬态冷蓝 `OmniLight3D`（无阴影，避免开销）；`Tracer.SPEED` 由 `320` 调至 `190 m/s`、`THICKNESS` 由 `0.014` 调至 `0.020`（仍满足 `< 0.03` 契约），让 10–30m 交火能清晰看见弹道线。
  - 命中碎屑：`CrystalImpact` 使用静态递增私有种子（`SEED + counter`）替代固定常量，彻底消除每枪碎屑完全雷同的问题；命中点增加 `0.06s` 瞬态亮斑/短光点，爆头扩大碎屑规模与初速度。
- **意志短刃（`MeleeWeapon` + `mind_blade.tres`）**：
  - 新增 3D 弧形刀光拖尾节点（`BladeSlashTrail`）：在 `Phase.ACTIVE` 期间按刀根/刀尖前几帧位置构建轻量半透明发光三角带，并在 `0.14s` 内淡出，随暂停冻结。
  - 挥砍曲线：`Phase.ACTIVE` 由对称 smoothstep 改为爆发加速曲线（先蓄后劈），增强劈砍锐度。
  - 命中冲击：新增 `shake` 信号接入 `Player.add_view_shake(0.65°, 0.018, 0.14s)`；`impact_force` 由 `2.0` 提升至 `6.2`、`impact_stagger` 由 `0.15s` 提升至 `0.22s`（在 `IMPACT_DECAY = 22` 下产生约 `0.40–0.55 m` 的清晰击退）；命中特效从旧 `Impact.spawn(..., flesh=true)` 切换为晶体斩裂特效（`CrystalImpact` 强化版，无写实血雾）。
- **格挡反馈**：当敌人（如愤怒 `Accumulator`）主动格挡玩家攻击时，发出专属格挡反馈（金属脆响 + 盾面弹开火花 + 零掉血/不弹红金 Hitmarker），避免玩家误判为“判定丢失”。

#### E. 音频清晰度与冲击层（`ProceduralAudio`）
- `SAMPLE_RATE` 升级为 `44100`（所有既有时间常量、攻击包络与 `-3 dBFS` 峰值归一自动按 `SAMPLE_RATE` 适配，保持确定性与 `1ms < 50%` 柔起音）。
- 重塑核心音色：
  - `gun_pistol`：保留四层结构，加强低频下潜（`165 → 48 Hz`，略延缓衰减增加胸腔厚度），叠加黑晶矿物短促高频泛音（`3.2–6.8 kHz` 瞬态）。
  - `melee_hit`：在滤波噪声基础上叠加低频冲击（`135 → 50 Hz`）与短促晶体切裂谐波，音量提升至 `0.0 dB`。
  - 新增 `hit_block`（护盾格挡金属钝响）与 `pistol_low_ammo` 叠加层（或最后 2 发开火叠加轻微高频机械/晶体提示音）。
  - 连续命中时在 `CombatFeedbackLayer` 私有 RNG/计数器上对命中音效做轻微音高递进（`+0.03/连击`，封顶 `+0.15`，`1.2s` 无命中归零）。

---

## Testing Decisions

### 什么是好的行为测试
好的测试只通过玩家与房间公开交互入口验证**可观测的玩家体验契约与安全不变量**，而不锁死内部私有辅助方法或易变像素细节：
- 验证“开火/挥刃命中真实敌人 → 产生预期反馈（Hitmarker、音频、顿帧、敌人闪白/后仰、血条显示与拖尾、击退位移）”，而不是断言内部私有字段的命名。
- 验证所有安全红线：物理体与 Hitbox 零偏移、原材质零破坏、全局 RNG 零消耗、暂停完全冻结、死亡与场景切换零残留/零泄漏、`fixture` 与 `headless` 模式下顿帧零生效。

### 锁定的测试接缝（1 个新增高层接缝 + 既有回归护栏）
1. **新增主验证接缝：生产 `RealmStage` 战斗打击感集成测试**（参照 `tests/realm_feedback_test.gd` 风格）
   - 遍历四领域生产房间（`sloth/fear/wrath/sorrow` 普通房 + Boss 房）与终局战 `ClimaxCombatHUD`：
     - **HUD 反馈闭环**：普通命中 / 爆头 / 击杀 / 弹反分别触发对应颜色与缩放的 Hitmarker、音效播放、连杀文案、以及（在开启 `HitStop.allow_headless` 且无 fixture 时）准确时长的 `HitStop`；验证 fixture/pause 护栏。
     - **敌人头顶血条与 Boss 血条**：验证存活可见非 Boss 敌人（含激活后 `FearWisp`）正确生成血条并在受击后更新 `HealthTrail` 拖尾；验证 `is_boss`、`dormant`、遮挡、背面、死亡敌人均不显示血条；验证 Boss 顶部血条拖尾在扣血后滞后衰减且暂停冻结。
     - **全敌人受击反应**：对四领域每类小怪及 5 个 Boss 施加非致命命中，断言闪白 overlay 生效、模型网格后仰且结束后完全还原，同时断言 `CharacterBody3D`、`Hitbox`、原始 `material_override` 和全局 `randi()` 序列完全不变。
     - **枪刃与音频契约**：验证手枪开火触发震屏（强于旧基线 `0.08°`）、滑套/核心脉冲、瞬态枪口光、两次 `CrystalImpact` 碎屑速度不同且不耗全局 RNG；验证短刃挥砍产生刀光、命中产生可见击退与震屏；验证 Accumulator 正面格挡不触发普通命中提示；验证 `44100 Hz` 音频满足峰值与柔起音契约。
2. **既有回归护栏（全量必跑）**
   - `tests/hit_feel_test.tscn`（守卫手枪逻辑后坐力契约、柔起音、击杀顿帧时长与旧 HUD 兼容）
   - `tests/gun_feel_test.tscn`（守卫 ViewSpring、Aim Camera 零偏移、Tracer 几何、HitReaction 零副作用）
   - `tests/realm_feedback_test.tscn`（守卫正式战役受击红边与恐惧预警剥夺不变量）
   - `tests/fixture_test.tscn`（守卫 AC-07 确定性回放哈希零漂移）

---

## Out of Scope

- 不更改黑晶手枪或意志短刃的基础伤害、射速、弹匣容量、换弹时长、逻辑后坐力（`camera_kick` / `camera_yaw` / `camera_return_time`）或射程衰减曲线等数值平衡。
- 不引入浮空伤害数字（Damage Numbers）或屏幕全屏后处理色差/径向模糊（保持 Mind Freak 极简克制的视觉语言，后续可独立评估）。
- 不重做敌人 AI 行为树或 Boss 招式机制（仅补全受击视觉反馈、近战击退调校与格挡反馈）。
- 不引入第三方外购商业音频素材或从 `../origin/` 拷贝任何资产；音频提升完全基于仓库既有合规 `.ogg` 与原创程序化合成。
- 不修改 `maps/` 地图几何或 `tools/gen_zones.py` 关卡布局。

---

## Further Notes

- **AC-07 确定性铁律**：任何新引入的随机性（`CrystalImpact` 递增种子、音高微抖、震屏相位）必须严格隔离在私有 `RandomNumberGenerator` 内，合并前必须通过 `tests/fixture_test.tscn` 哈希一致性校验。
- **Godot 4.7.2 与场景卫生**：全流程优先使用脚本化节点挂载，避免批量改写 `.tscn`；新建的 `.gd` 文件需由 Godot 4.7.2 生成并随 PR 提交对应 `.gd.uid`；所有 GPU/Shader 管线如涉及新材质（如刀光/瞬态光），需考虑房间加载预热以避免首击掉帧（参考近期 PR #232）。
- **分阶段交付建议**：后续使用 `swe-to-tickets` 可自然切分为 4 张垂直可验收的 Ticket：① P0 共享 HUD 战斗反馈层 + Boss 血条拖尾；② 敌人头顶血条 `EnemyHealthBars`；③ 全领域敌人与 Boss 统一 `HitReaction` + `CrystalImpact` 随机化；④ 枪刃本体手感（震屏/滑套/枪口光/刀光/击退/格挡反馈）与 44.1kHz 音频升级。
