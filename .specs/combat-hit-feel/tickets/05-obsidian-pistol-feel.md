# 05: 黑晶手枪本体手感强化

- **GitHub Issue**: `#246`
- **Parent Spec**: `#241` (`.specs/combat-hit-feel/spec.md`)
- **Blocked by**: `#242` (Ticket 01)
- **Status**: `ready-for-agent`

## What to build

在不改动黑晶手枪任何逻辑后坐力与平衡数值的前提下，全面强化开火瞬间的视听与机械回弹手感：

1. **表现层震屏与弹簧调优（`obsidian_pistol.tres`）**：
   - 严守既有逻辑后坐力契约：`camera_kick = 1.2`、`camera_yaw = 0.3`、`camera_return_time = 0.12`、`aim_feel_scale < 1.0` 保持不变。
   - 强化纯表现参数：`shake_degrees` 从 `0.08` 提升至 `0.38`、`shake_fov_punch` 从 `0.008` 提升至 `0.020`、`shake_duration = 0.13`；视模回弹调优为 `view_kick_back = 0.042`、`view_kick_pitch = 3.4`、`view_kick_roll = 1.4`、`view_spring_stiffness = 520`、`view_spring_damping = 28`（微欠阻尼产生利落“踢感”，且在既有测试 150 帧内完全归静）。
2. **黑晶零件开火联结动画（`ObsidianPistolView`）**：
   - 新增 `kick_fire()` 接口并在每次真实射击触发：开火瞬间驱动 `slide_block` 沿 `+Z` 瞬退并快速复进，同时将 `core_crystal` 发射强度瞬时脉冲提亮（`1.5 → 5.5` 并在 `0.10 s` 内衰减回常亮）。
   - 与现有 0.85 s 晶体重组动画时钟完全解耦，换弹或停用时安全归位。
3. **瞬态枪口动态光与曳光弹可读性**：
   - 在手枪枪口增加无阴影瞬态冷蓝 `OmniLight3D`（随开火点亮约 `0.045 s` 后衰减熄灭），照亮黑晶枪身与近处白色建筑，强化能量激发感（随暂停冻结、停用隐藏）。
   - 调整 `Tracer` 参数：`SPEED` 从 `320` 调至 `190 m/s`、`THICKNESS` 从 `0.014` 调至 `0.020`（严格满足 `< 0.03` 既有测试断言），让 10–30 m 交火弹道清晰可读。
4. **低弹量听觉提示**：
   - 当成功射击后剩余弹药 `<= 2` 发时，叠加播放 Ticket 01 提供的 `pistol_low_ammo` 轻脆提示音（独立声道不打断枪声尾音），形成快空匣的自然节奏锚点。

## Acceptance Criteria

- [ ] 黑晶手枪逻辑后坐力参数（`camera_kick=1.2`、`camera_yaw=0.3`、`camera_return_time=0.12`、`aim_feel_scale < 1.0`）与伤害/射速/弹容零改动；开火震屏峰值与 FOV 脉冲显著强于旧基线，且 Aim Camera 零偏移、ADS 仍按比例衰减。
- [ ] 开火瞬间 `ObsidianPistolView` 触发 `slide_block` 位移复进、`core_crystal` 发射强度瞬时拉升并平滑回落，且枪口瞬态 `OmniLight3D` 点亮后在 `~0.045 s` 内归零熄灭；视模弹簧在 150 帧内完全回正。
- [ ] 剩余弹药 `<= 2` 发开火时混叠播放 `pistol_low_ammo`，且不打断当前枪声尾音；`Tracer` 几何与自释放完全符合既有契约。
- [ ] 所有开火表现改动零消耗全局模拟 RNG。
- [ ] 既有回归套件与生产房间打击感测试全绿：`tests/hit_feel_test.tscn`、`tests/gun_feel_test.tscn`、`tests/obsidian_pistol_test.tscn`、`tests/fixture_test.tscn`。
