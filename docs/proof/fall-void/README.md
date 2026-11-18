# 四领域统一坠落边界（2026-11-18）

## 做了什么

- 新增 `environments/realm_void.gd`：一个领域共用的坠落边界组件。
- 四个领域全部接入：`sloth`、`fear`、`wrath`、`sorrow` 的 `realm.gd` 在构建几何后安装它。
- `FearRealm` 原本自带一份等价实现（`_build_void` / `_queue_recovery` / `_fatal_fall` 等约 100 行），现已删除并改为同一个组件；它继续通过 `abyss` 字段转发体积，既有诊断与测试不用改。
- 三个非恐惧领域顺带补齐了 `player_spawn()` / `exit_position()`，数值与原默认值一致（出生 z=16、出口 z=-20），关卡布局未变。

## 规则

| 对象 | 结果 |
|---|---|
| 玩家掉出战场 | 扣固定 **30 点真实生命**（绕过护盾、无敌、减伤），送回上一次整块稳定地面；扣到 0 才死 |
| 敌人 / 其它角色掉出 | 走 `environmental_fatal`，一次扣光全部生命，**不消耗护盾、不留残血** |
| 判定 | 低于地图原点 −12 米，或进入下方 180×8×180 的兜底体积 |
| 防连触发 | 0.3 秒冷却，避免同一帧重复结算 |
| 落点校验 | 脚下必须有 WORLD 支撑、法线朝上，胶囊不与世界或敌人重叠；失败则从出生点九宫格挑选，仍失败退回出生点 |

坠落伤害是唯一常量（`RealmVoid.FALL_DAMAGE = 30.0`），难度倍率不影响它。

## 复现

在项目根目录运行（Godot 4.7.2）：

```
godot --headless --path . res://tests/realm_void_test.tscn
godot --headless --path . res://tests/fear_realm_test.tscn
godot --headless --path . res://tests/fear_playtest_test.tscn
```

## 结果

| 测试 | 结果 |
|---|---|
| `realm_void_test` | **24 checks / 0 failed**（四关各 6 项：装上边界 / 敌人致死 / 玩家 −30 / 30 点不致死 / 回到地面 / 第二次再扣 30） |
| `fear_realm_test` | 32 checks / 0 failures（含"坠渊扣 30 并把玩家送回"的原断言） |
| `fear_playtest_test` | 30 checks / 0 failures（含"血量不足时坠渊导致真实死亡并记录 `abyss` 死因"） |

原始输出见同目录 `realm_void.log`、`fear_realm.log`、`fear_playtest.log`。

## 未覆盖 / 限制

- **没有截图**：全部为 headless 断言。视觉证明需要窗口运行，本目录未包含。
- 玩家被击退到边界外但仍高于 −12 米时不会触发（会先落地或卡在墙上）；这是有意的，避免把"贴边"误判成坠落。
- 坠落触发后玩家落在安全点，若安全点恰好在敌人身上，落点校验会改挑九宫格里的另一个位置；极端情况下退回出生点。
