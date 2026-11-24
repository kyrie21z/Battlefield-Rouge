# 04: 左选项 + 右 3D 戴冠半身像启动页与全局入口路由切换

- **GitHub Issue**: `#275`
- **Parent Spec**: `#271` (`.specs/title-screen-and-stasis-hub/spec.md`)
- **Blocked by**: `#272` (Ticket 01), `#273` (Ticket 02), `#274` (Ticket 03)
- **Status**: `done`

## What to build

落地「左选项 + 右实时 3D 戴冠主角半身像」启动页，并将全局入口路由切换至正式流程（同时保持所有测试与命令行直通全绿）：

1. **左选项 + 右 3D 戴冠半身像启动页（`TitleScreen`）**：
   - **整体视觉与构图**：16:9 自适应 Scheme B（Architectural Editorial）建筑画廊风，纯白哑光柱廊 3D 空间背景 + 共享 `default_env.tres` 的 SSAO/SSIL 光照副本。
   - **左侧菜单栏（约 42% 宽，完整支持鼠标/键盘/手柄焦点）**：
     - 顶部眉标 `THRESHOLD // 静滞之门`、主标题 `MIND FREAK`、动态副标题（未和解：`在停摆的那一刻，醒来。`，严禁前期剧透 Pride 或完整主题；已和解：`不再完美，但终于完整。`）。
     - 根据 `MetaProgression` 真实状态动态呈现菜单栈：
       - **全新档案（`not has_profile()`）**：`开始游戏`（主按钮）→ `设置与按键` → `退出游戏`。
       - **已有档案且无残局**：`继续游戏`（主按钮，副行展示静滞之门摘要：挑战次数 / 已击败心魔数 / 碎屑余额）→ `新游戏`（弹出二次确认弹窗，提示重置并保留 `.bak` 备份）→ `设置与按键` → `退出游戏`。
       - **已有档案且存在 `active_run`**：`继续当前挑战`（主按钮，副行展示 `第 X 层 · <领域名> 房 Y/3` 或 `终局返程回廊`）→ `返回静滞之门`（弹出确认弹窗：结算已清房锁定收益并放弃本次挑战）→ `新游戏`（二次确认重置）→ `设置与按键` → `退出游戏`。
     - 点击「设置与按键」直接打开 Ticket 02 解耦后的无 `Player` `PauseMenu`。
   - **右侧实时 3D 白晶主角半身像（约 58% 宽）**：
     - 实例化真实 `ProtagonistBody`（头部正常渲染可见，不设为 `SHADOWS_ONLY`），3/4 侧身朝向左下方菜单，取胸口以上至头顶皇冠的特写机位，循环柔和待机呼吸动画，支持极克制的鼠标微视差（可通过减少移动选项关闭）。
     - **三态视觉演化（纯只读消费 `MetaProgression` 快照）**：
       1. **全新档案（`not opening_completed`）**：`fracture_level = 0`（纯白完整），实体 `CrownModel`（`worn = false`）**悬空在头骨上方约 0.14m 处轻缓上下浮动**（悬空待加冕），`emission = 0.5`。
       2. **已加冕探索中（`opening_completed and not reconciled`）**：`CrownModel` 落位佩戴于头顶；复用 `BodyFracture` 展示 `clampi(defeated_realms.size(), 0, 4)` 级黑色晶面接缝与松动碎屑；皇冠光强同步按 `0.5 * pow(2.4, fracture_level)` 递增；右上角四枚极简菱形徽记点亮已击败心魔色。
       3. **已终局和解（`reconciled`）**：复用 `kintsugi_gold.gdshader` + `KintsugiFlow` 在晶面接缝呈现暗金流光与四色微光节点，皇冠落位佩戴且光强回落至温和的 `0.55`。
2. **入口路由收敛与开场衔接（`GameStart` + `OpeningSequence` + `RunDirector`）**：
   - `GameStart` 变为纯入口路由器：不再在 `_ready()` 无条件调用 `RunDirector.begin_run()`，也不再直接实例化全屏 `CrownForge`；保留 `--fixture=<id>` 与 `--skip-opening` 直通原有战斗流程。
   - 普通启动默认进入 `TitleScreen`：
     - 「开始游戏」或「新游戏」确认重置后 → 进入 `OpeningSequence`（一镜到底开场）；玩家穿过开场大门时原子标记 `MetaProgression.mark_opening_completed()` 并触发 `RunDirector.begin_run()` + `prepare_departure()` + 保存初始 `active_run` + 淡入第一层第一房。
     - 「继续当前挑战」→ 调用 `RunDirector.resume_run()` 淡入恢复对应房间。
     - 「继续游戏」→ 淡入 `StasisHub`；「返回静滞之门（放弃残局）」确认后先调 `RunDirector.abandon_active_run()` 再淡入 `StasisHub`。
   - 接通 `RunDirector` 从战区/大厅/结局菜单响应 `title_requested` 返回 `TitleScreen`。
3. **既有启动与战役测试定向对齐（保证本 Ticket 合入即全绿）**：
   - 更新 `opening_boot_test` 与 `meta_campaign_test` 适配新正式入口（通过 `TitleScreen` 按钮进入开场 / 静滞之门锻造台），保留对 `FX-001` / `FX-002`、`CrownForge` 事务、货币结算防重与死后归来流程的完整断言。

## Acceptance Criteria

- [ ] 普通启动直接呈现 `TitleScreen` 且不会提前自增 `RunDirector.run_count` 或写入空挑战历史；`--fixture=FX-001/FX-002` 与 `--skip-opening` 继续零延迟直通对应战斗场景。
- [ ] 启动页右侧 3D 半身像三态可验证：① 新档为纯白身躯 + 皇冠悬空浮动（悬空待加冕）；② 已加冕探索期皇冠落位佩戴，裂痕等级与皇冠发光严格对应 `defeated_realms.size()`；③ `reconciled` 后切为暗金金缮流光、温和皇冠与新副标题。
- [ ] 左侧菜单完整覆盖三类存档状态（无档 / 有档无残局 / 有 `active_run`），「新游戏」与「放弃残局回静滞之门」均需二次确认，且启动页可随时打开「设置与按键」修改并保存配置。
- [ ] 一镜到底开场穿门后持久化 `opening_completed = true` 并正常进入第一房；战区/大厅/结局菜单均可通过「返回标题画面」干净回到 `TitleScreen`。
- [ ] `opening_boot_test`、`meta_campaign_test`、`meta_forge_test`、`run_director_test` 与 `fixture_test`（AC-07）全部通过。
