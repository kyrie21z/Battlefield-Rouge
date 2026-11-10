# Issue #101 阶段验证

此目录来自独立堆叠分支的 #101 实际工作树，基线 `dfb49a1`。它只交付手枪模型、8 发半自动、35 伤害、ADS、回弹和晶屑；仍是常规有限储备换弹。旧近战、Q 切刀和 E 锤保留可用，完整身体尚未引入。

Godot 4.7.2 原生 Windows 引擎完成导入，无 ERROR/WARNING。16 个相关 headless 场景通过，逐场景结果见 `results.json` 和同名日志：

- `weapons_test`
- `minimap_test`
- `protagonist_body_test`
- `melee_test`
- `hammer_feel_test`
- `dash_test`
- `sloth_integration_test`
- `obsidian_pistol_test`
- `gun_feel_test`
- `hit_feel_test`
- `hud_test`
- `settings_test`
- `phase_banner_test`
- `active_magazine_test`
- `capture_hammer_test`
- `opening_boot_test`

`pistol_native_test.log` 是另外一次原生运行，验证真实 fire action 按住 24 帧跨两次冷却仍只开一枪，释放再按产生第二枪。headless 入口明确跳过鼠标捕获测试，不能代替这条原生证据。

`models.png` 由本阶段 `epic1_model_proof.tscn` 原生渲染，已目视检查侧面/四分之三视角；只有已交付手枪，没有提前混入重组、短刃或完整身体截图。模型实测 220×135×32mm，120 源多边形/180 三角形，源/GLB 收据见 `tools/epic1_models/manifest.json`。

未重跑全量 43 场景，也没有执行所有历史 UI proof。部分测试的音频退出清理增加了显式 stop/stream release 与 100ms 真实音频线程 drain；这避免 fixed-fps 只推进模拟时间时的误报。未将原集成提交的全套报告充作此阶段验证。
