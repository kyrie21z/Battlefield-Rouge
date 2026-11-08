# Sloth 场景备用方案

本目录保存前两关与 Boss 关的独立场景预演。它是场景备案与美术 / 地形评审材料，不自动替换正式游戏。

2026-11-08 更新基础为 main `5292b926939d536f2ac5e46e6aa44d76c1b77bdc`，已经包含弹匣 #88、弹道 #91、加载修复 #94 与敌人备用 #92。准确来源记录在 [UPSTREAM.json](UPSTREAM.json)。本次把先前本地场景正式纳入该版本上的隔离备案包，保留现有地形与防闪烁修复。

| 场景 | 内容 |
| --- | --- |
| 第一关 · 停滞前庭 | 大型分层庭院、中央下沉场、左右高台与高架横桥，中轴较开阔 |
| 第二关 · 锚定回廊 | 复用地形骨架，通过中央阻隔、掩体、顶棚与暖光侧庭改变空间节奏 |
| Boss · 云上静滞圣殿 | 直径92米的环形战场、巨环、钟摆、悬浮殿群与云海 |

前两关主场地各96×128米，中央-2.5米、左右高台+3 / +5米；主要路线由缓坡连接，不要求跳平台。敌人站位仅为规划用Marker3D，不包含新的战斗、刷怪、回血或奖励规则。详见 [场景设计](SCENE_DESIGN.md)。

## 独立运行

使用 Godot **4.7.2** 打开 [viewer/project.godot](viewer/project.godot)。默认运行 Boss 圣殿；在编辑器中打开 `rooms_preview.tscn` 并运行当前场景，可看前两关。

也可在本目录执行（`godot` 替换为本机引擎路径）：

```text
godot --path viewer
godot --path viewer res://rooms_preview.tscn
```

- WASD移动、Shift加速、单击观察、Esc释放鼠标。
- F1 / F2或顶部按钮切换前两关；1–4切换观景点。
- F自由飞行，Space / E上升、Ctrl / Q下降；R回入口。
- Tab隐藏界面，M可选缓慢运动，L切换雾。

外层 `.gdignore` 让正式工程不扫描嵌套预演。预演不依赖正式游戏自动加载、素材、存档或网络；在独立编辑器里打开内层工程即可使用。不需要从历史提交还原旧工程。

## 地面与相机稳定性

主殿、桥面与侧庭的结构层和表层分开，消除暴露共面；铺装使用带像素导数过滤和距离淡出的单层材质，移除高频颗粒和细线投影。角色采用渲染帧相机插值，切换机位立即重置，默认场景静止。

原生截图见 [proof/](proof/)。测试源码在 [viewer/tests/](viewer/tests/)，最终结果在 `scene-test.log`、`rooms-test.log`、`viewer-smooth.log`、`native.log`、`rooms-native.log` 和 `performance-after.log`。`manifest.json` 记录随包文件SHA-256。

Boss场景56项通过、前两关82项通过，均0失败。前两关覆盖下沉庭、双侧绕路、高台横桥、下层通道、缓坡、地板重叠与机位 / 模板切换；原生镜头平滑检查独立通过。11月8日重新验证见[更新验证](proof/UPDATE_VERIFICATION.md)：静态四机位288–300次绘制调用，GPU p95为0.827–1.318ms；不含正式战斗。保留共同的宿主证书读取提示，未宣称引擎整体零诊断。

在 `viewer` 目录可运行：

```text
godot --headless --path . --fixed-fps 60 --script res://tests/scene_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/rooms_test.gd
godot --path . --script res://tests/viewer_smooth_test.gd
```

本机运行如需把数据留在目录内，可为该次进程设置 `APPDATA` 到 `viewer/.runtime/AppData`，并指定本地 `--log-file`；不要修改系统级环境变量。

## 限制与后续

本版是固定布局与观赏 / 通行样板，没有Boss角色、敌人AI、导航烘焙、随机生成、关卡通关或恢复机制。尚需真人战斗平衡、跨机器性能与最终美术评审。GPU帧时间仅代表日志所列本机与机位，不是正式战斗帧率承诺。

正式接入若后续获准，应以当时main为基础，在`tools/gen_zones.py`内实现布局和生成结果。本备案不关闭正式场景制作任务，也不改变正式`project.godot`、地图、玩家、武器、RunState或fixture。

所有几何、天空、云层与材质由本项目代码构建，未加入第三方素材或生成式图片。截图为Godot引擎实际渲染。
