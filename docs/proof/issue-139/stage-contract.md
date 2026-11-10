# 巨像正式主流程

新增 `maps/realms/sloth_boss.tscn`，由同一生成器在 Boss provider 存在时生成。`RealmStage.boss_room=true` 只创建真实 Boss，注入 arena/player/boons；不沿用旧放大士兵或旧据点流程。Boss HP 与三种实际攻击均乘注入 difficulty_multiplier。巨像 setup 时朝向玩家，保证从入口能读出蜷缩躯干；背甲仍随脊柱动作。继承失去恐惧时，巨像预警音与预警几何同时关闭，实际招式和伤害保持。

Boss 真实 Health 死亡清理后，Stage 累加 deprivations、立即关闭本地 Rest / 加速 148 bpm、更新玩家独立碎片组件，再发 `realm_defeated(stage)` 供 run 控制器即时记录碎裂。这时不发完成、不弹赐福、不解锁出口；在导航可达地面生成真实 PsycheShardPickup。走近、无 WORLD 阻挡并真正获得碎片后才发一次 `stage_cleared(stage)`，打开出口。重复伤害 / 回调不重复结算。已持有该碎片的重访调试场景不会生成无法拾取的重复碎片。

所有领域的 Geometry 可提供 `player_spawn()` / `exit_position()` / `spawn_points()`；Sorrow 的 `set_player(player)` 与敌人 `arena` 注入已支持。默认入口 `(0,0.1,16)`，出口 `(0,0,-20)`，Boss `(0,0,-8)`。Stage 不读取 RunDirector、也不保存全局状态；campaign 模式发 exit_requested 由其推进。

真实 Godot 测试 `tests/realm_boss_stage_test.tscn` 18 / 18：Boss/导航/难度/HUD，继承预警剥夺与静音，死亡去重、累计剥夺、Rest / 时钟、真实可达拾取、取得独立能力、拾取前后出口门控。普通房间 `tests/realm_stage_test.tscn` 27 / 27 回归保持。三张 `boss-stage-*.png` 为正式生成地图第一人称原生实拍并逐张查看，展示 Boss 战、物理碎片拾取与 Rest 熄灭后继续前进。取证使用自动位置设置，未宣称人工通关；硬件听感未在 Dummy 音频驱动下验收。
