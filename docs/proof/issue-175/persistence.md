# 日记与档案进度接线

RunDirector 在实际安装领域房间、领域死亡、心魔击败与和解结束时向 MetaProgression 记录事件。进入或死亡记录 visited_realms；击败同时记录 defeated_realms；完成和解记录 reconciled。计数不从随机楼层深度推断心魔类型。UI 获得数组副本，不能修改真实进度。

版本 1 旧存档无 archive 时按全部锁定读入，不依据 run_count 猜测过去是否通关。新增字段走原校验、临时文件回读与备份流程，验证类型、领域范围、重复项和 defeated ⊆ visited。写盘失败保留内存进度，由下一次成功保存重试；不重复结算收益。

Godot 4.7.2 `lore_progress_test.tscn` 14项通过：隔离存档、真实领域安装、死亡入口、真实 Boss Health 死亡信号、未到达领域锁定、和解终页、新实例读档、防UI改写、非法领域、不可写路径、重试与旧档。日志见同目录。它验证程序触发与持久化，不替代叙事主观验收。
