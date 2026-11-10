# Epic 3 / Epic 4 集成验证

Godot **4.7.2**，Windows 原生 Forward+ / Jolt；原生画面使用 RTX 4060 Laptop。工作在独立功能分支，未改动或合并 `main`。基线为 `5d8b290162085ba1b8f5dbb36d756677784496be`。

## 全量回归与纠偏

`first-sweep/` 保留首次完整扫描的85个测试日志，结果为82通过、3失败。该次扫描期间皇冠尺寸与音频修正仍在集成，**不能称作最终固定提交的一次全绿**。最终结论结合每条PR的固定前缀验证，以及下表针对具体失败的复验。

| 首次失败 | 原因及修正 | 最终复验 |
| --- | --- | --- |
| `opening_sequence_test` | 旧断言比较玩家中心Z，新皇冠按实际头部坐标佩戴；改为检查真实头锚完整变换，保留走动跟随检查 | [16项通过](../issue-147/sequence.log)；另有[24项真实尺寸及冠结构检查](../issue-147/crown-bounds.log) |
| `opening_transition_test` | 旧回归仍期待原型RunState地图，也未完成新增Forge交互；移植到真实战役入口、实际Forge关闭与历史隔离 | [58项通过](../issue-152/opening-transition.log)，保留45项旧加载/错误/重试检查 |
| `realm_boss_stage_test` | 8次物理帧内尚未执行一次HUD更新，读取了ProgressBar默认上限；等待完成UI帧，仍严格检查1750并增加真实受击/死亡显示 | [固定FPS20项](../issue-139/hud-fixed-fps.log)与[无固定FPS20项](../issue-139/hud-unfixed-fps.log)均通过 |

首次R6还发现最终台词未列入素材清单，已在#150补齐；23段中文语音全部替换为来源明确的Kokoro离线输出。最终R1/R6复验见 `final-static.log`，不是忽略首次错误。

新增存档故障测试未在首次扫描开始时存在：[16项实际故障与重试检查](../issue-152/settlement-guard.log)单独通过。最终双手握持修正经过[20项终幕检查](../issue-151/reconciliation-test.log)和重新运行的原生画面检查。每个issue的独立前缀导入和机制检查另见 `prefix-validation.json`。

独立#146和#152前缀各有一次冷进程过场重试后，5秒内未观察到遮罩清理并引发后续断言失败。随后带状态探针及撤去探针的运行均通过；原超时阈值、玩法和断言均未放宽。首次失败及复验记录保留在 `prefix-transition-attempts/`。目前未复现根因，不将复跑通过描述为已经永久消除此偶发现象；PR保持草稿供审查。

## 旧流程与素材边界

R4在同一机器重新创建main基线工作树、导入并运行fixture，结果与集成树一致：`FX-001 = 18f02a294f3e538a`、`FX-002 = ad3703cd93d3073e`。见 `hashes_head.txt`、`hashes_base.txt` 和 `fixture_base.log`。地图重新生成无漂移，见 `gen_zones.log`。

原生截图来自真实生产节点，已逐张查看；皇冠为正常头围的普通六尖冠，无眼睛或手，实际头骨佩戴与双手拾取均使用同一模型。制作名单并列署名kyrie21z、KADG777、MRTODAYY。语音验证覆盖真实解码、播放进度与结束回调，尚无人工听感、情绪表演及长线难度平衡验收；自动输入和截图不等于人工完整通关。

保留引擎退出时的历史资源诊断。此次扫描`meta_campaign_test`出现一次退出资源报告，增加与其他driver相同的音频释放等待后已无固定FPS复测通过；日志在#152证明目录。旧`weapons_test`/fixture的退出清理诊断按仓库R3既有规则单独记录，不把它们伪装为玩法断言失败或声称已修复。
