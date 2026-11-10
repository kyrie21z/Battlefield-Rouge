# Issue #124：门扉、三选一与构筑试炼

Godot 4.7.2 Forward+ 原生窗口直接截图，未重绘。脚本驱动生产界面/角色/关卡输入，图片已实际打开检查；这不是对人工操作手感或最终数值平衡的宣称。

- `01-three-cards.png`、`02-replacement-confirm.png`、`03-amber-red-blue.png`：可控 BoonData 验证四系/双重主题、稀有度、数值描述和红字替换确认。
- `04-seven-door-rewards.png`：七种实际 DoorRewardMarker 组件的展示。石榴、生命、商店只提供标识组件；生产关卡目前实际发四系赐福。
- `05-production-entry.png`：真实 Zone 1 的生产候选池、暂停背景与开局核心选卡。
- `06-production-door.png`：生产 ZoneDirector 创建的真实门扉组件；为检查构图而在测试内提前调用创建入口，实际插旗触发另由完整流程测试验证。
- `07-boon-combat-bench.png`：显式调试试炼，可切换四系完整12卡及六组双重共鸣。使用生产晶体敌人、枪刃冲刺与实际伤害，不写 RunState；界面明确提示构筑跳过前置。

## 行为与复现

`tests/boon_picker_test.tscn` 检查暂停下动画、重抽消耗反馈、键盘选择、替换取消/确认、空池继续与退出恢复暂停。`tests/boon_offers_test.tscn` 检查54卡完整池、12卡/系、6双重、种子复现、战斗RNG隔离、生产两次重抽、保存与重开。`tests/boon_combat_bench_test.tscn` 遍历十套真实测试构筑、清理修饰器与注册真实靶敌。

`tests/buff_run_test.tscn` 已跑完两次两小关→Boss胜利、随后死亡→重开，核对每局三次选择、F交互开门扉选卡、同槽确认、跨关恢复、死亡清空和重抽重置。验证没有新增 ERROR/WARNING，详见本目录日志。

原生复现：

```sh
godot --path . res://tests/boon_offers_test.tscn -- --proof-dir=res://docs/proof/issue-124
godot --path . res://tests/boon_combat_bench_test.tscn -- --proof=res://docs/proof/issue-124/07-boon-combat-bench.png
```

当前保留每局三次选卡，通常不足以自然构成传奇前置后再抽传奇；调试试炼用于直接验证完整机制。没有增加房间图、商店货币或局外成长。具体决策见 [ADR 0017](../../adr/0017-boon-door-rewards.md)。

最终完整套件58/58、选卡22项及main fixture对照见 [Epic 2 集成验证](../epic-2-validation/README.md)。
