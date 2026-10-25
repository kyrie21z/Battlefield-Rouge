# 架构与依赖规则

引擎：Godot 4.7.2，Forward+，Jolt 物理。所有人必须用同一个版本。

## 目录

| 目录 | 放什么 |
| --- | --- |
| `autoload/` | 全局单例：`Events`（信号总线）、`RunState`（本局状态）、`InputMapSetup`（按键） |
| `components/` | 可复用的小部件：生命值、受击判定、数值（Stats） |
| `weapons/` | 武器数据（`.tres`）和开火逻辑 |
| `actors/` | 玩家、敌人 |
| `zone/` | 战区控制（zone director）、据点 |
| `buffs/` | 增益，每个增益一个 `.tres` |
| `ui/` | HUD、三选一增益界面、结算界面 |
| `maps/` | 战区场景，由 `tools/gen_zones.py` 生成 |
| `tools/` | 编辑器外的辅助脚本 |
| `docs/` | 设计文档。范围和验收以 `docs/Cut-001.md`、`docs/MVP_Scope.md` 为准 |
| `docs/adr/` | 架构决策记录 |

## 依赖规则

1. `components/`、`weapons/`、`actors/` 只向 `Events` 发信号，不读写 `RunState`，也不通过路径或分组去找别的系统。
2. 只有 `RunState` 和 `zone/` 下的战区控制可以改本局状态。
3. 增益只修改 `Stats`，不直接改玩家或武器脚本。新增增益只需要加一个 `.tres`。
4. 依赖方向只能是 `ui → zone → actors → components`，反过来要用信号。
5. 从 `../origin/sheji` 迁移代码时，先删掉对 `GameState`、`VoiceManager`、突破模式、载具、商店的引用，再放进来。

## 一个战区的流程

本节是**现在代码**在做什么：清敌，再站圈占点。设计目标已改为 Cut-001（`docs/Cut-001.md`）：小关先清零再锤砸，完美窗口 ±150ms，普通锤 +8%，完美 ×1.5。实现那套循环时再改本节，不要提前改掉下面的依赖规则。

由 `zone/zone_director.gd` 执行，场景里的节点顺序是：几何 → 掩体点 → 据点 → 玩家 → 敌人 → `ZoneDirector` → `HUD`。HUD 放在最后，保证它 `_ready` 时战区控制已经准备好。

1. 烘焙导航网格，把 `RunState.buffs` 应用到玩家的 `Stats`，把玩家和掩体点交给每个敌人。
2. 敌人全部死亡 → `Events.zone_cleared`，据点开放。
3. 据点占满 → `Events.point_captured`。不是最后一个战区就暂停并弹出三选一；选完发 `Events.buff_chosen`（`RunState` 记下增益），`RunState.advance_zone()`，切到下一个战区场景。最后一个战区则发 `Events.run_won` 并显示胜利界面。
4. 玩家死亡 → `Events.player_died`，`RunState` 清空本局，显示阵亡界面。重新开始回到第 1 个战区。

新增战区：在 `tools/gen_zones.py` 里加一个布局，生成后把场景路径加到 `RunState.ZONE_SCENES`。

## 碰撞层

定义在 `components/collision_layers.gd`，代码里不要直接写数字。

| 层 | 常量 | 放什么 |
| --- | --- | --- |
| 1 | `WORLD` | 场景几何和道具 |
| 2 | `ACTORS` | 玩家和敌人的移动碰撞体 |
| 4 | `HITBOXES` | 受击判定 |

子弹（玩家的射线、敌人的慢速弹）只检测 `WORLD | HITBOXES`。角色的移动碰撞体和受击判定位置重叠，子弹如果检测 `ACTORS`，会先打在移动碰撞体上而打不到受击判定。

## 从旧工程迁移

旧工程在 `../origin/sheji`，只当参考，不修改。迁移顺序和原因见 `docs/adr/0001-rebuild-on-clean-skeleton.md`。
