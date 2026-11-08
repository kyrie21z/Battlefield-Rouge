# Battlefield Rouge

普通启动现在先自动播放 Pride 开场：点击画面或按 Enter / 空格逐句推进，右上角可跳过。确认“开始行动”后先淡黑并显示“加载中…”，再加载第一关、淡入原来的开局增益三选一；关卡资源读取失败时可重试或退出，见 [开场加载卡住修复](docs/proof/loading-stall/README.md)。之后继续两小关与 Boss，死亡重开不重播开场。双击原有的本地“启动游戏.cmd”即可看到；编辑器请用 F5 运行项目。直接运行战区场景、指定 fixture 或使用 `--skip-opening` 会跳过开场。接入说明见 [ADR 0009](docs/adr/0009-pride-opening-bootstrap.md)。

游戏方向见 [Creative Vision](docs/CREATIVE_VISION.md)：抽象精神世界里的 FPS 肉鸽，头顶的皇冠 Pride 引导玩家逐层消灭心魔，最后与 Pride 和解；第一层是 Sloth（[关卡设计](docs/levels/SLOTH_LEVEL_DESIGN.md)）。下面描述的是当前原型。

**Sloth 可玩整合草稿（2026-11-08，紧凑战场修订）：** 本分支基于已合并场景备案的 main `fe0e1c9`。两小关的实际战斗核心改为 40×48 米，出生点到据点恢复旧版的 **22 / 24 米**（上一版为 103 米）；外围柱廊、云海与浮岛保留宏大尺度。Boss 使用直径 50 米的实际战斗台，外侧圣殿、巨环、钟摆和悬浮建筑作为景观。已接入守卫、增援、据点锤击、插旗冲击波、增益台、三次选卡、Boss 核心、胜负和重开。两小关分别有 7 / 11 名 Sloth 守卫；Boss 沿用原型大敌人及规则，配 11 名新小怪。披风迟滞者仍是 2 秒蓄力、最后 0.45 秒锁向的四连弹，间隔 0.18 秒、9 伤/发、40 米/秒，结束后留 1 秒反击窗口。完整巨像、休憩区与战后变化后续制作。当前战斗规则、实机图和验证见 [持续反击盾与主动敌群](docs/proof/counter-pressure/README.md)；[紧凑战场证明](docs/proof/sloth-compact/README.md)记录缩图阶段，[首次整合证明](docs/proof/sloth-integration/README.md) 保留宽场版本的历史数据。

[Sloth 场景备用预演](prototypes/sloth_scene_reserve/README.md)与[敌人备用包](prototypes/sloth_enemy_reserve/README.md)仍保留此前隔离版本的历史；本分支运行时使用 `environments/sloth/` 与 `actors/enemy/sloth/`，不依赖备用工程。

第一人称科幻射击肉鸽。枪感与本局构筑靠拢《Deadzone Rogue 2》。小关先把守卫清掉，再用锤砸据点；完美打击会加快这一下。增益一局 3 次：开局前 1 次，两个小关结束各 1 次；小关 2 和 Boss 进场不选；Boss 后不选。死亡后从头开始。

设计以 [docs/MVP_Scope.md](docs/MVP_Scope.md) 和 [docs/Cut-001b.md](docs/Cut-001b.md) 为准（课程：腾讯游戏学堂《AI游戏进化论》EP.04）。验收是 AC-01 至 AC-08。临时默认：完美窗口 ±150ms，普通锤 +10%，完美 ×2.0。

**现在能玩的构建：** `maps/zone_1.tscn`（7 个守卫）和 `maps/zone_2.tscn`（11 个守卫）是清守卫 → 用锤砸靠后的据点 → 插旗。据点开放后，后方每 10 秒刷 2 只增援，场上最多 5 只；插旗冲击波让小怪逃向后方刷怪点后消失。旗旁增益台按 F 才选通关增益（AC-01、AC-03、AC-04）。`maps/boss.tscn` 是 Boss 关：1 个大敌人加 11 个小敌人。Boss 活着时核心不能砸；打倒后一锤击碎，没有增援、冲击波和增益台，然后胜利，阵亡失败（AC-02）。三把枪（突击步枪、霰弹枪、狙击枪，滚轮切换，狙击枪是 2×/4×/8× 的镜）和三把近战（匕首、斧、太刀，V 挥砍、Q 切换）都能玩。三派九增益与 3 次选择已接入（AC-04、AC-08）：开局前 1 次仍是弹窗；两个小关结束各 1 次改在增益台；小关 2 和 Boss 进场不选；Boss 后不选。（原为小关 1 前、后；小关 2 前、后；Boss 前，共五次。）自身护盾按 G，任意技能卡解锁。增援节奏在 `zone/reinforcement_config.tres`，见 [ADR 0007](docs/adr/0007-reinforcements-shockwave-pedestal.md)。

- 引擎：Godot 4.7.2（Forward+）。用编辑器导入本目录的 `project.godot`。
- 当前操作：WASD 移动，Shift 冲刺（5 米，2 格充能，每 1.5 秒回 1 格），空格跳，左键开火，右键开镜（狙击枪开镜后是 2×/4×/8× 的镜），**滚轮切换枪**（突击步枪 → 霰弹枪 → 狙击枪，各枪弹匣独立；**开镜时滚轮改成换倍率**），R 换弹，C 主动投掷危险弹匣（对应增益解锁，最后一发打空时立即获得一枚，无需等待换弹完成），V 近战挥砍，Q 切换近战（匕首 → 斧 → 太刀），G 护盾（任意技能卡解锁），E 挥锤（站到据点建筑旁，清完守卫后才有效，节拍条的标记进入金色区间是完美打击），F 在小关插旗后的增益台领取通关增益，F3 显示占点调试条（含配置文件路径），Esc 释放鼠标，点击窗口重新锁定鼠标。开局增益界面按 1–3 或点击选择；结算界面按 R 或点按钮重新开始。
- 九增益：枪械、刀具、技能各三张，每次每派一张，可专精或混搭、重复叠加。前三次界面覆盖全部九张。危险弹匣、子弹收藏家、反击护盾分别提供最后一发耗尽时立即获得、按 C 主动投掷的爆炸弹匣，挥刀弹反收藏，以及持续蓄伤、满盾自动/再次 G 手动释放的 7 米反击波。刀具卡乘在三把近战上。危险弹匣最多持有一枚，无备用弹也能在打空时获得；投速 24 米/秒，投出后 1.5 秒引信，离敌人 0.5 米内或碰墙、地面提前引爆。爆炸半径 6 米，每层伤害为 120→60（1.5 米内全伤、6 米边缘半伤），配强化的橙色波前与厚环。数值是可调试玩默认，完整触发和限制见 [当前九增益](docs/Buff当前实现.md)，本次决策见 [ADR 0010](docs/adr/0010-empty-magazine-blast.md)，验证与截图见 [空仓即得弹匣证明](docs/proof/empty-magazine/README.md)；[主动弹匣与扩大盾波](docs/proof/active-buffs/README.md) 和 [AC-04 / AC-08 Proof](docs/proof/ac-04-ac-08/README.md) 保留历史版本事实。
- 图形 HUD：右下 `AbilityBar` 使用 G 护盾、V 近战和 C 弹匣方形槽。C 未解锁时锁定；有危险弹匣增益但未持有时暗态显示 `0/1`，最后一发打空获得弹匣后立即亮起显示 `1/1`，按 C 投出后回到 `0/1`。弹匣不占用护盾的角标；生命、冲刺充能、武器面板及上方目标与增益图标栏沿用当前布局，见 [空仓即得弹匣证明](docs/proof/empty-magazine/README.md)。
- 紫盾反馈：G 开盾显示有内外轮廓的分层紫色盾缘，中心保留瞄准视野；挡伤时亮闪，反击卡同时显示蓄能。成功反击时，第一人称双层波纹与世界中的厚波前向外扩散，配独立能量声；波前到达水平 7 米后短暂停留再淡出。反击卡开盾后无时间上限，默认容量100点，满盾自动反击、再次G可提前释放，伤害为实际吸收量×卡层数，释放后冷却8秒；破盾一击的超量部分正常扣血。未选反击卡的普通盾仍是2秒/8秒。
- 占点三个数（窗口 ±150ms、普通 +10%、完美 ×2.0）：`zone/capture_config.tres`。Boss 核心另用 `zone/boss_capture_config.tres`，每锤进度 100%。三把枪的数：`weapons/{rifle,shotgun,sniper}.tres`；近战三把的数：`weapons/melee/*.tres`（都是试玩默认值，不是锁定设计）。
- 无界面检查：`godot --headless --path . res://tests/capture_hammer_test.tscn`、`res://tests/boss_test.tscn`、`res://tests/melee_test.tscn`、`res://tests/weapons_test.tscn`、`res://tests/dash_test.tscn`、`res://tests/firing_position_test.tscn`、`res://tests/hud_test.tscn`、`res://tests/active_magazine_test.tscn`、`res://tests/shield_visual_test.tscn`、`res://tests/buff_run_test.tscn`、`res://tests/combat_traits_test.tscn`、`res://tests/school_icons_test.tscn`、`res://tests/reinforcement_test.tscn`。剪影证明：近战 `godot --path . res://tests/melee_proof.tscn -- --out=docs/proof/melee`（要窗口），枪的姿势帧在 `docs/proof/guns/`；冲刺 HUD 证明：`godot --path . res://tests/dash_proof.tscn -- --out=docs/proof/dash`（要窗口），图在 `docs/proof/dash/`。
- 复现一局（AC-07）：`fixtures/` 里是命名起点 FX-001（新开一局）和 FX-002（Boss 起点）。游戏里用 `godot --path . -- --fixture=FX-002` 从该起点开始，F3 调试条显示起点和种子，死亡后重开回到同一起点。复现检查：`godot --headless --fixed-fps 60 --path . res://tests/fixture_test.tscn`，机器人把每个起点打几遍并比较哈希，要加 `--fixed-fps 60`。指定 fixture 的测试首轮也由测试会话加载战区，避免正式启动逻辑提前加载一次。做法和限制见 `docs/adr/0005-reproducible-runs.md`，当前哈希和历史版本见 [issue #14 证明](docs/proof/issue-14/README.md)。
- 模型都是导出/拼出来的，不是原件：`tools/export_melee_models.py` 处理近战，`tools/export_gun_models.py` 把 `tools/gun_sources/` 里的霰弹枪和狙击枪 FBX 规整成第一人称模型（握点在原点、枪口朝 -Z）。重新导出见 `docs/ASSETS.md`。
- 当前战区：`maps/zone_1.tscn`、`maps/zone_2.tscn`、`maps/boss.tscn`，由 `tools/gen_zones.py` 生成，改布局请改脚本再重新生成。
- 文档：`docs/GDD.md`、`docs/Core_Loop.md`、`docs/Priority_Backlog.md`、`docs/bible/`；架构：`ARCHITECTURE.md`；术语：`GLOSSARY.md`；决策：`docs/adr/`；待优化：`TODO.md`；贡献：`CONTRIBUTING.md`。
