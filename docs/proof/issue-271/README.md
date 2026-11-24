# #271 / Ticket 05 原生视觉核查

Godot 4.7.2 · Forward+ · Vulkan 1.4.335（llvmpipe 软件光栅）下的非 headless 截图。
启动页为 1920×1080 画布；静滞之门大厅为 1280×720 窗口覆盖。

截图来源：

```bash
godot --path . res://tests/title_screen_test.tscn -- --title-proof-dir=/tmp/bfr-275-native
godot --path . res://tests/stasis_hub_test.tscn -- --stasis-hub-proof-dir=/tmp/bfr-274-native-final
```

## 启动页三态

| 文件 | 档案状态 | 已核查 |
| --- | --- | --- |
| `fresh.png` | 空白档 | 皇冠悬空于头顶上方，身体纯白无接缝；左侧只有「开始游戏 / 设置与按键 / 退出游戏」，副标题「在停摆的那一刻，醒来。」；文字无裁切，左右比例约 42/58。 |
| `mid.png` | 已加冕、3 心魔 | 皇冠落位佩戴，黑色晶体接缝覆盖胸臂，皇冠金光明显增强；右上四枚菱形徽记亮起三枚；主按钮「继续当前挑战」与房间摘要清晰。 |
| `reconciled.png` | 终局和解 | 接缝转为暗金金缮，皇冠回落为温和亮度；四枚徽记全亮，副标题「不再完美，但终于完整。」；无遮挡、无穿模。 |

## 静滞之门 3D 大厅

| 文件 | 取景 | 已核查 |
| --- | --- | --- |
| `hub-spawn.png` | 出生点面朝 -Z | 正前方「THRESHOLD / 心智之门」完整可见；左侧锻造台与悬浮皇冠、右侧四心魔立柱均在视野内；皇冠复盘字幕完整，比例与光照和谐。 |
| `hub-forge.png` | 左侧锻造台交互圈 | 石座与悬浮皇冠清晰，`[ F ] 皇冠锻造台` 提示与字幕互不遮挡。 |
| `hub-archive.png` | 右侧四心魔碑 | 四根立柱及「怠惰 / 恐惧 / 愤怒 / 悲伤」标签可读，暗金斜纹与对应情绪色正常；`[ F ] 心象档案与赐福图鉴` 提示清晰。该帧在测试中已记录四领域击败与和解，故四柱均为染色金缮状态。 |
| `hub-gate.png` | 心智之门交互距离 | 站在门前时 `[ F ] 穿过心智之门 · 开启挑战` 提示清晰；近景门框无穿模。远处门楣的全景以上一张 `hub-spawn.png` 为准。 |

## 结论

三态与大厅均未发现文字裁切、UI 重叠、模型穿插或比例失调。`tests/title_screen_test.tscn`（24 checks）与
`tests/stasis_hub_test.tscn`（40 checks）在采集同一轮次中零失败；`forward-plus.log` 保留了启动页这一轮的
Forward+ 设备信息与检查输出。
