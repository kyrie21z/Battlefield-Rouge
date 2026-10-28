# HUD 图形化第一、二、三步取证

2026-10-28，Godot 4.7.2 stable，Windows 原生窗口，Forward+ / Vulkan，RTX 4060 Laptop GPU。

## 重现

在仓库根目录的 WSL 终端执行（截图不能加 `--headless`）：

```bash
G=/mnt/d/Godot/Godot_v4.7.2-stable_win64_console.exe
P="$(wslpath -w "$PWD")"
"$G" --headless --path "$P" --import
"$G" --path "$P" res://tests/hud_proof.tscn
```

默认写入本目录，可用 `-- --out=<目录>` 改写。保存失败或交互检查失败会非零退出；本次输出 `HUD PROOF PASSED`，共 26 张 JPEG。

脚本载入真实 `zone_1.tscn`，通过数字 1 完成开局选卡，再清空构筑加成以隔离展示状态。敌人和玩家移动冻结；01–05、07–10 暂停相关组件计时，避免截图耗时吞掉受伤白条或弹反窗口。11–15 恢复武器、能力及 HUD 的逐帧处理，通过实际输入动作驱动滚轮、Q、R、G、V，而不是手工调用 HUD 更新。16–20 用真实 E 锤击和 F 交互推进小关；24–25 在增益台前通过 `RunState.add_buff()` 放入同一条增益两次加另外两条，检查叠加和流派边框后截取图标栏；26 是同一 Boss 场景在 1280×720 下的全貌。

## 截图

除标注外均为 1920×1080。每张已逐一打开检查，HUD 面板、数字、图标和按键之间无重叠或出界；开局弹窗已关闭。

截图由 `save_jpg(path, 0.85)` 直接输出，旧 PNG 已删除。Vitals 为 340×88、生命条高 44；第三步后武器面板为 504×100，三格各 84×80，增益图标 56×56、间隔 10；G/V 使用深色背景和逻辑字号 22，在 1280×720 下约为 14.7px。A 提交时（`fe81ca0`），原生 proof 和 67 项 HUD 回归均通过且无退出错误，日志为 `a_proof.log`、`a_hud_test.log`。本目录 26 张截图已在第三步全部重新生成，包含新目标布局、贴边箭头、Boss 关和增益图标栏，目录总计约 2.4MB（上限 5MB）。

| 文件 | 展示内容 |
| --- | --- |
| [01_full_health.jpg](01_full_health.jpg) | 生命 100、12 段生命条、30/240、步枪高亮、G 就绪、V 匕首。 |
| [02_low_health.jpg](02_low_health.jpg) | 生命降至 22，数字和边框变红，损失部分暂留白条。 |
| [03_reloading.jpg](03_reloading.jpg) | 4/240 低弹红字及换弹进度条；没有“换弹中”文字。 |
| [04_shield_active.jpg](04_shield_active.jpg) | 护盾生效到一半：上方青色细条半长、G 发光；保留原有紫色全屏护盾反馈。 |
| [05_shield_cooldown.jpg](05_shield_cooldown.jpg) | G 冷却剩 4 秒，半圈遮罩和数字；生命上方护盾条隐藏，没有串入换弹状态。 |
| [06_layout_1280x720.jpg](06_layout_1280x720.jpg) | 1280×720，就绪布局，实际换弹后为 30/214。 |
| [07_damage_settled.jpg](07_damage_settled.jpg) | 同一次伤害的白条回落到生命 22，仍保持低血红色警告。 |
| [08_shield_locked.jpg](08_shield_locked.jpg) | 未解锁 G：暗色图标和锁，近战槽仍可用。 |
| [09_parry_rounds.jpg](09_parry_rounds.jpg) | V 弹反窗口白色发光描边，收藏 1/2 发为一个实心点和一个空心点。 |
| [10_danger_badge.jpg](10_danger_badge.jpg) | 危险弹匣红色角标；独立于护盾解锁状态。 |
| [11_shotgun_axe.jpg](11_shotgun_axe.jpg) | 滚轮切到霰弹枪：6/36、第二格高亮；Q 切到斧图标。 |
| [12_sniper_tachi.jpg](12_sniper_tachi.jpg) | 滚轮切到狙击枪：5/25、第三格高亮；Q 切到太刀图标。 |
| [13_live_reload.jpg](13_live_reload.jpg) | 原生窗口中按 R 后自然推进的换弹条，V 保留太刀。 |
| [14_reload_1280x720.jpg](14_reload_1280x720.jpg) | 1280×720，4/214 低弹及正在推进的换弹条。 |
| [15_switch_1280x720.jpg](15_switch_1280x720.jpg) | 1280×720，换弹中滚轮切枪后进度条消失，霰弹枪高亮和斧图标正确。 |

1280×720 使用项目既有 `canvas_items` 缩放，逻辑视口仍是 1920×1080；截图文件自身确为 1280×720，并非把 1080p 截图事后缩小。

## 交互观察

- 完成开局选卡后弹窗关闭；三把枪滚轮循环，枪名、弹药、图标和高亮同步。Q 循环三种近战图标。
- R 开始并完成换弹；换弹中滚轮切枪会隐藏进度条，切回仍只有原来的 4 发，不会自动补满。
- G 从就绪进入生效，生命上方出现细条；到期进入冷却，冷却结束恢复就绪。V 短时亮起弹反描边，窗口结束后熄灭。
- 实际 `Health.apply_damage()` 后生命变为 22，白条先保留再自然回落；回血后数字和分段条恢复。
- 准星、StrikeBar 和紫色护盾覆盖层保持不变；第二步替换目标布局和 Boss 血条，并增加场景目标标记；第三步把增益文字列表换成图标栏，并收紧武器面板。

## 第二步：目标标记与 Boss（布局已随第三步调整）

当前目标面板在左上 `(32,24)`，宽 280；没有短提示时高 128，需要「按 E 挥锤／按 E 砸核心」时展开到 176。从上到下依次是「战区 1/3」小标签、阶段图标与短目标句、剩余敌人「图标 ×N」；沿用的 `director.objective` 长副标题已删除。Boss 血条为顶部居中的 640×76 面板。两种血条共用 `HealthTrail` 的 0.4 秒保留和每秒 120 HP 回落逻辑。目标、Boss 和距离文字都沿用上一轮的世界标记投影与安全边距，屏幕内不再显示方向箭头。

| 文件 | 展示内容 |
| --- | --- |
| [16_clear_guards_1920x1080.jpg](16_clear_guards_1920x1080.jpg) | 阶段图标、战区、守卫数量；弱灰色据点菱形与相机距离。 |
| [17_hammer_ring_1920x1080.jpg](17_hammer_ring_1920x1080.jpg) | 真实 E 锤击推进蓝色外环；目标面板展开「按 E 挥锤」；StrikeBar 保留短提示「E 挥锤 · 金色区间 = 完美打击」。 |
| [18_behind_edge_1920x1080.jpg](18_behind_edge_1920x1080.jpg) | 转身背对据点，菱形停在屏幕安全边缘，朝目标一侧伸出带深色描边的三角箭头和「3米」。 |
| [19_behind_edge_1280x720.jpg](19_behind_edge_1280x720.jpg) | 同一背后目标在 720p 下仍完整显示，箭头同样清晰。 |
| [20_pedestal_F_1280x720.jpg](20_pedestal_F_1280x720.jpg) | 插旗后据点标记隐藏；增益台绿色 F 菱形在范围内高亮。 |
| [21_boss_full_1920x1080.jpg](21_boss_full_1920x1080.jpg) | Boss 900/900、红色目标；同方向核心标记移开并用细线关联投影点；目标面板显示「击倒 Boss」和「× 7」。 |
| [22_boss_trail_1920x1080.jpg](22_boss_trail_1920x1080.jpg) | 42 点实际伤害后 858/900，白条保留损失部分。 |
| [23_boss_fallen_1280x720.jpg](23_boss_fallen_1280x720.jpg) | 已倒下灰态、Boss 标记隐藏，核心开启，任务切换为锤击据点并展开「按 E 砸核心」。 |
| [24_buff_bar_1920x1080.jpg](24_buff_bar_1920x1080.jpg) | 三条增益、三种流派：枪械黄框 ×2、刀具红框 ×1、技能紫框 ×1。 |
| [25_buff_bar_1280x720.jpg](25_buff_bar_1280x720.jpg) | 同一图标栏在 1280×720 下完整显示，边框色和 ×N 仍可辨认。 |
| [26_boss_overview_1280x720.jpg](26_boss_overview_1280x720.jpg) | Boss 关 1280×720 全貌：Boss 血条、目标面板、两条增益、Boss/核心标记和武器面板。 |

16–20 用伤害 API 清除守卫、冻结 AI，再以真实 E 输入逐次砸完建筑；F 在图标栏截图之后实际打开通关增益选卡。21–23 载入真实 Boss 地图，通过伤害 API 驱动血条；22 仅冻结血条计时以捕获短暂白条，随后恢复逐帧处理并确认自然回落；26 在 21 之后切成 1280×720 截取同一站位。站位和朝向由取证脚本布置，不声称是手工走位或实弹击杀。

画面检查发现并修正了同方向 Boss/核心标记重叠、距离文字压到准星、以及贴边三角与进度环挤在一起的问题：小三角已外移到菱形中心 40–55 px，并在下方垫 6 px 深色描边，因此 18/19 能直接读出目标在上方偏左。首轮取证把玩家放在小关锤击范围外（3.6 米），已改到 3 米；没有修改战斗范围来让取证通过。增益台原有的世界文字仍保留，靠近时会比新 F 菱形大。标记距离取相机到目标原点的三维距离并四舍五入，交互判定仍使用玩家位置，故范围内可能显示“3米”。

`hud_test` 的 F 交互边界检查放在距离 2.39 米处，而不是名义上的 2.4 米：`Vector3.RIGHT * 2.4` 在 float32 下实际是 2.4000001 米，会正确落在 `<= 2.4` 范围外；这是测试卡得过紧，不是交互范围的问题。

## 第三步：增益图标栏与布局收紧

`$Buffs` 的多行长文字已替换为 `BuffBar`：每条不同增益显示一格 56×56 斜切图标，间隔 10，图片直接取 `Buff.icon`，边框取 `SchoolCatalog` 的流派强调色（枪械 `#F5C400`、刀具 `#E0242A`、技能 `#B36CFF`，找不到流派时退回 `HudStyle.MUTED`），右下角深色徽章显示 `×N` 并用同一强调色描边。没有按名称写死图标；分组键优先用 `buff.id`，为空时退回 `resource_path + title`。零增益时 `BuffBar.visible = false`，整条栏不占空间；「选择任意流派开始构筑」已删除。选择界面继续负责完整说明，HUD 不再显示长句，也没有为图标栏新增鼠标悬停提示（HUD 各层都是 `mouse_filter = ignore`，加提示需要引入新的输入依赖）。

图标栏贴目标面板下沿 10 px：折叠时在 `(32,162)`，展开时随面板下移到 `(32,210)`。目标面板右边缘为 312，Boss 血条从 x=640 起，1920 逻辑宽度下两者不重叠；1280×720 按 `canvas_items` 等比缩放，布局坐标不变。目标面板没有为图标栏让位到别处——它本来就在左上角，直接把栏放在其下，跑图状态集中在同一只角，也避开居中的 Boss 血条。

同一轮去掉了武器面板里重复当前枪的大图标框：面板收紧为 504×100，左侧是弹药数字、枪名和换弹条，右侧并排三格 84×80，只高亮当前格；面板与生命、技能区仍互不重叠。贴边标记新增 `arrow_visible` 和 `arrow_tip()`，`hud_test` 用它验证箭头方向与目标屏幕方向一致。

## 自动回归（第一至三步）

导入完成，无导入错误。全部 12 个 `tests/*_test.tscn` 进程退出码均为 0、断言均通过；退出资源提示单独记录，不将日志描述为全部无错误。

| 场景 | 断言结果 |
| --- | --- |
| `boss_test` | `ALL PASSED (62 checks, 0 failed)` |
| `buff_run_test` | `ALL PASSED (0 failed)` |
| `capture_hammer_test` | `ALL PASSED (0 failed)` |
| `combat_traits_test` | `COMBAT TRAITS: ALL PASSED (0 failed)` |
| `fixture_test` | `ALL PASSED (0 failed)` |
| `hud_test` | `ALL PASSED (273 checks, 0 failed)`，最终日志无退出资源提示 |
| `melee_test` | `ALL PASSED (0 failed)` |
| `reflected_round_test` | `REFLECTED ROUND: ALL PASSED (0 failed)` |
| `reinforcement_test` | `ALL PASSED (0 failed)` |
| `reload_blast_test` | `RELOAD BLAST: 27 checks, 0 failed` |
| `school_icons_test` | `ALL PASSED (0 failed)` |
| `weapons_test` | `ALL PASSED (0 failed)` |

`hud_test` 在第三步新增的检查包括：零增益时图标栏隐藏、同一条增益选择两次只占一格且显示 `×2`、枪械和刀具的边框色分别等于 `SchoolCatalog` 的强调色且互不相同、贴边时箭头可见且箭头方向与目标的独立投影方向一致、武器面板不再有大图标框且三格 84×80 并排、当前格高亮；折叠状态的目标面板固定为 `(32,24,280,128)`，图标栏贴在其下 `(32,162)` 且不重叠，锤击时面板展开到 176。

fixture 使用 `--headless --fixed-fps 60 --path "$P" res://tests/fixture_test.tscn -- --runs=3`。HUD 这次改动之后两个固定构筑各三次的结果和哈希保持当时的基线不变；#40 让敌人找射击位、#42 把守卫铺到全场，哈希随之改变（见 [issue #14 证明](../issue-14/README.md)）：

| Fixture | 每次结果 | 每次 tick / 轨迹行数 | 三次一致的哈希 |
| --- | --- | --- | --- |
| FX-001 | 胜利 | 2554 / 139 | `95d4b590ae882378` |
| FX-002 | 胜利 | 912 / 41 | `4494ad3460ca6ab9` |

另外重跑原生 `tools/render_icons.tscn`，输出 `Rendered 6 icons to res://assets/ui/weapons (0 failed)`；六个 PNG 的 SHA-256 均与重跑前一致。没有引入新的第三方素材；派生图标沿用现有模型的许可状态，未将 `docs/ASSETS.md` 中待确认的来源擅自改为已确认。

## 音频退出提示及基线对照

首次全套回归中，`weapons_test`、`melee_test`、`fixture_test` 在断言通过后仍报告 `ObjectDB instances were leaked at exit` 和 `2 resources still in use at exit`。没有忽略这些日志，也没有修改生产音频代码来掩盖提示。

用 `git archive 8462d10` 导出的未改动基线副本、同一 Godot 引擎完成对照（不是切分支或新建 worktree）：

- `weapons_test` 基线同样报告 6 个 ObjectDB 实例及 2 个 `hit_body.ogg` 相关资源；当前也是 6 个及 2 个。
- `fixture_test` 基线也有同类音频退出提示（28 个实例、2 个 `hit_head.ogg` 相关资源）；当前全套运行是 23 个实例、2 个资源。基线断言和固定哈希仍通过。
- `melee_test` 最初单次基线没有提示，因此额外将基线和当前版本交替各跑三次，所有运行均使用 `--headless --verbose --path <对应项目路径> res://tests/melee_test.tscn`，未更改测试或音频设置。

| `melee_test` 对照 | 断言 / 退出码 | 退出资源提示 |
| --- | --- | --- |
| 基线第 1 次 | `ALL PASSED (0 failed)` / 0 | 4 个实例、2 个资源 |
| 当前第 1 次 | `ALL PASSED (0 failed)` / 0 | 4 个实例、2 个资源 |
| 基线第 2 次 | `ALL PASSED (0 failed)` / 0 | 无 |
| 当前第 2 次 | `ALL PASSED (0 failed)` / 0 | 4 个实例、2 个资源 |
| 基线第 3 次 | `ALL PASSED (0 failed)` / 0 | 无 |
| 当前第 3 次 | `ALL PASSED (0 failed)` / 0 | 无 |

三次出现提示的日志均列出同样的 `OggPacketSequence`、`AudioStreamOggVorbis`、`OggPacketSequencePlayback`、`AudioStreamPlaybackOggVorbis`，资源均为 `res://assets/audio/hit_head.ogg` 及其 `OggPacketSequence` 子资源。因此基线已存在不确定性的音频退出提示；这六次样本不能证明两个版本的出现概率相同，但排除了“只在本次 HUD 改动后才出现”的判断。

本次日志保留在 `/tmp/hud-review-20261028/`：各场景的 `*_test.log`、`proof.log`、`melee_comparison.json` 和六份 `melee_compare_{baseline,current}_{1,2,3}.log`。这些是当前机器的临时诊断文件，不是仓库资产。既有音频退出提示未在本次 HUD 范围内修复；新增 `hud_test` 在释放场景后等待音频混音周期，最终日志干净。第三步复跑 12 个场景时只有 `weapons_test` 仍报告 6 个 ObjectDB 实例和 2 个资源，其余场景无此类提示；日志在 `/tmp/hud-step3-tests/`。
