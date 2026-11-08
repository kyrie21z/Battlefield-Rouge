# 2026-11-08 · 最新main上的独立验证

- 基础：5292b926939d536f2ac5e46e6aa44d76c1b77bdc，前置#88与#92均已合并。本轮没有改动正式运行文件。
- 环境：Godot 4.7.2、Windows、Forward+ / Vulkan、RTX4060Laptop；独立打开viewer，不读正式游戏自动加载。
- Boss检查56/56、前两关82/82，均退出0；覆盖真实胶囊通行、共面、坡面、高台、横桥、下层、切换、相机瞬移与HUD。
- 原生镜头平滑通过；Boss和两关取证分别完整输出四个PNG并退出0，五张JPEG由本次PNG重编码，全部1280×720。几何和机位确定，JPEG字节与11月4日相同，未用旧图冒充新运行。
- 镜头放大测试采用专用10Hz物理：240渲染帧内身体更新13次、相机225次，最大位置步长0.8米/0.04913米；正常物理频率保持60Hz。
- 两关静态性能：1440×810、VSync关闭、max_fps=0；各120帧预热、180帧采样。入口/全景四组draw为288/295/293/300，GPU p95为1.318/1.230/0.827/1.232ms。这不是正式敌人战斗帧率承诺。
- native.log、rooms-native.log、scene-test.log、rooms-test.log、viewer-smooth.log、rooms-performance.log为本次11月8日重验；performance-after.log保留11月4日Boss性能历史，不冒充本次数据。
- 共同宿主提示：ERROR: Failed to read the root certificate store。无任何游戏内容的空工程也在启动时出现同一提示并退出0；未更改系统证书或降低安全设置。场景/脚本无报错、无ObjectDB退出泄漏提示。本轮不宣称Godot整体输出零诊断。
- 日志中的本地工作路径已替换为<workspace>或res://proof，结果和数值保持。
- 尚待：真人战斗平衡、其他机器/平台，以及正式地图/敌人/导航接入。本PR只交付场景备案。
