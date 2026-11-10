# Realm HUD 观察时机诊断

完整固定树 `0d755b1` 的90场景全套为89通过、1失败；唯一失败是 `realm_stage_test.gd` 的原断言“real realm effect drives the monochrome screen shader”。开始/结束/审计HEAD相同，tracked diff为空，90个原始日志没有引擎错误，fixture主哈希与同机 #173 / #168 结果相同。原失败保留在 [完整批次日志](realm-stage-original-full-failure.log) 与 [独立审计](full-suite-audit.json)，不以重跑覆盖。

合入已审核 main `19854cb` 后固定HEAD `2479898`，12项定向组合为11通过、同一断言再次失败；图鉴、模态、发现存档、构筑检视、MetaForge、RunDirector、hitstop、晶屑、怠惰音频、打印演出和fixture相关路径中的其余场景均通过。见 [批次结果](main-integration-results.json) 与 [原失败日志](realm-stage-integrated-failure.log)。这里按场景计数：图鉴相关有3个场景，总计12个。

## 隔离探针与同机基线

`/tmp/battlefield-174-mono-diagnostic` 先在 `2479898`、后在 main `19854cb` 上运行同一 [观察补丁](realm-stage-observation.patch)。保留原visible断言及原2个physics_frame等待；只记录状态，并在原断言之后继续观察两个process_frame信号。没有调用HUD._process、改状态、延长任意秒数或改成较弱断言。两个提交中原始测试的SHA-256相同：`229fe301ee8536769da6cf1c012521bb98970ee572822b816b5fbdcda309ccd7`。

| 观察点 | 2479898：physics / idle | visible / shader amount | main19854cb：physics / idle | visible / shader amount |
| --- | --- | --- | --- | --- |
| 设置真实效果后 | 18 / 2 | false / 0 | 18 / 4 | false / 0 |
| 原2个物理帧后 | 20 / 2 | false / 0，原断言失败 | 20 / 9 | true / 1，原断言通过 |
| 第1个process信号 | 24 / 2 | false / 0 | 20 / 9 | true / 1 |
| 第2个process信号 | 25 / 3 | true / 1 | 20 / 10 | true / 1 |

所有观察点均为 `monochrome=1`、`paused=false`、`hud_can_process=true`、`hud_processing=true`、`inspector_opened=false`。记录见 [2479898观察](realm-stage-head-observation.log) 和 [main观察](realm-stage-main-observation.log)。同一机器上，原等待期间HUD可能完成了若干次idle更新，也可能还没有运行一次；生产状态正确，失败来自测试在HUD处理前观察可见性。

## 最小修复

保留原来的physics等待及visible断言，在断言前增加两个 `await get_tree().process_frame`。该信号在节点 `_process` 前发出；跨越两次信号保证中间一次HUD更新已完成。没有修改生产HUD、效果数值、暂停条件或存档行为。

修复后定向入口为 `realm_stage_test.tscn`，并配合 `codex_modal_test.tscn` 与 `boon_hitstop_test.tscn` 检查暂停组合。此前90场景全套与12项集成批次的原始失败继续作为历史证据保留。
