# 领域共享玩家接口

`Player.set_realm_effect(source, values)` / `clear_realm_effect(source)` 按施法者来源管理重力、禁冲刺、换弹与冷却干扰。移动/跳跃/冲刺距离取最强约束，冷却取最长倍率；解除一个来源不清除其他敌人。可传 duration 或 owner 弱引用，暂停不走计时，死亡和来源移除清理。数值速度通过 Stats 来源修饰层注入，不读写 RunState。

真实冲刺在消耗充能之前检查约束；当冲刺过程中进入锚定场，取消当前冲刺及突进。`apply_external_impulse` 使用 CharacterBody 的 move_and_slide，墙体能挡住推挤，不直接改位置。`Health` 的 environmental_fatal 仅用于明确的深渊死亡边界，绕过无敌、吸收与取消钩子，但保留实际 HP、伤害来源、死亡和结算事件，已死对象不会重复通知。

Godot 4.7.2：共享效果测试15项通过；真实冲刺既有回归通过；赐福管道64项通过。日志见同目录三个 `*-shared.log`。共享测试验证真实2米弱化冲刺、WORLD墙碰撞、双来源解除、暂停/时限/施法者销毁、无敌和1000点盾下的深渊死亡。它不替代各领域敌人、关卡与画面的独立验收。
