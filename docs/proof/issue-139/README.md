# #139 沉眠巨像与失去怠惰

独立可玩入口：`tests/sloth_colossus_bench.tscn`。使用原始 24 骨晶体人体，3.3 倍尺寸、CowerIdle 蜷缩动作与绑定脊柱的五片琥珀背甲；死亡散成原始 56 件真实刚体碎片。原始 GLB、旧 SlothEnemy 与 fixture 均保留。

Boss 1400 HP；招式按地面震波、背甲晶块、钟摆射线轮换，每次有 1.3 / 1.55 / 1.8 秒预警与 1.4 秒恢复窗口。震波以 11 m/s 扩散至 18 m，造成 22 伤及真实扫掠推力，可跳过或由 WORLD 掩体阻挡；七枚背甲晶块分别延迟释放，18 m/s、12 伤；射线往返摆动 2.6 秒，WORLD 阻挡，10 伤 / 0.45 秒，命中施加短暂引力减速。巨像保持沉重的固定立足点，不被普通击退拖走。

真实死亡事件仅发一次，立即取消招式、关闭所有 Rest Zone、将世界时钟加速至 148 bpm，并播放程序生成的金属滴答和工业低鸣。测试台掉落真实 `PsycheShardPickup`，走近且无遮挡才获得沉睡碎片。独立脱战恢复遵从共享 fragment-contract：受伤、射击、挥刃后 5 秒，再以 2 HP/s 恢复；拾取不会重亮已剥夺的休息区。跨关持久化由后续 RealmStage / RunDirector 注入，本 Boss 不读全局局状态。

## 实测证据

- Godot 4.7.2 原生导入完成，无脚本 / 引擎错误。
- `tests/sloth_colossus_test.tscn`：25 / 25。覆盖真实 Health 命中、预警无提前伤害、暂停冻结、跳跃 / 掩体规避、七弹延迟、死亡去重与攻击取消、56 刚体、148 bpm 实际计时、Rest 全黑、真实拾取和脱战恢复。
- 共享 `tests/slumber_fragment_test.tscn`：12 / 12（见 `slumber-fragment.log`）。
- 旧 `tests/sloth_enemy_test.tscn`：64 / 64，确认旧延迟四连发 / 锚定减速 / 冲刺距离与 fixture 行为保留。
- 初次测试的测试台继承 ALWAYS 导致暂停检查失败；测试台及攻击显式 PAUSABLE 后全部通过。初始日志保留用于追溯。
- `colossus-pendulum.png`、`rest-extinguished.png` 为原生 Vulkan / Forward+ 实际运行截图，逐张打开检查。首次原生检查发现背甲遮挡躯干，收窄并绑定 Spine 后重拍；未用生成图替代玩法证据。
- 原生取证使用 Dummy 音频驱动，只验证音频节点 / 时序和无泄漏退出，不声称硬件听感验收。

## 接入

`res://actors/boss/sloth_colossus/sloth_colossus.tscn`，建议出生 `(0, 0, -8)`。注入 `arena`（具备 `set_deprivation(bool)` 的本地环境）和 `setup(player, [], board)`，并 `player.boons.register_enemy(boss)`。`realm_defeated(0)` 通知区域控制器，但角色不保存跨关数据。正式环境为 `environments/sloth/realm.gd`，设 `boss_arena = true`。
