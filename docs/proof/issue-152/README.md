# #152 皇冠锻造台与局外成长

独立可玩入口：`tests/meta_forge_bench.tscn`，使用带明确 demo 前缀的独立存档和 1200 / 30 试玩货币，退出清理，不改真实玩家钱包。生产界面为 `ui/meta_forge/crown_forge.tscn`，`setup(store, player=null)` 注入并发 `closed`；界面只调用交易 API，不生成结算货币。正式 GameStart 已接入该界面：首次演出走过门槛时打开一次，后续死亡重开直接到 Forge；关闭后创建第一间真实领域。MetaProgression 已注册为 autoload，RunDirector 负责收入、历史和结算。

## 当前可见默认值

| 天赋 | 等级 / 实际效果 | 每次升级价格 |
| --- | --- | --- |
| 坚韧心智 | 5级，每级+10初始基础HP，100→150 | 20×下一等级 意志碎屑 |
| 突触反射 | 3级，充能速率+10/20/25%；第3级实际充能数+1 | 30×下一等级 碎屑 |
| 专注容量 | 3级，每级弹匣+1发、重组速率+10% | 25×下一等级 碎屑 |
| 重构决意 | 2级，基础每局1次重抽→最多3次 | 35×下一等级 碎屑 |
| 不屈意志 | 1级，每局一次最终致死打击后恢复40%最大HP，占1高阶槽 | 50碎屑 + 1现实锚点 |
| 初见锋芒 | 1级，新局自带一枚可装备的基础随机核心赐福，占1高阶槽 | 40碎屑 + 2现实锚点 |
| 高阶信物槽 | 0→2容量，承载上述两项高级能力 | 3×下一等级 锚点 |

槽满、货币不足、达到上限与存档损坏都有明确禁用说明；已用/容量始终可见。默认价格和数值尚未经过人工平衡。数值经独立 `Stats` modifier 注入，不叠加重复绑定；提升冲刺上限只增加新槽，保留正在充能的计时。`apply_to_player()` 保留当前 HP，防止跨房间无条件加血。

## 控制器接入

- 以 `MetaProgression` 名注册 `autoload/meta_progression.gd`；类名为 `MetaProgressionStore`。
- 新局一次 `begin_run(unique_run_id)`；每个新 Player 调 `apply_to_player(player)`。`prepare_departure()` 在 Forge 关闭后刷新新局 HP、重抽和初始赐福，仅执行一次。先注入天赋，再恢复跨房保存 HP；新局 HP 使用 `maximum_health()`。跨房重新绑定不会恢复已经使用的不屈意志。
- `starting_rerolls()` 是每局总额度，`starting_boon(injected_rng)` 返回可装备基础核心资源或 null；仅新局调用一次并交给 BoonManager，不逐房重复发放。
- 真正的敌人击杀、房间通关和唯一 Boss 结算由 run 控制器计分。每个真实 Health 敌人死亡计 5 碎屑，每间实际清房计 20 碎屑，每个唯一 Boss 战胜计 1 锚点；信号按当前 Stage 和尸体/房间去重。死亡 / 结局通过 `settle_run(run_id, will, anchors, history)` 全额入账并写盘；同一 run_id 永久去重。不要由 UI 给币。
- `purchase(id)` 校验余额/等级/槽位后扣币，写盘成功才保留变更并刷新绑定 Player；失败完整回滚。`save()` 供返回起点时再次保存。
- `Health.lethal_guard(context)` 在普通护盾、赐福与独立碎片吸收全部完成后才评估，返回恢复 HP。复活不发 died / player_died，after_damage 保留本次实际生命损失并标注 death_prevented。深渊 environmental_fatal 不调用复活，以免在无地面处无限坠落。

## 存档边界与证据

`user://meta_progression.json` 保存版本、两货币、全部等级、已结算 run ledger，以及挑战次数/上次死亡深度/死因。有效的旧版无 history 存档保留钱包/等级并默认空历史，下一次写入补齐。历史与死亡收入在同次事务保存，读入后由 RunDirector 注入皇冠。写临时文件 → flush/close → 回读验证 → 保留有效旧档 .bak → 同目录 rename。SHA-256 使用统一 JSON 数值表示，另验证整数范围、等级与槽位约束。主档损坏时只读有效备份；两份均无效则保留原文并锁定写入，不静默覆盖。该校验能发现损坏与未经重算校验的编辑，不构成对可修改本地客户端者的安全隔离。

Headless、编辑器和命令行路径包含 `/tests/` 的原生测试在 autoload 的 `_ready` 阶段即自动使用进程专属 `user://meta_test_autoload_<PID>.json`，正常退出清理，仅测试自己显式指定的独立 test/demo 档保留到其清理。跨进程审计用 `--meta-test-profile=user://meta_test_<unique>.json`。这些测试不读取或改写真实 `meta_progression.json`。第一次回读测试发现 Godot JSON 往返的数字表示改变校验，现已统一；早期失败日志保留。非法 JSON 使用 JSON.parse 的错误返回处理，不再输出引擎 ERROR。

实际 Godot 4.7.2：MetaForge 28 / 28；温润独立屏障14 / 14；反击盾28 / 28；旧冲刺套件全过。测试覆盖全额结算 / 去重、真实扣款、等级上限、满槽拒绝、HP / 弹匣 / 重组 / 冲刺、40%复活 / 仅一次 / 真护盾先吸收 / 深渊排除、跨房不叠加不回血、损坏备份、双损坏保护、失败写盘回滚。另以两个独立引擎进程先写后读，确认余额、等级与结算 ledger 跨进程保存。

`forge-before.png`、`forge-after.png` 是原生 Vulkan/Forward+实拍，逐张打开检查。由真实按钮信号完成七次升级，钱包1200/30→1000/26，基础HP100→120，高阶槽0/0→1/1；两张都清晰显示钱包、价格、等级与禁用原因。没有用设计稿或生成图作为运行证据。


## 正式流程集成验证

- `campaign-mechanics.log`：23 / 23，真正的 GameStart 首次演出门槛 → Forge 实际按钮升级 → 第一间 RealmStage 数值和单枚初始赐福 → 真实敌人 Health 死亡/清房收益 → 消耗一次复活后跨房保持 37 HP → 真实 Boss 击败与实体碎片拾取 → 深渊真实死亡全额入账 → 重开 Forge 与历史对白 → `finish_campaign()` 单次结算。直接进入 Boss 地图的步骤是测试设置，不代表玩家跳过正式房间路线。
- `meta-regression.log`：31 / 31，原有 28 项加有效旧档迁移、历史保存不丢钱包和历史字段类型约束。`run-regression.log`：49 / 49。`opening-boot.log`：22 / 22，首次完整/跳过、正式Forge交接、死亡重开和两个旧fixture隔离。
- `history-process-write.log` 与 `history-process-read.log`（`tests/meta_history_process_probe.tscn`，先 `--write --meta-test-profile=user://meta_test_<unique>.json`，再另进程仅传同一 profile；该双进程 probe 不参加无参数 `*_test.tscn` 扫描）：两个独立引擎进程真实落盘/回读，钱包 117 / 4、生命天赋等级 1、历史 1 次挑战 / 第 3 层 / abyss；新进程第 2 次挑战创建真实 Player，基础生命 110，CrownVoiceSystem 实际播放 `deep_abyss`。不是同进程内存回读。
- `campaign-native.log` 与 `campaign-*.png`：原生 Vulkan / Forward+，23 / 23；全部 3 张打开审阅。专属测试预算 2000 / 30 经真实 UI 升级为 1415 / 18；真实战斗收益和死亡返回后 1475 / 19。每张均显示真实钱包、等级和槽位。

所有上述最终日志无脚本错误、引擎错误或资源泄漏警告。币值、价格和长线成长节奏仍未经人工平衡；升级交易保存失败会完整回滚并在 Forge 显示错误。保存失败时保留原 run_id 与全部未结算收益；重开/新挑战先重试，成功后才创建下一局。界面提供明确的“重试保存”按钮，未成功前不会清空待结算收入。现有有效旧档仍保留；磁盘持续不可写时新收益只在内存中，提示玩家暂勿退出。


### 结算失败与最终决战补充

`RunDirector.begin_run()` 现在返回 bool。若旧局有待结算收入或未保存的死亡/通关结果，必须先保存成功；`restart()`、GameStart 与结局菜单均检查返回值。存档失败显示可操作的重试通知，保留旧局 ID、收入、已消费复活与死亡/通关状态；保存成功后清除通知，但不会自动重生。完成结局仍立即关闭死亡循环，失败保存不会把通关变回未通关。

最终替身战胜由真实 Threshold → Doppelganger 死亡交接注入计分，沿用普通击杀 5 碎屑 + 清房 20 碎屑，同一尸体和房间只能奖励一次；不会凭空再发四领域的现实锚点。制作名单结算包含这 25 碎屑。

- `settlement-guard.log`：16 / 16。真实不可写父路径阻断存档，死亡/结局均保留原 ID，重开和菜单新挑战不切场；磁盘恢复后点击真实重试按钮，原 ID 单次入账，重复重试/结束不多发币，通关后 R 仍不能重生。
- `final-duel-income.log`：13 / 13。完整真实返程碎裂 → 替身打印/击杀 → 同一皇冠和解 → 制作名单，包含实际替身的 5+20 收入、同尸体重复回调去重及终点单次入账。
- `guard-campaign-regression.log` / `guard-opening-regression.log` / `guard-run-regression.log`：分别 23 / 22 / 50 全通过。Meta23还按R3方式去除fixed-fps重跑，增加driver退出前的音频释放等待后无资源泄漏报告。本轮并行 Windows/WSL 冷加载最长帧约 26 秒，仍在既有黑色加载层内；不作加载性能保证。

### 开场加载与锻造台回归

`opening-transition.log` 来自最终集成树 `770bea9`，按 R3 方式不传 `--fixed-fps` 运行 `res://tests/opening_transition_test.tscn`：**58 / 58 全部通过，exit 0，无脚本错误、引擎错误或警告**。原 45 项检查全部保留并改接真实 RunDirector 战役：黑幕先显示、加载提示至少两帧、同步加载后遮罩覆盖首帧、资源缺失/空场景两类失败、真实重试/退出按钮、重复重试仅额外读取一次、种子/赐福/选择历史保持，以及旧 fixture 的同步无过场入口。新增 13 项验证 autoload 独立测试存档，以及三个用例中实际 Forge 的暂停、加载前等待、重复进入单实例与关闭后准备出发。每个用例显式从首次挑战开始；正常历史重开行为仍由 `opening_boot` 和 `meta_campaign` 覆盖，未修改生产首播规则。
