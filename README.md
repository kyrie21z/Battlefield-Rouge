# Battlefield Rouge

第一人称、按战区推进的 Rogue 射击游戏。清空战区的敌人，占领据点，三选一拿一个只在本局有效的增益，再进下一个战区。死亡后从头开始。

- 引擎：Godot 4.7.2（Forward+）。用编辑器导入本目录的 `project.godot`。
- 操作：WASD 移动，Shift 冲刺，空格跳，左键开火，右键瞄准，R 换弹，Esc 释放鼠标，点击窗口重新锁定鼠标。增益界面按 1–3 或点击选择；结算界面按 R 或点按钮重新开始。
- 战区：`maps/zone_1.tscn`（4 个敌人）、`maps/zone_2.tscn`（6 个敌人），由 `tools/gen_zones.py` 生成，改布局请改脚本再重新生成。
- 架构和依赖规则：`ARCHITECTURE.md`；术语：`GLOSSARY.md`；决策记录：`docs/adr/`；待优化事项：`TODO.md`；多人协作规范：`COLLABORATE.md`。
