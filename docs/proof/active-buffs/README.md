# 主动弹匣与扩大盾波：PR #34 最新 main 复验

2026-10-28，在用户指定工程 `D:\CS Games\Rouge\Battlefield-Rouge` 合入 main `5d235ab41ca2af6370b02a38589dff769967cb76` 后运行。保留图形 HUD、Shift 冲刺、fixture 首轮修复、敌人射击位和 #42 的前沿 / 中段 / 据点布局；相对 main 没有修改这些玩法文件。

## 紫盾存在感修复（本轮最新）

用户试玩反馈“感觉不到冲击波、盾很薄”。旧版主动盾只有整屏淡色，反击球壳在第一人称内侧不易看见，低位环在达到最大范围时已接近淡完。本轮改为以下可见反馈，伤害、护盾持续和冷却维持原规则。

- 开 G：分层的厚紫盾缘、内外亮轮廓与斜面，不给中心瞄准区域铺满色块，HUD 保持在上层。
- 真正挡伤：盾缘亮闪，反击卡持续显示蓄能。未挡伤的护盾到期不会免费发波。
- 到期反击：第一人称双层波纹向外扫过，反馈持续 0.72 秒；保护仍按原持续时间结束，余波不提供额外无敌。
- 世界波：双面开口能量波前、上下厚环和两层延后余波，0.48 秒到水平半径 7 米、0.62 秒开始淡出、0.82 秒回收；专用 0.64 秒低频能量声。世界深度测试和伤害遮挡保留，不引入全局随机或外部素材。

新增 `shield_visual_test` 的 **24 项**覆盖真实敌弹、蓄能、一次伤害、保护结束、两种波的暂停冻结、死亡清理和回收。原生取证 **15 项**通过，直接比较同一冻结视角的真实渲染帧：盾缘区域平均 RGB 差 0.0295，瞄准区域 0.0073，第一人称反击区域 0.0897；边缘和波可见，瞄准区域保持清楚。四张新图覆盖开盾 / 挡伤 / 第一人称反击 / 外部完整波面，已人工查看。

## 当前行为与 HUD

危险弹匣成功完成空仓换弹后储存一枚，C 主动投出。取消未完成换弹不发放，切枪保留已储存枚；持有不计引信，开狙击镜隐藏模型，暂停或死亡不能投。每层伤害 120→60，1 米内全伤、3.5 米边缘半伤；投速 24 米/秒、上抛 3、重力 9、投出后引信 1.5 秒。紫盾 G 挡伤后到期反击，半径独立为 7 米、每层均匀 25 BODY 伤害。遮挡、无同队 / 自伤和每个 Health 一次结算继续生效。

右下 AbilityBar 使用同一风格的 G / V / C 方槽。C 无增益时锁定；有增益无库存时暗态 `0/1`；储存后亮态 `1/1`，投出后恢复 `0/1`。护盾槽的 `corner_icon` / `danger_badge` 已删除。`hud_test` 用真实换弹和投掷覆盖三态及返回空态、切枪、清理、三槽布局，总计 287 项。

## 全部自动测试

Godot 4.7.2。全部 **17 个** `tests/*_test.tscn` 断言通过、退出码 0。

| 场景 | 结果 | 退出码 |
| --- | --- | --- |
| `active_magazine_test` | `ACTIVE MAGAZINE: 36 checks, 0 failed` | 0 |
| `boss_test` | `ALL PASSED (63 checks, 0 failed)` | 0 |
| `buff_run_test` | `buff-two-small-zones-and-boss-20261027-seed-40408: ALL PASSED (0 failed)` | 0 |
| `capture_hammer_test` | `ALL PASSED (0 failed)` | 0 |
| `combat_traits_test` | `COMBAT TRAITS: ALL PASSED (0 failed)` | 0 |
| `dash_test` | `ALL PASSED (0 failed)` | 0 |
| `enemy_layout_test` | `ALL PASSED (34 checks, 0 failed)` | 0 |
| `firing_position_test` | `ALL PASSED (0 failed)` | 0 |
| `fixture_test` | `ALL PASSED (0 failed)` | 0 |
| `hud_test` | `ALL PASSED (287 checks, 0 failed)` | 0 |
| `melee_test` | `ALL PASSED (0 failed)` | 0 |
| `reflected_round_test` | `REFLECTED ROUND: ALL PASSED (0 failed)` | 0 |
| `reinforcement_test` | `ALL PASSED (0 failed)` | 0 |
| `reload_blast_test` | `RELOAD BLAST: 29 checks, 0 failed` | 0 |
| `school_icons_test` | `ALL PASSED (0 failed)` | 0 |
| `shield_visual_test` | `SHIELD FEEDBACK: 24 checks, 0 failed` | 0 |
| `weapons_test` | `ALL PASSED (0 failed)` | 0 |

全套扫描和完整输出保留在本机 `D:\CS Games\tmp\pr34-shield-visibility-validation`。仓库只附本次能力 / HUD 新检查、原生取证和 fixture 的 10 份日志，不附基线日志或其余既有测试的重复日志。

## 固定步 fixture：三个独立进程与一次诊断复验

同一版本分别运行整套 `--runs=3`，以及单独 `--fixture=FX-001 --runs=3`、`--fixture=FX-002 --runs=3`。每组第一遍为首次加载，后两遍通过真实结算重开；保存记录逐字节比较，全套与各独立进程的三个主种子记录均相同，种子 +1 对照也一致。另加 `--frame-delay 1` 做了一次全套诊断复验，各三遍及对照记录与上述三个进程也逐字节相同。

| fixture | 种子 | 每遍结果 | tick / 轨迹行数 | 全套与独立进程三遍的哈希 | 种子 +1 对照 |
| --- | --- | --- | --- | --- | --- |
| FX-001 | 1001 | 胜利 | 2554 / 139 | `95d4b590ae882378` | 1002：胜利，2537 tick，`c3c3084d44c20133` |
| FX-002 | 2002 | 胜利 | 912 / 41 | `4494ad3460ca6ab9` | 2003：胜利，912 tick，`07161059705b7ef8` |

本次重算与最新 main `5d235ab` 文档公布的值相同。机器人不操作 C；这些 fixture 的记录相同不代表所有构筑或真人打法都不受主动弹匣改动影响。审查最初提到的 `bd71b23b8c341b4f` / `5e1a5a995f643d72` 属于 #42 合并前的 main，历史值保留在 [issue #14 证明](../issue-14/README.md) 和 [HUD 证明](../hud/README.md)。旧 PR `4d370ae` 基于 `8462d10` 时曾得到 FX-001 胜利 2643 tick / `80db1126b6bac259`，FX-002 阵亡 355 tick / `5e1a5a995f643d72`，同样只作为历史。

[全套日志](logs/fixture_test.log)、[独立 FX-001](logs/fixture-FX-001.log)、[独立 FX-002](logs/fixture-FX-002.log)；`traces/` 保留本次全套三遍及种子 +1 的原始记录。哈希对记录去掉文件末尾换行后取 SHA-256 前 16 位，采样间隔保持默认 30 tick。

## 原生检查与 JPEG

Forward+ / Vulkan / RTX 4060 Laptop GPU：主动弹匣原生检查 **39 项**、弹匣取证 **18 项**、紫盾取证 **15 项**，均零失败、退出码 0，无脚本错误或退出诊断。真实物理 C 仅投出一枚并让槽位回到 `0/1`；平地投距约 24 米，当前取证落点 **24.50 米**、4 个真实敌人受伤，至少一个损失 ≥60 生命。G 护盾吸收真实敌方弹丸后，对约 6 米的敌人只结算一次 25 伤害。

截图直接由 Godot 当前画面保存为 JPEG，1080p / 720p，质量 0.82。为便于复查，把真实地图中的角色移到测试平地、冻结敌人 AI；距离线、额外地板和盾波外景相机只存在于取证脚本中。伤害仍走实际组件。截图已人工查看，不作为人工完整试玩的替代。

旧 PR 9 张 PNG 共 5,390,635 字节；现在 **9 张 JPEG 共 714,789 字节**（缩减 86.7%），每张均低于 300,000 字节。首次合入 main 的 `7a7f410` 曾为 7 张 JPEG / 517,867 字节；本轮补充两个盾阶段并重截原盾图。旧 PNG、重复图标和旧基线日志已移除；main 原有历史截图保留。

| 截图 | 字节数 |
| --- | --- |
| [magazine-01-C-locked.jpg](magazine-01-C-locked.jpg) | 93,059 |
| [magazine-02-C-empty.jpg](magazine-02-C-empty.jpg) | 95,247 |
| [magazine-03-C-ready.jpg](magazine-03-C-ready.jpg) | 99,320 |
| [magazine-04-C-ready-720p.jpg](magazine-04-C-ready-720p.jpg) | 54,135 |
| [magazine-05-distant-impact.jpg](magazine-05-distant-impact.jpg) | 54,064 |
| [shield-00-active-thick.jpg](shield-00-active-thick.jpg) | 78,834 |
| [shield-00-impact-charged.jpg](shield-00-impact-charged.jpg) | 84,314 |
| [shield-01-purple-pulse.jpg](shield-01-purple-pulse.jpg) | 83,583 |
| [shield-02-purple-pulse-wide.jpg](shield-02-purple-pulse-wide.jpg) | 72,233 |

五张 magazine 图对应 C 三态、720p 与远投；四张 shield 图对应开盾厚度、挡伤蓄能、同一次反击的第一人称与外景。

## 复现命令

```powershell
$P = 'D:\CS Games\Rouge\Battlefield-Rouge'
$G = 'D:\godot\Godot_v4.7.2-stable_win64_console.exe'
Get-ChildItem -LiteralPath "$P\tests" -Filter '*_test.tscn' |
  Where-Object Name -ne 'fixture_test.tscn' | ForEach-Object {
    & $G --headless --path $P ("res://tests/" + $_.Name)
    if ($LASTEXITCODE -ne 0) { throw $_.Name }
  }
& $G --headless --fixed-fps 60 --max-fps 240 --path $P res://tests/fixture_test.tscn -- --runs=3
& $G --headless --fixed-fps 60 --max-fps 240 --path $P res://tests/fixture_test.tscn -- --fixture=FX-001 --runs=3
& $G --headless --fixed-fps 60 --max-fps 240 --path $P res://tests/fixture_test.tscn -- --fixture=FX-002 --runs=3
& $G --headless --fixed-fps 60 --frame-delay 1 --path $P res://tests/fixture_test.tscn -- --runs=3
& $G --max-fps 60 --path $P res://tests/active_magazine_test.tscn
& $G --max-fps 60 --path $P res://tests/reload_blast_proof.tscn
& $G --max-fps 60 --path $P res://tests/shield_purple_proof.tscn
```

## 限制与诊断

所有断言和退出码通过，不将其描述为日志完全干净。本轮 `dash_test` 退出报告 2 个 ObjectDB 实例；`melee_test` 为 4 个实例 / 2 个资源，`weapons_test` 为 6 个实例 / 2 个资源；首次全套及两个独立 fixture 进程各为 8 个实例 / 2 个资源。历史音频退出诊断仍见原 [HUD 证明](../hud/README.md)，本轮未重跑或提交基线日志，也未宣称修复退出清理。

首次全套固定步运行还出现一次 Jolt 作业队列提示（种子 1002 对照局），原样保留在 [fixture_test.log](logs/fixture_test.log)。因此额外使用 `--fixed-fps 60 --frame-delay 1` 做全套各三遍诊断复验：无 Jolt 提示或资源占用错误，仅退出 4 个 ObjectDB 实例，结果和每份记录逐字节相同，见 [fixture-yield.log](logs/fixture-yield.log)。逐帧间隔不改变固定模拟步长；不能由这次干净复验推断引擎提示已被修复。新增盾反馈 / HUD 和三个原生检查均无脚本错误或退出诊断。

数值仍是试玩默认；换场景清除弹匣临时库存。fixture 只证明本机同版本重复，不保证跨机器哈希。手柄、导出平台、低帧率和真人难度平衡待后续验证。
