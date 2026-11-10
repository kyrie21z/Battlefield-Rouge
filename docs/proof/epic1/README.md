# Epic 1 验收记录

范围：[#101](https://github.com/kyrie21z/Battlefield-Rouge/issues/101)–[#106](https://github.com/kyrie21z/Battlefield-Rouge/issues/106)，包含武器 Blender/GLB 纠偏及 #105 最新的完整第一人称身躯要求。叙事依据为 `docs/NARRATIVE_FOUNDATION.md` 8.1/8.2；不扩展后续心魔或赐福系统。

## 可复现入口

使用 Godot **4.7.2**：

```sh
godot --headless --import --path .
godot --path . res://tests/combat_bench.tscn
godot --path . res://tests/epic1_model_proof.tscn
godot --path . res://tests/combat_bench_proof.tscn
godot --path . res://tests/protagonist_body_proof.tscn
godot --headless --fixed-fps 60 --path . res://tests/fixture_test.tscn
```

测试台：左键点射、右键 ADS、R 重组、V/鼠标侧键挥刃、Shift 冲刺。依次尝试移动靶、4 米木桩、慢弹反杀、节拍敲钟；低头查看身体，0–4 或按钮切换碎裂等级。正式关卡仅监听 `Events.sin_defeated(count)`，不把原型小关通关数当作已实现的心魔进度。

## 模型与图片

[models.png](models.png) 是 Godot Windows Forward+ 原生渲染的五栏模型展示，包含手枪侧面、四分之三、四块绽放，以及短刃两种视角。Blender 源文件、生成器和逐对象尺寸/面数/原点/SHA-256 在 [模型目录](../../../tools/epic1_models/README.md)。没有下载 SUPERHOT 素材。

尺寸采用最新文字规格，模型按多视角设计稿重建。当前创作要求允许增加必要面数；实际源多边形与导出三角形分别记录于模型 manifest。源多边形均为三角形或四边形，全部 Shade Flat。原人体与预切片保留原始文件，使用原 24 骨动画和主角材质。身体裂缝遵循当前创作要求：沿晶体真实接缝、统一黑色，等级递进不依赖彩色或发光。

| 模型 | 文字规格尺寸 | 源多边形 | 渲染三角形 |
| --- | --- | --- | --- |
| 黑晶手枪 | 长 220 × 高 135 × 宽 32mm | 120 | 180 |
| 意志短刃 | 长 400 × 刃宽 40 × 厚 15mm | 45 | 70 |

| 原生画面 | 检查内容 |
| --- | --- |
| [基础持枪](body_forward.png)、[ADS](ads.png)、[四块绽放](bloom.png) | 单手视野、切面高光、重组部件 |
| [低头 Level 0](body_0.png)、[Level 4](body_4.png) | 原胸腹与双腿、真实晶面黑缝 |
| [步态 A](body_walking_a.png)、[步态 B](body_walking_b.png)、[投影](body_shadow.png) | 原骨架动画与完整人影 |
| [快捷挥刃](body_melee.png)、[ADS＋挥刃＋Level 4](body_ads_melee_4.png) | 持握与组合状态的视野 |
| [材质近景](body-fracture/README.md) | 原接缝提取与黑缝宽度；此组为 T 姿态，不用于证明第一人称姿态 |

第一人称截图使用生产 Player 和测试台，展示姿态的截图会暂停移动或直接推进武器动画，因此只证明对应画面。伤害、实际输入、弹反、占点与整局流程由独立回归测试验证。截图不替代操作者的视觉和手感验收。

## 验证边界

Godot **4.7.2.stable.official.ed1daf0bf**，Windows Forward+ / Vulkan，RTX 4060 Laptop GPU。完整回归 **43/43 场景通过**，最终模型更新后复测 8 个受影响场景：`obsidian_pistol`、`weapons`、`mind_blade`、`melee`、`gun_feel`、`combat_bench`、`protagonist_body`、`body_awareness`。逐场退出码、耗时和结果见 [results.json](validation/results.json)，[validation/](validation/) 保留完整日志。最终导入与上述测试日志无 `ERROR`、`WARNING` 或失败断言；并非只凭退出码判断。

覆盖真实 35/55 伤害、点射与重组边界、ADS、0.45m 前冲、弹反归属及反杀、节拍与 Boss 钟面可达性、死亡/暂停/换场、G/C/F 保留功能、旧按键迁移和三关流程。几何测试核对 GLB 哈希与尺寸；裂缝测试逐顶点验证原三角位置和骨骼绑定不变，并排除共面/近共面剖分边。可用 `sha256sum -c docs/proof/epic1/SHA256SUMS.txt` 核对本次源码、模型与证据。

### Fixture 与同机 main 对比

基线是 `dfb49a1388e61a813cff1f26bda10f23b4bffd88`，在独立工作树、同一引擎与机器实际运行。[基线日志](validation/fixture_base.log) 与 [当前日志](validation/fixture_test.log) 均归档。主种子各重复两次，哈希严格一致；额外种子均无超时。

| Fixture / seed | main 哈希 / 结果 | 本次哈希 / 结果 |
| --- | --- | --- |
| FX-001 / 1001 | `a1bb290e0dc25f8c` / 胜利，2166 ticks | `fa067b58e9d95c8a` / 阵亡，2293 ticks |
| FX-001 / 1002 | `c7e573a3bfe2d38a` / 胜利，2218 ticks | `56b75555f7cc9277` / 胜利，2524 ticks |
| FX-002 / 2002 | `6ae040f6fd0e10ae` / 胜利，810 ticks | `ad3703cd93d3073e` / 胜利，878 ticks |
| FX-002 / 2003 | `2ee02df836fa7b07` / 胜利，740 ticks | `8a58f623826f08aa` / 胜利，887 ticks |

原型三枪三刀一锤迁移改变伤害、弹药、武器时序、眼位和敲钟输入，fixture bot 也迁移为真实 V 键挥刃及对应导航/朝向。原日志精度保持五位小数，未放宽一致性比较，另补了额外种子的非超时断言。FX-001 主种子结果由胜利变为阵亡，需要作为平衡变化审查；确定性通过不代表旧难度或玩家手感保持不变。

### 资产与流程边界

原 24 骨角色没有独立手指骨，保留原掌形并求解腕部持握位置，未另造握拳模型。横移、倒退和跳跃沿用现有 idle/run 动画。心魔进度尚未接入：`sin_defeated(count)` 只提供视觉接口，跨关持久等级由未来心魔流程驱动。人形投影完整，第一人称武器自身仍关闭投影。

截图与自动输入验证已完成，未把它们写成操作者手动试玩结果。

待 Kyrie 审查美术/手感、受保护文件、删除与 fixture 变化后按仓库流程合并。
