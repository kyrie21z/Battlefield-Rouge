# WEEK-08 阶段性汇报

> 教学周第 8 周。覆盖 2026-10-23 建仓到 2026-11-04 的全部开发，按阶段整理；从 WEEK-09 起只写增量。

## 一、基本信息

| 项目 | 内容 |
| --- | --- |
| 教学周 | 第 8 周（`WEEK-08`），基准日 2026-11-04 |
| 文档类型 | 阶段性汇报（全量，不是单周增量） |
| 统计区间 | 2026-10-23 — 2026-11-04（含首尾 13 天，其中 7 天有提交） |
| 提交数 | 51 次（含 1 次合并提交 `edcd469`） |
| 起止提交 | `e348ad4`（2026-10-23，Set up project skeleton）→ `5004e8c`（2026-11-04） |
| 改动规模 | 765 个文件，+154,177 行（空树到 HEAD 的全量差异，含首批素材导入） |
| 成员 | 张琰翔、何承泽、章家齐 |
| 引擎 | Godot 4.7.2（Forward+，Jolt 物理） |
| 分支 | `main`，与 `origin/main` 同步（0 ahead / 0 behind） |
| 小组编号 | 1 |
| 文档负责人 | 张琰翔 |
| 运行日期 | 2026-11-04 |

## 二、阶段目标

这 13 天只做一件事：把 10-23 的原型做到能当场演示。具体是两小关加 Boss 的完整流程、一局三次增益、可复现的 fixture、Pride 开场，以及看得清状态的 HUD 和打得有回应的打击反馈。协作方式也在这段时间定下来——改动用分支，走 PR 审查后合并，验证结果一律落到 `docs/proof`。

| 阶段 | 日期 | 提交数 | 阶段目标 | 代表提交 |
| --- | --- | --- | --- | --- |
| 1 骨架与战斗原型 | 10-23 | 6 | 从空仓库搭出能跑的第一人称射击循环 | `e348ad4` `57f5295` |
| 2 验收标准落地 | 10-23 — 10-25 | 9 | 按 Cut-001b 改造占点、Boss、图标与可复现 | `e04b026` `012814f` `70aa9d6` |
| 3 三枪三近战与九增益 | 10-27 | 5 | 武器 / 近战各三把，九条增益接入 3 次选择 | `ab914d7` `f64c122` |
| 4 试玩修正与图形 HUD | 10-28 | 10 | 据点与增援改版、Boss 核心、图形 HUD、冲刺 | `1d70b03` `ca73d89` `ba7a9da` |
| 5 剧情开场 | 11-02 | 1 | Pride 开场成为正式启动入口 | `e1e672d` |
| 6 美术资产与枪感 | 11-03 | 5 | 红晶体敌人、枪感、创作愿景、审查规范 | `0146b1d` `bf561b5` `a37a3ce` |
| 7 反馈、设置与难度 | 11-04 | 15 | 受击 / 击杀 / 锤击反馈、小地图、菜单、BGM、数值调整 | `2370c14` `ef29784` `5004e8c` |

## 三、开发与改进

### 3.1 骨架与战斗原型（10-23，6 次提交）

10-23 一天里把空仓库推到了能玩的射击循环。`e348ad4` 建工程：`Events` / `RunState` 自动加载、输入映射、占位第一人称玩家、灰盒地图一次到位，架构和术语同时写进 `ARCHITECTURE.md`、`GLOSSARY.md`，取舍记在 [ADR 0001](../adr/0001-rebuild-on-clean-skeleton.md)——在干净骨架上重建，只迁代码不拷素材。

后面几次提交把循环补满。`0cd59d1` 加玩家数值、生命、步枪和 HUD；`64e5580` 收紧腰射扩散并建 `TODO.md`；`3fd7d23` 放进会追击、点射、找掩体的敌兵；`9f6facc` 修掉敌人打不死的问题，敌人子弹改成慢速可躲；`57f5295` 串起据点、三选一增益、两张图和胜负界面。这时占点还是站进圈里读条，10-25 被锤砸替换（[ADR 0002](../adr/0002-mvp-deadzone-occupy.md)、[ADR 0003](../adr/0003-hammer-capture-timing.md)）。

### 3.2 验收标准落地（10-23 — 10-25，9 次提交）

先定规矩。`4d900f4` 合入协作分支，`f0679a7` 把它改成 `CONTRIBUTING.md`，写清 PR 三行描述和审查合并规则。`9da4b76` 锁定 Cut-001 的两段占点与九条增益，`1babf43` 在 `docs/ASSETS.md` 登记可用的开源素材。

验收项占了两天。`e04b026` 把站圈读条换成锤建筑占点加完美打击，HUD 补节拍条和 F3 调试条，新增 `capture_hammer_test`，规则进 [ADR 0003](../adr/0003-hammer-capture-timing.md)；当天真实窗口取证里完美 8 次、普通 1 次（[Issue #5 证明](../proof/issue-5/README.md)）。`e9d1117` 出垂直切片风格板，`5bc141f` 做三流派剪影图标并配 `school_icons_test`（[Issue #13 证明](../proof/issue-13/README.md)）。`012814f` 交出 Boss 关：1 个 Boss 带 6 个小怪、血条和胜负判定（[Issue #10 证明](../proof/issue-10/README.md)、[ADR 0004](../adr/0004-boss-wave-and-core.md)）。`70aa9d6` 补上 AC-07，`RunFixture`、按战区播种、`SimClock` 和机器人复现检查一并进仓库（[Issue #14 证明](../proof/issue-14/README.md)、[ADR 0005](../adr/0005-reproducible-runs.md)）。

### 3.3 三枪三近战与九增益（10-27，5 次提交）

10-27 把武器池和增益池一次补齐。`ab914d7` 一条提交把三把枪和三把近战都放了进来：近战带吸附前冲，霰弹打多弹丸，狙击是 2×/4×/8× 镜，截图在[近战证明](../proof/melee/README.md)和[枪械证明](../proof/guns/README.md)。`f64c122` 接上九条可叠加增益与入场 / 通关选择（AC-04、AC-08），Q 切近战、V 挥砍、G 护盾，PR #21 由 `edcd469` 合并。`eff407d` 把入场卡限制在第一关，一局只选三次（[ADR 0006](../adr/0006-nine-buffs-and-entry-choices.md)）。`83927bd` 补 Ironline 1944 的 MIT 声明并重存 `rifle.tres`。九卡与选择时机的取证在 [AC-04 / AC-08 证明](../proof/ac-04-ac-08/README.md)。

### 3.4 试玩修正、图形 HUD 与能力（10-28，10 次提交）

这一天主要在收拾试玩暴露的问题。`1d70b03` 把据点后移并居中，插旗后小怪往后方逃、灭点不算击杀，通关增益改成旗旁增益台按 F（[ADR 0007](../adr/0007-reinforcements-shockwave-pedestal.md)）。`3ba663e` 让 Boss 倒下后核心才能一锤击碎，同时按 #25 的反馈修卡墙、据点位置和逐步碎裂。`1252fdb` 给 Boss 换 Hazmat 模型，头部不再按放大后的命中区吃高倍率伤害。`8462d10` 把旗插进废墟，顺手去掉倒塌建筑的碰撞。

可读性和操作也在这天补上。`ca73d89` 的图形 HUD 加了生命、武器面板、世界标记、Boss 血条和增益图标栏（[HUD 证明](../proof/hud/README.md)）。`41b5a96` 用两格 Shift 冲刺替换长按疾跑，5 米、0.18 秒一次。

AI 侧改了刷怪和站位。`901b29b` 限定只有正常启动才进 fixture 战区；`a646f0f` 给敌人找射击位、用锤声唤醒守卫；`5d235ab` 把守卫和 Boss 小怪铺到全场（[敌人布局证明](../proof/enemy-layout/README.md)）。`ba7a9da` 加入危险弹匣主动投掷、C 槽和 7 米紫盾反击（[主动弹匣与护盾证明](../proof/active-buffs/README.md)、[ADR 0008](../adr/0008-held-magazine-and-shield-radius.md)）。

### 3.5 剧情开场（11-02，1 次提交）

`e1e672d` 把 Pride 开场接到正式入口：正常启动先播开场，确认后进原来的三选一和 `maps/zone_1.tscn`，死亡重开不重播，跑 fixture 或加 `--skip-opening` 直接跳过（[ADR 0009](../adr/0009-pride-opening-bootstrap.md)、[Pride 开场证明](../proof/pride-opening/README.md)）。11-04 的 `a5b197f` 补了第一关预热和黑场过渡，同步加载从 5051.7 ms 降到 788.8 ms（[过渡证明](../proof/opening-transition/README.md)）。

### 3.6 美术资产与枪感（11-03，5 次提交）

美术和手感在这天一起推进。`0146b1d` 做枪感：弹簧后坐、相机抖动、分层程序化枪声、命中与击杀反馈、准星、收紧扩散（[枪感证明](../proof/gun-feel/README.md)）。`bf561b5` 入库红晶体敌人的 static / rigged / parts 三形态，`a37a3ce` 补 23 个动画剪辑和 56 片碎裂（[红晶体敌人证明](../proof/crystal-enemy/README.md)）。文档侧，`85945c1` 迁入 Mind Freak 创作愿景作为方向，`480af5b` 加 PR 审查标准和 `tools/review/run_checks.sh`。

### 3.7 反馈、设置与难度（11-04，15 次提交）

15 次提交里大半来自前一天的试玩意见。

先补反馈。`2370c14` 加受击暗角、受伤音、方向弧和低血心跳，`d6fdf63` 强化命中与击杀反馈、把枪声压柔，`af27de4` 给锤击据点补石屑、碎裂和齿轮收尾，`eaa963c` 在屏幕中央加阶段横幅。四份证明在[受击反馈](../proof/hurt-feedback/README.md)、[打击感](../proof/hit-feel/README.md)、[锤击反馈](../proof/hammer-feel/README.md)、[阶段横幅](../proof/phase-banner/README.md)。

信息与设置一并补齐：`ef29784` 右上角旋转小地图，`d0a5a6f` 暂停菜单带准星和灵敏度，`00797dd` 加按键绑定页，`da411ca` 写三种程序化 BGM（[小地图](../proof/minimap/README.md)、[暂停菜单](../proof/settings-menu/README.md)、[按键绑定](../proof/keybindings/README.md)、[BGM](../proof/bgm/README.md)）。

难度调了三轮。`006028b` 提高敌人子弹速度、把增援改到视野外刷新；`49fcd45` 降敌人伤害和增援数量；`5004e8c` 强化危险弹匣与护盾，敌人移速从 4.6 降到 3.6 m/s。数值上 `1b02c1b` 把普通锤从 8% 提到 10%、完美倍率从 1.5 提到 2.0（本次 +20%），窗口仍保持 ±150 ms；提交说明写明这是张琰翔（Kyrie）的试玩决定。

表现层最后补：`be21795` 给玩家一个灰白晶体影子身体，`9422ed4` 让它持枪并随换枪切换（[玩家晶体身体证明](../proof/protagonist-body/README.md)）。

### 3.8 真人试玩与整改（11-03 收集 → 11-04 落实）

11-03 拉外部玩家试玩，收回 33 条书面反馈。去掉「无」「可」「挺好的」「暂无」，剩下 23 条有效建议，原始表 `改进建议.xlsx` 留在本机课程目录，没有入库。

11-04 按反馈改：受击暗角与受伤音、命中与击杀反馈、锤击石屑与碎裂、小地图、准星与灵敏度、程序化 BGM、敌人子弹提速与视野外刷新。逐条对照在[试玩反馈与整改](../proof/playtest-2026-11-03/README.md)，完成 14 条、部分完成 4 条、未完成 5 条。没做完的集中在画质、建模、武器数量、动作流畅度和玩法深度，已经排进第六节。

### 3.9 文档与流程（贯穿）

9 篇 ADR 覆盖骨架重建、占点规则、锤击节拍、Boss、复现、九增益、增援、危险弹匣和剧情开场。`docs/proof` 下 27 份 README 连同日志、截图是这段时间的取证，31 个 `tests/*_test.tscn` 也都是本区间新增的。审查方式写在 `CONTRIBUTING.md`、`docs/REVIEW.md` 和 `tools/review/run_checks.sh`：kk（Grok Bot）常驻审查，张琰翔（Kyrie）合并，走 squash merge。

## 四、验证结果

### 4.1 已有证明（按日期，引用原文结论）

| 日期 | 检查 | 结论 | 来源 |
| --- | --- | --- | --- |
| 2026-10-25 | 锤击占点真实窗口取证 | 日志统计完美 8 / 普通 1 | [Issue #5](../proof/issue-5/README.md) |
| 2026-10-27 | `buff_run_test` 与九卡图标 | `ALL PASSED (0 failed)`；九张图标渲染像素哈希互不相同 | [AC-04 / AC-08](../proof/ac-04-ac-08/README.md) |
| 2026-10-27 | Boss 关 1 胜 1 负取证 | 真实窗口跑通，规则与数值见 ADR 0004 | [Issue #10](../proof/issue-10/README.md) |
| 2026-10-28 | 全部 17 个 `tests/*_test.tscn` | 断言通过、退出码 0；`hud_test` **287 checks, 0 failed**；盾反馈新增 24 项通过 | [HUD 证明](../proof/hud/README.md) |
| 2026-10-28 | fixture 复现（AC-07） | FX-001 胜利 2554 tick / `95d4b590ae882378`；FX-002 胜利 912 tick / `4494ad3460ca6ab9` | [HUD 证明](../proof/hud/README.md) |
| 2026-11-02 | Pride 开场接入 | 全部 18 个测试场景通过；新增接入检查 30 项、原生 32 项通过；fixture 哈希与接入前一致 | [Pride 开场](../proof/pride-opening/README.md) |
| 2026-11-03 | 红晶体敌人资产自检 | `[check] OK 动画=23 骨骼=24 网格=11 顶点=5155 碎片=56 分组=11` | [红晶体敌人](../proof/crystal-enemy/README.md) |
| 2026-11-03 | 玩家晶体身体 | `PROTAGONIST BODY: ALL PASSED (0 failed)` | [玩家晶体身体](../proof/protagonist-body/README.md) |
| 2026-11-04 | 敌人子弹 / 增援刷点 | fixture FX-001 2500 tick / `c0b33a07d11cc184`；FX-002 880 tick / `4065f428dfc84c45` | [敌人子弹](../proof/enemy-bullets/README.md) |

表里 11-04 那两行是当天调参途中的中间值。最后一次调参 `5004e8c` 给出的基线是 FX-001 `91e7f1f7a1c5d232`、FX-002 `8d531b6cf8e98fb9`，与 4.2 的新跑结果一致。

### 4.2 本次新跑（2026-11-04，HEAD `5004e8c`）

命令（WSL 调用 Windows 版 Godot，逐场景运行；`fixture_test` 另加 `--fixed-fps 60`）：

```bash
G=/mnt/d/Godot/Godot_v4.7.2-stable_win64_console.exe
for t in tests/*_test.tscn; do
  n=$(basename "$t" .tscn); extra=""; [ "$n" = fixture_test ] && extra="--fixed-fps 60"
  timeout 900 "$G" --headless $extra --path . "res://$t"
done
```

31 个场景全部退出码 0，断言通过。下面只列有明确计数的，其余收尾行都是 `ALL PASSED (0 failed)`。

| 场景 | 结果 |
| --- | --- |
| `active_magazine_test` | `ACTIVE MAGAZINE: 36 checks, 0 failed` |
| `boss_test` | `ALL PASSED (63 checks, 0 failed)` |
| `enemy_layout_test` | `ALL PASSED (34 checks, 0 failed)` |
| `hud_test` | `ALL PASSED (287 checks, 0 failed)` |
| `opening_boot_test` | `OPENING BOOT: 30 checks, 0 failures` |
| `reload_blast_test` | `RELOAD BLAST: 41 checks, 0 failed` |
| `shield_visual_test` | `SHIELD FEEDBACK: 24 checks, 0 failed` |

`fixture_test` 输出：

```text
   FX-001  91e7f1f7a1c5d232
   FX-002  8d531b6cf8e98fb9
ALL PASSED (0 failed)
```

和 `5004e8c` 提交说明里的基线逐字一致；FX-001、FX-002 各跑两遍哈希相同，种子 +1 的对照组轨迹不同。

日志里还有几处非断言输出，照原样留着：

- 5 个场景退出时仍有 `ObjectDB instances were leaked` 或 `resources still in use at exit`：`dash_test`、`hammer_feel_test`、`opening_boot_test`、`opening_transition_test`、`weapons_test`。`weapons_test` 的 2 个资源占用和 HUD 证明里记录的音频退出提示是同一类，这次没有修。
- `opening_transition_test` 通过，但日志在预热第一关时打了 1 条 `ERROR: Another resource is loaded from path 'res://actors/player/player.tscn' (possible cyclic resource inclusion)`，断言没有失败。

### 4.3 未验证项

- 真人试玩有，录屏没有。11-03 收了 23 条建议（见 3.8），11-04 整改完也没安排复测，难度结论不算量化测试。
- 跨机器复现（AC-07）仍只在本机验证，[ADR 0005](../adr/0005-reproducible-runs.md) 与 `TODO.md` 都记了这条限制，这次还是同一台机器。
- 画面类证明（受击、击杀、小地图、菜单、横幅、BGM 试听）是截图、音频和生成脚本，不是自动断言；这次没有重新生成。

## 五、问题与决策

### 5.1 已记录的决策

| ADR | 日期 | 决策 |
| --- | --- | --- |
| [0001](../adr/0001-rebuild-on-clean-skeleton.md) | 2026-10-23 | 在干净骨架上重建，只从旧工程迁代码，不拷素材 |
| [0002](../adr/0002-mvp-deadzone-occupy.md) | 2026-10-25 | 放弃站圈读条，改为清守卫 + 锤砸据点；先留 `CapturePoint` 待替换 |
| [0003](../adr/0003-hammer-capture-timing.md) | 2026-10-25 | 命中时刻取据点节拍，判定用按键那一刻；窗口 ±150 ms |
| [0004](../adr/0004-boss-wave-and-core.md) | 2026-10-25 | Boss 关一波核心；10-28 修订为 Boss 倒下后核心才开、一锤击碎 |
| [0005](../adr/0005-reproducible-runs.md) | 2026-10-25 | `SimClock` + 战区播种 + fixture；限制是只在本机验证 |
| [0006](../adr/0006-nine-buffs-and-entry-choices.md) | 2026-10-27 | 三派九卡，一局 3 次选择（开局 1 次 + 两个小关结束各 1 次） |
| [0007](../adr/0007-reinforcements-shockwave-pedestal.md) | 2026-10-28 | 后方增援不回退进度；插旗冲击波；增益台按 F |
| [0008](../adr/0008-held-magazine-and-shield-radius.md) | 2026-10-28 | 危险弹匣独立库存与 5 米范围；护盾 7 米反击独立半径 |
| [0009](../adr/0009-pride-opening-bootstrap.md) | 2026-11-02 | Pride 开场只做启动入口，不改种子、增益、战区序号或战斗规则 |

### 5.2 已知问题与限制

1. **难度只经过一轮真人试玩。** 11-03 的试玩提出了子弹速度、受击反馈等意见，11-04 已整改（3.8）；但 `49fcd45`、`5004e8c` 两次调低强度之后没有复测，Boss + 6 小怪 1.7–2.6 秒打死站桩玩家的记录仍来自旧版本。
2. **引擎退出诊断没处理。** 5 个测试场景退出时有 ObjectDB / 资源提示。HUD 证明里拿 `8462d10` 做过对照，说明主分支早就有音频退出提示，这次没有修，也不声称修好了。
3. **开场预热有一条循环资源错误日志。** `opening_transition_test` 通过，但预热 `player.tscn` 时打了 cyclic resource inclusion，根因还没定位。
4. **灰盒与占位素材仍在。** 三个战区、据点建筑、锤和旗都是灰盒 / 占位模型，`TODO.md` 已列为下一步。
5. **影子身体的左手够不到前护木。** 模型 23 个剪辑里没有标准抵肩托护木姿势，`protagonist-body` 证明写明需要新剪辑或 IK，超出本次范围。
6. **锤击证明图是调参前的数字。** `af27de4` 的截图显示 +8% / +12%，随后 `1b02c1b` 改成 +10% / +20%；当前以 `zone/capture_config.tres`（10.0 / 2.0 / 150 ms）为准，截图未重拍。
7. **未跟踪文件。** 工作区还有 `.qoder/` 和 `art_source/`（244 KB），这次只写文档，没有入库，也没有删。
8. **周报目录是新建的。** 仓库此前没有 `docs/weekly/`，这次按课程要求补了 `README.md` 和 `WEEK-08.md`，`TEMPLATE.md` 也缺，一并补了一份最小模板。

## 六、下周计划

下一份是 `WEEK-09`，区间从 2026-11-05 写到运行当天，只写增量。

| 计划项 | 负责人 |
| --- | --- |
| 按 `docs/weekly/README.md` 补 WEEK-09 增量：提交、证明、验证结果 | 张琰翔 |
| 复测 11-04 调整后的难度：真人跑完两小关 + Boss，记录击杀时间与死亡原因并录屏 | 张琰翔 |
| 处理试玩剩下的 5 条未完成反馈：画质、建模、武器数量、动作流畅度、玩法深度 | 章家齐 |
| 换掉灰盒场景与据点 / 锤 / 旗的占位模型，保留碰撞与 `navigation_geometry` | 章家齐 |
| 跨机器跑 `fixture_test`，确认 AC-07 不只在本机成立 | 何承泽 |
| 清理音频退出提示与开场预热的循环资源错误 | 何承泽 |
| 敌人开枪的枪口火光、受击动画、绕侧行为 | 章家齐 |
| 补 `docs/weekly/TEMPLATE.md` 的正式版本（如课程有统一模板，按课程模板替换） | 张琰翔 |

## 七、个人贡献

| 成员 | 本周具体任务 | 完成产出 | 核验依据 | 下周任务 |
| --- | --- | --- | --- | --- |
| 张琰翔 | 工程骨架与战斗循环；三关流程与 Boss；可复现 fixture；图形 HUD 与 Shift 冲刺；枪感、受击 / 击杀 / 锤击反馈；小地图、菜单、BGM；玩家影子身体；数值调整 | 可现场运行的两小关 + Boss 构建；图形 HUD、冲刺与整套打击反馈；`fixture_test` 复现脚本；灰白晶体影子身体，能持枪并随换枪切换 | `kyrie21z` / `Yanxiang Zhang`；代表提交 `e348ad4` `ca73d89` `0146b1d` `5004e8c`；[HUD 证明](../proof/hud/README.md)、[枪感证明](../proof/gun-feel/README.md)、[玩家晶体身体证明](../proof/protagonist-body/README.md) | 补影子身体持枪姿势与动作 |
| 何承泽 | 三派九条增益与进场 / 结算选择；危险弹匣主动投掷与 C 槽；7 米紫盾反击；Pride 开场接入正式入口 | 九卡在三关流程里可选可叠加；C 槽三态与紫盾反馈；正常启动先播 Pride 开场再进第一关 | `KADG` / `KADG777`；提交 `f64c122` `ba7a9da` `e1e672d`；[主动增益证明](../proof/active-buffs/README.md)、[开场接入证明](../proof/pride-opening/README.md) | Pride 开场对白与镜头打磨 |
| 章家齐 | 三把枪与三把近战；红晶体敌人模型、23 个动画剪辑与 56 片碎裂 | 三枪三近战可切换、可战斗；红晶体敌人 static / rigged / parts 三形态入库 | `MRTODAYY`；提交 `ab914d7` `bf561b5` `a37a3ce`；[近战证明](../proof/melee/README.md)、[枪械证明](../proof/guns/README.md)、[红晶体敌人证明](../proof/crystal-enemy/README.md) | 完善角色建模、动作与特效 |

## 附录 A：提交清单（51 次，按时间倒序）

| 提交 | 日期 | 作者 | 说明 |
| --- | --- | --- | --- |
| `5004e8c` | 2026-11-04 | 张琰翔 | tune: stronger danger magazine and shield, slower enemies (#86) |
| `9422ed4` | 2026-11-04 | 张琰翔 | feat: the shadow body holds and aims the current gun (#84) |
| `be21795` | 2026-11-04 | 张琰翔 | feat: grey-white crystal humanoid as the player's shadow body (#82) |
| `a5b197f` | 2026-11-04 | 张琰翔 | feat: warm the first zone during the opening and fade into the game (#80) |
| `49fcd45` | 2026-11-04 | 张琰翔 | tune: lower enemy difficulty (slower bullets, less damage, fewer reinforcements) (#78) |
| `1b02c1b` | 2026-11-04 | 张琰翔 | tune: ordinary hammer +10%, perfect strike x2 (+20%) (#76) |
| `00797dd` | 2026-11-04 | 张琰翔 | feat: key bindings tab in the Esc menu, usable over the buff screen (#74) |
| `da411ca` | 2026-11-04 | 张琰翔 | feat: procedural background music with calm/combat/boss tracks (#72) |
| `d0a5a6f` | 2026-11-04 | 张琰翔 | feat: pause menu with crosshair and sensitivity settings (#70) |
| `eaa963c` | 2026-11-04 | 张琰翔 | feat: centre-screen phase banners (#68) |
| `006028b` | 2026-11-04 | 张琰翔 | feat: faster enemy bullets and out-of-sight reinforcement spawns (#66) |
| `ef29784` | 2026-11-04 | 张琰翔 | feat: HUD minimap (#64) |
| `af27de4` | 2026-11-04 | 张琰翔 | feat: hammer strike feedback on the capture point (#62) |
| `d6fdf63` | 2026-11-04 | 张琰翔 | feat: stronger hit and kill feedback, softer gunshots (#60) |
| `2370c14` | 2026-11-04 | 张琰翔 | feat: player hurt feedback — edge vignette, hurt sound, direction arcs, low-HP heartbeat (#58) |
| `a37a3ce` | 2026-11-03 | 章家齐 | art: 红晶体敌人补动画（23 剪辑）与碎裂碎片（56 片） (#55) |
| `480af5b` | 2026-11-03 | 张琰翔 | docs: add PR review standard and automated review checks for kk (#56) |
| `bf561b5` | 2026-11-03 | 章家齐 | art: 入库红晶体敌人（static / rigged / parts 三形态） (#54) |
| `85945c1` | 2026-11-03 | 张琰翔 | docs: migrate Mind Freak vision as the game's north star (#52) |
| `0146b1d` | 2026-11-03 | 张琰翔 | feat: gun feel — recoil, audio, hit feedback, crosshair, tighter spread (#50) |
| `e1e672d` | 2026-11-02 | 何承泽 | feat: play Pride opening before the existing Battlefield run (#48) |
| `ba7a9da` | 2026-10-28 | 何承泽 | 危险弹匣主动投掷与 C 槽，强化 7 米紫盾反击反馈 (#34) |
| `5d235ab` | 2026-10-28 | 张琰翔 | Spread first-wave guards and boss minions across the battlefield (#42) (#44) |
| `a646f0f` | 2026-10-28 | 张琰翔 | Give enemies a firing position and wake guards with hammer noise (#40) (#43) |
| `901b29b` | 2026-10-28 | 张琰翔 | Start a fixture zone only on a normal launch (#39) (#41) |
| `41b5a96` | 2026-10-28 | 张琰翔 | Replace hold-to-sprint with a Shift dash along the camera's facing (#37) (#38) |
| `ca73d89` | 2026-10-28 | 张琰翔 | Graphical HUD: vitals, weapon panel, world markers, boss bar, buff icons (#35) (#36) |
| `8462d10` | 2026-10-28 | 张琰翔 | Plant the flag in the rubble and drop the collapsed building's collision. (#32) |
| `1252fdb` | 2026-10-28 | 张琰翔 | Give the boss the Hazmat model and stop its big head paying out. (#29) (#30) |
| `3ba663e` | 2026-10-28 | 张琰翔 | Boss 关：打倒 Boss 后一锤碎核心；补 #25 试玩修正（卡墙、据点后移、逐步碎裂） (#28) |
| `1d70b03` | 2026-10-28 | 张琰翔 | Center small-zone points and clear them under rear reinforcements. (#27) |
| `83927bd` | 2026-10-27 | 张琰翔 | Add the Ironline 1944 MIT notice and re-save rifle.tres (#24) |
| `eff407d` | 2026-10-27 | 张琰翔 | Offer the opening buff only on the first zone of a run. (#23) |
| `edcd469` | 2026-10-27 | 何承泽 | Merge pull request #21 from kyrie21z/feat/ac-04-ac-08-buffs |
| `f64c122` | 2026-10-27 | 何承泽 | Implement nine stacking buffs and entry/clear choices (AC-04, AC-08) |
| `ab914d7` | 2026-10-27 | 章家齐 | 近战三把与枪械三把：吸附前冲、霰弹弹丸、狙击镜倍率 (#20) |
| `70aa9d6` | 2026-10-25 | 张琰翔 | AC-07 同起点可复现一局：fixture、按战区播种、SimClock、机器人复现检查 (#19) |
| `012814f` | 2026-10-25 | 张琰翔 | AC-02 Boss 关：一波城市核心 + Boss 血条，分出胜负 (#18) |
| `5bc141f` | 2026-10-25 | 张琰翔 | AC-06：三流派剪影图标（斧、弹药、准星） (#17) |
| `e9d1117` | 2026-10-25 | 张琰翔 | 文档：垂直切片风格板（配色与剪影） (#16) |
| `e04b026` | 2026-10-25 | 张琰翔 | AC-01/03 锤建筑占点 + 完美打击（替换站圈读条） (#9) |
| `1babf43` | 2026-10-25 | 张琰翔 | Art: document MVP-priority open-source assets in ASSETS.md (#8) |
| `9da4b76` | 2026-10-25 | 张琰翔 | 文档：Cut-001 两段占点 MVP 与九条增益 (#4) |
| `f0679a7` | 2026-10-25 | 张琰翔 | 将协作规范改为贡献指南，并写明审查与合并规则 (#3) |
| `4d900f4` | 2026-10-23 | 张琰翔 | Merge pull request #1 from kyrie21z/docs/collaborate |
| `57f5295` | 2026-10-23 | 张琰翔 | Step 4: zone loop — capture point, buff select, two zones, win/death screens |
| `9f6facc` | 2026-10-23 | 张琰翔 | Fix unkillable enemies; enemies fire slow, dodgeable projectiles |
| `3fd7d23` | 2026-10-23 | 张琰翔 | Add enemy soldiers with chase, burst fire and cover |
| `64e5580` | 2026-10-23 | 张琰翔 | Tighten hip-fire spread and add TODO list |
| `0cd59d1` | 2026-10-23 | 张琰翔 | Add player combat: stats, health, rifle and HUD |
| `e348ad4` | 2026-10-23 | 张琰翔 | Set up project skeleton |
