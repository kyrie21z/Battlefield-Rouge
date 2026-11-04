# 本备用包素材来源

复用模型：基线仓库既有 `assets/models/characters/red_crystal_enemy_animated.glb`、`assets/materials/red_crystal_material_shader.tres`；规格和原来源登记见 [红晶体说明](../../docs/RED_CRYSTAL_ENEMY.md)、[主素材登记](../../docs/ASSETS.md)。还原工具从固定基线导出这些已有素材，本PR没有新增或重复红晶体GLB，也没有从origin旧工程或外部商业素材拷贝。

新增披风、孔洞、缝线、链环和壳片为本项目原创程序几何；布料shader为本项目原创代码，随项目代码供评审使用。两张JPEG为本项目Godot原生渲染截图。没有新增第三方素材或外部素材许可。修改与生成过程由Codex协助完成。

| 文件 | 来源 | SHA-256 |
| --- | --- | --- |
| `overlay/actors/enemy/sloth/sloth_visual.gd` | 本项目原创代码或原生渲染截图 | `4037e19cc1a0f14503b2328a83c297eca1f76f33aefd19bfe47b10aae50c0bc2` |
| `overlay/actors/enemy/sloth/sloth_shatter.gd` | 本项目原创代码或原生渲染截图 | `69ff9a8adf6963d3881765a4bd30ba32e6bffbba721d8623ffceb0524e4abdd2` |
| `overlay/assets/materials/sloth_cloth.gdshader` | 本项目原创代码或原生渲染截图 | `3cd8da587583e353f8d587753b34833771f6e5f91838d6411351a45362a7ca59` |
| `proof/01-lineup.jpg` | 本项目原创代码或原生渲染截图 | `7b6dde9046eb086f5ccddabd5fc4eea73548dcb2a5147a58395c883b0cf546f7` |
| `proof/02-mantle-rear.jpg` | 本项目原创代码或原生渲染截图 | `31b7b5281058197f70ab2f57e8e582bac19726ae6b7d263e96ef745655228b7a` |
| `proof/03-impact-shatter.jpg` | 本项目原创代码或原生渲染截图 | `c7f540d31bb63944a1bbd96972deeab6a02c3d02bfd24d94a62f52a1b787f599` |
| `proof/04-cloak-throw.jpg` | 本项目原创代码或原生渲染截图 | `3d567c3ca02887965b7b89cf51f66020bedeb6cb7166cc6fb8ea5250d920d5ec` |

复用已登记red_crystal_enemy_shards.glb的56片碎屑，实例着色藏青，未增加第三方资源。
