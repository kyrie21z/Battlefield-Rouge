# Issue #5 Proof（AC-01 / AC-03）

占点配置路径：`zone/capture_config.tres`（窗口 ±150ms、普通 +8%、完美 ×1.5）。

由 `tests/capture_proof.tscn` 在真实窗口里跑出，不是手动录屏：

```bash
godot --path . res://tests/capture_proof.tscn -- --out=<输出目录>
```

| 文件 | 内容 | 证明 |
| --- | --- | --- |
| `01_clear_guards.png` | 阶段 `CLEAR_GUARDS`，还剩 4 个守卫，据点锁定 | AC-01 |
| `02_hammer_point_open.png` | 守卫清零，阶段 `HAMMER_POINT`，站在锤程内 | AC-01 |
| `03_perfect_strike.png` | 命中时刻 -25ms：金色闪光、金色大字、进度 +12% | AC-03 成功反馈 |
| `04_ordinary_strike.png` | 偏晚 374ms：蓝白闪光、灰色小字、进度 +8% | AC-03 失败反馈，与上一张分开 |
| `05_flag_planted.png` | 进度 100%，阶段 `FLAG_PLANTED`，旗从建筑顶升起 | AC-01 |
| `run.log` | 每次挥锤的偏差和进度，以及每张截图时的调试条文字 | AC-03 |

每张截图左上角是调试条（F3），写明配置文件路径和三个数。

## 局限

- 守卫由脚本直接造成伤害打死，不是枪打的。
- 挥锤是脚本按下 `hammer` 动作（真实输入路径），按命中时刻对齐，所以几乎全是完美打击。
- 这些不能代替 60 秒实机录像。AC-01 的“可玩”仍需要人玩一遍。
- 截图为 256 色 PNG（压缩过，金色闪光处有轻微色带）。
