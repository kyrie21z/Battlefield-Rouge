# 03: 全领域敌人与 Boss 统一受击反应与碎屑随机化（P0）

- **GitHub Issue**: `#244`
- **Parent Spec**: `#241` (`.specs/combat-hit-feel/spec.md`)
- **Blocked by**: None
- **Status**: `ready-for-agent`

## What to build

消除四领域新敌人与 5 个 Boss “打雕塑 / 打木桩”的无响应体感，同时消除枪击碎屑每发完全复制粘贴的机械感：

1. **全阵营统一接入 `HitReaction`**：
   - 通过代码化、幂等机制（优先在 `Enemy` 基类或 `RealmStage` 注册路径自动兜底安装，避免大面积修改 12+ 个 `.tscn` 文件）为所有未挂载 `HitReaction` 的正式敌人与 Boss 启用非致命受击反应：
     - 覆盖四领域全部小怪（`SlothRealmEnemy`、`SlothMire`、`FearRealmEnemy`、`FearReaper`、`FearWisp`、`WrathRealmEnemy`、`SorrowRealmEnemy`）及全部 5 个正式 Boss（`SlothColossus`、`FearOculus`、`WrathSpire`、`SorrowMonolith`、`FlawlessDoppelganger`）。
   - **保留原死亡碎裂演出**：对自带晶体碎裂/溶解死亡演出的新敌人与 Boss，启用受击闪白、受击后仰与爆头火花，但不叠播旧版红肉块死亡喷发（沿用 `sloth_hit_reaction` 的职责边界）。
   - **视觉强度与参数分级**：
     - 80 ms 高对比闪白覆盖（`FLASH_ALPHA` 强化至约 `0.78–0.85`），仅通过 `material_overlay` 叠加，结束后还原为 `null`，绝不改写 Mesh 原始 `material_override` 或共享材质。
     - 普通小怪方向性后仰（`flinch_degrees ≈ 7.5°`、`flinch_shove ≈ 0.08 m`），爆头 `1.4×` 并触发晶体金色火花；全部 Boss 自动设置温和倍率（`flinch_scale = 0.30`）。
   - **动态生成视觉体兼容**：`HitReaction` 在首次 `_acquire_model()` 尚未发现子网格时支持延迟重采，确保程序化构建网格的视觉体不会漏闪或空转。
   - **绝对不变量**：绝不移动 `CharacterBody3D.global_transform`、绝不移动任何 `Hitbox`、绝不改写 AI 状态或消耗全局 RNG。
2. **修复 `CrystalImpact` 固定种子与命中视觉增强**：
   - 将 `CrystalImpact` 每次生成的固定种子改为私有静态递增种子（不碰全局模拟 RNG），使连续命中的碎屑飞溅方向、速度与旋转自然变化。
   - 在命中点加入短寿命（约 `0.06 s`）无阴影瞬态亮斑/光点，爆头命中时扩大碎屑规模与初速度，强化中远距离肉眼命中可读性。

## Acceptance Criteria

- [ ] 四领域所有小怪类型（含 `FearReaper`、激活后 `FearWisp`、`SlothMire`）及全部 5 个正式 Boss 在受到玩家非致命伤害时，均触发受击闪白（`material_overlay != null`）与可视网格后仰，结束后自动清理 `material_overlay` 并完整恢复网格 rest transform。
- [ ] 所有受击反应绝不改变敌人的 `CharacterBody3D.global_transform`、所有 `Hitbox.global_transform`、原始 `material_override`、AI 状态字段以及全局 `randi()` 序列。
- [ ] 5 个正式 Boss 的受击后仰倍率均 `< 0.5`，且死亡时保持各自原有的晶体碎裂/终局演出，不误触旧版红肉块死亡喷发。
- [ ] 连续两次调用 `CrystalImpact.spawn` 产生的碎屑速度/角度互不相同，且全程不消耗全局模拟 RNG，生命周期结束后完全自释放。
- [ ] 既有回归套件与新增敌人受击行为断言全绿：`tests/gun_feel_test.tscn`、`tests/hit_feel_test.tscn`、`tests/fixture_test.tscn` 及生产房间验证测试。
