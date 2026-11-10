# 新领域正式房间与 HUD

`maps/realms/sloth_1.tscn`、`sloth_2.tscn` 为 `tools/gen_realms.py` 生成的新增地图；`tools/gen_zones.py` 同时调用它。旧三个地图生成结果保持逐字不变。只有本地 geometry 和 enemy provider 同时存在时才生成对应领域，避免提前引用未发布文件。

每图创建真实 Player、三种领域敌人（第一图 3 个、第二图 5 个）、WORLD 碰撞导航烘焙、门扉和 RealmHUD。清敌后暂停并提供实际 BoonPicker；选卡装备后恢复战斗，靠近门扉 3 米内且 WORLD 无阻挡时按 F 才能离开。反复交互不能推进两次。真实死亡仅发一次 player_fallen。独立打开场景时可顺序进入下一图；campaign 模式由注入控制器处理退出。

RealmHUD 复用 Vitals、Crosshair、DamageIndicator、PauseMenu，读取实际生命 / 弹药 / ADS / 冲刺 / 赐福，不假造显示值。临时单色效果驱动 screen shader；失去恐惧隐藏受击方位预警。HUD 不播放额外受击音，避免与后续脆裂音效叠加。

`configure_run(depth, deprivations, shards, hp, boons)` 接收 0-based 深度、累计剥夺、已拾取碎片、HP 与实际卡资源；不读取 RunDirector。`run_seed` 和 `difficulty_multiplier` 请在 add_child 前注入，敌人 HP / 真实弹伤随 multiplier 改变。`rerolls_remaining` 默认 2；真实重抽递减，发 `reroll_spent(stage)`。首房可调用 `offer_entry_reward()` 获取 starter 三槽候选，选择不解除门锁。`reward_selected(stage, card)`、`stage_cleared(stage)`、`exit_requested(stage)`、`player_fallen(stage, cause)` 供控制器记录。调用 `set_ordinary_impacts_enabled` 时优先使用方法，以便清理在途普通冲量。

实际验证 `tests/realm_stage_test.tscn` 27 / 27：导航有多边形；注入 HP / 深度 / 赐福 / 碎片；跨房保留 Rest 剥夺；1.5 倍 HP / damage 字段；初始卡、真实重抽、清敌奖励；远距 / 穿墙 / 重复出口拒绝；真实暂停恢复；单色 shader；死亡去重；第二图五敌。第一次 21 项测试错误地要求 headless 捕获真实鼠标，改为检查 PauseMenu 的捕获请求计数后通过；保留初始日志，没有修改游戏暂停实现来迁就测试。

`stage-combat.png`、`stage-reward.png`、`stage-exit.png` 是同一次原生 Forward+ 实际运行截屏，全部已打开检查；分别呈现第一人称战斗 HUD、真实三选一以及已解锁门扉。自动取证移动角色用于构图；战斗手感仍需玩家试玩，不用截图冒充人工通关。
