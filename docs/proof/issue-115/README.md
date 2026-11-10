# 怠惰三核心与滞后

对应 #115。生产 `Weapon` / `MeleeWeapon` / `PlayerDash` 经 `BoonManager` 驱动同一 `SlothEffect`，状态节点只有计时与琥珀钟印显示。正式注册敌人和实际伤害均来自共享战斗管线。

- 首次命中之后植入，植入这一击不追溯计压；之后所有实际扣血进入 `damage_pressure`，每次追加枪击另加 25 `shot_pressure`。普通爆发是 `60 + shot_pressure + damage_pressure`；刀强制引爆将整个结果乘 1.5。
- 时钟不被后续命中刷新；爆发伤害不反馈进其他时钟。目标死亡/移除取消时钟，不虚构死后伤害。
- 非原文指定的试玩默认：基础爆发半径 3 m；光环半径 2.5 m，持续 1.25 s。各值存于 `.tres` 的 `parameters`，可直接调平衡；光环对每个目标只触发一次，起落两个光环分别记账。
- 范围伤害、光环使用共享 WORLD 视线检测与 Health 去重。玩家和同队不参与。起落位置来自真实 Dash 事件。
- 起手霸体通过 source-key `armor` modifier 表达，结束清除；当前 Player 没有可被打断的硬直机制，不额外增加无敌。敲钟以 `clock_progress ×2` 直接进入生产据点进度。
- 暂停停止计时；死亡、移除赐福和换场清理时钟/来源减速/起手修正。绝不改全局 Engine.time_scale。

行为验证场景：`tests/sloth_boon_core_test.tscn`。验证生产枪击、生产刀命中、重复伤害独立记账、1.5s 边界、暂停、遮挡/同队、实际冲刺落点、一次性 +50%、清理。Godot 4.7.2 Windows headless 实测23项全部通过，退出零警告；日志 `sloth-core.log`。独立原生 Vulkan 渲染截图 `latency-clock.png` 已人工查看：生产迟滞者头顶的刻度、剩余秒数和地面琥珀光环均可见。

全伤组合边界：滞后爆发将原始基伤+射击压力乘结算时全伤倍率，再加已实际扣血的damage_pressure；最终burst标记damage_scaled=true，避免蓄积伤害二次放大。 跨系真实HP回归见#123 `boon_damage_scaling_test.tscn`。

独立 #115 前缀复验：固定FPS会快速推进模拟计时，原退出夹具的模拟0.25秒不足以排空真实音频工作线程；verbose明确显示2个AudioStreamWAV及2个AudioStreamPlaybackWAV退出残留。夹具改为释放节点后等待真实250ms并再让一帧，普通与verbose复验均23项通过、无ERROR/WARNING/泄漏；此修正仅改变测试退出清理。
