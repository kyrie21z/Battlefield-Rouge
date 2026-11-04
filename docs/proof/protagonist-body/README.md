# 玩家晶体身体证明

玩家的影子身体从 Soldier 换成了灰白色的晶体人形（和红晶体敌人同一套模型）：`actors/player/protagonist_body.tscn`
实例化 `assets/models/characters/red_crystal_enemy_animated.glb`（缩放 0.9，身高 1.75 m），
材质用 `assets/materials/protagonist_crystal_material.tres`（`MI_ProtagonistCrystal`）。
素材登记见 [ASSETS.md](../../ASSETS.md)。

四张图由 `tests/protagonist_body_proof.tscn` 在真实窗口里拍（`--headless` 没有渲染器，拍不出东西），
2026-11-03，Godot 4.7.2，Vulkan / Forward+：

```bash
G=/mnt/d/Godot/Godot_v4.7.2-stable_win64_console.exe
P="$(wslpath -w "$PWD")"
"$G" --path "$P" res://tests/protagonist_body_proof.tscn
# 换输出目录时在 -- 后面传 --out=<绝对路径>
"$G" --path "$P" res://tests/protagonist_body_proof.tscn -- --out="$(wslpath -w "$PWD/docs/proof/protagonist-body")"
```

写完后自动退出 0，控制台每个文件一行 `[proof] ... (OK)`。

| 文件 | 看什么 |
| --- | --- |
| `01_front.jpg` | 正面 idle：灰白低多边形晶体人形，竖直站立，面朝镜头，脚下有完整影子 |
| `02_three_quarter.jpg` | 四分之三视角，手臂、腿和头部的棱面都清楚 |
| `03_side.jpg` | 侧面，身体笔直、双脚踩在地面上 |
| `04_shadow_run.jpg` | `SHADOWS_ONLY` 播 `run` 第 0.4 秒并俯视地面：镜头里看不到身体，只看到奔跑的人影 |

## 材质与影子

`red_crystal_crystal.gdshader` 写 `ALPHA`（alpha 混合），混合材质不参与阴影贴图，
所以只用它当 `material_override` 时物体投不出影子。`actors/player/shadow_body.gd`
给每个网格铺一层不透明的灰白色 `StandardMaterial3D` 当 `material_override` 负责阴影，
再把 `MI_ProtagonistCrystal` 放进 `material_overlay` 负责外观；游戏里网格是
`SHADOWS_ONLY`，玩家只会在光线下看到这层影子。

无界面检查（11 个网格、24 根骨骼、idle/run 循环、1.75 m 身高、脚在 0 m）：

```bash
"$G" --headless --path "$P" res://tests/protagonist_body_test.tscn
```

最后一行是 `PROTAGONIST BODY: ALL PASSED (0 failed)`。
