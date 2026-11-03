# 受击反馈证明图

`tests/hurt_feedback_proof.tscn` 在真实窗口里跑 FX-001 的战区，把下面几帧写到本目录。
第一帧正前方的敌人只当取景参照；那一发不带攻击者，所以画面里只有暗角、没有方向弧。

| 文件 | 内容 |
| --- | --- |
| `01_full_hp_vignette.jpg` | 满血挨一枪（10 伤害）后的边缘暗角。中心不填色，暗角在半秒内淡出。 |
| `01_full_hp_vignette_centre.jpg` | 同一帧屏幕中心的 4 倍裁切，证明暗角没有盖住瞄准区。 |
| `02_indicator_behind_right.jpg` | 身后与右侧各一发：下方和右侧各一段红色弧线，指向攻击者。 |
| `03_low_hp.jpg` | 生命 15%（低于 30%）：常驻脉冲暗角，截图取在脉冲高点。 |

重新生成（需要真实显示，headless 没有渲染器）：

```
godot --path . res://tests/hurt_feedback_proof.tscn -- --out=docs/proof/hurt-feedback
```

参数 `--out=<目录>` 可以换输出位置，默认就是本目录。
