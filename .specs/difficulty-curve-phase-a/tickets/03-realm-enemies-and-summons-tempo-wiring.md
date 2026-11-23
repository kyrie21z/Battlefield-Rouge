# 03: 四领域敌人与召唤物正交节奏接入（防 tempo² 双重压缩）

- **GitHub Issue**: `#259`
- **Parent Spec**: `#256` (`.specs/difficulty-curve-phase-a/spec.md`)
- **Blocked by**: `#257` (Ticket 01)
- **Status**: `done`

## What to build

将四领域全部小怪、四领域 Boss 与召唤物接入 Ticket 01 建立的 `Enemy` 正交节奏基座，并严格守卫**防 `tempo²` 双重压缩不变量**：

1. **时钟已乘 `attack_scale` 组（仅换用 `effective_attack_scale()`，前摇基准保持 `boon_windup_scale`）**：
   - 怠惰：`SlothEnemy`、`SlothAttack`、`SlothRealmEnemy`、`SlothColossus`、`SlothColossusAttack`、`SlothMire`。
   - 愤怒：`WrathRealmEnemy`、`WrathSpire`。
   - 悲伤：`SorrowRealmEnemy`、`SorrowMonolith`。
   - 确保上述实体的冷却、前摇与攻击阶段严格按单次 `1 / realm_tempo_scale` 加速，绝不在前摇处再次除以 `realm_tempo_scale`。
2. **时钟用纯 `delta` 组（冷却用 `effective_attack_scale()`，前摇用 `effective_windup_scale()`）**：
   - 恐惧：`FearRealmEnemy`、`FearReaper`、`FearOculus`、`FearWisp`。
   - 确保冷却与前摇同样严格按单次 `1 / realm_tempo_scale` 加速，且 `FearOculus` 暴露恢复阶段同步读取 `effective_attack_scale()`。
3. **召唤物三维倍率继承（`FearWisp`）**：
   - `FearWisp` 激活时从召唤者继承 `realm_hp_scale`、`realm_damage_scale` 与 `realm_tempo_scale`：`max_health` 按 `18.0 * realm_hp_scale` 计算，扑击伤害按 `8.0 * realm_damage_scale` 计算，飞行追击速度按 `SPEED * (1.0 + (realm_tempo_scale - 1.0) * 0.5)` 适度提速，前摇按 `effective_windup_scale()` 单次缩放。
4. **守卫既有四领域测试与 `1.0×` 零偏移**：当 `realm_tempo_scale == 1.0` 时，所有既有前摇时长、冷却时长与行为测试结果保持完全一致。

## Acceptance Criteria

- [ ] 怠惰、恐惧、愤怒、悲伤四领域全部小怪与 4 个领域 Boss 均已接入正交节奏缩放；当 `realm_tempo_scale == 1.0` 时既有节拍零偏移。
- [ ] 在 `realm_tempo_scale > 1.0`（如 `1.28` / `1.40`）下，两类敌人的实际冷却耗时与前摇耗时均严格按单次 `1 / realm_tempo_scale` 缩短，不存在 `1 / tempo²` 双重压缩。
- [ ] `FearWisp` 激活时正确继承召唤者的 `realm_hp_scale`、`realm_damage_scale` 与 `realm_tempo_scale`，血量不再误用 `realm_damage_scale`。
- [ ] 叠加强化/减速赐福（如悲伤水压 `boon_windup_scale = 1.3`）后，实际前摇满足 `base * boon_windup_scale / realm_tempo_scale`，且清除状态后 `realm_tempo_scale` 完好保留。
- [ ] 四领域相关既有战斗与 Boss 回归测试全部通过（含 `sloth_enemy_test`、`sloth_realm_test`、`sloth_colossus_test`、`wrath_realm_test`、`wrath_spire_test`、`sorrow_boon_traits_test`、`fixture_test`）。
