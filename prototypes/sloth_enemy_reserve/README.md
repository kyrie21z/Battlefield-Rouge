# Sloth 藏青晶体敌人 · 独立备用方案

**只作备用，不接入主游戏。** 关联[Issue #89](https://github.com/kyrie21z/Battlefield-Rouge/issues/89)与[PR #92](https://github.com/kyrie21z/Battlefield-Rouge/pull/92)。本目录由`.gdignore`隔离。正式游戏不会扫描此处的类或应用接入补丁。

本轮按用户反馈：整体藏青配色；死亡直接按最后受击点碎裂，不倒地；斗篷有更清楚的沙漏纹、肩部层次与蓄力张开/弱点窗口；去除长条悬空光杆，地面预警恢复平贴地面。底层保留原红晶体的骨骼、几何与56片碎屑素材，颜色仅在备用实例中覆盖。

[完整设计](DESIGN.md) · [实机图与验证](proof/README.md) · [来源登记](ASSETS.md)

## 还原与打开

需要Python3.10+、Git克隆和Godot4.7.2。当前基线为`438fa73e99311607bb6a5d2a0617bf59a7a7b09f`，已包含弹匣PR #88、弹道PR #91和入口修复PR #94。ZIP或缺失基线历史的浅克隆不能直接还原。

```powershell
python prototypes/sloth_enemy_reserve/prepare.py --out "../Sloth-Enemy-Review"
godot --editor --path "../Sloth-Enemy-Review" --import --quit
godot --path "../Sloth-Enemy-Review"
```

输出必须是全新目录；工具只读取固定基线，不改正式工程或用户已有备用目录。Godot未加入PATH时，请使用自己的引擎路径。

展厅：0并排，1/2/3单体，左键拖动、滚轮缩放、空格开壳/张开斗篷，B演示命中头部后的碎裂。命令行`--break=head/leg`可以对比碎裂起点。真实技能预警可运行`res://tools/sloth_enemies/ability_view.tscn -- --kind=0`。

独立副本中的战斗与检查：

```powershell
godot --path "../Sloth-Enemy-Review" res://maps/zone_1.tscn -- --skip-opening
godot --headless --fixed-fps 60 --path "../Sloth-Enemy-Review" res://tests/sloth_enemy_test.tscn
godot --headless --fixed-fps 60 --path "../Sloth-Enemy-Review" res://tests/sloth_revision_test.tscn
```

## 验证与边界

现有战斗42项、修订检查27项均通过无界面与原生检查。原生检查固定角色视角、关闭测试角色鼠标视角输入，避免窗口捕获影响测量；冲刺两组均5.093米，没有修改冲刺数值或放宽断言。原始v1的40/42记录保存在proof/history，不再作为当前结果。

仍保留宿主shader缓存/编辑器设置路径提示、无界面音频退出诊断。真人平衡、性能和跨平台仍未完成。完整Sloth关卡、巨像、休憩和战后叙事没有制作；#47/#46不因本包自动完成。

26个overlay文件与独立接入补丁组成一个相互依赖的备用实验；没有重复提交整套工程、GLB或本地启动器。入口修复PR #94已先行上传并合并，用户已确认恢复本轮上传。敌人仍只保存备用，不接入主游戏。
