# 主角握姿

`protagonist_hands.blend` 展示黑晶手枪双手握姿和意志短刃的左手握姿。手掌和五指是独立的低多边形体块，左手用 `BladeGrip` 形态键切换。枪柄、短刃和原骨架来自项目已有资产。

`author.py` 保存各指节的截面和定位。持枪手型与 S2 握把共用 0.30 的斜率，约为 16.7°。更新握姿时，请以实物道具为参照。 `calibration.json` 记录 Godot 测得的手骨到实体道具握点的变换，以及原手骨的蒙皮绑定变换。脚本保留前臂和腕部权重，沿腕部切除原手型，再将新手型蒙皮到原手骨。游戏继续使用原骨架和动画。

```sh
blender --background --factory-startup --python-exit-code 1 --python tools/protagonist_hands/author.py
```

脚本生成本目录的 Blender 文件和 `assets/models/characters/protagonist_hands.glb`。前臂网格用于正常身体，独立手部网格用于第三、四级裂痕的手部碎片。用 `tests/protagonist_body_proof.tscn` 原生渲染检查腰射、开镜、两侧握柄及挥刃画面。
