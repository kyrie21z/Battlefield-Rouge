# Issue #114 验证结果

Godot 4.7.2 Windows console / WSL worktree，真实生产组件，headless。

- `boon_pipeline_test`：61 项通过，包括真实 Player 枪/刀/冲刺/换弹，四核心槽替换与取消、OR/特质前置、旧 Buff 保留、伤害前取消、旧盾与新屏障、实际吸收/扣血与真伤、来源独立的盾恢复阻断与恢复、固定债务不重复减伤、递归深度、暂停、死亡、换关保存保护。
- 生产 SlothAttack 的时停/动画停滞、恢复与延长预警、时停期间新弹冻结；换弹中途速度变化；时钟真实扩大判定窗和主题色均覆盖。
- 旧回归全部通过：weapons、mind_blade、dash、counter_shield（28项）、capture_hammer、sloth_enemy（64项）。完整日志逐项附后。最终日志无 ERROR / WARNING。
- capture 测试曾因未释放场景就退出出现 4 AudioStream 实例警告，补齐释放和音频线程 drain 后通过；未修改生产音频行为。

命令：`Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path <worktree> res://tests/<name>.tscn`。首次先 `--headless --import`。

接口见 API.md。现有生产敌人默认 `max_shield=0`、恢复率=0，**没有新增正式关卡盾敌**；盾单位相关特质由同一真实 Health 屏障接口验证。恢复阻断按来源叠加，清除一个来源不会误解除其他状态。`true_damage` 仍尊重队伍、无敌与死亡门槛，跳过部位倍率与吸收。

本基础PR仍使用旧 BuffPicker；家族卡和完整选择UI由其他issue接入。BoonReplacePrompt为可选显式bind组件。完整卡池集成、可复现fixture与原生视觉最终验收由Epic集成阶段补充，当前不声称已完成这些检查。

攻击速率是独立状态：`attack_scale` 只缩放敌方出手/连射/攻击冷却，保持移动、动画与防御计时不变；已验证 SlothAttack 实际攻击时钟减半与单独恢复。

最后收口：Health过杀返回实际生命损失（10HP受100伤返回10）；被before_damage取消的零伤不发damaged信号，仍完成after_damage/damage_resolved生命周期。新增两项实测通过，反击盾28项重跑通过。

全伤管道补测：64项全部通过，真实枪/刀在已有倍率下不重乘，raw proc及直接Health路径仅乘一次，已结算伤害和环境伤害保持原值。最终日志 `damage-pipeline.log`；完整契约见 `API.md`。
