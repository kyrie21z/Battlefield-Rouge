# Spec: 正式战役难度曲线重塑 · Phase A（分离缩放向量、怠惰剥夺加速、终局 Pride 调校与碎片续航收敛）

## Problem Statement

当前正式战役（四领域 `RealmStage` 共 12 房 + 终局 `FlawlessDoppelganger`）的难度曲线过于平缓，甚至从第 2 层起出现明显的**战力倒挂（越往后越简单）**：

1. **深度缩放单一且过缓**：`RunDirector` 当前仅输出单一线性倍率 `1.0 + 0.18 × depth`（第 1→4 层仅 `1.00× → 1.54×`），同时用于敌人生命与伤害，且敌人的出手频率、前摇时长与移动速度全程静止；相比玩家到第 4 层已累计 9 张赐福与 3 枚心智碎片的乘算战力增幅（约 4–5 倍），后期普通敌人在完成 `1.1–2.0s` 前摇前即被融化，导致「恐惧去预警 / 愤怒去击退 / 悲伤去缓释」等剥夺代价难以生效。
2. **怠惰剥夺缺乏真实战斗压力**：击败沉眠巨像后，虽关闭休息区并切换至 148 BPM 急促声景，但战斗侧没有任何全局节拍变化，未能将《创作愿景》中「清除停滞后世界运转过快」的心理体验落实到操作压力上。
3. **终局 Boss 脱离曲线且体量偏薄**：`FlawlessDoppelganger` 固定 `1650 HP`、弹伤 `10`、半血仅提升 `1.18×` 阶段时钟，在满配 9 赐福 + 4 碎片面前极易被快速压死，缺乏终局高潮感。
4. **心智碎片续航抹平跨房损耗**：沉睡碎片（`SLOTH`）脱战后每 5 秒起以 `2 HP/s` 无限回血，玩家清房后等待片刻即可满血进下一关；温润碎片（`SORROW`）提供高达 `60` 点且仅 `4s` 冷却即自动恢复的独立护盾，使跨 12 房的血量消耗张力几近消失。

---

## Solution

在严格遵守单向注入架构（组合根 → 房间 → 角色/组件，敌人不反向读 `RunDirector`）、不改动单张赐福卡数值、不破坏 AC-07 确定性回放的前提下，通过四项正交改动完成 **Phase A 难度曲线重塑**：

1. **拆分三维深度缩放向量（HP / 伤害 / 节奏）**：
   - 将 `RunDirector` 的单一深度倍率拆分为独立缩放配置：生命采用几何曲线拉开后期承伤，伤害保持温和增长避免不公平秒杀，节奏（`tempo_scale`）逐层收紧敌人攻击冷却、前摇与小幅移速，让后期战斗真正“更快、更紧绷”而非纯堆子弹海绵。
   - 在 `Enemy` 基类引入独立于 `BoonManager` 状态系统的 `realm_tempo_scale`，保证赐福减速/增前摇状态刷新时绝不冲掉深度与剥夺节奏倍率。
2. **让怠惰剥夺落实为全局节奏加速**：
   - 击败怠惰领域并获得怠惰剥夺后，后续所有领域房间的有效 `tempo_scale` 额外叠加全局加速（`+0.12`），使「世界加速、失去喘息」直接转化为敌人的压迫节拍。
3. **重调终局 `FlawlessDoppelganger` 体量与半血节奏跃迁**：
   - 将完美替身基础生命提升至 `2800 HP`，弹丸与斩击伤害匹配终局威胁（弹伤 `14`、斩击 `28`）；当生命低于 `55%` 时进入高压节拍（阶段推进倍率 `1.30×`、恢复窗口由 `0.85s` 压缩至 `0.55s`、等待间隔缩短），确保终局对决充分检验四枚独立碎片与四项剥夺。
4. **收敛两枚续航型心智碎片的无限保底能力**：
   - **沉睡碎片（`SLOTH`）**：保留脱战 5 秒后 `2 HP/s` 的回血手感，但增加**每房回复上限 `30 HP`**（进新房重置额度，同房快照恢复保留已用额度，杜绝清房后挂机回满血）。
   - **温润碎片（`SORROW`）**：独立护盾上限由 `60` 调整为 `40`，受击后恢复延迟由 `4.0s` 拉长至 `6.5s`（每秒回复速率保持 `6.0/s`），保留抗突发失误能力但要求玩家真正规避持续火力。

---

## User Stories

1. **As a** 正式战役玩家，**I want** 随着层数从第 1 层推进到第 4 层，敌人的生命、伤害和攻击节拍呈现清晰可感的递增（而不只是血条微涨），**so that** 每次拿到的新赐福都有对抗价值，不会从第 2 层开始一路割草。
2. **As a** 击败怠惰领域的玩家，**I want** 怠惰被剥夺后在后续所有领域的战斗中真实感受到敌人节奏明显加快、喘息窗口变短，**so that** 「清除停滞却失去宁静」的叙事代价直接反映在战斗体感里。
3. **As a** 抵达终局回廊的玩家，**I want** 面对血量扎实、输出具威胁、半血后节奏骤紧的完美替身，**so that** 终局之战配得上满构筑的巅峰强度，并真正逼出四枚碎片的协同破局。
4. **As a** 持有沉睡或温润碎片的玩家，**I want** 碎片依然能在关键时刻提供恢复与容错，但无法靠清房后站等回满血或靠高额秒回护盾硬吃伤害，**so that** 整局 12 个房间的血量管理保持紧张感。
5. **As a** 使用旧 `RunState` / `fixture` 或独立测试场的开发者，**I want** 所有未显式注入战役缩放的独立场景与历史 fixture 保持 `1.0×` 默认缩放、零随机序列漂移，**so that** AC-07 确定性回放与既有单元测试不受影响。
6. **As a** 装备减速或延迟赐福（如怠惰钟、悲伤水压）的玩家，**I want** 赐福施加的减速、定身、延长前摇与深度/怠惰加速按乘法正确叠算且互不覆盖，**so that** 控场构筑在高层依然可靠生效。

---

## Implementation Decisions

### 1. 架构边界与单向依赖
- 延续 `ADR 0018` 的组合根约束：只有 `RunDirector` 计算当前深度与剥夺对应的缩放配置，经由 `RealmStage` 公开注入属性传给房间，再由 `RealmStage` 单向施加到本房敌人；任何 `Enemy`、`Boss`、`PsycheFragments` 或 `BoonEffect` 均**不读取 `RunDirector` 或 `RunState`**。
- 独立场景（`campaign == false`）与旧 `ZoneDirector` 关卡默认保持 `hp_scale = 1.0`、`damage_scale = 1.0`、`tempo_scale = 1.0`，不改变历史灰盒与 `fixture` 行为。

### 2. 三维难度缩放契约（`RunDirector` → `RealmStage` → `Enemy`）

| 深度 `depth`（楼层） | `hp_scale` | `damage_scale` | 基础 `tempo_scale` | 含怠惰剥夺后 `tempo_scale`（`+0.12`） |
| --- | --- | --- | --- | --- |
| `0`（Floor 1） | `1.00` | `1.00` | `1.00` | `1.12`（仅同房 Boss 死后/诊断状态） |
| `1`（Floor 2） | `1.35` | `1.15` | `1.08` | `1.20` |
| `2`（Floor 3） | `1.85` | `1.32` | `1.18` | `1.30` |
| `3`（Floor 4） | `2.45` | `1.50` | `1.28` | `1.40` |

- **`RunDirector` 接口**：
  - 提供独立只读查询 `hp_scale(depth := -1)`、`damage_scale(depth := -1)`、`tempo_scale(depth := -1, active_deprivations := ...)`，以及打包快照 `difficulty_profile(depth := -1)`（返回 `{hp_scale, damage_scale, tempo_scale}`）。
  - 保留 `difficulty(depth := -1)` 返回 `damage_scale(depth)` 作为向后兼容的标量入口，避免破坏外部调用方语义；`install_stage()` 同时注入 `difficulty_multiplier`（兼容字段，等于 `damage_scale`）、`hp_multiplier`、`tempo_multiplier`。
  - 缩放表完全由 `depth` 与是否包含怠惰剥夺决定，**不依赖领域身份**（保持随机洗牌四领域公平性）。
- **`RealmStage` 注入契约**：
  - 新增导出属性 `hp_multiplier := 1.0`、`tempo_multiplier := 1.0`（保留 `difficulty_multiplier := 1.0` 承担伤害倍率；当调用方仅显式设置 `difficulty_multiplier != 1.0` 且未覆盖 `hp_multiplier` 时，可安全兼容既有独立测试）。
  - `_register_actor()` 对每个已生成敌人调用统一的 `actor.apply_realm_scaling(hp_scale, damage_scale, tempo_scale)`；当 `_apply_run()` 或 Boss 击杀刷新剥夺时，只按最新 `tempo_scale` 更新存活敌人的节奏倍率，**不重复乘算生命值**。

### 3. `Enemy` 正交节奏缩放与防双倍缩放不变量
- **隔离 `BoonManager` 状态层**：
  - `Enemy` 新增 `realm_hp_scale := 1.0`、`realm_tempo_scale := 1.0`（下限钳至 `0.25`）以及懒快照 `_base_run_speed` / `_base_max_health`。
  - `BoonManager._refresh_status()` 继续只读写 `boon_*_scale`；`Enemy` 提供公开组合读取：
    - `effective_attack_scale() -> float`：`boon_attack_scale * realm_tempo_scale`
    - `effective_windup_scale() -> float`：`boon_windup_scale / realm_tempo_scale`
  - `set_realm_tempo(value)` 幂等更新 `realm_tempo_scale` 与移速 `run_speed = _base_run_speed * (1.0 + (realm_tempo_scale - 1.0) * 0.5)`（静止敌人 `0.0` 保持 `0.0`，只调整常规巡逻/追击移速，不扭曲冲锋/扑击/击退冲量速度）。
  - `apply_realm_scaling(hp_scale, damage_scale, tempo_scale)` 为幂等入口：按 `_base_max_health * hp_scale` 计算上限（按当前血量比例或满血初始化），更新 `realm_damage_scale`（若存在）与 `set_realm_tempo(tempo_scale)`。
- **防 `tempo²` 双重压缩不变量（关键）**：
  - **推进时钟已乘 `attack_scale` 的敌人/攻击体**（`WrathRealmEnemy`、`WrathSpire`、`SorrowRealmEnemy`、`SorrowMonolith`、`SlothRealmEnemy`、`SlothMire`、`SlothAttack`、`SlothColossusAttack`、`FlawlessDoppelganger`）：在计时递减/推进处使用 `effective_attack_scale()`，其 `windup` 基准保留 `boon_windup_scale`（不再额外除以 `realm_tempo_scale`），保证前摇与冷却均严格按 `1 / realm_tempo_scale` 单次缩放。
  - **推进时钟仅用纯 `delta` 的敌人/召唤物**（`FearRealmEnemy`、`FearReaper`、`FearOculus`、`FearWisp`）：冷却递减使用 `effective_attack_scale()`，前摇计算使用 `effective_windup_scale()`，同样保证单次缩放。
  - **召唤物继承**：`FearWisp` 激活时从召唤者继承 `realm_hp_scale`、`realm_damage_scale` 与 `realm_tempo_scale`（血量按 `18.0 * realm_hp_scale`，伤害按 `8.0 * realm_damage_scale`，前摇与追击速度受 `realm_tempo_scale` 驱动）。

### 4. 终局 `FlawlessDoppelganger` 调校
- 基础生命由 `1650` 上调至 `2800`；普通弹丸伤害由 `10` 上调至 `14`，冲刺斩击伤害由 `22` 上调至 `28`。
- 半血阈值与高压节拍：当 `health < max_health * 0.55` 时，阶段推进倍率由 `1.18×` 提升至 `1.30×`；`_recover()` 窗口在高压阶段由 `0.85s` 压缩至 `0.55s`、`WAIT` 衔接间隔由 `0.25s` 压缩至 `0.15s`。
- 保留既有破防机制（沉睡共鸣 `Q` 减速并暴露 `1.0s`、锋芒撞墙破盾暴露 `1.6s`、暴露/恢复窗口暴击 `1.5×`）与 56 片死亡碎裂演出，不破坏 `flawless_combat_test` 的战术交互契约。

### 5. 心智碎片续航收敛与跨房状态边界（`PsycheFragments` + `RunDirector`）
- **沉睡碎片（`SLOTH`）每房回血上限**：
  - 新增常量 `SLUMBER_ROOM_HEAL_CAP := 30.0` 与房间内已回血计数 `room_healed := 0.0`。
  - 每次脱战回血步进受 `minf(2.0 * delta, SLUMBER_ROOM_HEAL_CAP - room_healed)` 钳制；达到上限后该房间停止继续回血，直到进入下一个房间调用 `reset_room_healing()` 清零 `room_healed`。
  - **防刷血不变量**：`RunDirector.capture_player()` / `restore_player()` 仍跨房保留 `since_combat`，进入新房间（`advance_room()` 触发的场景安装）重置 `room_healed = 0.0`；同一房间内保存/恢复（如中段快照测试）保留当前 `room_healed` 不被白嫖重置。
- **温润碎片（`SORROW`）屏障收敛**：
  - `TENDERNESS_CAPACITY` 由 `60.0` 调整为 `40.0`；受击重置的 `_barrier_recovery` 延迟由 `4.0s` 调整为 `6.5s`；恢复速率维持 `6.0/s`。
  - 保持既有 `unbuffered` 剥夺隔离契约：普通护盾与减伤依然被禁用，温润屏障仅通过 `fragment_absorber` 独立结算，暂停时冻结恢复。

---

## Testing Decisions

### 什么是好的行为测试
- 通过真实组合根 `RunDirector`、生产房间 `RealmStage`、终局场景 `DoppelgangerSpawn` 与组件公开接口验证**玩家可观测的战斗与续航行为**，而非锁死私有辅助函数。
- 重点守卫三类易回归边界：① `BoonManager` 状态施加/清除后 `realm_tempo_scale` 零丢失；② 前摇与冷却不会发生 `tempo²` 双重加速；③ 跨房切换重置沉睡回血预算但绝不重置温润冷却与锋芒蓄力，且全局模拟 RNG 与 AC-07 哈希零漂移。

### 锁定的测试接缝（1 个主高层接缝 + 既有回归集）
1. **新增主集成测试接缝（`tests/difficulty_curve_phase_a_test.tscn`）**：
   - **三维深度缩放与状态正交性**：通过 `RunDirector` 在 `depth = 0..3` 安装生产 `RealmStage`，校验敌人实际 `max_health`、`realm_damage_scale`、`realm_tempo_scale` 与移速符合分层曲线且与领域身份无关；对敌人施加并清除 `BoonManager` 减速/延前摇状态后，断言 `realm_tempo_scale` 保持原值、且实际前摇/冷却耗时严格按单次 `1 / tempo` 缩短（无双重缩放）。
   - **怠惰剥夺全局加速**：在 `RunDirector.deprivations` 含怠惰前后分别安装房间，校验敌人的有效 `tempo_scale` 准确叠加 `+0.12`，并在真实物理帧下比未剥夺房间更早完成冷却/前摇。
   - **终局 Pride 体量与半血压缩**：实例化 `FlawlessDoppelganger`，校验初始 `2800 HP`、弹丸/斩击实际伤害，以及压血至 `< 55%` 后恢复窗口与阶段推进速度真实收紧。
   - **碎片续航上限**：在真实房间与跨房切换流程中验证沉睡碎片单房最多回复 `30 HP`、满额后静置不再回血、进新房后额度恢复；验证温润碎片 `40` 容量与 `6.5s` 恢复延迟。
2. **既有回归对齐与守卫（全量必跑）**：
   - 同步更新精确旧数值断言：`run_director_test`（深度倍率契约）、`campaign_realms_test`（伤害/生命/节奏注入校验）、`slumber_fragment_test`（补充单房上限验证）、`tenderness_fragment_test`（对齐 `40` 容量与 `6.5s` 延迟）、`flawless_combat_test`（对齐容量常量引用与新伤害/血量兼容）。
   - 零改动回归必过：`climax_flow_test`、`sorrow_boon_core_test`、`sorrow_boon_traits_test`、`sloth_boon_core_test`、`fear_boon_traits_test`、`fixture_test`（AC-07 确定性哈希）。

---

## Out of Scope

- **不调整单张赐福卡数值**：本期不修改任何 `buffs/resources/*/*.tres` 或赐福效果倍率（保持既有赐福单测零改动，先隔离并验证曲线与续航收敛的净效果）。
- **不包含 Phase B 结构升级**：深度多波次增援、精英护盾怪词缀、四领域 Boss 半血二阶段转场演出及 Boss 控场递减（DR）留待 Phase B 独立 Spec 推进。
- **不改动地图几何与美术资产**：不修改 `maps/`、`environments/` 布局或 `tools/gen_zones.py`。
- **不改动局外成长（`MetaProgression`）或经济产出**（意志碎片/现实锚点收益规则不变）。

---

## Further Notes

- **文档同步**：实现合入前须在 `GLOSSARY.md` 同步更新沉睡碎片单房回复上限、温润屏障参数及三维缩放术语，并在 `docs/adr/0018-realms-and-independent-fragments.md` 文末追加本次修订记录（保留历史决策正文）。
- **AC-07 与场景卫生**：所有改动仅涉及 `.gd` 脚本（新建测试场景附带 `.tscn` 与 Godot 4.7.2 生成的 `.gd.uid`），不批量改写现有地图或角色 `.tscn`；不引入任何消耗全局 `randf()` 的逻辑。
- **下一步衔接**：确认 Spec 无误后，可通过 `$swe-to-tickets` 将本 Spec 切分为 3–4 张垂直可验收的 Ticket（① 三维缩放向量 + `Enemy` 正交节奏基座；② 怠惰剥夺全局加速 + 全领域敌人/召唤物接入；③ 终局 `FlawlessDoppelganger` 调校；④ 碎片续航收敛 + 集成与回归测试）。
