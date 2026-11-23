# WEEK-10 开发周报

> 教学周第 10 周。覆盖 2026-11-12 至 2026-11-18 的单周增量开发。

## 一、基本信息

| 项目 | 内容 |
| --- | --- |
| 教学周 | 第 10 周（`WEEK-10`） |
| 文档类型 | 单周增量 |
| 统计区间 | 2026-11-12 — 2026-11-18（共 7 天，其中 4 天有提交；另含 11-11 截稿后收尾提交 `19dd937`） |
| 提交数 | 25 次（普通提交 20 次，合并提交 5 次：`0c39cca`、`5ac99af`、`a5cb545`、`fa7187a`、`a41d1af`） |
| 起止提交 | `19dd937`（2026-11-11）→ `c5e6aa6`（2026-11-18） |
| 改动规模 | 395 个文件，+14,654 / −502 行（`git diff --shortstat 8d3db20..c5e6aa6`） |
| 引擎 | Godot 4.7.2（Forward+，Jolt 物理） |
| 分支 | `main`（与 `origin/main` 同步） |
| 小组编号 | 1 |
| 文档负责人 | 待填 |
| 运行日期 | 2026-11-18 |

上一份周报 WEEK-09 统计至 2026-11-11 16:15 提交 `8d3db20`；同日 16:18 收尾提交 `19dd937` 未计入 WEEK-09，一并归入本周增量。

## 二、本周目标

1. **悲伤水声柔化与恐惧领域重构**：调低悲伤涉水合成增益并同步至恐惧场景分支；重做恐惧白色断裂圣殿、引魂者与紫色追魂、幽魂张嘴变形动画及爬坡寻路。
2. **赐福流程、文案与统一坠落边界**：落地清场后出口天赋球交互，重写全部 54 张领域赐福卡描述与机制说明，改为全池发牌与开局三选一，并由 `RealmVoid` 统一四领域坠落规则。
3. **怠惰悬钟庭院与性能/流程治理**：细化怠惰悬钟庭院与四类守卫（含黏液池与时滞场视觉反馈），预热战斗音频/碎裂/奖励管线以消除帧卡顿，并完善 `HydrogenJr` PR 技术审查工作流。

## 三、开发与改进

### 3.1 悲伤水声柔化与恐惧圣殿重构（11-11 — 11-16，8 次提交）

- `19dd937`、`a41d1af`：将悲伤涉水合成增益从 0.80 降至 0.38，增加 0.30 系数一阶平滑，起音 45→75ms、淡出 120→180ms，播放电平从 -13 降至 -17dB。（[证明](../proof/sorrow-water-soft/README.md)）
- `10b0b10`、`fa7187a`、`a5cb545`：构建紧凑白色恐惧断裂圣殿（`fear_1`、`fear_2`、`fear_boss`）与每房 6 只高空漂浮幽魂，并将新版轻柔水声合入恐惧场景分支。（[圣殿证明](../proof/fear-sanctum/README.md)、[水声同步证明](../proof/sorrow-water-sync/README.md)）
- `cde6734`、`5ac99af`：新增斗篷镰刀引魂者及召唤的快速紫色追魂，在正式恐惧房间完成实机技能取证。（[证明](../proof/fear-reaper/README.md)）
- `ce33a6d`：细化幽魂张嘴扑击变形动画（牙根嵌入、上长下短、连续卷舌），修复恐惧爬行怪在斜坡上的寻路追踪；相关恐惧击杀与召唤卡顿排查归档于卡顿证明。（[变形证明](../proof/fear-morph/README.md)、[卡顿证明](../proof/fear-hitches/README.md)）

### 3.2 天赋球、赐福改版与统一坠落边界（11-16 — 11-18，10 次提交）

- `bfc4a96`、`c75700c`、`0c39cca`、`1df77cf`、`0a1a6ff`：在 `zone/realm_stage.gd` 出口门前接入 `TalentOrb`（113 片黄金角确定性聚拢、0.52 米 `WORLD` 碰撞体、核心提前点亮）。首次合并 `#215` 因缺少 4 个回归测试适配被 `1df77cf` 回退，随后在 `0a1a6ff`（#221）补齐全部受影响测试后重并入主线。（[证明](../proof/talent-orb/README.md)）
- `b4dc165`、`4834c46`、`32d3464`、`2f7e4e7`、`1bfcc2f`（#224）：按“触发条件—效果—带主语与单位的数值”重写全部赐福描述，重命名 4 个重复卡名，调整卡片视口自适应排版；新增并调试一次性领域机制说明，最终移除固定开局三选一礼物并修复旧存档缺少 `introduced_realms` 校验失败与光标未释放问题。（[卡片截图](../proof/boon-text/cards-sloth.png)）
- `91b0ce9`（#225）：
  - 门扉改为全池 54 张发牌（`sin_filter = -1`），强化卡要求先持有同系核心；恢复开局同领域三槽核心三选一，每轮最多 1 张替换位（全替换时提供放弃按钮）；
  - 领域机制说明从一次性弹窗改为卡片悬浮说明栏；
  - 新增 `environments/realm_void.gd` 统一四领域坠落边界：玩家扣 30 真实生命回平台，敌人坠落致死。（[发牌证明](../proof/boon-redesign/README.md)、[坠落证明](../proof/fall-void/README.md)）

### 3.3 怠惰悬钟庭院与四类守卫（11-18，3 次提交）

- `25e03ac`（#227）：细化怠惰悬钟庭院（保留 40×48 米核心平台、1.25 米双侧高台与斜坡、远景浮空钟楼与金色主题），恢复迟滞者、锚定者、退缩者三类守卫并加入凝胶异形，第一房 5 怪、第二房 7 怪。（[证明](../proof/sloth-sanctum-combat/README.md)）
- `2ff01de`（#229）：为凝胶异形抛球落地增加持续 3.5 秒、最大半径约 3.2 米的金色胶池（减速 35%、每 0.25 秒 2.5 基础伤害），并恢复迟滞者黑色兜帽披风与细金线。（[证明](../proof/sloth-sanctum-combat/README.md)）
- `136e3f8`（#231）：修复怠惰守卫追击逻辑，新增 `sloth_time_field.gd` 与 `sloth_stasis.gdshader` 强化锚定场、退缩波与屏幕边缘金色刻度视觉反馈。（[证明](../proof/sloth-sanctum-combat/README.md)）

### 3.4 性能预热、PR 审查规范与未提交改动（11-16 — 11-18，4 次提交）

- `f8533be`（#217）、`67bcba7`（#230）：将审查机器人统一为 `HydrogenJr`，新增 `.github/workflows/pr-checks.yml` 并完善 `tools/review/run_checks.sh` 自动化检查与独立技术审查策略。
- `c5e6aa6`（#232）：预热战斗程序化音频、四领域敌人碎裂（`sloth_shatter`、`sloth_realm_shatter`、`wrath_shatter` 等）、`TalentOrb` 与 `BoonPicker` 奖励管线，降低实战帧卡顿。
- 本地未提交改动（`git status --short`）：`actors/player/shadow_body.gd` 有 1 处本地修改（22 插入 / 9 删除），尚未提交。

## 四、验证结果

### 4.1 `docs/proof/` 已有验证记录

- **悲伤轻柔水声**（2026-11-11，[sorrow-water-soft](../proof/sorrow-water-soft/README.md)）：原生 `sorrow_audio_test` 16 项、无界面 `sorrow_audio_integration_test` 12 项、`sorrow_water_test` 32 项、`sorrow_ambience_test` 13 项全部通过；步行 RMS 由 0.033103 降至 0.009114，冲刺 RMS 由 0.035470 降至 0.010462。
- **恐惧圣殿与水声同步**（2026-11-15，[sorrow-water-sync](../proof/sorrow-water-sync/README.md)、[fear-sanctum](../proof/fear-sanctum/README.md)）：Godot 4.7.2 Vulkan Forward+ 原生 `sorrow_audio_test` 16 项通过，4 组无界面检查（含 `fear_sanctum_test` 37 项）合计 110 项通过；导出 WAV 与轻柔试听逐字节一致。
- **引魂者与幽魂变形**（2026-11-15 — 2026-11-16，[fear-reaper](../proof/fear-reaper/README.md)、[fear-morph](../proof/fear-morph/README.md)）：Godot 4.7.2 原生实机 1280×720 取证通过（`reaper-casting.jpg`、`three-wisps.jpg`、`ghost-maw.jpg`、`morph.gif`），斜坡寻路与变形帧验证通过。
- **恐惧卡顿治理**（2026-11-16，[fear-hitches](../proof/fear-hitches/README.md)）：首次召唤同步 CPU 调用由 33.847ms 降至 0.263/0.257ms，后两名普通敌人死亡调用由 1.225/1.298ms 降至 0.63–0.65ms；17 组无界面检查、原生生命周期 27 项、引魂者 30 项、审判之瞳 29 项及 60 Hz 双 fixture 均通过。
- **赐福发牌改版与统一坠落**（2026-11-18，[boon-redesign](../proof/boon-redesign/README.md)、[fall-void](../proof/fall-void/README.md)）：`boon_pipeline_test` 64 项、`boon_offers_test`、`boon_replacement_test` 7 项、`realm_intro_test` 13 项、`realm_stage_test` 27 项及 `realm_void_test`、`fear_realm_test`、`fear_playtest_test` 全部通过。
- **怠惰悬钟庭院与守卫**（2026-11-18，[sloth-sanctum-combat](../proof/sloth-sanctum-combat/README.md)）：Godot 4.7.2 原生 33 项通过（含 4 张实机截图），14 组无界面回归（含正式战役 98 项、天赋球 68 项、新怠惰战斗 29 项、领域坠落 24 项）通过；60 Hz fixture `FX-001` 保持 `edc3fc82c34f1bc0`、`FX-002` 保持 `ad3703cd93d3073e`。

### 4.2 本次新跑检查（2026-11-18，基于 `c5e6aa6`）

```bash
godot --headless --fixed-fps 60 --path . res://tests/fixture_test.tscn
godot --headless --path . res://tests/campaign_realms_test.tscn
```

- `fixture_test.tscn`：通过（`ALL PASSED (0 failed)`；`FX-001` 2736 ticks 哈希 `4c08f5cabeb67692`，`FX-002` 878 ticks 哈希 `96a9c443a6dae29f`，双次复现哈希一致）。
- `campaign_realms_test.tscn`：通过（`ALL PASSED (98 checks)`，十二房完整遍历、累计剥夺、四碎片激活与第四级身躯裂痕全部通过）。

## 五、问题与决策

- **策略决策**：本周无新增 ADR（最新仍为 `0018`）；PR 审查自动化流程由 [REVIEW.md](../REVIEW.md) 与 `.github/workflows/pr-checks.yml` 落地，规定 `HydrogenJr` 按技术正确性独立审查队友 PR。
- **已知限制**：
  1. `BoonPicker` 首次构建与卡片布局仍有约 30ms 同步开销（`--entry` 基准最长帧 36.466ms），本次未消除该 UI 构建耗时（[fear-hitches](../proof/fear-hitches/README.md)）。
  2. 赐福全池发牌权重（每轮 1 张替换位、未投资系权重 ×2、开局三槽核心）为设计默认，试玩后仍可能调整；`MetaProgression.introduced_realms` 存档字段保留以兼容旧档（[boon-redesign](../proof/boon-redesign/README.md)）。
  3. 悲伤轻柔涉水声仅完成本机 PCM 统计与测试，真人试听音量强度仍待团队确认（[sorrow-water-soft](../proof/sorrow-water-soft/README.md)）。
  4. `actors/player/shadow_body.gd` 存在未提交本地修改，尚未进入主线验证。

## 六、下周计划

| 计划项 | 负责人 |
| --- | --- |
| 组织完整四领域真人试玩，确认轻柔水声音量、全池赐福抽牌权重与怠惰新守卫数值手感 | 待填 |
| 评估并优化 `BoonPicker` 首次构建约 30ms 同步卡顿 | 待填 |
| 核对并收口 `actors/player/shadow_body.gd` 本地修改，走 PR 流程合入 | 待填 |
| 推进旧 TODO 遗留的场景现成模型替换与敌人受击/枪口表现补齐（按需对齐新版四领域） | 待填 |

## 七、个人贡献

| 成员 | 本周具体任务 | 完成产出 | 核验依据 | 下周任务 |
| --- | --- | --- | --- | --- |
| 张琰翔 | 完善 `HydrogenJr` PR 自动化审查与检查脚本；处理冲突回归并维护主线稳定；预热战斗音频、碎裂与奖励管线以降低帧卡顿 | `.github/workflows/pr-checks.yml` 与 `tools/review/run_checks.sh`；战斗音频/四领域碎裂/`TalentOrb`/`BoonPicker` 预热实现 | `Yanxiang Zhang`；提交 `f8533be` `1df77cf` `67bcba7` `c5e6aa6` | 优化 `BoonPicker` 首次构建卡顿并组织真人试玩 |
| 何承泽 | 调优悲伤轻柔涉水声；重构恐惧白色圣殿、引魂者/紫色追魂与幽魂变形/爬坡；细化怠惰悬钟庭院、恢复三类守卫并新增凝胶异形与时滞视觉反馈 | 轻柔水声波形与同步分支；恐惧圣殿、`FearReaper`、幽魂变形与斜坡寻路；怠惰悬钟庭院、`SlothMire`/`SlothResinPool`、`SlothTimeField` | `KADG`；提交 `19dd937` `a41d1af` `10b0b10` `fa7187a` `a5cb545` `cde6734` `5ac99af` `0c39cca` `ce33a6d` `25e03ac` `2ff01de` `136e3f8`；[sorrow-water-soft](../proof/sorrow-water-soft/README.md)、[fear-sanctum](../proof/fear-sanctum/README.md)、[fear-reaper](../proof/fear-reaper/README.md)、[fear-morph](../proof/fear-morph/README.md)、[sloth-sanctum-combat](../proof/sloth-sanctum-combat/README.md) | 依据真人试玩反馈微调怠惰与恐惧守卫数值及水声音量 |
| 章家齐 | 实现清场出口天赋球交互与碰撞；重写全部 54 张赐福描述并调试机制说明；落地全池发牌、开局三选一、卡片悬浮说明与统一 `RealmVoid` 坠落边界 | `objects/talent_orb/` 与全套回归适配；54 张新版赐福文案与排版；`environments/realm_void.gd` 与 `boon_replacement_test`/`realm_void_test` | `MRTODAY` / `MRTODAYY`；提交 `bfc4a96` `c75700c` `0a1a6ff` `b4dc165` `4834c46` `32d3464` `2f7e4e7` `1bfcc2f` `91b0ce9`；[talent-orb](../proof/talent-orb/README.md)、[boon-redesign](../proof/boon-redesign/README.md)、[fall-void](../proof/fall-void/README.md) | 根据试玩反馈调整全池发牌权重并核对本地未提交改动 |

## 附录 A：提交清单（25 次，按时间倒序）

| 提交 | 日期 | 作者 | 说明 |
| --- | --- | --- | --- |
| `c5e6aa6` | 2026-11-18 | 张琰翔 | Prewarm combat audio/shatter/reward pipelines and cut frame hitches (#232) |
| `136e3f8` | 2026-11-18 | 何承泽 | Fix Sloth guard pursuit and show active stasis attacks (#231) |
| `67bcba7` | 2026-11-18 | 张琰翔 | HydrogenJr 按技术正确性独立审查 PR (#230) |
| `2ff01de` | 2026-11-18 | 何承泽 | Give Sloth resin throws a lingering ground pool and restore black capes (#229) |
| `25e03ac` | 2026-11-18 | 何承泽 | 细化怠惰悬钟庭院，恢复三类守卫并加入凝胶异形 (#227) |
| `91b0ce9` | 2026-11-18 | 章家齐 | feat: full-pool boon draw, opening choice, unified fall boundary (#225) |
| `1bfcc2f` | 2026-11-17 | 章家齐 | Feat/重写全部54张天赋卡的描述，并给每个领域加一张一次性的机制说明卡 (#224) |
| `2f7e4e7` | 2026-11-16 | 章家齐 | Make the opening gift draw from one realm and explain it |
| `32d3464` | 2026-11-16 | 章家齐 | Fit long card text on screen and explain the two loose nouns |
| `4834c46` | 2026-11-16 | 章家齐 | Keep the real card names and add proof shots |
| `b4dc165` | 2026-11-16 | 章家齐 | Rewrite every boon card and explain each realm once |
| `0a1a6ff` | 2026-11-16 | 章家齐 | Fix the clear-flow regression tests and the piece count (#221) |
| `ce33a6d` | 2026-11-16 | 何承泽 | Refine ghost maw animation and fix Fear crawler ramp pursuit (#218) |
| `1df77cf` | 2026-11-16 | 张琰翔 | Revert "Merge pull request #215 from kyrie21z/feat/talent-orb-pickup" (#220) |
| `0c39cca` | 2026-11-16 | 何承泽 | Merge pull request #215 from kyrie21z/feat/talent-orb-pickup |
| `f8533be` | 2026-11-16 | 张琰翔 | docs(review): replace kk with HydrogenJr and add PR checks workflow (#217) |
| `c75700c` | 2026-11-16 | 章家齐 | Add a solid body to the talent orb and light its core with the shell |
| `bfc4a96` | 2026-11-16 | 章家齐 | Add reclaimed-talent orb in front of the exit gate |
| `5ac99af` | 2026-11-15 | 何承泽 | Merge pull request #214 from kyrie21z/feat/fear-reaper-summoner |
| `cde6734` | 2026-11-15 | 何承泽 | Add cloaked scythe summoner and fast purple wisps to Fear |
| `a5cb545` | 2026-11-15 | 何承泽 | Merge pull request #212 from kyrie21z/art/fear-white-cathedral |
| `fa7187a` | 2026-11-15 | 何承泽 | Merge latest main with softer water audio into Fear scene branch |
| `a41d1af` | 2026-11-15 | 何承泽 | Merge pull request #210 from kyrie21z/fix/sorrow-water-softer |
| `10b0b10` | 2026-11-15 | 何承泽 | Build compact white Fear sanctum with drifting ghosts |
| `19dd937` | 2026-11-11 | 何承泽 | Make Sorrow movement water quieter and gentler |
