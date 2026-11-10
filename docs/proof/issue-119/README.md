# Issue #119：愤怒核心

实现使用真实 CharacterBody/Jolt `move_and_slide` 碰撞结果。SpiteStatus 在角色移动后读取滑移接触，只有朝向墙法线的相对速度 >6 m/s 才结算；法线 y 绝对值≥0.5 的地面/天花板不算墙。冲量期间临时开启 ENEMIES 碰撞，结束恢复原 mask。

可调默认：基础冲量8m/s，枪2.5倍、刀/冲刺3倍；冲量0.9秒；Boss仅45%冲量。撞击主目标60伤，3米内可见其他敌人30伤，主目标晕0.8秒。刀造成真实撞墙后再追加3.6米30伤熔岩爆破。刀扇形×1.5、敲钟窗口×1.4、进度×1.25。

枪为90m/s真实晶体飞弹，保留原8发/.18秒/35伤与距离衰减；一次WORLD反射后×1.6伤害。弹速Stats在公共注册时应用。冲刺按每步真实移动线段扫描半径1.3米，每个敌人仅撞击一次，再探测16个水平射线推向最近墙面。

`wall_slam` 提供真实 wall_impact 字段；地图静态碰撞不被破坏，wall_broken=false。双重技能使用wall_impact触发碎墙冲击视觉，不伪造地图破坏。

验收入口：tests/wrath_core_test.tscn，使用生产 Player、SlothEnemy、Hitbox、实际 WORLD 墙和Jolt运动。Godot 4.7.2 `--headless --fixed-fps 60`：21 项检查全部通过，零 ERROR/WARNING。完整日志见 core.log。原生视觉证据见下文，当前不宣称已完成完整人工试玩。

追加边界：贴墙首帧仍能真实触发；慢速状态将实际移动速度降到6m/s以下时不会误用未缩放意图速度伪造撞墙。接触判断读取CharacterBody真实移动速度，初始冲量按局部时间/移动倍率缩放。

原生 Vulkan Forward+ 取证：`tests/wrath_proof.tscn` 默认仅装备 #119 愤怒枪核心，在 #119 独立前缀运行，将三只生产敌人通过真实冲量推到 WORLD 墙面。`wall-slam.png` 已实际打开查看，呈现真实撞墙与猩红晶体冲击反馈；`native.log` 无ERROR/WARNING。此默认路径不使用 #120 资源。`--legendary` 参数由 #120 扩展阶段使用。

全伤组合边界：真实Wrath晶弹在发射时已乘全伤，命中上下文明确damage_scaled=true；固定撞墙伤害仍走公共raw路径。 跨系真实HP回归见#123 `boon_damage_scaling_test.tscn`。
