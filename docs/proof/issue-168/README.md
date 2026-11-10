# #168 四系 GPU 晶屑

生产四系 Enemy（及继承的领域 Boss）用 `sin_type` 标识；Health 的真实 `after_damage` 才产生受击/死亡碎片。Hitbox 同步传播真实位置和方向，友伤、免疫及重复死伤不产生反馈。破绽、延爆、撞墙和泪晶使用既有 BoonManager 事件；同一命中不会由 Hitbox 和 Enemy 各发一次。

暖琥珀低重力慢飘、冷紫细长定向碎片、绯红余烬及墙面两秒灼环、苍蓝晶滴和扩散水环。全部为原创代码生成的八面体平面法线网格；无第三方素材。`CrystalBurst.prepare` 在 RealmStage 播种前准备 48 个 GPU emitter，战斗只借还。Godot 的 GPUParticles3D 构造会消耗全局 RNG，因此不能在命中时临时 new，也不能在池耗尽时 fallback 创建。满池跳过纯视觉效果，随场景完整释放。

## 验证

- Godot 4.7.2，`crystal_feedback_test.tscn`：28 项通过、0 失败、无引擎错误；四系真实受击/死亡、友伤、重复死伤、真实接触、全局随机序列、池上限、暂停、场景退出与复用。
- `crystal_feedback_bench.tscn`：Windows NVIDIA RTX 4060 Laptop、Vulkan Forward+，1280×720，固定模拟步长60；12 emitter / 528 GPU 碎片，121帧实测 p50 5.558 ms、p95 5.742 ms、最大177.507 ms。
- 原生图 `four-crystal-bursts.png` 已打开检查：四种配色/几何/速度差异与环波实际可见。
- 初版 RNG 检查失败已保留原始日志；fixed_seed 单独不足，改播种前预建池后通过。

## 边界

首次爆发存在177.507 ms尖峰，不能承诺所有帧不掉帧；这不是已通过的广泛性能验收。截图使用独立展示台，真实敌人接线由行为测试覆盖，不冒充人工完整战役试玩。

顿帧由 UI 的 BoonHitstop 接既有事件，排除 fixture、暂停、死亡；该小提交由集成负责人添加到同一 issue 的 PR。泪晶拾取的真实 `sorrow_tear_collected` 事件由 #179 提供，#168 接收端已兼容；切碎事件无需该依赖。
