# 06: 意志短刃本体手感与盾牌格挡反馈

- **GitHub Issue**: `#247`
- **Parent Spec**: `#241` (`.specs/combat-hit-feel/spec.md`)
- **Blocked by**: `#242` (Ticket 01), `#243` (Ticket 02)
- **Status**: `ready-for-agent`

## What to build

补齐意志短刃挥砍的视觉轨迹与命中重量感，同时打通敌人护盾格挡的专属视听反馈，彻底消除“挥空与砍中没差别”以及“打中盾牌以为丢判定”的问题：

1. **3D 弧形刀光拖尾（`BladeSlashTrail`）**：
   - 在 `MeleeWeapon` 生效窗口（`Phase.ACTIVE`）沿刀根与刀尖采样构建轻量发光三角带刀光网格（契合 Mind Freak 极简晶体视觉语言），挥砍结束后约 `0.14 s` 内平滑淡出，随暂停冻结，死亡或退出场景干净释放。
2. **爆发挥砍曲线与近战命中冲击**：
   - 将 `Phase.ACTIVE` 的挥砍插值从对称平滑曲线改为先蓄后劈的爆发加速曲线，同时保持起止点精确落位（守卫刀尖深度 `MIN_TIP_DEPTH` 与刃口领先 `edge_leading()` 既有契约）。
   - `MeleeWeapon` 新增 `shake` 信号接入 `Player.add_view_shake(0.65°, 0.018, 0.14 s)`，让砍中敌人有扎实的定向镜头冲击。
   - 提升短刃击退参数：`impact_force` 从 `2.0` 提升至 `6.2`、`impact_stagger` 从 `0.15 s` 提升至 `0.22 s`（使普通非免疫敌人被砍中产生约 `0.40–0.55 m` 的清晰可见半步击退；尊重 `ordinary_impacts_enabled` 剥夺与 `Aggressor` 免疫规则）。
   - 近战命中敌人时的特效从旧版暗红肉块血雾（`Impact.spawn(..., flesh=true)`）切换为晶体斩裂特效（`CrystalImpact` 强化版），并按 `0.0 dB` 播放升级后的 `melee_hit` 音色。
3. **护盾格挡专属反馈（如愤怒领域 `Accumulator` 正面挡弹）**：
   - 当敌人在 `before_damage` 中以护盾/格挡取消本次攻击（如 `WrathRealmEnemy` 的 `Accumulator` 正面挡弹）时，向攻击上下文标记格挡（如 `ctx["blocked_by_shield"] = true`）。
   - `Weapon` / `MeleeWeapon` 检测到该标记后：发射专属 `hit_blocked` 信号，在命中点生成盾面弹开火花（替代普通实体受击碎屑），且不触发普通白/金 Hitmarker；由 `CombatFeedbackLayer` 播放 `hit_block` 金属钝响与克制的灰色格挡标记。

## Acceptance Criteria

- [ ] 意志短刃挥砍在 `Phase.ACTIVE` 期间生成可见 3D 弧形刀光并在 `~0.14 s` 内淡出，同时保持所有既有短刃几何/刃口领先/刀尖深度断言绿灯（`tests/mind_blade_test.tscn`、`tests/melee_test.tscn`）。
- [ ] 短刃命中非免疫敌人时，产生清晰可见的击退位移（显著大于旧 `~0.09 m` 基线）、触发 `Player` 镜头震屏、播放晶体斩裂特效（不再生成旧肉块血雾），并触发 Ticket 02 的 `0.025 s` 近战微顿帧。
- [ ] 愤怒领域 `Accumulator` 正面格挡黑晶手枪射击时：零掉血、正常蓄压、触发 `hit_blocked` 信号与 `hit_block` 金属钝响及弹开火花，**不触发**普通实体 Hitmarker 与实体受击闪白。
- [ ] 所有新增刀光、特效与反馈在暂停时冻结，在死亡/退出时干净清理，且绝不消耗全局模拟 RNG。
- [ ] 生产 `RealmStage` 战斗打击感集成测试补充短刃与格挡全量用例并通过，既有回归套件（`mind_blade_test`、`melee_test`、`wrath_realm_test`、`hit_feel_test`、`gun_feel_test`、`fixture_test`）全绿。
