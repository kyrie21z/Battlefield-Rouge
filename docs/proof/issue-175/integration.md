# 生产接入验收

战斗中 TAB / 手柄 View 心智矩阵增加“心象日记”页签，读取 MetaProgression 的进度快照。结局菜单另有独立“心象日记”阅读入口，不开始新挑战、不生成新的 run_id，不改钱包与装备；阅读时隐藏背后菜单按钮，防止手柄焦点落到“新挑战/退出”，关闭后恢复菜单焦点。

RunDirector 的真实房间安装、玩家死亡、领域 Boss 死亡与最终和解记录进度。首次进入/死亡解锁该领域日记和皇冠评论；领域击败再解锁对应人性保护价值；最终手记只有完成和解后显影。未知标题和正文不会放入隐藏控件或 tooltip。实际来源与旧档兼容见 [persistence.md](persistence.md)。

## 最终验证

Godot 4.7.2 stable，在 /tmp/battlefield-epic7-codex 整合后执行：

| 测试 | 结果 | 覆盖 |
| --- | --- | --- |
| lore_diary_test | 43 checks / 0 failed | 逐领域解锁、双面档案、防隐藏正文剧透、回退换档、手柄焦点与滚动 |
| lore_progress_test | 14 checks / 0 failed | 真实房间安装、真实 Player Health 致死、真实 Boss Health 致死、隔离存档重新加载、写盘失败/重试与旧档 |
| lore_modal_test | 8 checks / 0 failed | 战斗入口、页面更新、暂停不泄漏、结局入口单实例与焦点隔离、实际 ESC 返回、钱包/局数不变 |
| climax_flow_test | 15 checks / 0 failed | 实际56碎片重构、最终对手死亡、拾冠、和解序列 finished 触发终章、提前锁定与重复结算幂等 |
| meta_forge_test | 31 checks / 0 failed | 原经济、旧档与原子保存回归 |
| run_director_test | 51 checks / 0 failed | 原多局流程、历史与死亡状态回归 |

日志依次为 [integration-ui.log](integration-ui.log)、[lore-progress.log](lore-progress.log)、[production-modal.log](production-modal.log)、[climax-flow.log](climax-flow.log)、[meta-forge-regression.log](meta-forge-regression.log)、[run-director-regression.log](run-director-regression.log)。这些最终日志没有 ERROR / SCRIPT ERROR / WARNING / FAIL 行。

原生生产 UI 证据为 [production-diary.png](production-diary.png) 和 [ending-diary.png](ending-diary.png)，分别来自实际 sloth_1 HUD 的日记页、实际结局菜单的终章阅读器；两张1280×720原始帧均已由主管实际 view_image 审阅，标题、行距、封存条目与滚动正文清晰。截图场景使用受控隔离进度来展示布局，真实事件触发由上述流程测试证明。子代理另交付14张独立状态/双分辨率原生图，均逐图审阅，清单见 README。

```bash
/tmp/epic34-plan/godot-wsl --headless --editor --path . --import
/tmp/epic34-plan/godot-wsl --headless --path . res://tests/lore_diary_test.tscn
/tmp/epic34-plan/godot-wsl --headless --path . res://tests/lore_progress_test.tscn
/tmp/epic34-plan/godot-wsl --headless --path . res://tests/lore_modal_test.tscn
/tmp/epic34-plan/godot-wsl --headless --path . --fixed-fps 60 res://tests/climax_flow_test.tscn
flock /tmp/epic675-native.lock /tmp/epic34-plan/godot-wsl --path . res://tests/lore_modal_proof.tscn
```

全部 tests/ 入口由 MetaProgression 在 autoload 初始化时隔离真实存档；原生持有共享 flock。手柄为 Godot InputEventJoypadButton 注入，未声称实体手柄实玩。文字为原创虚构叙事，程序正确性不替代主观文学验收；全库suite与最终PR由集成负责人执行。

整合第一次在编辑器完成全局类扫描前启动独立UI测试，出现 LoreEntries/LoreDiary 未注册的解析错误。已停止该测试进程，完成导入后原断言复跑；首次日志保留在 [integration-preimport.log](integration-preimport.log)，不作为最终功能失败或通过证据。
