# 04: 心智碎片续航收敛（沉睡单房上限 + 温润屏障收紧）与跨房边界

- **GitHub Issue**: `#260`
- **Parent Spec**: `#256` (`.specs/difficulty-curve-phase-a/spec.md`)
- **Blocked by**: `#257` (Ticket 01)
- **Status**: `done`

## What to build

收敛两枚续航型心智碎片的无限保底能力，在保留碎片独立保护手感的同时恢复跨 12 房的血量管理张力：

1. **沉睡碎片（`SLOTH`）单房回血上限**：
   - 在 `PsycheFragments` 新增常量 `SLUMBER_ROOM_HEAL_CAP := 30.0` 与房间已回复量 `room_healed := 0.0`。
   - 脱战满 5 秒后维持 `2.0 HP/s` 回血速率，但单帧实际回复受剩余房间额度 `SLUMBER_ROOM_HEAL_CAP - room_healed` 钳制；达到 `30.0` 后本房停止继续回血（避免清房后挂机回满血）。
   - 提供 `reset_room_healing()` 显式重置当前房间的 `room_healed = 0.0`。
2. **跨房与同房状态持久化边界（`RunDirector`）**：
   - `capture_player()` / `restore_player()` 持久化 `room_healed`，确保同一房间内快照恢复或诊断重载不会白嫖重置已消耗的回血额度。
   - `advance_room()` 推进到下一个真实房间时，将快照中的 `room_healed` 重置为 `0.0`，使玩家进入新房间后重新获得 `30 HP` 的休整预算；同时保持既有规则：换房不重置温润屏障冷却、锋芒蓄力与脱战计时。
3. **温润碎片（`SORROW`）护盾容量与恢复延迟收紧**：
   - `TENDERNESS_CAPACITY` 由 `60.0` 调整为 `40.0`；受击重置的恢复延迟由 `4.0s` 拉长至 `6.5s`；恢复速率保持 `6.0/s`。
   - 保持既有 `unbuffered` 剥夺隔离契约：普通护盾与减伤继续禁用，温润屏障仅经 `fragment_absorber` 独立吸收，暂停冻结恢复。
4. **同步更新既有碎片与组合根回归测试**：更新 `slumber_fragment_test`（补充单房 `30 HP` 封顶与重置断言）、`tenderness_fragment_test`（对齐 `40` 上限与 `6.5s` 恢复延迟）及 `run_director_test`（验证同房保留 `room_healed`、跨房推进重置 `room_healed`）。

## Acceptance Criteria

- [ ] 沉睡碎片脱战 5 秒后按 `2.0 HP/s` 恢复，单房累计达到 `30.0 HP` 后自动停止继续回血；暂停与 12 米内可见活敌仍正确阻断回血。
- [ ] 同房内 `RunDirector.capture_player()` / `restore_player()` 保留 `room_healed` 不重置；通过 `advance_room()` 进入新房后 `room_healed` 重置为 `0.0`，且温润冷却与锋芒蓄力仍跨房保留。
- [ ] 温润碎片激活后提供 `40.0` 独立屏障、受击后等待 `6.5s` 才开始按 `6.0/s` 回复、暂停冻结，且仍完全隔离普通护盾/减伤/缓释。
- [ ] `tests/slumber_fragment_test.tscn`、`tests/tenderness_fragment_test.tscn`、`tests/run_director_test.tscn` 与 `tests/flawless_combat_test.tscn` 全部通过。
