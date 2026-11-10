# Issue 105：第一人称完整身躯验证

基于 #104 `3f7e161`，使用 Godot 4.7.2 stable（`ed1daf0bf`）Windows Forward+，从 WSL 启动。本目录是拆分后 #105 阶段重新执行的日志和原生截图，没有复用整包提交的测试结果。#104 的最后追加提交只清理其历史日志空白，不改变本次运行代码。

同一个原始 24 骨角色提供胸腹、双臂、双腿与完整人影；头部保持仅投影。右手跟随真实手枪握把，左手平时自由抬起，挥刃时跟随短刃。头骨眼位同时供逻辑射线和渲染相机使用，跑动腿动画不改变它。原始 GLB、预切碎片和主角材质保持不变。

裂缝统一黑色，沿原非共面晶体边生成。0 级恢复原资源，1 级左腕细缝，2 级扩展到手背/胸锁骨，3 级胸臂剥落，4 级覆盖全身并加深。派生网格保留原几何与蒙皮；原预切碎片代替相应部位，避免重叠。`Events.sin_defeated(count)` 为剧情提供表现接口；本阶段不实现四心魔流程或跨关计数。

导入、五套行为测试及两套原生取证全部通过，无 ERROR/WARNING；逐项结果见 [results.json](results.json)，完整日志就在本目录。

| 验证入口 | 实际覆盖 |
| --- | --- |
| `protagonist_body_test` | 原 24 骨/11 网格与蒙皮；头部投影策略；待机/跑动腿；0°、−65°、−82°、55°、85° 持握；逻辑眼位与渲染眼位一致；动画眼位稳定；挥刃跟手 |
| `body_awareness_test` | 56 个原碎片；逐实例材质；五级区域；原部位与碎片不重叠；0 级资源恢复；事件、调试输入与退出断连 |
| `crystal_seams_test` | 原 67 网格几何/骨索引/权重/UV 保留；共面边剔除、真实折面边保留；法线/切线允许 Godot 再量化 0.0002 误差 |
| `dash_test` | 真实 Player 冲刺、瞄准及换弹交互回归 |
| `buff_run_test` | 原有完整小关/Boss流程及实际场景替换，验证无迟到骨骼回调错误 |

原生截图由生产 Player 与武器节点直接渲染。已逐张查看水平、低头、五级关键帧、两帧行走、人影及组合挥刃：截图中心未被手臂或武器遮住，低头可见躯干和腿，两帧腿姿不同，人影完整。组合图让手枪与短刃的生产时钟以同一步长推进，58° ADS 下展示 4 级裂缝和真实挥刃中段。

- [水平双手与手枪](body_forward.png)、[低头躯干](body_torso.png)、[纯白全身](body_0.png)
- [左腕 1 级](body_1.png)、[2 级胸部](body_2.png)、[3 级](body_3.png)、[4 级](body_4.png)
- [行走 A](body_walking_a.png)、[行走 B](body_walking_b.png)、[完整人影](body_shadow.png)
- [普通挥刃](body_melee.png)、[4 级＋ADS＋挥刃](body_ads_melee_4.png)、[向上瞄准](body_aim_up.png)
- [外部全身审计](body_external.png)、[外部 4 级](body_full_4.png)。仅这两张外部审计临时显示原头部；第一人称始终是头部仅投影。
- [静态材质证据](body-fracture/README.md)：近距离检查原左腕、胸锁骨与全身晶体接缝，不能替代生产第一人称证据。

限制：原模型只有手骨，没有独立手指骨，保留原手型与自然人体比例，不宣称新增握拳手指动画。身体保留原跑动剪辑，未新增方向步态。这里只验证列出的受影响场景；最终 #106 核对生产源码与既有 43 场景通过版本一致，并对最终清理与新增测试定向复测。

复现（在项目根目录，`godot` 为同版本可执行文件）：

```sh
godot --headless --editor --import --quit --path .
godot --headless --path . res://tests/protagonist_body_test.tscn
godot --headless --path . res://tests/body_awareness_test.tscn
godot --headless --path . res://tests/crystal_seams_test.tscn
godot --headless --path . res://tests/dash_test.tscn
godot --headless --path . res://tests/buff_run_test.tscn
godot --path . res://tests/protagonist_body_proof.tscn
godot --path . res://tests/body_fracture_proof.tscn
```

源码、原始资源及本目录证据的 SHA-256 见 [SHA256SUMS.txt](SHA256SUMS.txt)，在项目根目录运行 `sha256sum -c docs/proof/issue-105/SHA256SUMS.txt`。
