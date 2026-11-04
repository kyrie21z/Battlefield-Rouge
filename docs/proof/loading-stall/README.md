# 开场结束后持续“加载中…”修复

关联 [Issue #93](https://github.com/kyrie21z/Battlefield-Rouge/issues/93)。本次处理普通入口在 Pride 开场结束后持续停留在“加载中…”、无法进入第一关的问题。

## 发生原因与本次取舍

旧入口在开场期间依次请求第一关的直接依赖，但每个 `load_threaded_request(..., true)` 仍会并行加载内部依赖；如果线程请求持续保持 `IN_PROGRESS`，入场流程就会无限等待。此前仅保留最后一次依赖读取的局部引用，也不能保证所有已预热资源一直留在缓存。

本次从 `GameStart` 移除全部后台线程请求与预热队列。玩家确认入场后，先用 0.45 秒淡黑，显示“加载中…”，让提示经过两帧更新，再用主线程 `ResourceLoader.load()` 读取目标 `PackedScene`。成功后切入原战区，在黑幕下保留首 3 帧，再用 0.6 秒淡出遮罩；遮罩挂在场景树根节点，以 `PROCESS_MODE_ALWAYS` 运行，因此开局三选一暂停战区时仍可继续淡出并释放。

主线程读取期间加载提示会静态停留，冷加载仍可能耗时；本次优先消除后台资源互等与无限等待，不将这一方案描述为全程无阻塞或沿用旧方案的加载速度。取舍不改变开局增益、关卡推进、种子、危险弹匣、弹道或地图内容。

## 失败与重试

关卡资源读取失败时，入口释放重复加载保护，保留黑幕，将加载文字替换为“关卡加载失败，请重试。”，显示“重试加载”和“退出游戏”。重试通过同一入场路径重新读取，不残留后台加载请求；重复点击由一次性按钮连接与入口保护共同拦截。成功后移除错误界面与过渡遮罩。

fixture、`--skip-opening` 与死亡重开沿用原有直接入场路径。上述错误界面针对普通开场交接，不能据此宣称其他错误路径均已覆盖。

## 最终验证

Godot 4.7.2 / Windows / Forward+ / Vulkan / RTX 4060 Laptop。冷启动观察脚本只使用路径字符串与引擎内置类型，不预载 Player、ZoneDirector 或战斗场景；每条路线启动一个全新进程。开场前和开场中均断言第一关资源尚未缓存，避免普通集成测试提前编译战斗脚本后掩盖问题。

| 独立进程 | 断言 | 全流程耗时 | 最长一帧 | 日志 |
| --- | --- | --- | --- | --- |
| 跳过开场 | 19 通过 / 0 失败 | 3.776 秒 | 807 ms | [首轮](native-skip/native.log) |
| 逐句确认 | 24 通过 / 0 失败 | 3.760 秒 | 802 ms | [首轮](native-confirm/native.log) |
| 跳过开场复跑 | 19 通过 / 0 失败 | 3.317 秒 | 766 ms | [复跑](native-skip/repeat.log) |
| 逐句确认复跑 | 24 通过 / 0 失败 | 3.655 秒 | 765 ms | [复跑](native-confirm/repeat.log) |

四个冷进程全部成功进入实际战区，确认只加载一次；真实 KEY1 选卡后成功开火，真实阵亡后 KEY_R 直接重开战区，不回开场。`frame_post_draw` 确认“加载中…”实际绘制后才开始主线程读取；首次逐帧记录为 [跳过路线](native-skip/skip-frames.jsonl)、[确认路线](native-confirm/confirm-frames.jsonl)。同步读取期间提示静止、单帧约 0.8 秒，随后场景实例化也会产生约 0.35–0.43 秒停顿；没有把成功进入描述为零卡顿。

| 无界面回归 | 通过项 | 证明 |
| --- | ---: | --- |
| opening_transition_test | 45 | [淡出、加载、失败重试](logs/opening_transition_test.log) |
| opening_boot_test | 30 | [确认/跳过、死亡重开、两个 fixture](logs/opening_boot_test.log) |
| gun_feel_test | 183 | [子弹朝向修复与开火表现](logs/gun_feel_test.log) |
| active_magazine_test | 62 | [打空即得、C 投掷](logs/active_magazine_test.log) |
| fixture_test | 24 | [固定60帧重复通关](logs/fixture_test.log) |

无界面 344 项全部通过。fixture 两个起点各两遍和另种子各一遍均正常结束，复现哈希保持当前 main：FX-001 `91e7f1f7a1c5d232`，FX-002 `8d531b6cf8e98fb9`。

错误恢复测试通过仅首次返回 null 或空 PackedScene 的辅助子类，实际运行入口、错误面板和按钮：两种失败都停止加载提示并释放防重保护；按钮重试成功，重复点击只多一次读取，不重置本局状态。原生错误面板截图及本地运行结果见 [native-error-retry.log](logs/native-error-retry.log)。

最终运行日志无脚本错误或未结束的加载任务。编辑器导入退出 0、两个新增脚本 UID 已生成，但本机编辑器启动仍报告一次 Safe save failed 环境提示；不把此项说成导入完全无诊断，也没有更改引擎保存或系统安全设置。

## 原生画面

| 路线 | 开场 | 加载提示已绘制 | 已进入战斗并开火 |
| --- | --- | --- | --- |
| 跳过 | [开场](native-skip/skip-01-opening.jpg) | [加载](native-skip/skip-02-loading-rendered.jpg) | [战斗](native-skip/skip-03-combat-visible.jpg) |
| 逐句确认 | [开场](native-confirm/confirm-01-opening.jpg) | [加载](native-confirm/confirm-02-loading-rendered.jpg) | [战斗](native-confirm/confirm-03-combat-visible.jpg) |

资源读取失败时的 [重试与退出界面](load-error.jpg) 也经过原生运行检查。

## 复查入口

在项目根目录用 Godot 4.7.2：

```powershell
godot --headless --path "." "res://tests/opening_transition_test.tscn"
godot --path "." "res://tests/cold_opening_proof.tscn" -- --route=skip --out=res://docs/proof/loading-stall/native-skip
godot --path "." "res://tests/cold_opening_proof.tscn" -- --route=confirm --out=res://docs/proof/loading-stall/native-confirm
godot --path "." "res://tests/opening_transition_test.tscn" -- --error-proof=res://docs/proof/loading-stall
```

[此前后台预热证明](../opening-transition/README.md) 保留当时的事实和计时，不作为当前实现的结果。Godot 的[资源缓存说明](https://docs.godotengine.org/en/stable/classes/class_resource.html)指出引用释放后缓存也会释放；[上游线程加载问题](https://github.com/godotengine/godot/issues/120827)提供相关背景。本机未采集原生锁栈，不能将上游的具体锁问题认定为已被本项目直接证实。
