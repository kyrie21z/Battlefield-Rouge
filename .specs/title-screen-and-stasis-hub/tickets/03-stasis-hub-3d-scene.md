# 03: 标配 3D「静滞之门」大厅与死亡归来复盘闭环

- **GitHub Issue**: `#274`
- **Parent Spec**: `#271` (`.specs/title-screen-and-stasis-hub/spec.md`)
- **Blocked by**: `#272` (Ticket 01), `#273` (Ticket 02)
- **Status**: `done`

## What to build

落地标配 3D「静滞之门」局外成长大厅（`StasisHub`），让皇冠锻造、心象日记/赐福图鉴、皇冠复盘对白与穿门出征在真实紧凑的纯白建筑空间内闭环运作：

1. **紧凑纯白柱廊 3D 大厅（`StasisHub`）**：
   - 复用开场序列的极简纯白/浅灰柱廊语言与 `default_env.tres` 的 SSAO/SSIL 光照规范；总深约 22m、宽 16m，出生点位于中央 `(0, 0.02, 2.0)`，正前方约 9m 为常开的心智之门（按冲刺 3 秒即可穿门出发，拒绝跑图拖沓）。
   - 实例化真实第一人称 `Player`（保留移动、视角、冲刺与低头身躯感知；在大厅内收起/禁用武器开火避免误射击；即时调用 `MetaProgression.apply_to_player(player)` 同步永久天赋）并挂载 `CrownVoiceSystem` 与 `PauseMenu`（`ESC` 支持设置调参及「返回标题画面」）。
2. **左侧实体皇冠锻造台（The Crown's Forge Altar）**：
   - 放置于出生点左侧约 4m 处：极简白石斜切基座 + 上方轻缓自转的实体微缩 `CrownModel`；当 `MetaProgression.has_affordable_upgrade()` 为真时，台座发出克制的暗金脉冲提示。
   - 玩家走近并面向台座时显示 Scheme B 世界/屏幕交互提示 `[F] 皇冠锻造台`，按 `interact` 打开现有 `CrownForge`（传入 `MetaProgression` 与大厅 `player`）；关闭面板后自动回到大厅，升级后的生命上限/冲刺格数/弹匣立即反映到大厅玩家，并保持台座脉冲状态实时刷新。
3. **右侧四心魔立柱与静滞档案碑**：
   - 放置于出生点右侧约 4m 处：四根并列细长白晶立柱（怠惰/恐惧/愤怒/悲伤）与中央矮台，柱体材质实时映射 `MetaProgression.archive_snapshot()`（未访问纯白 → 已访问亮边 → 已击败染对应情绪主题色 → 终局和解呈现暗金纹饰）。
   - 走近按 `interact` 打开 Ticket 02 提供的双页签只读「静滞档案」视图（`心象日记` + `赐福图鉴`），按 `ESC` 回到大厅。
4. **正前方心智之门（Departure Gate）与皇冠复盘防重**：
   - 穿过正前方心智之门（或在门前按 `interact`）发出防重保护的 `departure_requested` 信号，由 `RunDirector` 执行 `begin_run()` + `prepare_departure()` + 保存初始 `active_run` 快照 + 平滑淡入第一层第一房。
   - **死后归来复盘对白**：当经由死亡面板「返回静滞之门」进入大厅（`post_death` 语境）时，`CrownVoiceSystem` 在苏醒后短暂延迟播放历史复盘对白（依据 `run_count`、`last_death_depth`、`last_death_cause`）；随后玩家从大厅穿门进入第一层第一房时，`RunDirector` 抑制首房重复播报同一条历史对白；而从死亡界面按 `R` 直接立即再战时，首房照常播报历史对白。
5. **死亡界面与终局菜单连通**：
   - 将 `RunDirector` 的 `hub_requested` 接线至 `enter_hub("post_death")` 切入 `StasisHub`；在 `EndingMenu` 增加「返回静滞之门」与「返回标题画面」入口，保持既有 `ArchiveReader` 与退出行为。

## Acceptance Criteria

- [ ] 玩家可自由在 `StasisHub` 内移动、冲刺与低头观察身躯，出生点直行约 9m 即可在 3 秒内穿过心智之门，大厅内不会误开火或触发战斗 HUD。
- [ ] 走近左侧锻造台按 `interact` 可打开 `CrownForge` 完成真实扣费升级并立即刷新大厅 `Player` 属性与台座脉冲；关闭后回到大厅而非强制入战。
- [ ] 右侧四心魔立柱按 `MetaProgression` 的访问/击败/和解状态呈现对应视觉差异，按 `interact` 可只读浏览心象日记与赐福图鉴、`ESC` 返回大厅且不改写存档。
- [ ] 从领域死亡面板点击「返回静滞之门」进入大厅时触发皇冠历史复盘对白，且随后穿门入第一层第一房不重复播报；点击死亡面板「重新挑战 / R」仍直接重开入战并在首房正常播报。
- [ ] 穿门出发能正确执行 `begin_run()`、`prepare_departure()`、落盘初始 `active_run` 并进入真实第一房，且 `ESC` 暂停菜单可打开设置并触发返回标题请求。
- [ ] 既有 `meta_forge_test`、`run_director_test`、`campaign_realms_test` 与 `fixture_test` 全绿。
