# 05: Phase A 战役端到端集成验收测试与文档收口

- **GitHub Issue**: `#261`
- **Parent Spec**: `#256` (`.specs/difficulty-curve-phase-a/spec.md`)
- **Blocked by**: `#258` (Ticket 02), `#259` (Ticket 03), `#260` (Ticket 04)
- **Status**: `done`

## What to build

落地 Spec 锁定的单一高层战役集成测试接缝，对 Phase A 四项改动进行跨系统联合验收，并完成项目术语与 ADR 文档同步：

1. **新增高层战役集成验收测试（`tests/difficulty_curve_phase_a_test.tscn`）**：
   - **三维深度缩放与领域无关性**：经 `RunDirector` 在 `depth = 0..3` 安装生产 `RealmStage`，断言真实敌人的 `max_health`、`realm_damage_scale`、`realm_tempo_scale` 与移速符合分层曲线。
   - **状态正交与防 `tempo²` 真实帧校验**：对两类代表敌人（时钟已乘 `attack_scale` 组与纯 `delta` 组，如 `SlothEnemy` / `WrathRealmEnemy` 与 `FearRealmEnemy`）在 `realm_tempo_scale > 1.0` 下叠加并清除 `BoonManager` 状态（如悲伤水压延前摇），通过真实物理帧计时验证冷却与前摇严格单次缩放且状态清除后节奏不丢失。
   - **怠惰剥夺全局加速对照**：对比 `deprivations` 含/不含怠惰时同一深度房间的敌人有效 `tempo_scale`（`+0.12`）与实际冷却/前摇完成帧数。
   - **终局 Pride 调校实测**：验证 `FlawlessDoppelganger` 的 `2800 HP`、真实弹丸/斩击扣血以及压血 `< 55%` 后的恢复窗口压缩。
   - **碎片跨房续航闭环**：在真实战役换房流程中验证沉睡碎片单房 `30 HP` 封顶、换房额度重置，以及温润碎片 `40` 容量 / `6.5s` 延迟。
2. **全量回归与 AC-07 确定性守卫**：完整运行 Phase A 关联测试集与 `tests/fixture_test.tscn`，确认零回归、零全局 RNG 漂移、零 Godot 报错。
3. **文档与资产卫生同步**：
   - 在 `GLOSSARY.md` 补充三维难度缩放、怠惰剥夺全局加速、沉睡碎片单房回血上限与温润屏障新参数。
   - 在 `docs/adr/0018-realms-and-independent-fragments.md` 文末追加本次 Phase A 难度曲线修订记录（不改写历史正文）。
   - 确保新建 `.gd` 均附带 Godot 4.7.2 生成的 `.gd.uid`。

## Acceptance Criteria

- [ ] `tests/difficulty_curve_phase_a_test.tscn` 覆盖三维缩放、Boon 正交性、防 `tempo²` 真实帧验证、怠惰剥夺全局加速、`FearWisp` 继承、终局 Pride 调校与碎片跨房续航，并 100% 通过。
- [ ] 全部既有回归集全绿：`run_director_test`、`campaign_realms_test`、`slumber_fragment_test`、`tenderness_fragment_test`、`flawless_combat_test`、`climax_flow_test`、`sorrow_boon_core_test`、`sorrow_boon_traits_test`、`sloth_boon_core_test`、`fear_boon_traits_test` 与 `fixture_test`（AC-07）。
- [ ] `GLOSSARY.md` 与 `docs/adr/0018-realms-and-independent-fragments.md` 已同步更新且与最终实现数值完全一致。
- [ ] 所有新增脚本均包含 Godot 4.7.2 生成的 `.gd.uid`，无无关场景改动。
