# 天赋球接入（Talent Orb）

## 接在哪：`zone/realm_stage.gd`（正式四领域流程）

第一次接错到了 `zone/buff_pedestal.gd`，那是 `zone_director.gd` 用的**旧流程**（fixture / 独立测试）。
正式开局走的是 `RunDirector → RealmStage`，你截图里那个「下一关 / 靠近后按 F 进入」的门
是 `RealmStage._build_gate()` 建的。现在球接在正式流程上。

## 流程改动

**之前**：清完敌人 → `_check_clear()` → **立刻** `_offer_reward()` → 三选一盖住屏幕。

**现在**：

```
清完敌人
  → _check_clear() → _spawn_talent_orb()
      球在门前 1.95 米处出现，播出场演出
  → 玩家走近（≤ 2.8 米），HUD 提示「天赋 · N 米 / 按 F 取回」
  → 按 F → claim_talent()
      球缩小升空消失（0.3 秒），随后 _offer_reward()
  → 三选一
  → 选完 _finish_reward() → 门变青绿 → 再按 F 进入下一关
```

门的开启时机没变，仍然是**选完卡之后**（`_finish_reward` 里改 `_gate_material` 颜色）。

## 出场演出：碎片组装

**不是**整体弹出，而是**球壳自己的装甲块从四周飞回来拼成**。

`TalentOrb.scatter(1.9)` 把外壳拆开：

- **全部 113 个 mesh 都参与**，包括底层球壳、深色内环、开口唇和封底
- 散开距离按 `AABB 尺寸` 反比缩放：`weight = clamp(1.15 - extent × 0.55, 0.22, 1.0)`
  大球壳只飘 `×0.22`（几乎原地），小装甲块飘到满 `1.9 m`
- 每块沿**黄金角**（`i × 2.399963`）方向飞出，自转，按 `lerp(1.0, 0.78, weight)` 缩小
- 全程用索引推导，**不调 `randf()`** —— fixture 回放每次拼成一模一样的姿态（AC-07）

### 从虚空浮现

碎片**不是一次性全部出现**，也不是硬切 `visible`：

- `scatter()` 把每块放到散开位的 **2 倍远**（`home.origin + dir * spread * 2.0`），
  `transparency = 1.0`（完全透明），但 `visible = true` —— 已经在渲染，只是看不见
- `reveal_pieces()` 让每块错开 `i × 0.020 s` 起步，在 `0.85 秒` 内**同时**做两件事：
  - `transform` 从远处飘到散开位（`TRANS_SINE / EASE_OUT`）
  - `transparency` 从 `1.0` 降到 `0.0`（淡入）
- **浮现和归位共用同一条时间线**：第 i 块在 `i × 0.020` 开始淡入，`i × 0.020 + 0.70` 就开始飞回原位。
  不需要等全部出现——之前等最后一块（2.4 秒）才组装，先出现的碎片会原地悬停，视觉上就是「所有零件飘着不动」

于是画面是：一块、两块……从黑暗里慢慢飘出来亮起，而不是齐刷刷弹出来。

`TalentOrb.assemble(1.60, 0.70)`：每块从自己的 `i × 0.020` 起算再等 `0.70 秒` 开始飞回，
单块 `1.60 秒`，`TRANS_BACK / EASE_OUT` 带回弹，同时 `emission` 在 `1.60 × 1.2 秒` 内褪到 0。

**总时长约 4.6 秒**（113 × 0.020 + 0.70 + 1.60），全程没有静止段—— 站在远处也能看清整个过程，
来得及走过去。

同时并行的四层：

| 元素 | 动作 |
|---|---|
| 碎片浮现 | 逐块从远处淡入，与归位共用时间线 |
| 碎片归位 | 浮现后 0.70 秒立刻起飞，总时长约 4.6 秒 |
| 地面光环 | `TorusMesh` 半径 ×0.25 → ×3.4，`EXPO/OUT` 扩散 **2.6 秒**，alpha 同步归零 |
| 光柱 | `CylinderMesh`（r 0.42→0.78，高 4.5），ADD 混合，0.30 秒闪光后 **3.4 秒**淡出 |
| 点光 | `OmniLight3D` 0 → 7 → 0，range 9 米 |

立方体 `set_core_visible(false)` 一开始是隐藏的，**外壳拼完之后才点亮**，所以出场过程是
「黑壳成形 → 中心亮起」。

演出期间 `set_idle_enabled(false)` 让 tween 独占 transform，结束后交还给 `_process` 的浮动。

**收尾不能跳**：`set_idle_enabled(true)` 会把 bob 相位对齐到球当前高度
（`_bob_phase = asin((y - base_height) / bob_height)`，`_bob_clock = SimClock.now()`），
`_process` 用 `sin((t - _bob_clock) × bob_speed + _bob_phase)`。
之前直接用全局 `sin(t × bob_speed)`，`t` 是关卡启动后的秒数（可能已经 30+ 秒），
`sin(27)` 落在任意相位上，恢复浮动的瞬间球会突然上下跳 0~0.16 米 —— 就是那个"小位移"。
实测对齐后 `before=1.2800 after=1.2800`，下一帧只变化 0.0024 米。
因为是 `PAUSABLE` 节点，三选一一打开（暂停）演出也会跟着停。

## 交互

`RealmStage._unhandled_input`：

```gdscript
if event.is_action_pressed("interact"):
    if _orb_ready and talent_orb.player_in_range(player):
        claim_talent()          # 球优先于门
        return
    if request_exit(): ...      # 原来的进门
```

球的交互半径 `TalentOrb.INTERACT_RANGE = 2.8`，门的进门半径仍是 3.0，不冲突——
球被领走后 `_orb_ready = false`，F 自然回到门身上。

## HUD

`ui/realm_hud.gd` 的 `_exit_hint`：

| 状态 | 字号 | 位置 | 文字 | 颜色 |
|---|---|---|---|---|
| 球未领 | **34** | **屏幕中下方固定**（`y = 70%`，560×116）不跟随 3D 点 | `按 F 取回天赋`；超出范围显示 `天赋球 · 前方 N 米 / 朝标记方向前进` | 金色 `(1.0, 0.86, 0.42)`，`sin` 脉动 |
| 门已开 | 30 | 跟随门（原逻辑） | `下一关门扉 · N 米` | 青蓝 |

两种状态都加了 `StyleBoxFlat` 底板（深色 72% 不透明、2px 青色描边、8px 圆角、10px 内边距）。

`RealmStage` 新增 `orb_pending()` 供 HUD 查询，HUD 不直接读私有字段。

## 文件

```
objects/talent_orb/
├── orb_shell.glb    1.07 MB
├── orb_core.glb     153 KB
└── talent_orb.gd    朝向 / 浮动 / 立方体自转 / 主题色 / INTERACT_RANGE

zone/realm_stage.gd       + talent_orb, _orb_ready, _spawn_talent_orb(),
                            _play_orb_arrival(), claim_talent(), orb_pending()
                            _check_clear() 改调 _spawn_talent_orb()
                            _unhandled_input 加球优先分支
ui/realm_hud.gd           _exit_hint 加「天赋」分支

zone/buff_pedestal.gd     旧流程的灰盒也换成了球（保留契约，不影响正式流程）
tests/talent_orb_preview.tscn     单球预览
tests/talent_gate_preview.tscn    门前构图 + 完整出场演出预览
```

## 验证

```bash
godot --path . res://tests/talent_gate_preview.tscn --resolution 1100x700
```

自动截 `docs/proof/talent-orb/gate-1..4.png`（第 8 / 26 / 60 / 130 帧）后退出。

回归测试：

| 测试 | 结果 |
|---|---|
| `hud_test` | ALL PASSED（282 checks, 0 failed） |
| `buff_run_test` | ALL PASSED |
| `reinforcement_test` | ALL PASSED（77 checks） |

## 截图

- `gate-2.png` 出场中：光柱下落、光环扩散、球正在弹起
- `gate-4.png` 稳定态：球悬浮在门前，开口朝向玩家
- `preview-1..3.png` 单球预览（无门）

## 可调

| 想改 | 改哪 |
|---|---|
| 球离门多远 | `realm_stage.gd` 里 `away * 1.95` |
| 交互半径 | `TalentOrb.INTERACT_RANGE`（默认 2.8） |
| 浮动幅度 | `TalentOrb.bob_height`（默认 0.16） |
| 演出时长 | `_play_orb_arrival()` 里的 tween 时长常量 |
