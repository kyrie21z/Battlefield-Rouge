# 危险弹匣：打空即得，C 投掷，6 米爆炸

2026-11-04，Issue [#87](https://github.com/kyrie21z/Battlefield-Rouge/issues/87)。基于 main `5004e8c`，Godot 4.7.2。

## 当前行为

最后一发成功射出后，同一帧立即储存一枚危险弹匣，不等换弹完成；无备用弹也能获得。保留按 C 投掷、手持模型和 C 槽 `0/1` / `1/1`。库存上限一枚，切枪与取消换弹保留库存；空仓扣扳机、重复换弹或换弹完成不额外发放。

半径从 main 的 5 米适度扩大到 6 米，保留 1.5 米全伤区、每层 120→60 线性衰减。C 投出时读取当前叠层数值；速度 24 米/秒，投出后 1.5 秒引信，0.5 米近敌扫掠和墙/地碰撞提前引爆。遮挡、无自伤友伤、同一 Health 一次 BODY 伤害继续生效。

世界特效增加双面开口橙色波前、上下厚环、延迟余环和 24 枚火花，沿用烟光与合成爆炸声。波前 0.38 秒抵达 6 米，0.52 秒开始淡出，0.85 秒回收。贴地爆点的下环在爆点上方，避免埋入地面。视觉随暂停冻结，不消费玩法全局随机数。

## 原生画面与操作证明

Windows / Forward+ / Vulkan / RTX 4060 Laptop，1280×720。真实玩家、枪械、HUD、选卡与敌人模型；固定位置并停止 AI、移动和换弹倒计时，以清楚验证“无需换弹完成”。不把取证布置说成人工完整通关。

[原生日志](native.log)：**21 项通过，0 失败，无脚本或引擎错误**。真实最后一发同栈发放库存，鼠标捕获下的物理 C 输入在弹量仍为 0、换弹尚未完成时投出；22.29 米外引爆并实际命中 4 个敌人。验证一次投出、C 槽回到 0/1、6 米波前、暂停冻结与自动回收。

| 图 | 证明 |
| --- | --- |
| [打空前](01-ready-last-round.jpg) | 已获得增益、C 槽尚无库存 |
| [打空即得](02-C-ready-before-reload.jpg) | 枪弹量 0、换弹未完成，手持弹匣和 C 槽 1/1 已可用 |
| [远投引爆](03-distant-impact.jpg) | 约 22 米外真实爆炸，投出后 C 回 0/1 |
| [6 米范围](04-six-metre-pressure-wave.jpg) | 外部观察镜头显示橙色厚环及 6 米标记 |

四张 JPEG 共 269,094 字节，每张小于 77 KB；已逐张目视检查。

## 功能回归

以下最终版本运行均退出 0、断言无失败。测试日志位于 `logs/`。

| 场景 | 通过项 | 重点 |
| --- | ---: | --- |
| [active_magazine_test](logs/active_magazine_test.log) | 62 | 同帧获取、换弹前可投、三枪无备弹、库存上限、持有无引信、当前伤害、暂停死亡 |
| [reload_blast_test](logs/reload_blast_test.log) | 43 | 1.5/3.75/6 米伤害、5.5 米新增伤害带、越界、遮挡、去重、投射物 |
| [combat_traits_test](logs/combat_traits_test.log) | 26 | 弹匣、收藏弹和盾机制兼容 |
| [hud_test](logs/hud_test.log) | 287 | C 保持原图形槽，打空立即亮起，投出变暗 |
| [buff_run_test](logs/buff_run_test.log) | 269 | 三次选卡、叠层、换关及阵亡重开 |
| [keybinding_test](logs/keybinding_test.log) | 33 | C 和其他操作的改键设置 |
| [weapons_test](logs/weapons_test.log) | 38 | 三枪、切枪、镜及基础换弹 |
| [shield_visual_test](logs/shield_visual_test.log) | 24 | 7 米紫盾反馈和死亡清理保持 |
| [reflected_round_test](logs/reflected_round_test.log) | 6 | 收藏弹遮挡及伤害保持 |
| [fixture_test](logs/fixture_test.log) | 24 | 固定 60 帧下两个起点各两遍、另种子各一遍，实际通关、重开与复现 |

fixture 最终两遍一致：FX-001 `91e7f1f7a1c5d232`；FX-002 `8d531b6cf8e98fb9`。另种子及 tick 见日志，不把其他版本的旧哈希改写成本次结果。

`weapons_test` 和 `fixture_test` 退出时仍报告 ObjectDB（10 个）及 2 个资源占用的清理诊断；断言通过，最终原生日志无该诊断。本次未修复这一退出清理问题。6 米仍需团队试玩平衡，未进行跨平台或长期性能评估。

## 复查

在项目根目录，用 Godot 4.7.2 执行：

```powershell
& "D:\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "." "res://tests/active_magazine_test.tscn"
& "D:\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --fixed-fps 60 --path "." "res://tests/fixture_test.tscn"
& "D:\godot\Godot_v4.7.2-stable_win64_console.exe" --path "." "res://tests/empty_magazine_proof.tscn"
```

旧 `reload_blast_proof.tscn` 入口仍转到这份当前证明；历史 [主动弹匣证明](../active-buffs/README.md) 和 ADR 0008 保留当时事实。本次决策见 [ADR 0010](../../adr/0010-empty-magazine-blast.md)。
