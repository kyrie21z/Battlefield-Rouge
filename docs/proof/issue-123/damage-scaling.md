# 跨系全伤结算回归

Godot 4.7.2 headless、固定60fps，`tests/boon_damage_scaling_test.tscn` 34项检查全部通过、completed=true，无ERROR/WARNING/泄漏。包括依赖卡实际装备和真实HP数值断言，见 `damage-scaling.log`。完整基础契约见 `../issue-114/API.md`。

Wrath死斗本能在30%血量实际授予1.6全伤：普通枪56、普通刀88、实际Wrath晶弹56+撞墙96；原始18点飞弹28.8；Sorrow单层水蚀4×1.6×1.1=7.04。Sloth基伤60+射击压力25乘1.6，再加实际受伤16×惯性1.5=160，实际伤害不重复乘；回波复用96，两次共192。Fear35点新爆发即使复制已标记上下文仍重新按新基数×1.6×破绽2=112。Sorrow收到60伤后立即30/债务30，每0.5秒偿还5，反伤200%为10，即便全伤倍率已经随血量变化。

测试使用真实Player、生产Sloth CharacterBody、Hitbox和Health；伤害与冲量来自实际武器、Projectile、能力公开方法和生产计时器，没有伪造命中/死亡/墙体事件。此fixture依赖全部家族资源，因此归完整组合#123，不作为#114或前缀PR的独立测试入口。
