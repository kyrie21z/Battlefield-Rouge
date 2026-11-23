# 02: 终局完美替身（FlawlessDoppelganger）体量与半血高压节拍调校

- **GitHub Issue**: `#258`
- **Parent Spec**: `#256` (`.specs/difficulty-curve-phase-a/spec.md`)
- **Blocked by**: None
- **Status**: `done`

## What to build

抬升终局 Boss `FlawlessDoppelganger` 的生命体量、伤害威胁与半血后的连段压迫感，使其匹配 9 赐福 + 4 碎片的终局构筑强度：

1. **终局基础体量与输出重调**：
   - 基础最大生命由 `1650` 上调至 `2800`（`health` 同步初始化为 `2800`）。
   - 普通四连弹单发伤害由 `10` 上调至 `14`，冲刺斩击伤害由 `22` 上调至 `28`。
2. **半血高压节拍跃迁（`< 55%` HP）**：
   - 高压阈值由 `50%` 上移至 `55%`，阶段推进倍率由 `1.18×` 提升至 `1.30×`。
   - 高压阶段压缩招式衔接空档：`_recover()` 恢复窗口由 `0.85s` 压缩至 `0.55s`，`WAIT` 衔接间隔由 `0.25s` 压缩至 `0.15s`（半血以上保持原窗口以便玩家熟悉招式）。
3. **保留既有破防与演出契约**：
   - 保持沉睡共鸣 `Q` 减速与 `1.0s` 暴露、锋芒受击反震撞墙破盾与 `1.6s` 暴露、暴露/恢复窗口暴击 `1.5×`、暂停冻结以及 56 片晶体死亡碎裂清理逻辑不变。
4. **扩充终局战斗测试**：在 `flawless_combat_test` 补充初始 `2800 HP`、新弹丸/斩击伤害以及 `< 55%` 血量后恢复窗口压缩与加速推进的断言（同时用 `PsycheFragments.TENDERNESS_CAPACITY` 替代硬编码 `60`，保证后续 Ticket 04 零冲突）。

## Acceptance Criteria

- [ ] `FlawlessDoppelganger` 初始 `max_health == 2800`，弹丸伤害 `14`、冲刺斩击伤害 `28`。
- [ ] 当生命值 `< 55%` 最大生命时，阶段推进倍率达 `1.30×`，`_recover()` 恢复窗口缩短为 `0.55s`，`WAIT` 衔接缩短为 `0.15s`；`>= 55%` 时维持原 `0.85s` / `0.25s`。
- [ ] 完美格挡、沉睡 `Q` 破防减速、锋芒撞墙破墙暴露、暴露暴击 `1.5×` 与 56 片死亡碎裂全部保持正常。
- [ ] `tests/flawless_combat_test.tscn` 与 `tests/climax_flow_test.tscn` 全部通过。
