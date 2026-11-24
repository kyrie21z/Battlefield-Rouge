# ADR 0018：四领域编排与独立碎片能力

状态：按 Epic 3 issues #138–#146 与用户关于碎片的明确答复实现。

四领域并列。每局以独立 RNG 对四种身份洗牌，固定两间战斗房与一间 Boss 房；HP 与实际伤害倍率只按当前深度 `1 + 0.18 × depth` 增加。每间普通房清敌发真实赐福选择，首房额外提供动作核心三选一；重抽余额在本局内共享。

`RunDirector` 是新增组合根，与既有 `RunState` 同属 `autoload/` 的状态拥有者。它持有领域排列、进度、死亡历史与跨房快照；`RealmStage` 通过显式注入接收种子、深度、赐福与碎片，再向角色注入敌人、约束和伤害倍率。方向仍为组合根 → zone → actors/components；角色不读取 RunDirector/RunState。旧 RunState、旧三图及 fixtures 保留用于已有回归，只有正式入口启用新流程。

Boss 死亡先累计对应剥夺、发一次 `Events.sin_defeated(count)`；真实碎片拾取后才打开出口，避免第四 Boss 后漏掉碎片。每次新 Player 都恢复原有白晶模型的黑色接缝碎裂级别，皇冠亮度按 `0.5 × 2.4^count` 增强。四座 Boss 完成后进入实际白色返程长廊，终局演出由 Epic 4 接续。

用户明确选择“拾取后启用独立碎片能力，普通机制仍受剥夺”。因此沉睡脱战恢复不重亮休息区；警觉暴击/反应加成不恢复预警；锋芒的独立受击反震与第三次直接命中脉冲不恢复普通武器击退；温润的独立屏障不恢复普通减伤、无敌盾或缓释。Health 与 Enemy 分别提供独立吸收/冲量接口，防止通过共享普通通道意外解除剥夺。

跨房保存 HP、赐福、四枚碎片、屏障余额与恢复冷却、锋芒蓄力/冷却和沉睡脱战计时；不会利用换房重置余额。死亡重开清除本局状态并保留次数/深度/死因，完成终局后禁止回到死亡循环。持久化局外成长由 #152 接续。

验证分层：各领域独立真实攻击/物理/原生渲染；组件剥夺与碎片交互；RunDirector 的 96 seed 无重复分布、四阶段累计、死亡去重和真实新 Player 恢复；正式十二房流程与原有回归。原生截图不等同于人工手感或平衡验收。

## 2026-11-11：暂固定恐惧开局并修复试玩流程

用户要求本轮先固定顺序、第一关仍为恐惧，后续再恢复随机。因此正式战役当前默认恐惧→怠惰→愤怒→悲伤，仍为十二房；`randomize_realm_order=false`，原种子洗牌作为可恢复分支继续测试。这是本轮试玩覆盖，不改写上述最初随机编排的历史决策。

恐惧击杀回调曾逐次生成56个凸碰撞形状，引发秒级停顿；现在在加载时缓存，不减少原碎片数量。深渊除Area外增加相对高度-12米判定，沿用不可护盾吸收或复活的环境致死；HUD显示明确死因与重试按钮。门扉增加可读的实体门框/半透明门面及屏幕方向距离提示，仍需通关奖励或Boss碎片后、近距离无遮挡交互，不自动跳关。

## 2026-11-11：Boss反馈与可恢复坠落（#205）

用户追加“掉下去直接死改为扣血30”，覆盖上一节对玩家的致死默认。恐惧每次坠落现在扣30点实际生命并返回最近稳定静态平台，落点有实体阻挡时检查入口安全位；扣至0生命时仍正常死亡。Area及-12米高度检测保留，防重避免一次坠落反复扣血，不消耗或触发护盾反击，也不让短暂无敌抵消这项固定代价。敌人和其他明确致死边界不变。

审判之瞳自身的碎片原来仍重复烹制凸碰撞，改为复用同一56片缓存；昂贵准备移到加载时，完整碎片/领域剥夺/真实拾取与出口保留。狂暴尖塔新增有锁向预警的三轮五弹齐射和有地面预警的三点晶刺，保留1.5秒反击窗口及掩体/跳跃/离圈应对；不通过增血加强。悲伤脚下外扩波与潮波统一蓝色无光照发光材质，原伤害/减益时机不变。默认值和原生验证见[本轮证明](../proof/realm-balance/README.md)，具体难度仍待真人试玩反馈。

## 2026-11-11：恢复随机顺序并补正式领域受击反馈（#207）

用户现在明确要求“改回随机关卡顺序”，因此覆盖本页前面的临时固定默认：正式新局恢复种子控制的四领域洗牌，每领域两战斗房加Boss、深度倍率及领域剥夺保持；相同种子可复现，也允许不同局偶然得到同一排列。`randomize_realm_order=false`只保留给专门恐惧诊断，不能再写成正式默认。

旧HUD的红边未进入新的RealmHUD，本次以注入Health的独立控件补齐实际扣血反馈，0.55秒淡出、中心透明、无敌/护盾完全吸收不触发、死亡清除；它不揭示敌人方向，不恢复恐惧剥夺的预警能力。用户确认悲伤背景短促枪声站立时也有，检查定位雨底中规律性共鸣和4秒循环接缝，替换为连续滤波雨声并平滑重叠首尾；保留玩家真实枪声和其他六种悲伤音色。原生画面、环境音对比与边界见[本轮证明](../proof/hit-rain-shuffle/README.md)，真人主观听感仍待回听反馈。

### 同日补充：涉水质感使用原创合成

用户继续指出行走声也应为水波荡漾，提供录音作参考，随后明确选择“根据这个音频对应的改一版我们自己的，并上传PR”。因此新增原创滤波噪声/液体共鸣的步行和冲刺音色，替换此前低频敲击，复用到独立场景fallback；保持动作触发与战斗数值。参考录音只指导风格，不进入新提交或运行时，原录音本地预览另行保留。验证与原创试听见[涉水续改](../proof/sorrow-water-audio/README.md)。

## 2026-11-23：正式战役难度曲线 Phase A（#256–#261）

本节追加并覆盖本页最初「HP 与实际伤害倍率只按当前深度 `1 + 0.18 × depth` 增加」的单一标量决策；此前历史正文保持原样。正式战役现在由 `RunDirector` 输出并锁定三维深度向量：生命 `1.00/1.35/1.85/2.45`、伤害 `1.00/1.15/1.32/1.50`、节奏 `1.00/1.08/1.18/1.28`（第 1→4 层），只取深度、不取领域身份。`difficulty()` 保留为伤害倍率兼容入口；`install_stage()` 同时注入 `hp_multiplier`、`difficulty_multiplier` 与 `tempo_multiplier`，由 `RealmStage` 通过 `apply_realm_scaling()` 一次性施加给本房敌人，Boss 死后刷新剥夺时只更新存活敌人的节奏倍率，不重复乘算生命。

`Enemy` 的深度节奏位于 `realm_tempo_scale`，与 `BoonManager` 的 `boon_*_scale` 状态层正交：时钟已乘 `attack_scale` 推进的敌人与攻击体（怠惰、愤怒、悲伤及 `SpireEruption`）在时钟递减/推进处读取 `effective_attack_scale() = boon_attack_scale × realm_tempo_scale`，前摇基准保持 `boon_windup_scale`；仅按纯 `delta` 推进前摇的恐惧系（含 `FearWisp`）冷却读取 `effective_attack_scale()`、前摇读取 `effective_windup_scale() = boon_windup_scale / realm_tempo_scale`，保证两类敌人均只压缩一次、绝不出现 `tempo²`。常规移速按半强度跟随节奏，静止、冲锋与击退冲量速度不受影响。

击败怠惰后，后续所有房间的有效节奏额外 `+0.12`（例如第 3 层 `1.18 → 1.30`）；组合根注入时已折叠该加速，房间通过 `tempo_includes_sloth_haste` 防止二次叠加。沉睡碎片保留脱战 5 秒后的 `2 HP/s` 回血，但每房上限 `30 HP`，同房快照保留已用额度，`advance_room()` 只重置该额度；温润碎片屏障容量收敛为 `40`、受击后恢复延迟 `6.5s`、恢复速率仍 `6.0/s`，跨房保留余额与冷却。终局 `FlawlessDoppelganger` 提升到 `2800 HP`、弹丸 `14`、斩击 `28`；生命低于 `55%` 时阶段时钟 `1.30×`、恢复窗口 `0.85 → 0.55s`、等待间隔 `0.25 → 0.15s`，破防与 56 片碎裂演出保持。

验证新增高层集成接缝 `tests/difficulty_curve_phase_a_test.tscn`：由 `RunDirector` 在四个深度安装生产 `RealmStage`，并用真实物理帧校验怠惰加速、赐福状态正交、`FearWisp` 三轴继承、沉睡单房上限与温润跨房边界；既有 `run_director_test`、`campaign_realms_test`、`realm_tempo_wiring_test`、`slumber_fragment_test`、`tenderness_fragment_test`、`flawless_combat_test` 及 AC-07 `fixture_test` 全量回归通过。

## 2026-11-23：正式战役难度曲线 Phase B（#265–#270）

Phase B 只扩正式战役的遭遇结构，不触碰旧 `ZoneDirector`、旧三图与 `fixtures/*.tres`。`RealmEncounter` 以 `depth`、`room_index` 与领域名确定性查表，`RealmStage` 仅在 `campaign == true`、非 Boss 房且已注入深度向量时启用多波；`campaign == false` 的单房继续按旧规则一次性生成既有数量与零精英。如此既保留 `fear_realm_test` 等单房验收的原始意图，也让 AC-07 的 fixture 哈希保持零漂移。

多波刷新不消费全局随机数：波次表是常量数据，增援点按“距离玩家 `>= 10m`、`ENEMIES` 胶囊查询未占用、同波不重复”的几何筛选确定，`SorrowVisual` 滴水表现采用无随机的确定性下落动画，全部计时（含 HUD 波次提示）跟随物理步长并随暂停冻结。清房门禁统一为 `living_enemies() == 0 and not has_pending_waves()`，因此门扉与天赋球不会在增援未清完时提前解锁。

节奏层保持正交：`Enemy.elite_tempo_scale` 与 `boss_phase_tempo_scale` 只参与 `effective_attack_scale()` / `effective_windup_scale()` 的乘除，不与 `realm_tempo_scale` 或 `boon_*_scale` 相互覆写；`apply_realm_scaling()`、剥夺刷新和赐福清除只更新各自那一层。精英生命加成折叠进 `_base_max_health`，护盾始终按缩放后的 `max_health` 重算，重复晋升或重新缩放都不会二次叠加。

四界 Boss 的二阶段同样走单次状态迁移：`boss_phase == 1` 且首次 `<= 50%` 时发放一次性 `15%` 非再生晶盾、`1.20×` 阶段节拍与领域招式强化，`phase_changed(2)` 只发一次。战役护卫由 `RealmStage` 在订阅到该信号后生成，仅作为普通战斗单位存在；Boss 死亡时强制清退，不参与碎片掉落与通关门禁。`RealmHUD` 的「二阶段」徽章优先级低于瞬态「破绽」「护盾」。

Boss 控制的唯一闸口是 `BoonManager.set_status()`：硬控按 12 秒窗口 `1.0× → 0.5× → 0.25× → 免疫` 递减，`freeze_world()` 复用同一通道；软控在 `_refresh_status()` 钳位到安全下限/上限。普通怪与精英没有该分支，完美替身的沉睡共鸣与撞墙破防也不经过该闸口，因此固有破防在免疫阶段仍然有效。

验证新增统一端到端接缝 `tests/difficulty_curve_phase_b_test.tscn`：由 `RunDirector` 在真实四界生产房间覆盖 Depth 1→4 的首发密度、增援触发与安全选点、清房门禁、单房兼容、精英护盾/回复/正交节奏/血条、四界 Boss 二阶段与护卫清退，以及 `SlothColossus`、`FlawlessDoppelganger`、普通与精英目标的控制递减。既有 `campaign_realms_test`、`difficulty_curve_phase_a_test` 与 `fear_realm_test` 已对齐多波清房、精英生命/护盾和 8 点恐惧出生池；AC-07 `fixture_test --fixed-fps 60` 与 `tools/review/run_checks.sh` 保持全绿。
