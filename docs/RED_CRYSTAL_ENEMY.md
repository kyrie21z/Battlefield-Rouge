# 红晶体敌人（Red Crystal Enemy）

SUPERHOT 的 Unity 版里 `EnemyMimic` 预制体那套低模敌人：11 件网格、24 根骨的标准人形链、
纯色红晶体材质（原材质就没有贴图）。这里是把本机游戏资源解码出来、转成 glTF 的产物，
素材登记见 [ASSETS.md](ASSETS.md)，截图见 [`proof/crystal-enemy`](proof/crystal-enemy/README.md)。

**现在的状态：素材入库，还没接进 `actors/enemy/`。** 要当敌人外观用，另开一个 PR 改
`actors/enemy/enemy.tscn` 的 `model_scene`，别在这个 PR 里顺手改玩法。

## 文件

| 文件 | 内容 | 顶点 / 三角 |
| --- | --- | --- |
| `assets/models/characters/red_crystal_enemy_static.glb` | 11 件合并成 1 个网格，绑定姿势已烘焙，无骨骼 | 5,155 / 2,211 |
| `assets/models/characters/red_crystal_enemy_rigged.glb` | 11 个蒙皮网格 + 1 个 `Skeleton3D`（24 骨） | 5,155 / 2,211 |
| `assets/models/characters/red_crystal_enemy_parts.glb` | 11 个刚性部件，每件枢轴在自己那根主骨上 | 5,155 / 2,211 |
| `assets/materials/red_crystal_material.tres` | `StandardMaterial3D` 近似版，颜色取自原 Unity 材质 | — |
| `assets/materials/red_crystal_crystal.gdshader` | Godot 4 空间着色器：菲涅尔边缘 + 自发光 | — |
| `assets/materials/red_crystal_material_shader.tres` | 上面着色器的现成 `ShaderMaterial` | — |

部件名（`.glb` 里的节点名与网格名）：

```
GEO_m_head  GEO_m_torso  GEO_m_hips
GEO_m_upper_arm_L / _R    GEO_m_forearm_L / _R
GEO_m_thigh_L / _R        GEO_m_shin_L / _R
```

Unity 里原本是 `m.head`、`m.torso`、`m.hips`、`m.upper_arm.L/R`、`m.forearm.L/R`、
`m.thigh.L/R`、`m.shin.L/R`。`GEO_` 前缀和点号换下划线是导出时加的。

## 规格（实测，不是估的）

| 项目 | 值 |
| --- | --- |
| 总包围盒（glTF 轴，米） | X 1.687 × Y **1.948** × Z 0.394（X 是 T-pose 双手展宽） |
| 脚底 | y = 0.0001（贴地） |
| 顶点 / 三角 | 5,155 / 2,211（11 件之和，三个版本一致） |
| 骨骼 | 24 根，绑定姿势是 T-pose |
| 面朝 | −Z（Godot 默认前方），单位是米 |
| 法线 | 平面法线（Unity 原数据如此），低模的棱面要保留，别开 smooth |
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

`EnemyBody / rig / root` 三根是原预制体的容器骨（`rig` 带 −90°X 的 Z-up → Y-up 校正），
不要删：它们是大半条链的父级，删了姿势会散。

## 怎么用

**当摆件 / 敌人尸体**（`static`）：1 个 `MeshInstance3D`，拖进场景就行。

**当会动的敌人**（`rigged`）：带 `Skeleton3D`，可直接挂 `AnimationPlayer`；骨骼是标准人形命名，
用 Godot 的 Retarget（Bone Map 预设 `Humanoid`）能吃 Mixamo 一类的外部动画。源动画也按 T-pose
做参考最省事。

**打碎 / 断肢**（`parts`）：11 件各自带枢轴，逐件换成 `RigidBody3D` 飞出去最合适：

```gdscript
const PARTS := preload("res://assets/models/characters/red_crystal_enemy_parts.glb")

func shatter(at: Vector3) -> void:
	var root := PARTS.instantiate()
	root.position = at
	add_child(root)
	for piece in root.get_children():
		var rb := RigidBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = piece.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		cs.shape = shape
		rb.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = piece.mesh
		rb.add_child(mi)
		rb.global_transform = piece.global_transform
		rb.linear_velocity = (piece.global_position - at).normalized() * randf_range(2.0, 5.0) + Vector3.UP * 2.0
		add_child(rb)
	root.queue_free()
```

**想更接近原版晶体感**：把 `red_crystal_material_shader.tres` 挂到 `material_override` 上，
或者改 `.tres` 里那几个 `shader_parameter/*`（`base_color`、`rim_strength`、`emission_strength`）。

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

纯 Python 校验（不需要 Godot）：

```bash
# 重跑导出，产物应与仓库里的 GLB 逐字节一致
python tools/crystal_enemy/export_crystal_to_glb.py --root <SH_Data 目录>
# 关节世界矩阵 + 按 glTF 蒙皮公式重算包围盒
python tools/crystal_enemy/check_glb.py assets/models/characters/red_crystal_enemy_rigged.glb \
       tools/crystal_enemy/_out/_joint_expect.json
# 三角形缠绕与顶点法线是否同向（内外翻检查，一致率应为 1.000）
python tools/crystal_enemy/check_normals.py assets/models/characters/red_crystal_enemy_*.glb
```

`--root` 指 Unity 版的 `SH_Data/`（里面有 `resources.assets` 和 40 个 `sharedassetsN.assets`），
也可以用环境变量 `SUPERHOT_DATA`。导出依赖 UnityPy（实测 1.25.4）和 numpy；`unitymesh.py`、
`glb_writer.py` 是本目录里手写的纯 Python 实现，不进 pip。内部校验文件
（`_joint_expect.json`、`_export_report.json`）落在 `tools/crystal_enemy/_out/`，已在 `.gitignore` 里。

## 技术要点

1. **UnityPy 跨文件指针**：`PPtr.deref()` 不能把 `env` 当参数传，否则 `m_FileID ≠ 0` 的外部引用
   会炸在 `Environment has no attribute 'externals'`；要传空参走 `self.assetsfile`。
2. **顶点流按 16 字节对齐**：`m_VertexData` 分多个 stream，每个 stream 块的起始地址要 16 字节对齐
   （例：`m.head` 每顶点 24+12+4=40 字节，数据总长比 `n×40` 多 8 字节就是这个对齐造成的）。
   不补这个对齐，权重和骨骼索引整块错位，表现是「骨骼看着对，模型被拉成怪物」。
3. **蒙皮公式**：`世界顶点 = (root⁻¹ · boneWorld · bindPose) · v`，`root_inv` 在**前**。写反过一次，
   模型散成一地。
4. **左手 → 右手**：Unity 是左手 Y-up +Z 前，glTF/Godot 是右手 Y-up −Z 前。统一 `z' = −z`、
   四元数 `(x, y, z, w) → (x, y, −z, −w)`、三角环绕反向，逆绑定矩阵 `IBM' = S · IBM · S`
   （`S = diag(1,1,−1,1)`）。glTF 的 `MAT4` 是列主序，写 IBM 时必须转置。
5. **UV 没导出**：原材质 `_MainTex` 的 `m_PathID = 0`（没贴图），导 UV 没意义。
6. **`parts` 是刚绑**：每件只绑到第一根骨。小腿和前臂原来有 2–3 根骨混合，所以逐件飞出时会有
   不到 1 cm 的姿势差；要完全精确就播 `rigged` 的骨骼。
7. **`parts` 的法线别多转置一次**：顶点进骨骼局部空间是 `v·B0ᵀ`，法线对应的是 `n·B0⁻¹`
   （行向量右乘**逆矩阵**，不是逆的转置）。写成 `B0⁻ᵀ` 不会报错，但 `parts` 整件会暗一档，
   `check_normals.py` 的一致率掉到 0.29–0.98。`static` 走的是另一条路径（`inv(R).T` 之后
   又 `.T` 转回来），所以没被一起带错——这也是当初只看 `static` 的 1.000 会漏掉它的原因。

## 已知限制

* 只有敌人本体，没带枪。`PistolEnemy`、`ShotgunEnemy`、`KatanaPickup` 是另外的预制体。
* 只有一套姿势（T-pose 绑定姿势）。游戏里的动作来自 Unity 的 Animator 控制器，本包不含动画。
* 材质是近似：原版是自写的 `"MAIN"` 前向着色器（相位闪烁、FOV 补偿、局部雾），这里用
  `baseColor + emission + 菲涅尔边缘` 复刻观感，颜色数值是原材质里的真值。
* 没有 UV / 贴图，原材质本来就没有。
* 许可未确认，见 [ASSETS.md](ASSETS.md) 的登记和待办。
