# 红晶体敌人（Red Crystal Enemy）

一套低模敌人素材：11 件网格、24 根骨的标准人形链、23 个人物剪辑、56 片按部位预切好的碎屑，
纯色红晶体材质（源材质本来就没有贴图）。几何、骨骼、动画和碎屑由本项目的美术导出管线产出
（源工程在仓库外，不随仓库分发），规格与校验方式见下文。
素材登记见 [ASSETS.md](ASSETS.md)，实机与出图记录见 [`proof/crystal-enemy`](proof/crystal-enemy/README.md)。

**现在的状态：素材入库，还没接进 `actors/enemy/`。** 要当敌人外观用，另开一个 PR 改
`actors/enemy/enemy.tscn` 的 `model_scene`，别在这个 PR 里顺手改玩法。

## 文件

| 文件 | 内容 | 顶点 / 三角 |
| --- | --- | --- |
| `assets/models/characters/red_crystal_enemy_static.glb` | 11 件合并成 1 个网格，绑定姿势已烘焙，无骨骼 | 5,155 / 2,211 |
| `assets/models/characters/red_crystal_enemy_rigged.glb` | 11 个蒙皮网格 + 1 个 `Skeleton3D`（24 骨） | 5,155 / 2,211 |
| `assets/models/characters/red_crystal_enemy_parts.glb` | 11 个刚性部件，每件枢轴在自己那根主骨上 | 5,155 / 2,211 |
| `assets/models/characters/red_crystal_enemy_animated.glb` | 11 个蒙皮网格 + 1 个 `Skeleton3D`（24 骨）+ 23 个剪辑 | 5,155 / 2,211 |
| `assets/models/characters/red_crystal_enemy_shards.glb` | 56 片碎屑，按 `SHARD_m_<部位>_<序号>` 分组命名 | 5,155 / 2,211 |
| `assets/materials/red_crystal_material.tres` | `StandardMaterial3D` 近似版，颜色取自源材质 | — |
| `assets/materials/red_crystal_crystal.gdshader` | Godot 4 空间着色器：菲涅尔边缘 + 自发光 | — |
| `assets/materials/red_crystal_material_shader.tres` | 上面着色器的现成 `ShaderMaterial` | — |
| `assets/materials/red_crystal_crystal_shard.gdshader` | 碎屑版着色器：同一套观感，菲涅尔边缘光与高光压低 | — |
| `assets/materials/red_crystal_material_shard.tres` | 上面碎屑着色器的现成 `ShaderMaterial` | — |

部件名（`.glb` 里的节点名与网格名）：

```
GEO_m_head  GEO_m_torso  GEO_m_hips
GEO_m_upper_arm_L / _R    GEO_m_forearm_L / _R
GEO_m_thigh_L / _R        GEO_m_shin_L / _R
```

源工程的部件名是 `m.head`、`m.torso`、`m.hips`、`m.upper_arm.L/R`、`m.forearm.L/R`、
`m.thigh.L/R`、`m.shin.L/R`。`GEO_` 前缀和点号换下划线是导出时加的，方便在 Godot 里
按固定名字取件。

## 规格（实测，不是估的）

| 项目 | 值 |
| --- | --- |
| 总包围盒（glTF 轴，米） | X 1.687 × Y **1.948** × Z 0.394（X 是 T-pose 双手展宽） |
| 脚底 | y = 0.0001（贴地） |
| 顶点 / 三角 | 5,155 / 2,211（11 件之和，三个版本一致） |
| 骨骼 | 24 根，绑定姿势是 T-pose |
| 面朝 | −Z（Godot 默认前方），单位是米 |
| 法线 | 平面法线（源数据如此），低模的棱面要保留，别开 smooth |
| 材质原值 | `_Color = (0.7206, 0, 0)`、`_EmissionColor = (0.5221, 0, 0)`、`_SpecColor = (1, 0.186, 0)` |

各件三角数：torso 424、forearm.L 320、forearm.R 256、shin.R 187、thigh.R 169、shin.L 166、
upper_arm.L 165、upper_arm.R 143、hips 130、thigh.L 129、head 122。

骨骼顺序（Godot 里 `Skeleton3D` 打印出来的）：

```
EnemyBody, rig, root, Hips,
LeftUpLeg, LeftLeg, LeftFoot, LeftToe,
RightUpLeg, RightLeg, RightFoot, RightToe,
Spine, Chest, LeftShoulder, LeftArm, LeftForeArm, LeftHand,
Neck, Head, RightShoulder, RightArm, RightForeArm, RightHand
```

`EnemyBody / rig / root` 三根是容器骨（`rig` 带 −90°X 的 Z-up → Y-up 校正），
不要删：它们是大半条链的父级，删了姿势会散。

## 动画（23 个剪辑）

`red_crystal_enemy_animated.glb` 比 `rigged` 多一套 `animations`：23 个人物剪辑，导入后挂在
`AnimationPlayer` 上，名字和 glTF 里一致（30 fps 导出，每个剪辑 20 条轨道：位移 / 旋转 / 缩放）。

| 剪辑 | 时长 | 用途 |
| --- | --- | --- |
| `idle` | 1.967 s | 待机，呼吸和轻微晃动 |
| `walk` | 1.000 s | 行走循环 |
| `WalkForward` | 1.000 s | 直线前进 |
| `WalkBackCut` | 1.000 s | 后退 |
| `WalkFwdTurnLeft` | 1.000 s | 边走边左转 |
| `WalkFwdTurnRight` | 1.000 s | 边走边右转 |
| `run` | 0.567 s | 直行跑 |
| `RunLeft` | 0.533 s | 左跑 |
| `RunRight` | 0.533 s | 右跑 |
| `Aim` | 0.250 s | 举枪瞄准 |
| `Aiming_1` | 0.033 s | 瞄准姿势的过渡帧 |
| `Shoot` | 0.375 s | 单发开火 |
| `Shooting_1_1` | 0.300 s | 连射循环 |
| `ShootAndReload` | 1.250 s | 射击 + 换弹 |
| `death` | 0.967 s | 后仰倒地 |
| `punch` | 1.000 s | 出拳 |
| `kick` | 1.767 s | 踢腿 |
| `jump` | 1.667 s | 跳跃 |
| `flip` | 1.200 s | 前滚翻 |
| `CowerIdle` | 0.233 s | 平民抱头待机 |
| `CowerGlance` | 0.533 s | 抱头张望 |
| `EnterCower` | 0.500 s | 进入抱头 |
| `ExitCower` | 0.967 s | 退出抱头 |

全部是**原地动画**，不含根位移：`run` / `WalkForward` 不会自己往前走，位移交给代码
（`move_and_slide`、`NavigationAgent3D`，或者直接改 `position`）。剪辑按本模型的 24 根骨导出，
源骨架上的手指骨没有对应关节，忽略。

## 碎裂碎片（56 片）

`red_crystal_enemy_shards.glb` 是 11 个部位预切好的刚性碎屑，合计 56 片。坐标已经摆成绑定姿势
（T-pose）下的整身，每片**枢轴在自己质心**，节点名按部位分组：

| 部位 | 碎屑 | 部位 | 碎屑 |
| --- | --- | --- | --- |
| `head` | 10 | `thigh_L` / `thigh_R` | 7 / 9 |
| `shin_L` / `shin_R` | 4 / 6 | `hips` | 3 |
| `forearm_L` / `forearm_R` | 5 / 5 | `upper_arm_L` / `upper_arm_R` | 3 / 3 |
| `torso` | 1 | **合计** | **56** |

命名是 `SHARD_m_<部位>_<序号>`，例如 `SHARD_m_head_0` … `SHARD_m_head_9`。`torso` 只有 1 片是
有意的：躯干本来就是一整块，切细要另做切割面，反而会露出内壁。56 片加起来 5,155 顶点 /
2,211 三角，就是本体那批面切开的结果，没有额外几何。

用法是把碎屑做成刚体、按部位替换掉动画模型上的同名网格。完整实现（初速度、复位、自检）见
`tools/crystal_enemy/anim_shatter.gd`，下面是同一套流程的最小版：

```gdscript
const SHARDS := preload("res://assets/models/characters/red_crystal_enemy_shards.glb")
const MAT_SHARD := preload("res://assets/materials/red_crystal_material_shard.tres")

## 读成 {部位: [{mesh, xf}]}，实例化一次缓存起来
func load_shards() -> Dictionary:
	var groups := {}
	var lib := SHARDS.instantiate()
	for mi in lib.find_children("*", "MeshInstance3D", true, false):
		var rest := String(mi.name).trim_prefix("SHARD_m_")
		var part := rest.substr(0, rest.rfind("_"))
		if not groups.has(part):
			groups[part] = []
		groups[part].append({"mesh": mi.mesh, "xf": mi.transform})
	lib.free()
	return groups

## 把一个部位换成碎屑刚体；碎屑是 T-pose 模型空间导出的，要乘骨骼增量
func shatter_part(model: Node3D, skel: Skeleton3D, bone: String,
		groups: Dictionary, part: String, parent: Node3D) -> void:
	var b := skel.find_bone(bone)
	var delta := skel.get_bone_global_pose(b) * skel.get_bone_global_rest(b).affine_inverse()
	for s in groups[part]:
		var rb := RigidBody3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = (s["mesh"] as Mesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var cs := CollisionShape3D.new()
		cs.shape = shape
		rb.add_child(cs)
		var vis := MeshInstance3D.new()
		vis.mesh = s["mesh"]
		vis.material_override = MAT_SHARD
		rb.add_child(vis)
		rb.global_transform = model.global_transform * delta * (s["xf"] as Transform3D)
		parent.add_child(rb)
```

部位到骨的对应（`anim_shatter.gd` 里的 `PART_BONE`）：`head`→`Head`、`torso`→`Spine`、
`hips`→`Hips`、`upper_arm_L/R`→`LeftArm`/`RightArm`、`forearm_L/R`→`LeftForeArm`/`RightForeArm`、
`thigh_L/R`→`LeftUpLeg`/`RightUpLeg`、`shin_L/R`→`LeftLeg`/`RightLeg`。

碎屑单独用 `red_crystal_material_shard.tres`：同一套着色器，把菲涅尔边缘光和高光压下来。碎片体积小、
掠射角占比高，用本体的参数会让高光爆掉，碎裂瞬间看起来像「变亮变色」，和本体接不上。

## 怎么用

**当摆件 / 敌人尸体**（`static`）：1 个 `MeshInstance3D`，拖进场景就行。

**会动、不用预切碎**（`animated`）：带 `Skeleton3D` + `AnimationPlayer`，`play("walk")` 就动。
骨骼是标准人形命名，用 Godot 的 Retarget（Bone Map 预设 `Humanoid`）能吃 Mixamo 一类的外部动画，
导出时按 T-pose 做参考最省事。只要骨骼不要动画就用 `rigged`：两份文件的网格规格一样（5,155 / 2,211）。

**按部位打碎**（`shards`）：56 片碎屑，按部位替换同名网格，见上一节。`parts` 那份 11 件的刚性部件
仍然保留：只换整块（断臂、断腿）又不想飞碎屑时更好用。

**想更接近晶体感**：把 `red_crystal_material_shader.tres` 挂到 `material_override` 上，
或者改 `.tres` 里那几个 `shader_parameter/*`（`base_color`、`rim_strength`、`emission_strength`）。
碎屑用 `red_crystal_material_shard.tres`，参数同名。

## 出图与校验

预览场（不是游戏主场景，从 `tools/` 里跑）：

```bash
godot --path . res://tools/crystal_enemy/gallery.tscn
godot --path . res://tools/crystal_enemy/gallery.tscn -- --shot=<绝对路径.png>   # 等 90 帧截图后退出
godot --path . --resolution 760x950 res://tools/crystal_enemy/views.tscn -- --out=<输出目录>   # 三版本 × 前/侧/头
```

会打印每个版本的实际结构，三个版本都应该是 `verts=5155`，`rigged` 那条是 `meshes=11 skeleton=1 bones=24`：

```
[demo] res://assets/models/characters/red_crystal_enemy_static.glb -> meshes=1 verts=5155 skeleton=0 bones=0
[demo] res://assets/models/characters/red_crystal_enemy_rigged.glb -> meshes=11 verts=5155 skeleton=1 bones=24
[demo] res://assets/models/characters/red_crystal_enemy_parts.glb -> meshes=11 verts=5155 skeleton=0 bones=0
```

动画与碎裂的预览 / 自检场是 `tools/crystal_enemy/anim_shatter.tscn`（同样不是游戏主场景）：

```bash
# 自检：只读模型和碎片库，打印实际结构，全对时退出码 0
godot --headless --path . res://tools/crystal_enemy/anim_shatter.tscn -- --check
# 有窗口：← → 切剪辑，1 爆头 2 断左臂 3 断左腿 4 全身碎裂 R 复位，左键拖动转视角
godot --path . res://tools/crystal_enemy/anim_shatter.tscn
# 出图：摆好姿势 / 碎好，等 N 帧截图再退出
godot --path . --resolution 900x1100 res://tools/crystal_enemy/anim_shatter.tscn -- \
	--anim=walk --dist=3.1 --shot=<绝对路径.png> --shotframes=78
```

`--check` 的实测输出（`[check]` 行）：

```
[check] OK 动画=23 骨骼=24 网格=11 顶点=5155 碎片=56 分组=11
```

纯 Python 校验（不需要 Godot，也不需要源工程）：

```bash
# 节点层次 + 按 glTF 蒙皮公式重算顶点位置与包围盒
python tools/crystal_enemy/check_glb.py assets/models/characters/red_crystal_enemy_rigged.glb
python tools/crystal_enemy/check_glb.py assets/models/characters/red_crystal_enemy_animated.glb
# 三角形缠绕与顶点法线是否同向（内外翻检查，一致率应为 1.000）
python tools/crystal_enemy/check_normals.py assets/models/characters/red_crystal_enemy_*.glb
```

`check_glb.py` 的第二个参数是可选的关节世界矩阵期望文件，只有在比对导出器中间产物时才需要；
单独审仓库里的 GLB 时省略即可。两个脚本只依赖 numpy。导出器的中间文件落在
`tools/crystal_enemy/_out/`，已在 `.gitignore` 里。

## 实现要点（导出器侧，只读 GLB 的人可以跳过）

1. **坐标系转换**：源工程是左手 Y-up、+Z 前，glTF / Godot 是右手 Y-up、−Z 前。统一 `z' = −z`、
   四元数 `(x, y, z, w) → (x, y, −z, −w)`、三角环绕反向，逆绑定矩阵 `IBM' = S · IBM · S`
   （`S = diag(1,1,−1,1)`）。glTF 的 `MAT4` 是列主序，写 IBM 时必须转置。
2. **蒙皮公式**：`世界顶点 = (root⁻¹ · boneWorld · bindPose) · v`，`root_inv` 在**前**。写反过一次，
   模型散成一地。
3. **顶点流按 16 字节对齐**：源数据的顶点通道分多个 stream，每个 stream 块的起始地址要 16 字节对齐
   （例：head 每顶点 24+12+4 = 40 字节，数据总长比 `n×40` 多 8 字节就是这个对齐造成的）。
   不补这个对齐，权重和骨骼索引整块错位，表现是「骨骼看着对，模型被拉成怪物」。
4. **UV 没导出**：源材质没有贴图（`_MainTex` 为空），导 UV 没意义。
5. **`parts` 是刚绑**：每件只绑到第一根骨。小腿和前臂原来有 2–3 根骨混合，所以逐件飞出时会有
   不到 1 cm 的姿势差；要完全精确就播 `rigged` 的骨骼。
6. **`parts` 的法线别多转置一次**：顶点进骨骼局部空间是 `v·B0ᵀ`，法线对应的是 `n·B0⁻¹`
   （行向量右乘**逆矩阵**，不是逆的转置）。写成 `B0⁻ᵀ` 不会报错，但 `parts` 整件会暗一档，
   `check_normals.py` 的一致率掉到 0.29–0.98。`static` 走的是另一条路径（`inv(R).T` 之后
   又 `.T` 转回来），所以没被一起带错——这也是当初只看 `static` 的 1.000 会漏掉它的原因。
7. **动画是「逐帧烘 TRS」**：23 个剪辑按 30 fps 把每根骨的 `localPosition/localRotation/localScale`
   写成 glTF `animations`，根位移在导出时丢弃（源数据把位移写在根上），所以全是原地动作。
   两个剪辑名带空格或小数点（`Aiming 1`、`Shooting 1.1`），导出时改成 `Aiming_1`、`Shooting_1_1`，
   免得 Godot 导入器再改一次名字。
8. **碎屑的枢轴和坐标系**：按部位切开后，每片的枢轴挪到自身质心、坐标摆回 T-pose 模型空间，
   所以 `SHARD_*` 节点只有平移，贴当前姿势全靠骨骼增量。切面就是部位本身的封闭面，
   没有额外补 cap；`torso` 在原数据里没有可用的切片，补成一整块。
9. **碎屑的法线要重算**：初版导出把法线穿错了矩阵，56 片的缠绕和顶点法线全部对不上
   （`check_normals.py` 一致率 0.06–0.80），但几何本身是向外的（每片的有符号体积全为正）。
   现在按缠绕重算成面积加权顶点法线，一致率回到 1.000，明暗也和本体接上了。

## 已知限制

* 只有敌人本体，没带枪。手持武器是 `actors/enemy/` 那边另接的节点。
* 动画全是原地动画：根位移已丢弃，`run` / `WalkForward` 不会自己前进，位移交给代码。
* `death` 不会真的砸到地上：倒地前那段位移在根位移里，跟着一起丢了；敌人死亡通常直接换成碎屑。
* 髋部平移基本静止（原始位移混着根位移），走路没有上下起伏；要起伏就在代码里叠一个小 sin 波。
* 碎屑按 11 个部位分组：`torso` 是 1 整块；逐片飞出时和蒙皮姿势有不到 1 cm 的差（每片只绑单骨）。
* 没有腰斩：这套碎屑是按部位分的，要把上下半身各自合成一整块，得在代码里合并部位网格。
* 材质是近似：源材质是自写的前向着色器（相位闪烁、FOV 补偿、局部雾），这里用
  `baseColor + emission + 菲涅尔边缘` 复刻观感，颜色数值取自源材质。
* 没有 UV / 贴图，源材质本来就没有。
* 来源与许可登记见 [ASSETS.md](ASSETS.md)；源工程与来源凭证在仓库外，由 Art 负责人归档。
