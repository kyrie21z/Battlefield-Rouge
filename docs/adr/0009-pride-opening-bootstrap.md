# 0009：先播放 Pride 开场，再进入现有游戏

日期：2026-11-01。状态：按用户要求完成临时接入，随本次 PR 评审。

## 背景

Sloth 开场任务 #45 的早期交付是独立 Godot 预演，所以双击 Battlefield-Rouge 的启动器看不到。用户明确要求先把动画放在原游戏开头，之后继续玩原来的内容。

## 决定

- 项目 `run/main_scene` 改为 `ui/game_start.tscn`。普通启动立即播放开场，不多加一层观看确认。
- 复制本次已生成的皇冠图集和演出资源到 `ui/pride_opening/`，改为工程内引用；不依赖旁边的 Mind-Freak 文件夹。
- 演出完成或整段跳过后，均显示出发选择。确认经 0.35 秒过门衔接，启动器读取 `RunState.zone_scene()`，加载原 `maps/zone_1.tscn`。不进入独立预演的首关白模。
- 后续完全使用现有开局三选一、两小关、Boss、武器、增益、胜负与重开流程，不把旧地图改成 Sloth 关卡。
- fixture 和开发参数 `--skip-opening` 直接进入对应战区。保留已有 RunState 命令行逻辑，启动器只在自身仍是当前场景时加载，防止重复载入。
- 重开由现有 ZoneDirector 直接载入战区，不重复动画。不新增进度存档，开场不会改变本局随机种子或构筑。

## 接口与画面

开场只发 `combat_entry_requested`，`GameStart` 用单次连接加载实际游戏。不预加载战斗场景来充当动画背景，因此敌人、导航、计时与 HUD 都在交接后才启动。适配原项目 1920×1080 画布，按比例显示 1280×720 设计的字幕与按钮。

## 验证

`tests/opening_boot_test.tscn` 验证逐句、观察返回、跳过、真实 zone_1、单次战区加载、种子和构筑保持、开局选卡、原有玩家组件、死亡重开以及两个 fixture 的绕过路径。全部既有测试与 fixture 另跑，结果见 [接入证明](../proof/pride-opening/README.md)。

本次没有修改玩家、武器、增益、ZoneDirector、RunState 或生成地图脚本。素材来源及哈希已登记到 ASSETS。

## #147 后续替代

2026-11-10：以上保留历史决策；旧点击推进开场已由 `ui/cinematics/opening_sequence.tscn` 的真实第一人称连续演出替代。旧图集与对白原件移至 `docs/levels/sloth-opening/` 归档。首次 Run 播完整开场，死亡重开和 fixture 旁路仍保留。
