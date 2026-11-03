# 敌人子弹 / 增援刷新证明图

`tests/enemy_bullets_proof.tscn` 在真实窗口（1280×720）里跑 FX-001 的第 1 关。

| 文件 | 内容 |
| --- | --- |
| `01_enemy_tracer.jpg` | 一发敌人子弹以 30 m/s 从视野中横穿：弹体拖尾约 1.05 m（0.035 秒 × 速度），相机朝向的光晕仍然保留，中距离也能看清。 |
| `02_wave_out_of_sight.jpg` | 玩家面对据点、刚敲出完美一击时刷出的一波增援：小地图上能看到新增红点在两侧/后方，但正前方视野里没有任何新敌人（侧翼刷点藏在 Cover3/Cover4 后面）。 |

重新生成（需要真实显示，headless 没有渲染器）：

```
godot --path . res://tests/enemy_bullets_proof.tscn -- --out=docs/proof/enemy-bullets
```

## 本次改动后的 fixture 数字

以下都是 `--runs=3`，三次一致、结果均为「胜利」：

| fixture | ticks | hash |
| --- | --- | --- |
| FX-001（run 1–3） | 2500 | `c0b33a07d11cc184` |
| FX-002（run 1–3） | 880 | `4065f428dfc84c45` |

fixture 自带的「换一个种子」对照组（测试里的 seed 1002 / 2003）：

| fixture | 对照种子 | ticks | hash |
| --- | --- | --- | --- |
| FX-001 | 1002 | 2518 | `db773e4c084799e6` |
| FX-002 | 2003 | 885 | `a9a005a7ee3ded7e` |

子弹速度和刷怪选点都改动了模拟，哈希和 tick 数相对上一版（2524 / 945）变化是预期的。
