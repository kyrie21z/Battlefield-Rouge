# WEEK-09 开发周报

> 教学周第 9 周。覆盖 2026-11-05 至 2026-11-11 的单周增量开发。

## 一、基本信息

| 项目 | 内容 |
| --- | --- |
| 教学周 | 第 9 周（`WEEK-09`） |
| 文档类型 | 单周增量 |
| 统计区间 | 2026-11-05 — 2026-11-11（共 7 天，其中 5 天有提交） |
| 提交数 | 58 次（普通提交 55 次，含合并提交 3 次：`8d3db20`、`c6c33a0`、`a6f4186`） |
| 起止提交 | `5292b92`（2026-11-06）→ `8d3db20`（2026-11-11） |
| 改动规模 | 2,199 个文件，+94,351 / −6,105 行（`git diff --shortstat 5292b92^..8d3db20`） |
| 引擎 | Godot 4.7.2（Forward+，Jolt 物理） |
| 分支 | `main`（与 `origin/main` 同步） |
| 小组编号 | 1 |
| 文档负责人 | 张琰翔 |
| 运行日期 | 2026-11-11 |

上一份阶段性汇报 WEEK-08 统计至 11-04 16:33 提交 `5004e8c`；11-04 当晚收尾的 4 次紧急修复提交（`d42dea2`、`f9922e6`、`6665f30`、`438fa73`，涵盖 [ADR 0010](../adr/0010-empty-magazine-blast.md) 危险弹匣打空即得、弹道方向与开场加载死锁修复）已完整归档于 [empty-magazine](../proof/empty-magazine/README.md)、[tracer-direction](../proof/tracer-direction/README.md)、[loading-stall](../proof/loading-stall/README.md)。本周（WEEK-09）增量严格自 11-05 00:00:00 算起，首个提交为 11-06 的 `5292b92`。

## 二、本周目标

1. **武器与身躯感知落地（Epic 1 一枪一刃）**：退役旧三枪三刀原型，实现单手黑晶手枪（8 发半自动、平滑 ADS 聚焦、0.85 秒晶体重组）与意志短刃（三段斩、磁吸前冲、短刃弹反慢弹、节拍敲钟占点）；构建 24 骨第一人称身躯感知与 0–4 级黑色晶体接缝裂痕；搭建独立生产测试台。
2. **构筑深度与全流程闭环（Epic 2、Epic 3、Epic 4）**：建立四动作槽位与统一伤害管道，实现四心魔 12 棵赐福天赋树、六组双重共鸣与门扉三选一；构建怠惰、恐惧、暴怒、哀伤四大领域与累计剥夺规则，跑通十二房全流程；落地完美替身决战、身躯粉碎金缮、和解加冕与局外皇冠锻造台。
3. **视听打磨与试玩调优**：引入领域专属音效、全息打印、接触光照与 ADS 聚焦；编写 Windows 根启动器解决无缓存黑屏；缓存恐惧碎块凸碰撞消除卡顿，优化审判之瞳性能与尖塔 Boss 战斗；落地受击红边、柔化雨底噪声并替换原创水波涉水音效。

## 三、开发与改进

### 3.1 Sloth 场景与敌人整合（11-06 — 11-08，3 次提交）

- `5292b92`：从备用包引入 `SlothEnemy`，实现迟滞者四连慢弹（间隔 0.18 秒、40 米/秒、9 伤/发）、闭篷 30% 闪避与 56 片碎裂。（[证明](../proof/sloth-integration/README.md)、[ADR 0011](../adr/0011-sloth-playable-integration.md)）
- `fe0e1c9`：前两关 96×128 米复层庭院与 Boss 关 92 米云海圣殿场景独立备案入库，准备导航几何与掩体点。（[证明](../proof/sloth-integration/README.md)、[ADR 0011](../adr/0011-sloth-playable-integration.md)）
- `b9575a8`：
  - 缩图重排：战斗核心压缩至 40×48 米，据点距离缩短为 22/24 米；外围柱廊与浮岛标记为 `sloth_scenery` 纯景观并抑制碰撞与导航烘焙。（[证明](../proof/sloth-compact/README.md)、[ADR 0012](../adr/0012-compact-combat-scenic-surroundings.md)）
  - 持续反击盾：限时盾改为 100 点持续容量反击盾，`Health` 增加 `damage_absorber` 吸收回调与外层防重结算；吸收满或再次按 G 释放 7 米冲击波。（[证明](../proof/counter-pressure/README.md)、[ADR 0013](../adr/0013-persistent-counter-and-active-pressure.md)）
  - 主动敌群与波次：开场小怪具备主动位移与绕掩体施法行为；增援采用胶囊体空间查询，防止刷怪重叠堆叠。（[证明](../proof/counter-pressure/README.md)、[证明](../proof/wave-tuning/README.md)、[ADR 0013](../adr/0013-persistent-counter-and-active-pressure.md)）

### 3.2 叙事基石与 Epic 1 一枪一刃（11-09 — 11-10，8 次提交）

- `c59fc7a`、`dfb49a1`：新增 `docs/NARRATIVE_FOUNDATION.md`（v1.3/v1.5），确立四心魔世界观、导入武器概念图、规划 12 棵赐福天赋树与双重共鸣。（[说明](../NARRATIVE_FOUNDATION.md)）
- `7e67055`（#101）：实现单手黑曜石手枪（8 发弹匣、35 伤、0.18 秒半自动、右键平滑 ADS 聚焦 75°→58°、菱形准星与后坐力）。（[证明](../proof/issue-101/README.md)、[ADR 0014](../adr/0014-epic1-mind-arsenal.md)）
- `5716b8a`（#102）：实现 0.85 秒晶体重组动画与补弹，冲刺不打断重组进度。（[证明](../proof/issue-102/README.md)、[ADR 0014](../adr/0014-epic1-mind-arsenal.md)）
- `5b4dbd3`（#103）：实现意志短刃（55 伤、三段挥砍 0.08/0.12/0.15 秒、4.5 米 ±40° 磁吸与 0.45 米前冲，右手持枪右偏不收枪）。（[证明](../proof/issue-103/README.md)、[ADR 0014](../adr/0014-epic1-mind-arsenal.md)）
- `eff6fbc`（#104）：
  - 短刃挥砍前 0.15 秒挂载 `BladeParryArea` 弹反敌方慢弹，移交投射物归属反击发射者；
  - 敲钟占点：废除旧 Hammer，短刃在挥砍生效帧、面向据点且无遮挡时结算据点进度（普通 10%、完美 20%、±150ms 窗口）；Boss 核心一击击碎。（[证明](../proof/issue-104/README.md)、[ADR 0014](../adr/0014-epic1-mind-arsenal.md)）
- `b57180a`（#105）：实现第一人称 24 骨全身感知，沿真实晶体接缝呈现 0–4 级黑色全身裂痕，监听 `Events.sin_defeated`。（[证明](../proof/issue-105/README.md)、[ADR 0014](../adr/0014-epic1-mind-arsenal.md)）
- `3696ed1`（#106）：新增独立生产测试台 `tests/combat_bench.tscn`，清理旧多枪多刀废弃 API。（[证明](../proof/issue-106/README.md)、[证明](../proof/epic1/README.md)、[ADR 0014](../adr/0014-epic1-mind-arsenal.md)）

### 3.3 Epic 2 赐福动作管道与四系共鸣体系（11-10，11 次提交）

- `6f605c8`（PR 2.1）：建立枪、刃、冲刺、战技四动作槽位与统一伤害管道，实现基于 source-key 的修饰层。（[证明](../proof/issue-114/README.md)、[ADR 0015](../adr/0015-boon-action-pipeline.md)）
- `efb022a`、`61c146f`（PR 2.2、2.3）：实现 Sloth 怠惰滞后蓄压三核心、九张特质卡与永恒停滞传奇。（[证明](../proof/issue-115/README.md)、[证明](../proof/issue-116/README.md)）
- `3e3ad0a`、`d30b5bf`（PR 2.4、2.5）：实现 Fear 恐惧实体破绽、追踪弹反与残影三核心、九张特质卡与全景惊惧传奇。（[证明](../proof/issue-117/README.md)、[证明](../proof/issue-118/README.md)）
- `e48f80f`、`aae0c8d`（PR 2.6、2.7）：实现 Wrath 暴怒真实冲量、跳弹与撞墙破裂三核心、九张特质卡与灾厄怒潮传奇。（[证明](../proof/issue-119/README.md)、[证明](../proof/issue-120/README.md)）
- `58cf5f1`、`8f03ed4`（PR 2.8、2.9）：实现 Sorrow 哀伤溶蚀、泪晶与苍蓝水带三核心、九张特质卡与无尽悲渊传奇。（[证明](../proof/issue-121/README.md)、[证明](../proof/issue-122/README.md)）
- `40f1e29`（PR 2.10）：实现六组双重共鸣机制与目标全局双异常 +40% 伤害结算。（[证明](../proof/issue-123/README.md)、[ADR 0016](../adr/0016-dual-boon-composition.md)）
- `5d8b290`（PR 2.11）：接入门扉赐福 UI、三选一抽取与构筑试炼台 `tests/boon_sandbox.tscn`。（[证明](../proof/issue-124/README.md)、[证明](../proof/epic-2-validation/README.md)、[ADR 0017](../adr/0017-boon-door-rewards.md)）

### 3.4 Epic 3 与 Epic 4 全流程与终局叙事（11-10，15 次提交）

- `ae28b0c`、`5781f15`：实现怠惰琥珀领域、沉眠巨像 Boss、休息剥夺机制与沉睡碎片。（[证明](../proof/issue-138/README.md)、[证明](../proof/issue-139/README.md)）
- `2adc28c`、`44cbb0d`：实现恐惧深渊石桥领域、审判之瞳 Boss、预警剥夺机制与警觉碎片。（[证明](../proof/issue-140/README.md)、[证明](../proof/issue-141/README.md)）
- `c822ec1`、`264fb9c`：实现暴怒熔炉领域、狂暴尖塔 Boss、击退剥夺机制与锋芒碎片。（[证明](../proof/issue-142/README.md)、[证明](../proof/issue-143/README.md)）
- `59695f2`、`70f5aca`：实现哀伤泪池领域、哀泣巨碑 Boss、缓冲剥夺机制与温润屏障。（[证明](../proof/issue-144/README.md)、[证明](../proof/issue-145/README.md)）
- `eddbaea`：实现四领域随机顺序、累计剥夺与完整十二房流程编排 `RunDirector`。（[证明](../proof/issue-146/README.md)、[ADR 0018](../adr/0018-realms-and-independent-fragments.md)）
- `13606c0`：实现第一人称苏醒、皇冠加冕与开门交权过场。（[证明](../proof/issue-147/README.md)、[证明](../proof/voice-assets/README.md)）
- `f1dc8c1`：实现历史语音流、头部随行佩戴与指数增强冠光。（[证明](../proof/issue-148/README.md)）
- `1f5d864`：实现真实身躯粉碎、四声呼喊与金缮重组机制。（[证明](../proof/issue-149/README.md)）
- `21baeb6`：实现皇冠打印完美替身与四碎片决战机制。（[证明](../proof/issue-150/README.md)）
- `d3210e3`：实现双手和解加冕与现实苏醒终局演出。（[证明](../proof/issue-151/README.md)）
- `b9457c7`：实现皇冠锻造台、双货币存档与可靠结算重试保护。（[证明](../proof/issue-152/README.md)、[证明](../proof/epic34-validation/README.md)）

### 3.5 视听反馈打磨与试玩调优（11-10 — 11-11，21 次提交）

- 视听反馈系统落地（11-10）：
  - `a6be955`：增加 TAB 构筑检视面板与安全暂停生命周期。（[证明](../proof/issue-173/README.md)）
  - `149509b`、`1cafd5b`、`b56c603`、`dfe6080`、`84601d3`：分别构建怠惰、暴怒、哀伤、恐惧四领域战斗音效及终局皇冠声音。（[证明](../proof/issue-176/README.md)、[证明](../proof/issue-178/README.md)、[证明](../proof/issue-179/README.md)、[证明](../proof/issue-177/README.md)、[证明](../proof/issue-180/README.md)）
  - `5a1d829`、`19854cb`、`7391e6c`、`f6c6e34`：实现全息切片打印替身、晶体受击飞溅、镜面水体降雨与流动金缮接缝视觉。（[证明](../proof/issue-170/README.md)、[证明](../proof/issue-168/README.md)、[证明](../proof/issue-169/README.md)、[证明](../proof/issue-172/README.md)）
  - `bef6f9e`、`b462cb9`：实现图鉴系统（实时赐福目录）与进度解锁日记/双重档案。（[证明](../proof/issue-174/README.md)、[证明](../proof/issue-175/README.md)）
  - `34de2b3`：实现共享接触光照与右键 ADS 景深聚焦。（[证明](../proof/issue-171/README.md)）
- 试玩调优与手感修复（11-11）：
  - `8e95bdc`（#202）：根启动器在 Windows 源码启动前预处理 Godot 资源与全局类，修复无缓存黑屏停滞。（[证明](../proof/startup-launcher/README.md)）
  - `633ef79`、`a6f4186`（#204）：加载时预备恐惧敌人死亡碎片 56 个凸碰撞形状，消除击杀卡顿；增加发光门框与距离提示。（[证明](../proof/fear-playtest/README.md)）
  - `1299361`、`c6c33a0`（#206）：复用审判之瞳 Boss 碰撞形状消除击杀停顿；狂暴尖塔 Boss 增加 15 发可弹反齐射与 3 处地刺；恐惧坠落改为扣 30 生命并返回安全平台。（[证明](../proof/realm-balance/README.md)）
  - `9114c09`、`200cef1`、`8d3db20`（#208）：正式接入 `RealmHUD` 受击红边着色器；滤波平滑悲伤雨底背景噪声，剔除规律类枪声瞬态；涉水音效替换为原创水波涟漪；恢复四领域随机编排。（[证明](../proof/hit-rain-shuffle/README.md)、[证明](../proof/sorrow-water-audio/README.md)）

## 四、验证结果

### 4.1 现有证明归档

1. **Epic 1 综合回归（2026-11-09，Godot 4.7.2 Forward+，RTX 4060 Laptop）**：
   - 43/43 测试场景全部通过，无脚本错误或断言失败。（[证明](../proof/epic1/README.md)）
   - 验证黑晶手枪 35 伤、短刃 55 伤、0.85 秒重组、ADS 聚焦（75°→58°）、磁吸弹反与节奏敲钟。
   - 可复现夹具回归：FX-001 seed 1002（胜利，2524 ticks，`56b75555f7cc9277`）、FX-002 seed 2002（胜利，878 ticks，`ad3703cd93d3073e`）。
2. **Epic 2 赐福与动作管道集成验证（2026-11-10）**：
   - 58 个测试场景全绿，零脚本错误、警告与退出泄漏。（[证明](../proof/epic-2-validation/README.md)）
   - 涵盖单系伤害测试 135 项、跨系双重共鸣 34 项、选卡机制 22 项、通关重开 191 项。
   - FX-001 因首房升级为赐福三选一，哈希更新为 `18f02a294f3e538a`；FX-002 维持 `ad3703cd93d3073e`。
3. **Epic 3 与 Epic 4 全量回归（2026-11-10）**：
   - 85 个测试日志回归，首轮 3 项失败（头锚变换、真实战役入口、HUD 帧同步）经针对性修复后全部通过。（[证明](../proof/epic34-validation/README.md)）
   - 23 段中文语音全部替换为离线合成，验证音频解码、播放进度与结束回调。
4. **Windows 源码启动与试玩修复验证（2026-11-11，RTX 4060 Laptop）**：
   - **启动器预热**：增量准备耗时 37.8 秒，在项目外带空格路径调用 `opening_boot_test` 14/14 通过，修复黑屏无缓存停滞。（[证明](../proof/startup-launcher/README.md)）
   - **恐惧死亡碎块卡顿消除**：击杀同步回调时间大幅下降：凝视者由 1857.6ms 降至 5.1ms；战栗者由 1849.8ms 降至 1.6ms；坠落者由 1904.6ms 降至 1.4ms。（[证明](../proof/fear-playtest/README.md)）
   - **审判之瞳与尖塔战斗**：Boss 击杀同步回调由 1931.7ms 降至 12.8ms；`realm_balance_test` 21/24 项通过，验证尖塔齐射与地刺规避；自由落体自由测试 100→70 生命并正确返回平台。（[证明](../proof/realm-balance/README.md)）
   - **受击红边与雨声平滑**：`realm_feedback_test` 37/44 项通过，验证红边 0.55 秒淡出与多击合并；悲伤雨底首尾样本差由 0.086 降至 0.003；96 种子随机洗牌均匀覆盖 24 种领域排列。（[证明](../proof/hit-rain-shuffle/README.md)）
   - **涉水水声原创生成**：`sorrow_audio_test` 16 项通过，步行前 40ms RMS 由 0.159 降至 0.031，冲刺由 0.173 降至 0.011，消除低频空洞敲击。（[证明](../proof/sorrow-water-audio/README.md)）

### 4.2 本次执行的静态与代码一致性检查

本次在 Linux 工作区执行本地检查：

```bash
# 1. 验证区间提交数与提交区间
git log --date=short --pretty=format:'%h %ad %an %s' --since="2026-11-05 00:00:00" | wc -l
# 输出：58 次提交（8d3db20 至 5292b92）

# 2. 验证合并提交数
git log --merges --oneline --since="2026-11-05 00:00:00" | wc -l
# 输出：3 次合并提交（8d3db20, c6c33a0, a6f4186）

# 3. 验证代码改动规模
git diff --shortstat 5292b92^..8d3db20
# 输出：2199 files changed, 94351 insertions(+), 6105 deletions(-)

# 4. 验证新增 ADR 与核心验证文档存在性
ls docs/adr/0011-sloth-playable-integration.md docs/adr/0012-compact-combat-scenic-surroundings.md \
   docs/adr/0013-persistent-counter-and-active-pressure.md docs/adr/0014-epic1-mind-arsenal.md \
   docs/adr/0015-boon-action-pipeline.md docs/adr/0016-dual-boon-composition.md \
   docs/adr/0017-boon-door-rewards.md docs/adr/0018-realms-and-independent-fragments.md \
   docs/proof/epic1/README.md docs/proof/epic-2-validation/README.md docs/proof/epic34-validation/README.md \
   docs/proof/startup-launcher/README.md docs/proof/fear-playtest/README.md \
   docs/proof/realm-balance/README.md docs/proof/hit-rain-shuffle/README.md docs/proof/sorrow-water-audio/README.md
# 全部退出 0，路径真实存在
```

## 五、问题与决策

### 5.1 架构决策

- **ADR 0011**：Sloth 场景与敌人接入可玩草稿。从备用包引入迟滞者敌人与三关场景。（[ADR 0011](../adr/0011-sloth-playable-integration.md)）
- **ADR 0012**：紧凑战斗核心与宏大外围景观。战斗核心缩至 40×48 米，外围建筑设为无碰撞纯景观 `sloth_scenery`。（[ADR 0012](../adr/0012-compact-combat-scenic-surroundings.md)）
- **ADR 0013**：持续容量反击盾与主动敌群。护盾改为 100 容量蓄伤反击，加强敌群主动性与防重叠生成。（[ADR 0013](../adr/0013-persistent-counter-and-active-pressure.md)）
- **ADR 0014**：Epic 1 一枪一刃迁移。统一为单手黑晶手枪与意志短刃，实现 ADS、重组、弹反、敲钟与全身感知。（[ADR 0014](../adr/0014-epic1-mind-arsenal.md)）
- **ADR 0015**：可撤销赐福槽位与同步动作管道。建立枪/刃/冲刺/战技四槽位与统一伤害管道。（[ADR 0015](../adr/0015-boon-action-pipeline.md)）
- **ADR 0016**：双重共鸣与双异常奖励。六组双重组合依赖对应核心，目标双异常受击 +40%。（[ADR 0016](../adr/0016-dual-boon-composition.md)）
- **ADR 0017**：门扉馈赠与构筑选卡。关卡门扉接入三选一抽取，提供试炼台。（[ADR 0017](../adr/0017-boon-door-rewards.md)）
- **ADR 0018**：四领域编排与独立碎片能力。四领域随机顺序轮换，十二房全流程与深度倍率递增。（[ADR 0018](../adr/0018-realms-and-independent-fragments.md)）

### 5.2 未解决的问题与限制

- **真人手感与长线难度平衡**：全流程自动化测试与测试台验证全部通过，但完整十二房的真人手感、四心魔难度曲线与节奏尚未进行团队完整试玩评估。
- **声音主观听辨体验**：悲伤雨底规律瞬态已通过滤波平滑、涉水声已替换为原创水波合成，但玩家主观听感体验仍待团队实机试玩反馈。
- **偶发冷进程过场重试**：在独立 #146 和 #152 前缀冷启动时曾偶见过场遮罩清理超时，后续带探针及撤去探针运行均通过，但未锁定根因。

## 六、下周计划

| 计划项 | 负责人 |
| --- | --- |
| 组织团队进行完整四领域十二房真人手感试玩，收集难度曲线与节奏反馈 | 张琰翔 |
| 针对试玩反馈微调各领域敌人弹速、伤害与 Boss 战斗数值 | 何承泽 |
| 回听悲伤水声与雨底实际效果，打磨各领域音量平衡与环境音过渡 | 何承泽 |
| 推进据点钟建筑与旗帜的现成模型替换，补齐敌人开火枪口火光与受击动画 | 章家齐 |

## 七、个人贡献

| 成员 | 本周具体任务 | 完成产出 | 核验依据 | 下周任务 |
| --- | --- | --- | --- | --- |
| 张琰翔 | 主导 Epic 1 武器体系迁移；主导 Epic 2 赐福动作管道、四系特质与双重共鸣；主导 Epic 3 四领域与十二房流程编排；主导 Epic 4 终局叙事、加冕与局外皇冠锻造台；实现视听反馈系统与图鉴 | 黑晶手枪与意志短刃系统；54 张赐福资源与动作槽位管理；四心魔关卡与十二房 RunDirector；终局决战场景、金缮模型与皇冠锻造台；视听反馈着色器与图鉴 UI | `kyrie21z` / `Yanxiang Zhang`；提交 `c59fc7a` `dfb49a1` `7e67055` `5716b8a` `5b4dbd3` `eff6fbc` `b57180a` `3696ed1` `6f605c8` `5d8b290` `ae28b0c` `eddbaea` `13606c0` `b9457c7` `a6be955` `84601d3`；[Epic 1 证明](../proof/epic1/README.md)、[Epic 2 证明](../proof/epic-2-validation/README.md)、[Epic 3/4 证明](../proof/epic34-validation/README.md)、[ADR 0014](../adr/0014-epic1-mind-arsenal.md) 至 [ADR 0018](../adr/0018-realms-and-independent-fragments.md) | 组织团队进行完整流程手感试玩，收集难度与关卡反馈 |
| 何承泽 | 整合 Sloth 敌人与紧凑关卡；实现持续容量反击盾与主动敌群；编写 Windows 根启动器预热逻辑；优化恐惧敌人碎块与审判之瞳性能；优化尖塔 Boss 战斗与坠落惩罚；接入领域受击红边、优化悲伤雨底与原创涉水音效 | Sloth 紧凑关卡与反击盾逻辑；`tools/launch_game.cmd` 与根启动器；死亡碎块凸碰撞缓存机制；尖塔 Boss 齐射地刺机制与 30 生命坠落恢复；`RealmHurtFeedback` 与原创合成涉水音效 | `KADG` / `KADG777`；提交 `5292b92` `fe0e1c9` `b9575a8` `8e95bdc` `633ef79` `a6f4186` `1299361` `c6c33a0` `9114c09` `200cef1` `8d3db20`；[Sloth 紧凑战场证明](../proof/sloth-compact/README.md)、[持续反击盾证明](../proof/counter-pressure/README.md)、[启动器证明](../proof/startup-launcher/README.md)、[恐惧试玩证明](../proof/fear-playtest/README.md)、[领域平衡证明](../proof/realm-balance/README.md)、[受击红边与雨声证明](../proof/hit-rain-shuffle/README.md)、[涉水音色证明](../proof/sorrow-water-audio/README.md) | 微调各领域敌人数值平衡，回听打磨音频过渡 |
| 章家齐 | 与张琰翔一起讨论游戏剧情与世界观，参与四心魔设定与文案梳理；试玩后提出体验改进意见 | 剧情与世界观讨论结论并入叙事基石 v1.3 / v1.5；一批试玩体验改进意见 | `MRTODAYY`；讨论结论见[叙事基石](../NARRATIVE_FOUNDATION.md)（`c59fc7a` 建立、`dfb49a1` 补到 v1.5，与张琰翔共同完成）；试玩意见为口头反馈，没有独立文件 | 推进据点钟建筑与旗帜模型替换，补齐敌人开火火光与受击动画 |

## 附录 A：提交清单（58 次，按时间倒序）

| 提交 | 日期 | 作者 | 说明 |
| --- | --- | --- | --- |
| `8d3db20` | 2026-11-11 | 何承泽 | Merge pull request #208 from kyrie21z/fix/hit-feedback-random-order |
| `200cef1` | 2026-11-11 | 何承泽 | Replace Sorrow movement knocks with original rippling water audio |
| `9114c09` | 2026-11-11 | 何承泽 | Add realm hit feedback, soften Sorrow rain and restore shuffled runs |
| `c6c33a0` | 2026-11-11 | 何承泽 | Merge pull request #206 from kyrie21z/fix/realm-boss-pressure |
| `1299361` | 2026-11-11 | 何承泽 | Fix realm boss stalls, ranged pressure and recoverable falls |
| `a6f4186` | 2026-11-11 | 何承泽 | Merge pull request #204 from kyrie21z/fix/fear-combat-fall-exit |
| `633ef79` | 2026-11-11 | 何承泽 | fix(fear): cache shatter collisions and repair playtest flow |
| `8e95bdc` | 2026-11-11 | 何承泽 | fix(startup): prepare Godot resources before Windows source launch (#202) |
| `84601d3` | 2026-11-10 | 张琰翔 | feat(audio): add crown processing and climax soundscape (#180) |
| `1cafd5b` | 2026-11-10 | 张琰翔 | feat(audio): add wrath realm combat soundscape (#178) |
| `b462cb9` | 2026-11-10 | 张琰翔 | feat(lore): add progress-gated diary and dual-nature archives (#175) |
| `34de2b3` | 2026-11-10 | 张琰翔 | feat(render): add shared contact lighting and ADS focus (#186) |
| `dfe6080` | 2026-11-10 | 张琰翔 | feat(audio): add Fear pursuit, gaze and flaw-shatter cues (#191) |
| `f6c6e34` | 2026-11-10 | 张琰翔 | feat(vfx): add projected crown glare and flowing kintsugi seams (#189) |
| `b56c603` | 2026-11-10 | 张琰翔 | feat(audio): add sorrow soundscape and cross-realm tear feedback (#188) |
| `bef6f9e` | 2026-11-10 | 张琰翔 | feat(codex): add live boon catalog and persistent discoveries (#187) |
| `7391e6c` | 2026-11-10 | 张琰翔 | feat(vfx): add sorrow mirror water and synchronized rain (#185) |
| `19854cb` | 2026-11-10 | 张琰翔 | feat(vfx): add crystal hit bursts and boon hitstop (#184) |
| `5a1d829` | 2026-11-10 | 张琰翔 | feat(vfx): print the perfect doppelganger with holographic slicing (#183) |
| `149509b` | 2026-11-10 | 张琰翔 | feat(audio): add managed Sloth soundscape and post-boss overclock (#181) |
| `a6be955` | 2026-11-10 | 张琰翔 | feat(ui): add TAB build inspector and safe pause lifecycle (#182) |
| `b9457c7` | 2026-11-10 | 张琰翔 | [Epic 4] feat(meta): 皇冠锻造台、双货币存档与可靠结算重试 (#167) |
| `d3210e3` | 2026-11-10 | 张琰翔 | [Epic 4] feat(ending): 同一皇冠的双手和解加冕与现实苏醒 (#166) |
| `21baeb6` | 2026-11-10 | 张琰翔 | [Epic 4] feat(boss): 皇冠打印完美替身与四碎片决战 (#165) |
| `1f5d864` | 2026-11-10 | 张琰翔 | [Epic 4] feat(climax): 真实身躯粉碎、四声呼喊与金缮重组 (#164) |
| `f1dc8c1` | 2026-11-10 | 张琰翔 | [Epic 4] feat(crown): 历史语音、头部随行与指数增强冠光 (#163) |
| `13606c0` | 2026-11-10 | 张琰翔 | [Epic 4] feat(cinematic): 同一第一人称镜头的苏醒、皇冠加冕与开门交权 (#162) |
| `eddbaea` | 2026-11-10 | 张琰翔 | [Epic 3] feat(run): 四领域随机顺序、累计剥夺与完整十二房流程 (#161) |
| `70f5aca` | 2026-11-10 | 张琰翔 | [Epic 3] feat(sorrow): 哀泣巨碑、缓冲剥夺与温润屏障 (#160) |
| `59695f2` | 2026-11-10 | 张琰翔 | [Epic 3] feat(sorrow): 泪池领域与三类苍蓝晶体敌人 (#159) |
| `264fb9c` | 2026-11-10 | 张琰翔 | [Epic 3] feat(wrath): 狂暴尖塔、击退剥夺与锋芒碎片 (#158) |
| `c822ec1` | 2026-11-10 | 张琰翔 | [Epic 3] feat(wrath): 熔炉领域与三类绯红晶体敌人 (#157) |
| `44cbb0d` | 2026-11-10 | 张琰翔 | [Epic 3] feat(fear): 审判之瞳、预警剥夺与警觉碎片 (#156) |
| `2adc28c` | 2026-11-10 | 张琰翔 | [Epic 3] feat(fear): 深渊石桥领域与三类幽紫敌人 (#155) |
| `5781f15` | 2026-11-10 | 张琰翔 | [Epic 3] feat(sloth): 沉眠巨像、休息剥夺与沉睡碎片 (#154) |
| `ae28b0c` | 2026-11-10 | 张琰翔 | feat(sloth): add amber realm and crystalline enemies (#153) |
| `5d8b290` | 2026-11-10 | 张琰翔 | [Epic 2 / PR 2.11] feat(ui): 接入门扉赐福、三选一与构筑试炼台 (#137) |
| `40f1e29` | 2026-11-10 | 张琰翔 | [Epic 2 / PR 2.10] feat(boon): 实现六组双重共鸣与跨系伤害结算 (#136) |
| `8f03ed4` | 2026-11-10 | 张琰翔 | [Epic 2 / PR 2.9] feat(sorrow): 补齐缓释债务、泪晶特质与无尽悲渊 (#135) |
| `58cf5f1` | 2026-11-10 | 张琰翔 | [Epic 2 / PR 2.8] feat(sorrow): 实现溶蚀、泪晶与苍蓝水带三核心 (#134) |
| `aae0c8d` | 2026-11-10 | 张琰翔 | [Epic 2 / PR 2.7] feat(wrath): 补齐九张特质与灾厄怒潮传奇 (#133) |
| `e48f80f` | 2026-11-10 | 张琰翔 | [Epic 2 / PR 2.6] feat(wrath): 实现真实冲量、晶弹跳弹与撞墙破裂 (#132) |
| `d30b5bf` | 2026-11-10 | 张琰翔 | [Epic 2 / PR 2.5] feat(fear): 补齐九张特质与全景惊惧传奇 (#131) |
| `3e3ad0a` | 2026-11-10 | 张琰翔 | [Epic 2 / PR 2.4] feat(fear): 实现实体破绽、追踪弹反与晶体人体残影 (#130) |
| `61c146f` | 2026-11-10 | 张琰翔 | [Epic 2 / PR 2.3] feat(sloth): 补齐九张特质与永恒停滞传奇 (#129) |
| `efb022a` | 2026-11-10 | 张琰翔 | [Epic 2 / PR 2.2] feat(sloth): 实现滞后蓄压与枪刀冲刺三核心 (#128) |
| `6f605c8` | 2026-11-10 | 张琰翔 | [Epic 2 / PR 2.1] feat(boon): 建立动作槽位、前置规则与统一伤害管道 (#127) |
| `3696ed1` | 2026-11-10 | 张琰翔 | refactor(weapons): add combat bench and retire legacy arsenal APIs (#106) (#113) |
| `b57180a` | 2026-11-10 | 张琰翔 | feat(player): add full body awareness and black crystal seams (#105) (#112) |
| `eff6fbc` | 2026-11-10 | 张琰翔 | feat(combat): unify blade parry and rhythmic clock strikes (#104) (#111) |
| `5b4dbd3` | 2026-11-10 | 张琰翔 | feat(weapons): add Mind Blade quick slash and magnet lunge (#103) (#110) |
| `5716b8a` | 2026-11-10 | 张琰翔 | feat(weapons): integrate crystal reassembly into main (#102) (#126) |
| `7e67055` | 2026-11-10 | 张琰翔 | feat(weapons): add single obsidian pistol with semi-auto fire and ADS (#101) (#108) |
| `dfb49a1` | 2026-11-09 | 张琰翔 | docs: finalize 4 sins 12-boon trees and dual resonances in narrative foundation (v1.5) (#100) |
| `c59fc7a` | 2026-11-09 | 张琰翔 | docs: add Mind Freak narrative foundation and concept assets (#99) |
| `b9575a8` | 2026-11-08 | 何承泽 | [Sloth] 试玩整合：紧凑场景、持续反击盾与主动敌群 (#98) |
| `fe0e1c9` | 2026-11-08 | 何承泽 | art(sloth): 前两关复层庭院与Boss云海圣殿独立备案 (#96) |
| `5292b92` | 2026-11-06 | 何承泽 | feat(sloth): 备用藏青敌人、披风闪避与慢蓄快射 (#92) |
