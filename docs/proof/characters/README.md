# 角色模型证明

Boss 换成 Hazmat 模型、玩家加只投影子的 Soldier 身体。规则和数值见 [ADR 0004](../../adr/0004-boss-wave-and-core.md) 文末「Boss 模型与耐打」，素材登记见 [ASSETS.md](../../ASSETS.md)「角色模型」。

截图由 `tests/character_models_proof.tscn` 在真实窗口里拍（不能 `--headless`），2026-10-27，Godot 4.7.2：

```bash
G=/mnt/d/Godot/Godot_v4.7.2-stable_win64_console.exe
P="$(wslpath -w "$PWD")"
"$G" --path "$P" res://tests/character_models_proof.tscn -- --out=<windows path>
```

| 文件 | 看什么 |
| --- | --- |
| `01_boss_hazmat.png` | Boss 是黄色防化服，周围 6 个红头盔小怪；血条 `900 / 900` |
| `02_player_shadow_idle.png` | 低头看地面：玩家站着的影子 |
| `03_player_shadow_run.png` | 同一位置跑动时的影子；镜头里看不到身体本身 |

脚本最后一行输出 `boss health 900, headshot x1.25`。

`boss_test.tscn` 里对应的检查：

```
  [ok] the boss has far more health (900 vs 100)
  [ok] the boss wears the Hazmat model
  [ok] the small enemies keep the Enemy model
  [ok] the boss head hitbox moved onto the new skeleton
  [ok] a bigger head pays less per headshot (1.25 vs 2.50)
```

全部 10 个无界面测试通过。fixture 的新哈希见 [issue-14 证明](../issue-14/README.md)。
