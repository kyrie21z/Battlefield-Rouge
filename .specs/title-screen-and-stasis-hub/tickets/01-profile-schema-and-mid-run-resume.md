# 01: 档案扩展与换房中途续关闭环

- **GitHub Issue**: `#272`
- **Parent Spec**: `#271` (`.specs/title-screen-and-stasis-hub/spec.md`)
- **Blocked by**: None
- **Status**: `ready-for-agent`

## What to build

建立向后兼容的档案元信息与房间边界自动续关能力，并严格守卫反 S/L 经济与状态不变量：

1. **`MetaProgressionStore` v1 存档扩展与兼容**：
   - 在保持 `VERSION := 1`、既有 SHA-256 校验和与 `.bak` 原子写盘机制的前提下，在持久化 `payload` 中新增两个可选字段：`opening_completed: bool` 与 `active_run: Dictionary`。
   - **向后兼容**：读取缺失上述字段的旧版 v1 存档时绝不视为损坏；`opening_completed` 推断为 `history.run_count > 0 or not settled_runs.is_empty() or not visited_realms.is_empty()`，`active_run` 默认 `{}`。
   - **严格 Schema 校验**：`active_run` 非空时校验 `run_id` 非空且不在 `settled_runs` 中、`order` 为 `[0, 1, 2, 3]` 合法排列、`floor_index ∈ [0, 4]`、`room_index ∈ [0, 2]`（`floor_index == 4` 时要求 `room_index == 0` 且 `defeated.size() == 4` / `shards.size() == 4`）、`defeated` / `deprivations` / `shards` 无重复且合法、`boon_ids` 均可由 `BoonCatalog` 解析且核心槽位不冲突、`hp > 0`、`rerolls ∈ [0, 10]`、`earned_will >= 0`、`earned_anchors >= 0`、`entry_reward_claimed` 与 `defiance_consumed` 为 `bool`。
   - 新增公开接口：`has_profile() -> bool`、`has_active_run() -> bool`、`has_affordable_upgrade() -> bool`、`mark_opening_completed() -> bool`、`save_active_run(snapshot: Dictionary) -> bool`、`clear_active_run() -> bool`、`reset_profile() -> bool`（重置前将当前有效存档备份至 `.bak`，清空全部进度与 `active_run` 并原子写盘）。
   - `settle_run(...)` 同步支持原子清空 `active_run`，避免结算成功但残局残留。
2. **`RunDirector` 房间边界落盘、冷重启续关与残局放弃**：
   - 仅在三个安全边界持久化 `active_run`：
     1. 新局准备完成进入首房 `0:0`（`entry_reward_claimed = false`、`earned_will = 0`、`earned_anchors = 0`）；
     2. `0:0` 完成开局三选一后（置 `entry_reward_claimed = true` 并更新玩家快照）；
     3. 每次过门调用 `advance_room()` 推进到下一房（含抵达第 5 层终局返程回廊）后，记录当前已清房累计的 `earned_will` / `earned_anchors`、已捕获玩家构筑/血量/碎片状态（`room_healed = 0.0`）与 `MetaProgression.defiance_consumed`。
   - 新增 `resume_run() -> bool`：从 `MetaProgression.active_run` 精确还原全部战役状态（`run_id`、`run_seed`、`order`、`floor_index`、`room_index`、`defeated`、`deprivations`、`shards`、`hp`、`boons`、`fragment_state`、`rerolls`、`selections`、`earned_will`、`earned_anchors`、`crown_strength`），并同步恢复 `MetaProgression.active_run_id` 与 `defiance_consumed`，随后安装对应房间且不重复触发历史开局语音。
   - 新增 `abandon_active_run() -> bool`：结算 `active_run` 中已安全锁定的 `earned_will` / `earned_anchors`（按 `run_id` 去重）并原子清空 `active_run`。
   - 死亡（`record_death`）与终局和解（`finish_campaign`）结算时原子清空 `active_run`。
3. **`RealmStage` 防重复发卡接入**：
   - 新增可注入标记 `skip_entry_reward := false`：当 `RunDirector` 续关恢复到 `0:0` 且 `entry_reward_claimed == true` 时置为 `true`，跳过 `offer_entry_reward`；未领取过开局卡时照常按原 `run_seed` 发出确定性三选一。
4. **单元测试补强**：
   - 在 `meta_forge_test` 与 `run_director_test` 中补齐旧 v1 档兼容、`active_run` 篡改校验、`reset_profile()` 备份、换房续关冷重启还原与 4 条防 S/L 不变量断言。

## Acceptance Criteria

- [ ] 旧版缺失 `opening_completed` / `active_run` 的有效 v1 存档可无损加载；非法或引用已结算 `run_id` 的 `active_run` 被校验拒绝并走 `.bak` 恢复/只读保护。
- [ ] `reset_profile()` 重置后 `has_profile() == false`、`opening_completed == false`、`active_run` 为空，且重置前有效档案已保留为 `.bak`。
- [ ] 推进至 `0:0` 选卡、跨房 `advance_room()` 与抵达第 5 层返程回廊时均自动落盘 `active_run`；重建存储与组合根状态执行 `resume_run()` 后，完整还原楼层、房间、领域顺序、血量、赐福、碎片、剥夺、重抽次数、复活消耗与已锁货币。
- [ ] 守卫全部 4 条防 S/L 不变量：未清房击杀不写入 `active_run`；已选 `0:0` 开局卡后续关不重发三选一；已消耗 `defiance` 续关不刷新复活；死亡/终局/放弃结算后 `active_run` 被原子清空且旧 `run_id` 不可二次结算。
- [ ] `meta_forge_test`、`run_director_test` 与 `fixture_test`（AC-07）全部通过，零全局 RNG 漂移。
