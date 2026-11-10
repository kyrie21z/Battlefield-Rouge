# 黑晶手枪（#101 / #102）

原创 Blender Shade Flat 模型为 220×135×32mm，120 源面／180 导出三角形。四块各有中心 pivot，根在握把中心；作者文件、几何统计及 SHA-256 见 `tools/epic1_models/`。

8 发半自动，0.18 秒间隔、35 伤害，30m 后衰减；75°→58° ADS，1.2° pitch、±0.3° yaw，0.12 秒镜头回弹。命中喷出实体多面体晶屑。

#102 增加 0.85 秒晶体重组：0.35 秒绽放、0.30 秒悬浮、0.20 秒归位。R 或空匣触发，`reserve=-1` 表示无限再生；归位同帧补满弹匣、发出一次 `ammo_refilled`、清脆音和 0.06 秒枪口短闪。Stats.RELOAD_SPEED 按比例缩放全部阶段；Stats.MAGAZINE_SIZE 生效。暂停冻结，死亡取消且不补弹，重复 R 不重置计时。

玩家只配置一把手枪；旧多槽 API、旧近战和锤保留至后续迁移。`grip_transform()` 与 `set_melee_active()` 为后续短刃/身体集成提供实际握把坐标和右侧让位。此阶段尚不引入新短刃或完整身体。

验证入口：`tests/obsidian_pistol_test.tscn`。分阶段原生图和真实测试日志分别见 `docs/proof/issue-101/` 与 `docs/proof/issue-102/`。
