# 全身裂痕材质原生检视

本目录只验证原模型上的裂缝位置、宽度与颜色。模型保持导入时的 T 姿态，
没有第一人称相机或游戏中的骨骼姿态，因此不作为 Body Awareness 的验收证据。
第一人称可见胸腹、走动双腿、双臂和完整投影由
`tests/protagonist_body_proof.tscn` 单独验证。

来源：`assets/models/characters/red_crystal_enemy_animated.glb` 的原有 11 件网格和
24 骨骨架，原始材质参数取自 `assets/materials/protagonist_crystal_material.tres`。
运行组件：`actors/player/body_fracture.gd`、`actors/player/body_fracture.gdshader`、
`actors/player/crystal_seams.gd`。裂缝全部为黑色，不再发出彩色光。
接缝由原三角面的共享边和非共面法线提取；共面三角剖分对角线，以及法线夹角
小于约 10° 的近共面细分边，不画裂缝。
渲染副本只展开原索引以附加每个三角面的边距属性，不改变原三角位置、轮廓或
骨骼绑定。Godot 对法线/切线重新进行 16 位量化，测试按存储精度核对；原 GLB、
网格和材质保持不变，Level 0 恢复原网格资源。
后期手臂、腿部脱嵌使用 `red_crystal_enemy_shards.glb` 原预切碎片。该素材只有
一整块胸部，胸口使用原网格的少数平面切面在顶点着色器中毫米位移，未重建人体、
改变拓扑或制作新的胸部碎片。

| 图像 | 等级与镜头 | 实际观察 |
| --- | --- | --- |
| `wrist_1.png` | Level 1，左腕近景，原始 T 姿态 | 黑色细缝沿原腕部晶面接缝出现 |
| `chest_2.png` | Level 2，胸部近景，原始 T 姿态 | 黑缝沿胸口、锁骨与手背原晶面扩展 |
| `full_4.png` | Level 4，全身，原始 T 姿态 | 全身原晶面接缝裂开，细黑缝与毫米脱嵌区分后期状态 |

Godot 4.7.2 原生 Forward+ / Vulkan，1280 × 720。复现命令：

```sh
godot --path . res://tests/body_fracture_proof.tscn -- --out=res://docs/proof/epic1/body-fracture
```

必须使用实际渲染窗口；无界面模式会明确退出失败。
