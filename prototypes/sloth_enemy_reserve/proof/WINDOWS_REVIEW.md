# 2026-11-05 · 当前备用版验收

## 本次范围与人工确认

用户已实际试玩并明确认可当前备用敌人的强度和画面；同日确认“本次验收Windows，其他系统后续实测”。据此完成当前备用PR验收，不宣称量产最终平衡或macOS/Linux/Android/iOS/Web已验证。Godot的Mobile在本表中是Windows上的渲染模式，不是手机实测。

本PR保持正式待审，内容仍为隔离备用包，不接入正式游戏。宏观Sloth关卡/巨像/叙事和其他系统发布不属于本次完成项。

## 修复的性能问题

重复生成同种敌人的披风、兜帽、缝线和壳片几何，会在击杀守卫触发增援时造成停顿。现在按类型缓存PackedScene几何/拓扑，实例仍独占材质、骨骼跟随和壳片铰链；原56片碎屑的网格和原始变换只提取一次，击杀时仅建立当前姿态实例。不删细节、不降碎片数量，不改变30%闪避、2.5秒冷却、2秒蓄力/40m/s、伤害、导航或回收规则。

有效优化前对照中，12只敌人同帧死亡并触发正常增援的同步调用为1624.633ms；优化后Forward+为44.851ms。6个额外演员实例化为4.816ms。两者是本机单次对照，包含真实ZoneDirector增援流程，不冒充跨机器平均值。

## 实测结果

Godot4.7.2 / Windows / i7-14650HX / RTX4060Laptop，真实zone_2地图、导航、AI、HUD和技能；1440×810，关闭VSync和帧率上限，不用fixed-fps。玩家用大血量防止死亡暂停，逐段断言仍存活且树未暂停。先暖机3秒，再分别采样6人战斗5秒、12人战斗5秒、12人同时672片碎裂2秒。工具内墙钟只用于性能采样，不进入玩法随机/模拟。

稳态帧时p95预算16.67ms；672片压力阶段p95预算33.33ms；12次击杀加正常增援的同步创建预算100ms。以下列值单位均为毫秒；完整样本数、median/max、GPU/CPU、draw calls和硬件元数据见同目录windows-*-performance.json。

| Windows渲染模式 | 6人帧时p95 | 12人帧时p95 | 672片帧时p95 | 12次击杀及增援创建 | 功能检查 |
| --- | --- | --- | --- | --- | --- |
| forward_plus | 6.414 | 10.403 | 16.053 | 44.851 | 107/107 |
| mobile | 2.597 | 3.406 | 4.830 | 13.685 | 107/107 |
| gl_compatibility | 2.895 | 3.891 | 5.520 | 14.634 | 107/107 |

每种渲染模式均通过原生战斗43、藏青修订27、披风防御21、缓存隔离16，共107项；包含实际射线、闪避、2秒凝聚/40m/s、暂停、按命中点56片碎裂、材质/姿态/壳片独立。性能工具另确认672片全部生成并回收、技能与减速来源清理、原生实际分辨率。

无界面缓存16项、原有91项与危险弹匣62项通过；fixture重复两遍及换种子0失败，哈希仍为FX-001 5d0e1503f50e1299 / FX-002 9af355b642d0021f。优化没有改变原备用玩法轨迹。

![Windows OpenGL实际锁向与三类模型](08-windows-opengl.jpg)

已实际查看OpenGL图：披风镂空、藏青材质、核心和锁向晶体可见。与Forward+的色调/阴影表现有渲染器差异，不宣称逐像素一致。

## 复现与限制

还原并完成导入后运行：

```powershell
godot --path "../Sloth-Enemy-Review" --rendering-method forward_plus --audio-driver Dummy --disable-vsync --max-fps 0 --resolution 1440x810 res://tests/sloth_performance.tscn -- --out=performance.json
godot --path "../Sloth-Enemy-Review" --rendering-method gl_compatibility --fixed-fps 60 --audio-driver Dummy res://tests/sloth_cache_test.tscn
```

渲染模式可替换为mobile或gl_compatibility。性能阈值只面向本机本次备用验收；首次技能/着色器编译仍有孤立尖峰，Forward+采样最大单帧163.129ms，不能把p95通过写成所有帧锁60。宿主shader缓存目录不可写、编辑器设置路径和退出时资源诊断继续保留；音频使用Dummy，未测音频硬件。macOS/Linux及其他平台另作后续实际设备验证。
