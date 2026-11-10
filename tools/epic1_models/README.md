# 黑晶手枪作者文件

`generate.py` 通过真实 Blender 5.2.3 LTS 创建并导出 `obsidian_pistol.glb`；`obsidian_pistol.blend` 保留可编辑源。参考用户手枪转面图和 SUPERHOT 平面矿物质感，无复制 origin 素材。用户最终要求质感优先，面数如实报告。

模型长 220mm、高 135mm、宽/握把厚 32mm，共 120 个源三角/四边多边形、180 个导出三角形。四个物体均 Shade Flat，各自几何中心为 pivot，根原点位于握把中心。10mm 六角凹孔、阶梯枪身、斜柄切面与细暗金缝均为几何。

源坐标 Blender -Y 向前、Z 向上；导出时绕 Z 烘焙 180°，得到 Godot -Z 向前、+Y 向上。逐物体面数、尺寸和 GLB SHA-256 见 `manifest.json`。`.gdignore` 隔离作者文件。

```sh
blender --background --python tools/epic1_models/generate.py
```
