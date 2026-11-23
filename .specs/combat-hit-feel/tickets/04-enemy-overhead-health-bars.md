# 04: 敌人头顶血条（`EnemyHealthBars`）

- **GitHub Issue**: `#245`
- **Parent Spec**: `#241` (`.specs/combat-hit-feel/spec.md`)
- **Blocked by**: `#243` (Ticket 02)
- **Status**: `ready-for-agent`

## What to build

为所有活跃的普通（非 Boss）敌人增加克制、高可读性的屏幕空间头顶血条，让玩家在交火中能立刻感知单发伤害占比与补刀时机：

1. **统一 2D 屏幕空间投影层（`EnemyHealthBars`）**：
   - 作为 HUD 子 `Control`（`mouse_filter = IGNORE`，层级位于世界画面之上、准星与 Hitmarker 之下），统一接入 `RealmHUD`、`HUD` 与 `ClimaxCombatHUD`。
   - **目标纳管**：初始化采集当前房间已有敌人，同时订阅 `Events.enemy_registered` 自动纳管动态生成的敌人（如增援、`FearReaper` 激活后的 `FearWisp`），仅持有弱引用并在死亡或失效时清理。
   - **零 `.tscn` 侵入与单向依赖**：遵循 `ui → actors` 依赖规则，不给每个敌人场景塞 3D `SubViewport`，不污染 `HitReaction` 网格遍历。
2. **显示与剔除规则**：
   - **排除目标**：`is_boss == true`（由顶部大血条负责）、`health.is_dead()`、未激活 `dormant == true`、潜伏无受击盒（如悲伤潜行者 `submerged` 状态）、距离超出 `32 m`、处于相机后方、或从相机到锚点被 `CollisionLayers.WORLD` 实体墙遮挡。
   - **渐进可见策略**：满血敌人位于近中距（`<= 18 m`）或处于准星小锥角（`<= 8°`）时显示；一旦敌人血量低于上限（受击后）则在可见范围内持续显示直至死亡，兼顾信息可读性与极简画面整洁。
3. **视觉样式与 `HealthTrail` 拖尾**：
   - 锚点取敌人头部 `Hitbox` 顶部（回退为 `eye_height + 0.55 m`），投影至 2D 屏幕坐标。
   - 极简细长条（宽约 `54–64 px`、高 `5–6 px`），深色半透明底框 + 清晰填充色 + 独立 `HealthTrail` 白色延迟扣血条；若目标拥有 `max_shield > 0` 或残余护盾，在血条正上方叠加 `2 px` 护盾细条。
   - 暂停时冻结所有 `HealthTrail` 动画推进，玩家死亡或切换房间时自动隐藏并释放状态。

## Acceptance Criteria

- [ ] 四领域生产房间中，全部活跃可见非 Boss 敌人（含 `SlothMire`、`FearReaper`、激活后的 `FearWisp`）在受击或进入可见距离/准星锥角时均正确投影显示头顶血条，血量变化立即同步并呈现 `HealthTrail` 白色延迟扣血拖尾。
- [ ] `is_boss == true` 敌人、未激活 `dormant` 追魂、潜水态无 `HITBOXES` 敌人、处于相机背面、超过 `32 m` 距离或被实体墙遮挡的敌人均不渲染血条。
- [ ] 敌人死亡当帧立即隐藏并移除对应血条条目，不残留空条或报错。
- [ ] 拥有护盾的敌人同步显示上方护盾细条；暂停时所有 `HealthTrail` 拖尾完全冻结；全流程不消耗全局模拟 RNG。
- [ ] 在既有 `RealmStage` 高层战斗打击感集成测试中补充完整头顶血条断言，全部测试与既有回归套件全绿。
