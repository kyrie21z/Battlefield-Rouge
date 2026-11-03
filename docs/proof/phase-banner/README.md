# 阶段横幅证明图

`tests/phase_banner_proof.tscn` 在真实窗口（1280×720，画布 1920×1080）里跑 FX-001 的第 1 关和 Boss 关。

| 文件 | 内容 |
| --- | --- |
| `01_clear_guards.jpg` | 开局选完卡：标题「战斗开始」，副标题「消灭所有守卫，据点才会开放」。左上角常驻面板本身写「清除守卫」，所以横幅换了标题，避免和面板重复。 |
| `02_hammer_point.jpg` | 守卫清完、据点开放：金色「据点开放」+「前往据点，按 E 挥锤 · 金色区间是完美打击」。 |
| `03_reinforcement.jpg` | 第一波增援：红色「增援来袭」+「守住据点，继续砸」。它排在「据点开放」之后播完，不会抢第一条横幅的前 1.2 秒。 |
| `04_flag_planted.jpg` | 插旗：绿色「据点已占领」+「增援撤退 · 到旗旁增益台按 F 领取增益」，和左上角「到增益台按 F」一致。 |
| `05_boss_standing.jpg` | Boss 关开场：红色「Boss 现身」+「击倒 Boss，城市核心才会打开」。左上角面板原文是「击倒 Boss」，横幅标题因此不照抄；顶部 Boss 血条不被遮挡。 |

重新生成（需要真实显示，headless 没有渲染器）：

```
godot --path . res://tests/phase_banner_proof.tscn -- --out=docs/proof/phase-banner
```

横幅在 24% 高度处，位于 Boss 血条（顶部中央）与准星上方的打击/判定文字之间；
纯展示层，不改变任何玩法状态。fixture 基线保持不变：seed 1002 → 2518 ticks
`db773e4c084799e6`，seed 2003 → 885 ticks `a9a005a7ee3ded7e`。
