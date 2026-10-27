# Battlefield Rouge

第一人称科幻射击肉鸽。枪感与本局构筑靠拢《Deadzone Rogue 2》。小关先把守卫清掉，再用锤砸据点；完美打击会加快这一下。增益一局 3 次：开局前 1 次，两个小关结束各 1 次；小关 2 和 Boss 进场不选；Boss 后不选。死亡后从头开始。

设计以 [docs/MVP_Scope.md](docs/MVP_Scope.md) 和 [docs/Cut-001b.md](docs/Cut-001b.md) 为准（课程：腾讯游戏学堂《AI游戏进化论》EP.04）。验收是 AC-01 至 AC-08。临时默认：完美窗口 ±150ms，普通锤 +8%，完美 ×1.5。

**现在能玩的构建：** `maps/zone_1.tscn`（4 个守卫）和 `maps/zone_2.tscn`（6 个守卫）是清守卫 → 用锤砸据点建筑 → 插旗（AC-01、AC-03）。`maps/boss.tscn` 是 Boss 关：1 个大敌人加 6 个小敌人，城市核心开局就能砸，占满胜利，阵亡失败（AC-02）。三把枪（突击步枪、霰弹枪、狙击枪，滚轮切换，狙击枪是 2×/4×/8× 的镜）和三把近战（匕首、斧、太刀，V 挥砍、Q 切换）都能玩。三派九增益与 3 次选择已接入（AC-04、AC-08）：开局前 1 次 + 两个小关结束各 1 次；小关 2 和 Boss 进场不选；Boss 后不选。（原为小关 1 前、后；小关 2 前、后；Boss 前，共五次。）自身护盾按 G，任意技能卡解锁。增援和冲击波还没做。

- 引擎：Godot 4.7.2（Forward+）。用编辑器导入本目录的 `project.godot`。
- 当前操作：WASD 移动，Shift 冲刺，空格跳，左键开火，右键开镜（狙击枪开镜后是 2×/4×/8× 的镜），**滚轮切换枪**（突击步枪 → 霰弹枪 → 狙击枪，各枪弹匣独立；**开镜时滚轮改成换倍率**），R 换弹，V 近战挥砍，Q 切换近战（匕首 → 斧 → 太刀），G 护盾（任意技能卡解锁），E 挥锤（站到据点建筑旁，清完守卫后才有效，节拍条的标记进入金色区间是完美打击），F3 显示占点调试条（含配置文件路径），Esc 释放鼠标，点击窗口重新锁定鼠标。增益界面按 1–3 或点击选择；结算界面按 R 或点按钮重新开始。
- 九增益：枪械、刀具、技能各三张，每次每派一张，可专精或混搭、重复叠加。前三次界面覆盖全部九张。危险弹匣、子弹收藏家、反击护盾分别提供空仓爆炸、挥刀弹反收藏、挡伤后反击。刀具卡乘在三把近战上。数值沿用用户已有试玩默认，完整触发和限制见 [当前九增益](docs/Buff当前实现.md)，接入取舍见 [ADR 0006](docs/adr/0006-nine-buffs-and-entry-choices.md)，截图与新验证见 [AC-04 / AC-08 Proof](docs/proof/ac-04-ac-08/README.md)。
- 占点三个数（窗口 ±150ms、普通 +8%、完美 ×1.5）：`zone/capture_config.tres`。三把枪的数：`weapons/{rifle,shotgun,sniper}.tres`；近战三把的数：`weapons/melee/*.tres`（都是试玩默认值，不是锁定设计）。
- 无界面检查：`godot --headless --path . res://tests/capture_hammer_test.tscn`、`res://tests/boss_test.tscn`、`res://tests/melee_test.tscn`、`res://tests/weapons_test.tscn`、`res://tests/buff_run_test.tscn`、`res://tests/combat_traits_test.tscn`、`res://tests/school_icons_test.tscn`。剪影证明：近战 `godot --path . res://tests/melee_proof.tscn -- --out=docs/proof/melee`（要窗口），枪的姿势帧在 `docs/proof/guns/`。
- 复现一局（AC-07）：`fixtures/` 里是命名起点 FX-001（新开一局）和 FX-002（Boss 起点）。游戏里用 `godot --path . -- --fixture=FX-002` 从该起点开始，F3 调试条显示起点和种子，死亡后重开回到同一起点。复现检查：`godot --headless --fixed-fps 60 --path . res://tests/fixture_test.tscn`，机器人把每个起点打几遍并比较哈希，要加 `--fixed-fps 60`。做法和限制见 `docs/adr/0005-reproducible-runs.md`。
- 模型都是导出/拼出来的，不是原件：`tools/export_melee_models.py` 处理近战，`tools/export_gun_models.py` 把 `tools/gun_sources/` 里的霰弹枪和狙击枪 FBX 规整成第一人称模型（握点在原点、枪口朝 -Z）。重新导出见 `docs/ASSETS.md`。
- 当前战区：`maps/zone_1.tscn`、`maps/zone_2.tscn`、`maps/boss.tscn`，由 `tools/gen_zones.py` 生成，改布局请改脚本再重新生成。
- 文档：`docs/GDD.md`、`docs/Core_Loop.md`、`docs/Priority_Backlog.md`、`docs/bible/`；架构：`ARCHITECTURE.md`；术语：`GLOSSARY.md`；决策：`docs/adr/`；待优化：`TODO.md`；贡献：`CONTRIBUTING.md`。
