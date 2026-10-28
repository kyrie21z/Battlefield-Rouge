# HUD 图形化第一步取证

2026-10-28，Godot 4.7.2 stable，Windows 原生窗口，Forward+ / Vulkan，RTX 4060 Laptop GPU。

## 重现

在仓库根目录的 WSL 终端执行（截图不能加 `--headless`）：

```bash
G=/mnt/d/Godot/Godot_v4.7.2-stable_win64_console.exe
P="$(wslpath -w "$PWD")"
"$G" --headless --path "$P" --import
"$G" --path "$P" res://tests/hud_proof.tscn
```

默认写入本目录，可用 `-- --out=<目录>` 改写。保存失败或交互检查失败会非零退出；本次输出 `HUD PROOF PASSED`。

脚本载入真实 `zone_1.tscn`，通过数字 1 完成开局选卡，再清空构筑加成以隔离展示状态。敌人和玩家移动冻结；01–05、07–10 暂停相关组件计时，避免截图耗时吞掉受伤白条或弹反窗口。11–15 恢复武器、能力及 HUD 的逐帧处理，通过实际输入动作驱动滚轮、Q、R、G、V，而不是手工调用 HUD 更新。

## 截图

除标注外均为 1920×1080。每张已逐一打开检查，HUD 面板、数字、图标和按键之间无重叠或出界；开局弹窗已关闭。

截图由 `save_jpg(path, 0.85)` 直接输出，15 张约 1.5MB，旧 PNG 已删除。修整后 Vitals 为 340×88、生命条高 44；枪械小格为 92×50，便于辨认剪影。G/V 使用深色背景和逻辑字号 22，在 1280×720 下约为 14.7px。本次重新运行原生 proof 和 67 项 HUD 回归，均通过且无退出错误，日志为 `a_proof.log`、`a_hud_test.log`。

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
- 保留原有顶部目标、增益文字、准星和紫色护盾覆盖层；没有增加场景目标标记、Boss 新血条或增益图标栏。

## 自动回归

导入完成，无导入错误。全部 12 个 `tests/*_test.tscn` 进程退出码均为 0、断言均通过；退出资源提示单独记录，不将日志描述为全部无错误。

| 场景 | 断言结果 |
| --- | --- |
| `boss_test` | `ALL PASSED (0 failed)` |
| `buff_run_test` | `ALL PASSED (0 failed)` |
| `capture_hammer_test` | `ALL PASSED (0 failed)` |
| `combat_traits_test` | `COMBAT TRAITS: ALL PASSED (0 failed)` |
| `fixture_test` | `ALL PASSED (0 failed)` |
| `hud_test` | 67 项，`ALL PASSED (0 failed)`，最终日志无退出资源提示 |
| `melee_test` | `ALL PASSED (0 failed)` |
| `reflected_round_test` | `REFLECTED ROUND: ALL PASSED (0 failed)` |
| `reinforcement_test` | `ALL PASSED (0 failed)` |
| `reload_blast_test` | `RELOAD BLAST: 27 checks, 0 failed` |
| `school_icons_test` | `ALL PASSED (0 failed)` |
| `weapons_test` | `ALL PASSED (0 failed)` |

fixture 使用 `--headless --fixed-fps 60 --path "$P" res://tests/fixture_test.tscn -- --runs=3`，两个固定构筑各三次的结果和哈希保持基线不变：

| Fixture | 每次结果 | 每次 tick / 轨迹行数 | 三次一致的哈希 |
| --- | --- | --- | --- |
| FX-001 | 胜利 | 2583 / 138 | `c77413a921d58fc4` |
| FX-002 | 阵亡（既有基线结果） | 355 / 13 | `5e1a5a995f643d72` |

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

本次日志保留在 `/tmp/hud-review-20261028/`：各场景的 `*_test.log`、`proof.log`、`melee_comparison.json` 和六份 `melee_compare_{baseline,current}_{1,2,3}.log`。这些是当前机器的临时诊断文件，不是仓库资产。既有音频退出提示未在本次 HUD 范围内修复；新增 `hud_test` 在释放场景后等待音频混音周期，最终日志干净。
