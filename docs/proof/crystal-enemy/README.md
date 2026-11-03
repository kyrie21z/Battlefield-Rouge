# 红晶体敌人证明

五个 GLB（static / rigged / parts / animated / shards）在 Godot 4.7.2 里跑通的记录。素材登记见 [ASSETS.md](../../ASSETS.md)，
模型规格和复现命令见 [RED_CRYSTAL_ENEMY.md](../../RED_CRYSTAL_ENEMY.md)。

两张场景都在真实窗口里拍（`--headless` 没有渲染器，拍不出东西），2026-11-03，Godot 4.7.2，
Vulkan / Forward+：

```bash
# 三个版本并排 + 标签
godot --path . --resolution 1600x900 res://tools/crystal_enemy/gallery.tscn -- --shot=<绝对路径>.png
# 每个版本各拍前 / 侧 / 头
godot --path . --resolution 760x950 res://tools/crystal_enemy/views.tscn -- --out=<输出目录>
```

`gallery` 等 90 帧再截图退出，控制台会打印三个版本的真实结构：

```
[demo] res://assets/models/characters/red_crystal_enemy_static.glb -> meshes=1 verts=5155 skeleton=0 bones=0
[demo] res://assets/models/characters/red_crystal_enemy_rigged.glb -> meshes=11 verts=5155 skeleton=1 bones=24
[demo] res://assets/models/characters/red_crystal_enemy_parts.glb -> meshes=11 verts=5155 skeleton=0 bones=0
```

| 文件 | 看什么 |
| --- | --- |
| `01_godot_in_engine.jpg` | 三个版本并排，姿态、大小、明暗都一致；标签是场景里的 `Label3D` |
| `02_static_views.jpg` | static 的前 / 侧 / 头；平面法线保留棱面，没有 smooth，头部是一块块切面 |
| `03_rigged_views.jpg` | rigged 的前 / 侧 / 头；绑定姿势下和 static 完全重合（顶点数 5155 一致） |
| `04_parts_views.jpg` | parts 的前 / 侧 / 头；11 件在肩、肘、膝、胯、颈留缝，逐件飞出时按这些缝断 |

`02–04` 上三个版本的明暗一致是有意看的项：`parts` 的法线要在骨骼局部空间里用 `B0⁻¹` 变换，
写错（多转置一次）时整件会暗一档、`check_normals.py` 的一致率掉到 0.29–0.98。
碎屑那 56 片是同一个坑的另一头：初版法线整体穿错矩阵，一致率只有 0.06–0.80，
按缠绕重算后碎片才和本体一个亮度。当前五份都应该是 `一致率=1.000`：

```bash
python tools/crystal_enemy/check_normals.py assets/models/characters/red_crystal_enemy_*.glb
```

## 动画与碎裂（`tools/crystal_enemy/anim_shatter.tscn`）

同一个窗口里拍的三张，2026-11-03，Godot 4.7.2，Vulkan / Forward+：

```bash
# 自检（无窗口）：打印 23 个剪辑、24 骨、56 片碎屑，全对时退出码 0
godot --headless --path . res://tools/crystal_enemy/anim_shatter.tscn -- --check
# 播 walk 拍一张
godot --path . --resolution 900x1100 res://tools/crystal_enemy/anim_shatter.tscn -- \
	--anim=walk --dist=3.1 --shot=<绝对路径>.png --shotframes=78
# 爆头 / 全身碎裂，等 14 / 16 帧再拍
godot --path . --resolution 900x1100 res://tools/crystal_enemy/anim_shatter.tscn -- \
	--anim=idle --fx=head --shot=<绝对路径>.png --shotframes=14
godot --path . --resolution 900x1100 res://tools/crystal_enemy/anim_shatter.tscn -- \
	--anim=idle --fx=all --dist=3.4 --shot=<绝对路径>.png --shotframes=16
```

自检的最后一行：

```
[check] OK 动画=23 骨骼=24 网格=11 顶点=5155 碎片=56 分组=11
```

| 文件 | 看什么 |
| --- | --- |
| `05_animation.jpg` | `walk` 第 78 帧：`animated.glb` 的骨骼动画在引擎里跑通，抬腿、摆臂、脚跟着地都正常 |
| `06_shatter_head.jpg` | 爆头：`head` 那 10 片换成刚体飞走，身子继续播 `idle`，断口正好在脖子上 |
| `07_shatter_all.jpg` | 全身碎裂：11 个部位 56 片一起炸开，碎片用 `red_crystal_material_shard.tres`，明暗和本体接得上 |

## 另一个跑法

在编辑器里打开项目，把 `tools/crystal_enemy/gallery.tscn` 或 `anim_shatter.tscn` 拖进视口
（或设成临时主场景）再按 F5，就是同一串输出。这些场景都不是游戏主场景，`project.godot` 的
`run/main_scene` 没动。
