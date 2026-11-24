# Epic 1 武器作者文件

两个模型均由本目录的 `generate.py` 在真实 Blender 中创建并导出，按 `docs/assets/` 的用户转面图和各武器当前规格建模，风格参考 SUPERHOT 的硬朗轮廓与平面反光；没有复制其他游戏素材。材质为程序创建的纯色 PBR，不依赖贴图。

```sh
blender --background --python-exit-code 1 --python tools/epic1_models/generate.py -- --pistol-only
```

省略 `--pistol-only` 时会重新导出两个模型。

交付包含可编辑的 `obsidian_pistol.blend`、`mind_blade.blend`，以及 `manifest.json`。实际生成版本为 Blender 5.2.3 LTS；`.gdignore` 避免 Godot 自动处理这些作者文件。生成器覆盖自己生成的同名输出，不读写已有 `art_source/`。

| 模型 | Blender 原始三角/四边形 | GLB 三角形 | 尺寸 |
| --- | ---: | ---: | --- |
| 黑晶手枪 | 728 | 1116 | 长 200 mm，高 142 mm，宽 38 mm，握把厚 32 mm |
| 意志短刃 | 45 | 70 | 全长 400mm，刃宽 40mm，厚度 15mm，握持点到刀尖 340mm |

手枪的截面站点以毫米记录在 `PISTOL_SPEC`。S2 的枪身共用一条直顶线，两侧三角切面的起伏限制在面内。枪口有 12 mm 深的消光凹腔。闭合时前枪身盖住滑套内腔，32 面琥珀晶核藏在腔内。握把后移，手指接触带沿 0.30 的斜率保持平直。握把顶端的插接段藏在下护罩内，使握把包围盒中心与根原点重合。短刃采用 Tanto 双坡菱形截面、八角极简柄和 0.8 mm 脊线能量缝。

所有源面均为三角形或平面四边形，`use_smooth = false`。导出器独立统计最终 GLB 索引数，验证三角形数量与 Blender 三角化结果相同；逐对象统计、轴转换、尺寸和 GLB SHA-256 见 manifest。源多边形数与渲染三角形数分别报告，不混用。

源文件采用 Blender -Y 向前、Z 向上。导出时临时绕 Z 旋转 180°并烘焙网格，使 Blender 的 Y-up glTF 转换最终得到 Godot -Z 向前、+Y 向上；`.blend` 本身保留原作者坐标。手枪根原点在实际握把包围盒中心，每一重组块的局部原点在自己的几何包围盒中心。短刃握持点为根原点，厚度沿 X、刀背朝 +Y、刃口朝 -Y。

用 `tests/epic1_model_proof.tscn` 渲染模型各角度和绽放图，用 `tests/protagonist_body_proof.tscn` 渲染生产角色的腰射、ADS 和双手握持特写。
