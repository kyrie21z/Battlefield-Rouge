# 02: 无 Player 设置弹窗、静滞档案只读视图与死亡双出口信号

- **GitHub Issue**: `#273`
- **Parent Spec**: `#271` (`.specs/title-screen-and-stasis-hub/spec.md`)
- **Blocked by**: None
- **Status**: `done`

## What to build

完成启动页与静滞之门大厅复用的三项交互能力与单向信号通道预重构，保持所有既有场景与测试全绿：

1. **`PauseMenu` 解耦无 `Player` 模式与「返回标题画面」出口**：
   - 允许 `PauseMenu` 在 `player == null` 的独立/外围上下文（如启动页、静滞之门）打开，安全跳过依赖 `Player` 的逻辑，完整保留灵敏度、准星样式/颜色/预览、音乐音量、按键重绑与恢复默认，关闭时自动持久化 `GameSettings`。
   - 新增可选的「返回标题画面」入口（通过注入回调或公开信号 `return_to_title_requested` 通知上层，不反向读取 `RunDirector`）：
     - 在正式战役战区打开暂停菜单时展示，并附带清晰说明「进度已保存至本房间起点」（`fixture` 模式下隐藏）；
     - 在静滞之门大厅打开时展示为「返回标题画面」；
     - 在启动页打开设置时隐藏该按钮，仅保留「恢复默认」与「关闭」。
2. **双页签只读「静滞档案」视图（复用 `LoreDiary` 与 `DualBoonCodex`）**：
   - 确保 `DualBoonCodex` 在无活跃 `BoonManager`（传入 `null`）的局外场景下可安全只读初始化并完整渲染 48 张领域赐福 + 6 张双重赐福的已发现/未发现状态与共鸣拓扑（零空指针、不修改存档）。
   - 提供可由静滞之门直接弹出的统一只读容器（沿用 Scheme B 建筑画廊风格、两页签切换：`01 心象日记` / `02 赐福图鉴`，支持手柄/键盘焦点与 `ESC` 关闭，自行妥善管理并恢复鼠标与暂停状态）。
3. **领域死亡面板双出口与单向信号通道（`RealmStage` + `RealmHUD`）**：
   - 在 `RealmStage` 新增公开信号 `hub_requested(stage: RealmStage)` 与 `title_requested(stage: RealmStage)` 及对应的薄方法 `request_hub()` / `request_title()`。
   - 在 `RealmHUD` 死亡面板中，**严格保留既有节点索引顺序**（`child 0` 为死因文案，`child 1` 为「重新挑战 · R」按钮），在其下方追加 `child 2`「返回静滞之门」按钮（当 `MetaProgression.has_affordable_upgrade()` 为真时附带「· 可锻造」轻标）；暂停菜单的「返回标题画面」经由 `stage.request_title()` 向上转发。
   - 在 `RunDirector` 订阅 `title_requested` 与 `hub_requested`（在 `StasisHub` 尚未合入前保留安全默认回退，不破坏既有战役流程）。

## Acceptance Criteria

- [ ] 在 `player == null` 场景下实例化并打开 `PauseMenu` 可正常修改灵敏度、准星、音量与键位并关闭保存，无空引用报错；战区模式下可见「返回标题画面」及本房起点说明，`fixture` 模式下自动隐藏。
- [ ] `DualBoonCodex` 在 `manager == null` 时可稳定展示已发现与锁定的全量赐福与共鸣拓扑；双页签只读「静滞档案」容器可自由切换心象日记与赐福图鉴、`ESC` 关闭并还原暂停与鼠标模式，全程不修改 `MetaProgression`。
- [ ] `RealmHUD` 死亡面板保留 `child 0`（死因）与 `child 1`（重试按钮）索引不变，新增 `child 2`「返回静滞之门」按钮并在可锻造时显示提示，点击触发 `RealmStage.hub_requested`。
- [ ] `RealmHUD` 与 `PauseMenu` 均遵守单向依赖规则，不直接操作 `RunDirector` 状态。
- [ ] `lore_diary_test`、`dual_boon_codex_test`、`codex_modal_test` 与 `campaign_realms_test`（及 `pause_menu` 相关测试）全部通过。
