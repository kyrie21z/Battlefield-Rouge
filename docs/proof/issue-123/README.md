# Issue #123：六组双重共鸣

Godot 4.7.2 生产 Player / Enemy / Hitbox / Projectile / Jolt 真实运行：`tests/dual_boons_test.tscn` 135项全部通过，零 ERROR/WARNING；完整日志为 `dual-boons.log`。验证六组前置、同槽替换停用、普通特质不能冒充核心、全局双异常+40%、真实WORLD撞墙与远处破绽连锁、物理聚拢/地面贴合、债务实扣反噬、真实挥刃切泪晶、静止/ADS视线、两种冲刺区域并集、独立敌攻速与5%弹速、双泪晶，以及空地/敌碰敌不触发墙体连锁。

旧 ReloadCharge 的真实物理范围查询经 Health 入口也正确获得玩家的双异常奖励，普通环境伤害不继承该奖励；hit_before 与 Health 拦截通过同一标记避免重复相乘。

跨系全伤34项另见 [damage-scaling.md](damage-scaling.md)，惊惧泪海8项和泥沼12项原生截图断言见 [native-proof.md](native-proof.md)。所有画面已打开查看；数值与范围属于可调默认，不代表最终平衡或人工手感验收。具体合成边界见 [ADR 0016](../../adr/0016-dual-boon-composition.md)。
