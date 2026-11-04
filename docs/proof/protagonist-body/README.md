# 玩家晶体身体证明

玩家的影子身体从 Soldier 换成了灰白色的晶体人形（和红晶体敌人同一套模型）：`actors/player/protagonist_body.tscn`
实例化 `assets/models/characters/red_crystal_enemy_animated.glb`（缩放 0.9，身高 1.75 m），
材质用 `assets/materials/protagonist_crystal_material.tres`（`MI_ProtagonistCrystal`）。
素材登记见 [ASSETS.md](../../ASSETS.md)。

身体手里拿着玩家当前那把枪：`RightHand` 骨上挂一个 `BoneAttachment3D`，按 `WeaponData` 换
`assets/models/weapons/` 里的模型（步枪 `ak.gltf`、霰弹枪 `shotgun.glb`、狙击枪 `sniper.glb`）。
`AnimationTree` 把身体分成两截：腿在 `idle` / `run` 之间按速度混合（0.15 s），
上半身（`Spine` 及以上，过滤掉 `Hips` 和腿骨）一直保持 `Aiming_1` 的举枪瞄准姿势，
开火时在这层上叠一小段 `Shooting_1_1` 的后坐。换枪、开火信号来自 `Head/Camera3D/Weapon`。

七张图由 `tests/protagonist_body_proof.tscn` 在真实窗口里拍（`--headless` 没有渲染器，拍不出东西），
2026-11-03，Godot 4.7.2，Vulkan / Forward+：

```bash
G=/mnt/d/Godot/Godot_v4.7.2-stable_win64_console.exe
P="$(wslpath -w "$PWD")"
"$G" --path "$P" res://tests/protagonist_body_proof.tscn
# 换输出目录时在 -- 后面传 --out=<绝对路径>
"$G" --path "$P" res://tests/protagonist_body_proof.tscn -- --out="$(wslpath -w "$PWD/docs/proof/protagonist-body")"
```

写完后自动退出 0，控制台每个文件一行 `[proof] ... (OK)`。截图实例化整个 `player.tscn`（影子身体要从
父节点找到 `Weapon`），并隐藏 `Head`，否则第一人称的枪模型会停在画面里。01–03 是正常投影，
04–05 把主光抬到接近头顶、镜头俯视地面，这样贴地的人影不会被低角度的光拉成一长条；
06–07 是三格特写拼图（`Image.blit_rect` 拼一张，顺序固定为步枪 / 霰弹枪 / 狙击枪），
俯视那张在脚下临时铺了一块深色板，白模型才不会被浅色地面糊掉。

| 文件 | 看什么 |
| --- | --- |
| `01_front.jpg` | 正面：灰白低多边形晶体人形，双手在胸前举枪，枪口朝镜头，脚下有完整影子 |
| `02_three_quarter.jpg` | 四分之三视角：步枪在右手，枪托贴肩、枪口朝前，左臂托在前护木下 |
| `03_side.jpg` | 侧面：枪身水平、枪托贴在右肩前、枪口朝前，手压在枪身下面 |
| `04_shadow_run.jpg` | `SHADOWS_ONLY` 奔跑并俯视地面：镜头里看不到身体，只看到带枪奔跑的人影 |
| `05_shadow_idle.jpg` | 同上，站着的人影，枪从身前伸出去 |
| `06_guns_side.jpg` | 三格上身特写，左→右步枪 / 霰弹枪 / 狙击枪：核对枪口方向、握把是否在右手、枪托是否贴肩 |
| `07_guns_top.jpg` | 同样三格，俯视：核对枪在两只手之间怎么放 |

## 枪的摆放

`shadow_body.gd` 的 `GUNS` 表给每把枪记一个模型空间的握把点（`grip`）：步枪取网格实测的握把
形心 `(0.03, -0.08, 0)`，霰弹枪和狙击枪是导出时"握点在原点"，取 `(0, 0, 0)`。放枪时先把模型绕 Y
转到枪口朝 -Z，再平移，使 `grip` 正好落在右手骨往前 5 cm（手掌心）的位置；枪托因此正好在右肩前。

步枪 `ak.gltf` 的枪口在模型 **-X** 端、枪托在 +X 端，所以这里要 **-90°** 才能把枪口转到 -Z；
写成 +90° 会把枪托甩到前面、枪口顶到脸上（第一版就是错的）。`06_guns_side.jpg` 就是为核对这个加的。

**左手够不到前护木，这是模型姿势的限制**：这套 23 个剪辑里没有"枪托抵肩、左手托护木"的标准姿势，
`Aiming_1` 实测两手骨骼相距 28.5 cm（X 向）、前后只差 2 cm，左臂已经伸直（肩到手腕 0.43 m，
臂长 0.46 m）。枪口朝前时前护木在握把前约 25 cm，离左肩 0.74 m，左臂够不到。所以现在左手落在
机匣 / 扳机护圈侧面，从侧面（`03`、`06`）看两只手都压在枪身上；要让左手真正托在前护木，得另做
一条瞄准剪辑或给左臂加 IK，两者都超出"影子身体拿枪"这次改动。

## 材质与影子

`red_crystal_crystal.gdshader` 写 `ALPHA`（alpha 混合），混合材质不参与阴影贴图，
所以只用它当 `material_override` 时物体投不出影子。`actors/player/shadow_body.gd`
给每个网格铺一层不透明的灰白色 `StandardMaterial3D` 当 `material_override` 负责阴影，
再把 `MI_ProtagonistCrystal` 放进 `material_overlay` 负责外观；游戏里网格是
`SHADOWS_ONLY`，玩家只会在光线下看到这层影子。手里那把枪的网格用同一套材质和投影设置。

无界面检查（11 个身体网格 + 枪、24 根骨骼、idle/run 循环、腿与上半身的分支、
右手上的枪与枪口方向、枪贴着右手、开火后坐、换枪、1.75 m 身高、脚在 0 m）：

```bash
"$G" --headless --path "$P" res://tests/protagonist_body_test.tscn
```

最后一行是 `PROTAGONIST BODY: ALL PASSED (0 failed)`。
