# 05: 端到端集成验收测试、原生截图与文档收口

- **GitHub Issue**: `#276`
- **Parent Spec**: `#271` (`.specs/title-screen-and-stasis-hub/spec.md`)
- **Blocked by**: `#274` (Ticket 03), `#275` (Ticket 04)
- **Status**: `ready-for-agent`

## What to build

落地 Spec 锁定的单一主端到端集成测试接缝，完成跨系统联合验收、原生视觉核查与文档同步：

1. **新增主端到端集成测试接缝（`tests/title_hub_resume_test.tscn`）**：
   - 使用隔离测试档案，在同一真实场景树生命周期内完整验证四大端到端链路：
     - **启动页三态与重置**：空白档启动校验悬空待加冕皇冠、`fracture_level == 0` 与「开始游戏」→ 完成开场穿门断言 `opening_completed == true`；注入 3 心魔与终局和解存档校验佩戴皇冠、裂痕等级、皇冠光强、暗金金缮与副标题切换；校验「新游戏」二次确认重置与 `.bak` 备份保留。
     - **换房中途续关与反 S/L 闭环**：在 `0:0` 完成开局选卡 → 清房过门进入 `0:1` 落盘 `active_run` → 在 `0:1` 消耗一次「不屈意志」复活并击杀 1 名敌人后通过暂停菜单「返回标题画面」→ 模拟冷重启重新加载档案并点击「继续当前挑战」→ 断言精准恢复至 `0:1`、未重复弹 `0:0` 选卡、未将未清房击杀带入货币、`defiance_consumed` 仍为 `true`；随后阵亡并校验 `active_run` 原子清空与货币一次性入账。
     - **3D 静滞之门全交互闭环**：经由死亡面板「返回静滞之门」进入 `StasisHub` → 断言皇冠复盘语音触发 → 靠近左侧锻造台按 `interact` 打开 `CrownForge` 扣费升级并验证大厅 `Player` 属性即时更新 → 靠近右侧四心魔立柱按 `interact` 打开只读「静滞档案」切换日记与图鉴并 `ESC` 关闭 → 穿过正前方心智之门进入真实第 1 房并断言皇冠历史对白未重复播报。
     - **启动页无 Player 设置弹窗**：在 `TitleScreen` 打开「设置与按键」修改灵敏度与按键绑定并关闭保存，验证无空引用报错且配置落盘。
2. **全量回归与 AC-07 确定性守卫**：
   - 运行全部关联与核心回归测试：`title_hub_resume_test`、`opening_boot_test`、`meta_campaign_test`、`meta_forge_test`、`run_director_test`、`campaign_realms_test`、`lore_diary_test`、`dual_boon_codex_test`、`codex_modal_test`、`fixture_test`（AC-07）。
3. **非 headless 原生渲染截图核查**：
   - 采集并人工核查两组原生渲染截图（确认无遮挡、无穿模、文字清晰、比例和谐）：
     - 启动页三态：新档悬空皇冠 / 探索期 3 心魔裂痕+耀眼皇冠 / 和解期金缮；
     - 静滞之门大厅第一人称视野：左侧锻造台、右侧四心魔碑、正前方心智之门与交互提示。
4. **文档与资产卫生收口**：
   - 同步更新 `GLOSSARY.md`（登记「启动页半身像（悬空待加冕）」「静滞之门 3D 大厅（`StasisHub`）」「换房中途续关快照（`active_run`）」）；
   - 更新 `ARCHITECTURE.md` 启动入口流程说明，并在 `docs/adr/0009-pride-opening-bootstrap.md` 文末追加本次入口与大厅演进修订注记（保留历史正文）；
   - 核对所有新建 `.gd` 均附带 Godot 4.7.2 生成的 `.gd.uid`，无无关场景漂移。

## Acceptance Criteria

- [ ] `tests/title_hub_resume_test.tscn` 完整覆盖启动页三态、冷重启换房续关与 4 条防 S/L 不变量、`StasisHub` 全交互与标题页设置，100% 通过。
- [ ] 全量回归套件与 `tests/fixture_test.tscn`（AC-07）全绿，零新增报错与警告。
- [ ] 启动页三态与静滞之门大厅的原生渲染截图已生成并核查通过。
- [ ] `GLOSSARY.md`、`ARCHITECTURE.md` 与 `docs/adr/0009-pride-opening-bootstrap.md` 已同步更新且与最终实现完全一致。
- [ ] 所有新增脚本均包含 Godot 4.7.2 生成的 `.gd.uid`，`git diff` 干净无无关改动。
