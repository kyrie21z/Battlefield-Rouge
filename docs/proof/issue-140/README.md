# #140 恐惧之境：深渊、凝视与三种晶体异化敌人

## 实现与可玩入口

独立可玩场景：`res://tests/fear_realm_bench.tscn`。使用真实 Player、Health、Hitbox、导航、赐福管理器与生产敌人；WASD 移动、鼠标射击/瞄准、V 挥刃、Shift 冲刺、F6 重开。场景节点通过引用注入，不读取 RunState。

- `environments/fear/realm.gd`：4 米主桥、2.7 米侧桥、四个 7 米侧岛，连接入口 `(0,0,16)` 与出口 `(0,0,-20)`。三个旋转桥面位于 z=5/0/-5；侧路保持可通行。桥外无隐藏地板、无护栏。黑色深渊中缓慢扫过巨大紫色光锥。
- 深渊在 y=-12 以下触发真实 Health 死亡事件；`environmental_fatal` 明确绕过冲刺免疫、护盾与免疫，不使用复活传送或直接伪造结算。
- `FearRealmEnemy.variant`：Watcher/Trembler/Faller，共用原 24 骨、11 块人形晶体模型；死亡使用原 56 片碎屑的真实刚体及凸碰撞。原 GLB 不改动。
- 窥视者：悬浮、针状四肢、尖锐单晶面；1.6 秒蓄力，9° 内无遮挡直视持续 0.15 秒才取消。普通硬直不能代替对视。未打断发出 27 伤、55m/s 实体弹。
- 战栗者：高频局部抖动；每次向玩家瞬移最多 4 米，保留 2.2 米距离；路径、落点胶囊、地面与坡度均检查。受击和瞬移留下真实骨骼姿态的紫色虚影。0.55 秒后发出 13 伤实体弹。
- 坠落者：弓背、反向膝关节和跟随手骨的倒钩晶爪；7.5 米内开始 0.85 秒蓄力、16m/s 扫掠扑击 0.38 秒，单次爪击 22 伤。落点附近桥块 0.85 秒预警后旋转 90°，产生实际可跌落缺口，2.4 秒后恢复。

这些数值是可玩默认值，不是最终平衡结论。

## 验证

Godot 4.7.2，Forward+，Windows 原生 Vulkan / RTX 4060 Laptop。

```text
godot --headless --path <repo> --fixed-fps 60 res://tests/fear_realm_test.tscn
godot --path <repo> --fixed-fps 60 res://tests/fear_realm_proof.tscn
```

`mechanics.log` 的 29 项断言全部通过，记录实际机制断言：连续地面支撑、桥外真空、实际相机对视、WORLD 遮挡、真实弹丸伤血、瞬移墙体/落地拒绝、虚影、扑击和翻转后的物理缺口、带冲刺免疫及 500 护盾进入深渊仍真实死亡、56 刚体碎裂与回收。不是对实现常量的镜像测试。

原生截图均来自同一生产模型与几何，并已打开查看。`01-abyss-bridges.png` 是连通布局，`02-crystal-variants.png` 为三敌轮廓材质，`03-physical-fall-trap.png` 为真实竖起桥块与缺口。截图模式只冻结玩家/敌人的 AI 和调整摄影机；陷阱仍运行实际物理。截图不代替手感验收。

## 集成边界

主路线由 `tools/gen_zones.py` 与 RealmStage 集成；本提交交付独立生产场景与局部 API。Stage 应使用 `spawn_points()`、`player_spawn()`、`exit_position()`，为敌人注入 `arena`，并烘焙 NavigationRegion。`set_deprivation(true)` 仅关闭本地预警，不移除真实危险。全局进度、跨关继承与 HUD 由 #141 / #146 统一接入。
