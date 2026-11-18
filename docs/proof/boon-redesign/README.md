# 赐福发牌改版（2026-11-18）

## 做了什么

1. **门扉改为全池发牌**：不再限定"这个房间只出本领域的卡"，从全部 54 张里抽（`RealmStage._offer_reward` 传入 `sin_filter = -1`）。
2. **强化卡必须先有同系核心**：新增 `BoonManager.has_sin_core()`，`can_equip` 里对 `core == false` 且非双重卡强制检查。第一轮门扉因此必然三张都是核心卡，天然形成"先定打法、再深挖"。
3. **开局多一次三选一**：`RealmStage.offer_entry_reward` 在新一局第一关进场后（延后一帧，避开 `RunDirector.restore_player` 的整组恢复）弹出，给同一领域枪/刃/冲刺三张核心。
4. **每轮最多一张替换卡**：发牌按"会替换现有核心"与"不会替换"分层，替换位只给 1 张，且该位优先给未投资过的领域；三张全是替换卡时，界面给出"放弃这次馈赠"。
5. **领域机制说明改为卡片悬浮栏**：删除选卡前的一次性 `RealmIntro` 面板，机制文字挂到每张卡的悬浮说明；双重卡同时列两系。`RealmIntro` 类保留给截图与独立诊断。

## 权重与分布

卡池 54 张：4 领域 × 12（3 核心 + 6 强化 + 2 史诗 + 1 传说）+ 6 双重。
基础权重按稀有度 普通 6 / 稀有 4 / 史诗 2 / 传说 1 / 双重 1。

用截图那套卡组（枪=恐惧、刃=怠惰、冲刺=恐惧）跑 30000 轮：

| 指标 | 改版前 | 改版后 |
|---|---|---|
| 抽到的卡里"会替换"的占比 | 55.9% | **33.3%**（每轮恰好 1 张） |
| 三张全是替换卡的轮次 | 14.9% | **0.0%** |
| 每轮能看到"未投资系核心"的轮次 | 约 10% | **80.1%** |

开局空手时四系仍各 25%，不受影响。完整数据见 `distribution.txt`。

## 复现

在项目根目录运行：

```
godot --headless --path . res://tests/boon_pipeline_test.tscn
godot --headless --path . res://tests/boon_offers_test.tscn
godot --headless --path . res://tests/boon_replacement_test.tscn
godot --headless --path . res://tests/realm_intro_test.tscn
godot --headless --path . res://tests/realm_stage_test.tscn

# 分布统计（需要 Python 3）
python docs/proof/boon-redesign/boon_dist.py
```

## 结果

| 测试 | 结果 |
|---|---|
| `boon_pipeline_test` | 64 checks / 0 failed |
| `boon_offers_test` | ALL PASSED |
| `boon_replacement_test` | 7 checks / 0 failed（全替换可放弃、混入特性时按钮消失） |
| `realm_intro_test` | 13 checks / 0 failed（不再弹面板、悬停写入机制栏、开局给一次选择） |
| `realm_stage_test` | 27 checks / 0 failed |

原始输出见同目录 `*.log`。

## 未覆盖 / 限制

- **没有截图**：`boon_text_shots` 与 `hud_proof` 需要窗口渲染，本目录只含 headless 断言与统计。
- 数值（每轮 1 张替换位、未投资系权重 ×2、开局给同系三槽核心）是设计默认，不是验收结论；试玩后仍可能调整。
- `MetaProgression.realm_needs_intro` / `mark_realm_introduced` 已无生产调用者，但存档字段 `introduced_realms` 仍保留，避免旧档字段变孤儿。
