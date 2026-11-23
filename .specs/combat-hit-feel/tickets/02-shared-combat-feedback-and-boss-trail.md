# 02: 正式战役共享战斗反馈层与 Boss 血条拖尾（P0）

- **GitHub Issue**: `#243`
- **Parent Spec**: `#241` (`.specs/combat-hit-feel/spec.md`)
- **Blocked by**: None
- **Status**: `ready-for-agent`

## What to build

彻底修复正式战役（四领域 `RealmStage` 与终局战）HUD 打击感反馈大断链，并建立后续所有打击感 Ticket 共用的高层生产房间验证测试接缝：

1. **抽离共享战斗反馈组件（`CombatFeedbackLayer`）**：
   - 独立 UI 呈现组件，遵守 `ui → actors` 单向依赖，不读写 `RunState` / `RunDirector` 状态（仅沿用既有 `RunState.fixture != null` 判断是否跳过 HitStop）。
   - 统一接入旧原型 `HUD`、四领域 `RealmHUD` 与终局战 `ClimaxCombatHUD`，订阅 `player.weapon.hit_landed`、`player.melee.hit_landed`、`Events.blade_parried`、`player.health.damaged`、`player.health.died`。
   - 完整交付：
     - **Hitmarker 三态**：普通命中（白）、爆头（金）、击杀（红）的缩放弹出与淡出动画。
     - **分层命中/击杀音效**：播放仓库既有真实音频（`hit_body.ogg` / `hit_head.ogg`），叠加爆头 `hit_tink` 与击杀 `hit_kill` / `hit_kill_head`；连续命中时以私有状态做细微音高递进（如 `+0.03/连击`，封顶 `+0.15`，`1.2 s` 归零）。
     - **分级顿帧（HitStop）**：普通击杀 `0.05 s`、爆头击杀 `0.075 s`、弹反 `0.05 s`、近战非致命命中 `0.025 s`；在 `fixture` 模式、暂停、玩家死亡或 headless 默认状态下安全跳过。
     - **连杀确认文案（`KillText`）**：「击杀 / 爆头击杀 / 双杀 / 三杀 / 连杀 ×N」缩放弹出与淡出。
     - **玩家受击音效与低血心跳**：`0.06 s` 合并窗口、轻/重受击音（`>= 20% max_health` 或爆头播重击音）、低血 `< 30%` 进入 / `> 35%` 退出心跳；护盾/无敌挡伤绝不误触发；暂停冻结、死亡立即静音清空。
   - 预留 `on_hit_blocked()`（或对应信号监听接口），供后续盾牌格挡 Ticket 接入。
2. **升级 `RealmHUD` 顶部 Boss 血条**：
   - 将裸 `ProgressBar` 替换为支持既有 `HealthTrail` 的自定义绘制 Boss 血条控件（保留领域主题配色与 Boss 名称），扣血后展示延迟白条拖尾并附带短促受击微抖（`0.12 s`），暂停时冻结拖尾推进。
3. **建立生产 `RealmStage` 高层行为测试套件**：
   - 新建端到端集成测试场景与脚本（参照 `realm_feedback_test` 风格），覆盖四领域生产房间、Boss 房与 `ClimaxCombatHUD` 的战斗反馈闭环。

## Acceptance Criteria

- [ ] 四领域 `RealmHUD` 与终局战 `ClimaxCombatHUD` 在普通命中、爆头、击杀、弹反、近战非致命命中时，均能触发对应三态 Hitmarker、分层音效（含连击音高微升）、连杀文案与对应时长 `HitStop` 请求。
- [ ] 在 `RunState.fixture != null`、暂停、玩家死亡或默认 headless 模式下，绝不触发 `Engine.time_scale` 降速。
- [ ] 正式战役玩家真实掉血时触发合并后的轻/重受击音效与低血心跳；护盾/无敌完全吸收时不触发；暂停时冻结进度，死亡时立即停止心跳并清空状态。
- [ ] `RealmHUD` 顶部 Boss 血条在 Boss 受击后显示 `HealthTrail` 白色延迟拖尾并随帧平滑衰减，暂停时冻结。
- [ ] 旧原型 `HUD` 保持对外行为与节点兼容，既有回归套件全绿：`tests/hit_feel_test.tscn`、`tests/gun_feel_test.tscn`、`tests/realm_feedback_test.tscn`、`tests/fixture_test.tscn`。
- [ ] 新建的生产 `RealmStage` 战斗打击感集成测试在 headless 模式下全项通过，且全程不消耗全局模拟 RNG。
