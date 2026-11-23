# 01: 三维深度缩放注入、怠惰剥夺加速与 Enemy 正交节奏基座

- **GitHub Issue**: `#257`
- **Parent Spec**: `#256` (`.specs/difficulty-curve-phase-a/spec.md`)
- **Blocked by**: None
- **Status**: `done`

## What to build

打通「组合根 → 房间 → 敌人基座」的单向三维难度缩放通道，并让怠惰剥夺产生真实的全局节奏加速：

1. **`RunDirector` 三维深度缩放与怠惰剥夺加速**：
   - 将单一线性深度倍率拆分为独立曲线（仅由 `depth = 0..3` 与是否包含怠惰剥夺决定，不依赖领域身份）：
     - `hp_scale`：`1.00 / 1.35 / 1.85 / 2.45`
     - `damage_scale`：`1.00 / 1.15 / 1.32 / 1.50`
     - `tempo_scale`：基础 `1.00 / 1.08 / 1.18 / 1.28`，当 `deprivations` 包含怠惰（`0`）时额外 `+0.12`（即 `1.12 / 1.20 / 1.30 / 1.40`）。
   - 提供只读查询 `hp_scale(depth := -1)`、`damage_scale(depth := -1)`、`tempo_scale(depth := -1)` 与 `difficulty_profile(depth := -1)`；保留 `difficulty(depth := -1)` 返回 `damage_scale(depth)` 以兼容既有调用语义。
   - 装配房间时同时向 `RealmStage` 注入 `hp_multiplier`、`difficulty_multiplier`（伤害倍率兼容名）与 `tempo_multiplier`。
2. **`RealmStage` 单向注入与中途剥夺刷新**：
   - 新增导出属性 `hp_multiplier := 1.0` 与 `tempo_multiplier := 1.0`（保留 `difficulty_multiplier := 1.0` 承担伤害倍率；当调用方仅显式设定 `difficulty_multiplier != 1.0` 且未设 `hp_multiplier` 时保留向后兼容）。
   - 敌人注册时调用统一的 `apply_realm_scaling(hp_scale, damage_scale, tempo_scale)`；当房间中途刷新剥夺时，只更新存活敌人的 `realm_tempo_scale`，绝不重复乘算生命上限。
3. **`Enemy` 正交节奏缩放基座（隔离 `BoonManager` 状态层）**：
   - 新增 `realm_hp_scale := 1.0`、`realm_tempo_scale := 1.0`（下限钳至 `0.25`）及懒快照基值（基础血量与基础移速），保证重复调用完全幂等。
   - 提供 `effective_attack_scale() -> boon_attack_scale * realm_tempo_scale`、`effective_windup_scale() -> boon_windup_scale / realm_tempo_scale`、`set_realm_tempo(value)`（常规移速按 `1.0 + (tempo - 1.0) * 0.5` 半幅缩放，静止敌人 `0.0` 保持 `0.0`）与 `apply_realm_scaling(hp_scale, damage_scale, tempo_scale)`。
   - 确保 `BoonManager` 施加或清除减速/延前摇状态后，`realm_tempo_scale` 与缩放后移速基准不被覆盖。
   - 基础 `Enemy` 的交火反应与射击节拍改用 `effective_attack_scale()` / `effective_windup_scale()`（且默认 `1.0` 时与旧行为逐比特等价）。
4. **同步对齐既有组合根与战役流程测试**：更新 `run_director_test` 与 `campaign_realms_test` 以断言三维缩放向量、怠惰剥夺加速注入与既有战役流不变量。

## Acceptance Criteria

- [ ] `RunDirector` 对 `depth = 0..3` 返回精确 `hp_scale`（`1.00/1.35/1.85/2.45`）、`damage_scale`（`1.00/1.15/1.32/1.50`）与 `tempo_scale`（基础 `1.00/1.08/1.18/1.28`，含怠惰剥夺时 `+0.12`），且与领域身份无关。
- [ ] `RealmStage` 注册敌人时正确注入三维倍率；同房多次刷新剥夺时只更新节奏，不重复乘算 `max_health`；未注入的独立场景与旧灰盒默认保持 `1.0×`。
- [ ] `Enemy.set_realm_tempo()` 与 `apply_realm_scaling()` 多次调用幂等；经 `BoonManager` 施加并清除减速/延长前摇状态后，`realm_tempo_scale` 零丢失，有效攻击/前摇倍率按乘法正确叠加。
- [ ] 所有敌人脚本不反向引用 `RunDirector` 或 `RunState`，且新增逻辑零消耗全局模拟 RNG。
- [ ] `tests/run_director_test.tscn`、`tests/campaign_realms_test.tscn` 与 `tests/fixture_test.tscn`（AC-07）全部通过。
