# #168 四系 GPU 晶屑

生产四系 Enemy（及继承的领域 Boss）用 `sin_type` 标识；Health 的真实 `after_damage` 才产生受击/死亡碎片。Hitbox 同步传播真实位置和方向，友伤、免疫及重复死伤不产生反馈。破绽、延爆、撞墙和泪晶使用既有 BoonManager 事件；同一命中不会由 Hitbox 和 Enemy 各发一次。

暖琥珀低重力慢飘、冷紫细长定向碎片、绯红余烬及墙面两秒灼环、苍蓝晶滴和扩散水环。全部为原创代码生成的八面体平面法线网格；无第三方素材。`CrystalBurst.prepare` 在 RealmStage 播种前准备 48 个 GPU emitter，战斗只借还。每色12个；预先配置44粒子容量、材质、网格和梯度，受击改amount_ratio避免重建GPU缓冲。房间加载前四帧以透明粒子及环波预热渲染管线，此窗口跳过纯视觉反馈、不影响伤害；正式借出时显示并重启。Godot 的 GPUParticles3D 构造会消耗全局 RNG，因此不能在命中时临时 new，也不能在池耗尽时 fallback 创建。满池跳过纯视觉效果，随场景完整释放。

## 验证

- Godot 4.7.2，`crystal_feedback_test.tscn`：28 项通过、0 失败、无引擎错误；四系真实受击/死亡、友伤、重复死伤、真实接触、全局随机序列、池上限、暂停、场景退出与复用。
- `crystal_feedback_bench.tscn`：Windows NVIDIA RTX 4060 Laptop、Vulkan Forward+，1280×720，固定模拟步长60；性能默认不截图，`-- --capture`是独立截图模式。
- 最终无截图采样：12 emitter / 528 GPU碎片，121帧 p50 5.556 ms、p95 6.265 ms、最大9.954 ms；首爆同为9.954 ms，12次spawn合计CPU8.083 ms。原始逐帧值在 `performance.json`；前一次无截图独立进程为p95 6.387 ms、最大11.645 ms。
- 加载预热58帧单列：p95 11.506 ms、最大22.910 ms。这些是新引擎进程实测，不声称已清空驱动shader cache。
- 原生图 `four-crystal-bursts.png` 已打开检查：四种配色/几何/速度差异与环波实际可见。
- 初版 RNG 检查失败已保留原始日志；fixed_seed 单独不足，改播种前预建池后通过。

## 边界

**更正原性能解释**：旧 `native.log` 的177.507 ms和预热后的 `capture-with-readback.log` 145.432 ms均在采样窗口第75帧执行了同步GPU截图读回与PNG写盘。它们是受采集影响的结果，不能归因为首次战斗爆发。已把采图和计时拆成独立进程，保留旧日志，没有删除离群帧来改善统计。当前战斗采样窗口全部低于16.67 ms；加载预热仍有22.910 ms峰值，且不承诺其他硬件或更复杂全关卡一律不掉帧。截图使用独立展示台，真实敌人接线由行为测试覆盖，不冒充人工完整战役试玩。

顿帧由 UI 的 BoonHitstop 接既有事件，排除 fixture、暂停、死亡；该小提交由集成负责人添加到同一 issue 的 PR。泪晶拾取的真实 `sorrow_tear_collected` 事件由 #179 提供，#168 接收端已兼容；切碎事件无需该依赖。
