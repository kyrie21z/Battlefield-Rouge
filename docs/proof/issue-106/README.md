# Issue 106：战斗测试台与最终清理

本 PR 拆分时基于 #105 `c7d7abe`，只交付独立战斗测试台、旧武器兼容 API/资源清理、剩余调用方和文档迁移。此前五个 issue 的实现分别位于其前序 PR；完整叠加结果保留一枪一刃、原完整角色和黑色真实晶体接缝。

## 验证来源与边界

合并准备说明：本目录的 16 场景、两项原生验证和 fixture 记录来自 2026-11-10 UTC 的拆分阶段 `3c7eed0`；本轮在前序 PR 进入 main 后重放 #106，仅纠正 README 的旧武器表述及关联证据文档，未改运行代码、未重跑引擎。

参考完整实现为 `85555908f532fa582844de1408d21318fde9f588`，该提交的 43/43 场景回归日志保持原样，见 [原始完整验证记录](../epic1/README.md) 与 [原始结果](../epic1/validation/results.json)。本次没有重新运行全部 43 场景。

[production_parity.json](production_parity.json) 对 489 个运行源码、资源、配置和工具逐文件比较，并包含 `project.godot`、根资源和可玩的 `combat_bench`/target。与参考提交逐字节一致。全树差异只允许明确列出的三份测试增强、五份设计/架构/使用文档纠正及验证证据；没有额外运行时代码漂移或未知未跟踪代码。

Godot 4.7.2（`ed1daf0bf`）导入，以及本阶段新执行的 16 个 headless 场景全部通过，无 ERROR/WARNING：obsidian_pistol、weapons、mind_blade、melee、combat_bench、active_magazine、combat_traits、body_awareness、hud、keybinding、gun_feel、phase_banner、music、settings、hit_feel、fixture。完整新日志与 [results.json](results.json) 在本目录。

两项原生验证也通过：手枪在固定 60 fps 下持续按住真实 fire action 24 帧只发一枪，松开重按再发一枪；真实 V 敲钟记录五次完美 +20% 和一次普通 +10%。截图脚本等待实际 struck 事件才捕捉反馈。原生结果见 [native_results.json](native_results.json)，[完美命中](03_perfect_strike.png) 已查看。自动输入和截图不替代操作者手感与美术审查。

保留的测试增强：

- 手枪真实按住/松开输入、Stats 2 倍换弹速度对应 0.425 秒、1.5 倍弹匣对应 12 发。
- 真实 Player 默认唯一短刃、移除切刀入口、V/鼠标侧键、挥刀仍持枪、0.45 米精确前冲与死亡取消。
- 敲钟 proof 按刀刃实际接触时序触发，缺失命中或缺少普通/完美证据时失败。

## 固定回放

fixture 用 `--headless --fixed-fps 60` 新跑，两个主种子各两次哈希一致；与参考实现完全相同。

| Fixture / seed | 结果 | 轨迹哈希 |
| --- | --- | --- |
| FX-001 / 1001 | 两次阵亡，2293 ticks | `fa067b58e9d95c8a` |
| FX-001 / 1002 | 胜利，2524 ticks | `56b75555f7cc9277` |
| FX-002 / 2002 | 两次胜利，878 ticks | `ad3703cd93d3073e` |
| FX-002 / 2003 | 胜利，887 ticks | `8a58f623826f08aa` |

原 main 的 FX-001 主种子是胜利；迁移后变为阵亡仍是需要审查的平衡变化。拆 PR 没有改变这一结果，也没有放宽哈希或超时断言。

## 运行与校验

使用 Godot 4.7.2，直接打开 `tests/combat_bench.tscn`。左键点射、右键 ADS、R 重组、V/侧键挥刃；移动靶、4 米木桩、慢弹和节拍钟可循环测试；0–4 或按钮切换身体裂痕。正式关卡不消费这些调试键。

当前集成源码和原验证材料用 `sha256sum -c docs/proof/epic1/SHA256SUMS.txt` 校验；本阶段新材料用 `sha256sum -c docs/proof/issue-106/SHA256SUMS.txt` 校验。`reference_SHA256SUMS.txt` 保存参考提交的原始清单，仅用于该提交；前序 `issue-105/SHA256SUMS.txt` 同理应在 #105 分支核验，不能用后续文档和测试路径变更冒充原快照。

测试日志归档仅统一行尾、去终端颜色与行尾空白。原 24 骨角色无独立手指骨，保留原掌形；四心魔计数持久化仍由后续剧情流程实现。
