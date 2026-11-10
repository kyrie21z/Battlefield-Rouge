# 黑晶手枪

Epic 1 / #101–#102，按 `docs/NARRATIVE_FOUNDATION.md` 8.1、转面图和用户后续“面数可以增加，最重要的是质感”的修订实现。正文尺寸优先于参考图内冲突标注。开火逻辑集中在 `weapons/weapon.gd`，视图实例化 `assets/models/weapons/obsidian_pistol.glb`。

- 原创 SUPERHOT 风格黑曜石矿物轮廓：六角收腰截面、阶梯滑套、斜握把、10mm 深矿物枪口和 0.7mm 暗金缝，使用真实 Blender Shade Flat 网格。四个独立对象为 `barrel_block`、`slide_block`、`grip_block`、`core_crystal`。
- Blender 源为 **120 个三角/四边多边形**，GLB 为 **180 个渲染三角形**。全长 **220mm**，总高 **135mm**，宽度/握把厚度 **32mm**。采用质量优先预算，如实分别报告源面和渲染三角形；无机械螺栓或扳机护圈。根原点在握把中心，每块局部原点位于自身包围盒中心；不额外缩放模型。
- 可再生源码、两份 `.blend` 与面数/尺寸/SHA-256 收据放在 `tools/epic1_models/`，以 `.gdignore` 隔离作者文件。源文件枪口指向 Blender -Y、Z 向上；导出时显式烘焙轴转换，Godot 中枪口为 -Z、+Y 向上。
- 基础 8 发、35 伤、0.18 秒半自动；30 米开始衰减，90 米到 50%。材质粗糙度 0.25，ADS 为 58°。
- 重组基础时长 0.85 秒：0.35 秒绽放、0.30 秒悬浮、0.20 秒磁吸合拢。四块围绕各自中心展开，视图和添弹使用同一计时器。合拢帧同时触发清脆声、枪口 0.06 秒短闪与 `ammo_refilled`。
- 既有赐福的 `Stats.RELOAD_SPEED` 按比例缩放全部重组阶段；`MAGAZINE_SIZE` 仍生效。`reserve = -1` 表示无限能量重组，HUD 展示当前弹数/容量。打空自动重组，R 可主动重组，满匣与重组中 R 不重新启动。
- 冲刺和挥刃期间平滑继续重组。挥刃让枪身右偏，枪仍可射击；死亡调用 `deactivate()` 停止重组且不给弹。
- 命中敌方 Hitbox 时喷出 8 枚实体三棱晶屑（0.45 秒消失，最多 24 组），不生成手枪血雾；墙面命中效果沿用原实现。
- 音频复用项目自生成 PCM。模型、枪口光与晶屑均为原创，未使用外部下载资产；表现随机数不消耗战区模拟随机序列。

运行 `tests/obsidian_pistol_test.tscn` 核验导出收据、实际 GLB 网格、尺寸、pivot、真实 Hitbox 伤害、冷却、重组时间边界、晶屑、输入防重与死亡取消。`tests/weapons_test.tscn` 是同一验收入口；枪感和阴影回归分别在 `gun_feel_test` 与 `protagonist_body_test`。
