# #172 皇冠眩光与暗金金缮

## 生产行为

`CrownVoiceSystem.GLARE` 指向 `ui/shaders/blinding_glare.gdshader`，沿用已有 fracture_level/intensity/visual_time/reduced_motion 注入接口。第 4 层从头顶的光源产生金色星芒、横向耀斑和屏幕边缘眩光，伴随约 1.6 像素量级的轻微色散。中心准星区域的眩光受抑制，低等级维持微弱边缘光。

`DoppelgangerSpawn` 在 PRINT / SEAL / COMBAT 持有同一着色器的独立材质，使用当前渲染相机将**真实皇冠世界坐标**投影为 source_uv，发光不固定在屏幕中心；皇冠在相机背后或演出结束时隐藏该层。层 44 位于原闪光/字幕层 45 与暂停菜单之下。不改变皇冠几何、原眼手约束或相机控制。

`BodyReassembly.KINTSUGI` 指向 `actors/player/shaders/kintsugi_gold.gdshader`：56 片真实碎片与完成后的 11 个原始蒙皮部位，都复用 CrystalSeams 的 CUSTOM0 距离/真实边掩码。没有绘制假裂纹，没有改源 GLB、24 骨、顶点、蒙皮绑定或剔除共面三角形对角线的规则。金缮只覆盖接缝，白壳保持；金属度 0.92、粗糙度 0.15，暗金液流以缓慢相位和微弱呼吸流动，裂隙节点分布琥珀/紫/红/蓝微光。

演出中由 BodyReassembly 注入视觉时间；恢复后由同一 ShadowBody 所有的 `KintsugiFlow` 持续驱动原始材质，随身体释放。暂停冻结时间，已有 `CrownVoiceSystem.reduced_motion` 注入值将金缮流动和眩光脉动固定。所有新 Shader 不使用 TIME。BodyReassembly 与 CrownVoiceSystem 未改音频接线；actors/player/player.gd 未改。

## 验证

引擎为 Godot 4.7.2；实际命令前缀 `/tmp/epic34-plan/godot-wsl --headless --path .`：

- `tests/body_reassembly_test.tscn`：真实门槛触发→56 刚体→四哭喊/接纳→重组→控制恢复；新增碎片/恢复后材质、两阶段暂停时钟、持续流动、减少移动、四微光断言。
- `tests/crown_voice_test.tscn`：原真实语音/历史/死亡/切层回归；新增第 4 层眩光材质、时钟暂停、减少移动。
- `tests/doppelganger_spawn_test.tscn`：原物理落冠/2.5秒打印/AI交接/战斗HUD/结局回归；新增真实光源投影、眩光暂停、结束清理。
- `tests/crystal_seams_test.tscn`：原 GLB 全三角形位置、法线、UV、骨索引和权重保持，对角线排除。
- `flock /tmp/epic675-native.lock /tmp/epic34-plan/godot-wsl --path . res://tests/climax_shaders_proof.tscn`：对照随行 0/4 级、金缮全身/近景、真实打印皇冠眩光，共五张 Forward+ 截图。外部相机仅用于金缮与替身审阅；金缮截图临时把同一头网格设为正常投影，生产第一人称头仍只投影。没有替代人体。

性能与截图使用**独立进程**：默认 proof 仅截图，`-- --climax-perf` 模式在任何截图回读/PNG 写入前直接返回，只采 GPU 时间。同一视口每状态预热1秒及32帧，再采样60帧 `RenderingServer.viewport_get_measured_render_time_gpu`，记录平均/p95/max；金缮同一状态再重复一次。两次运行均持有共享文件锁。最终性能证据仅为 `perf.log`，`native.log` 仅为截图日志。首轮混合截图/16帧预热数据保留在 `native-initial.log`，不作效果成本比较。

样本是单台 RTX 4060 Laptop / 1280×720 的独立场景诊断，不等同全机型压力测试。预热与初次加载不计入采样窗口，但不能保证异步编译、驱动频率及系统噪声完全排除；其他工作区存在 headless 测试，所以不作 CPU 性能结论。截图回读与 UNC PNG 写入的延迟不纳入独立 perf 进程。

MetaProgression 在 tests 入口之前即自动选择独立 meta_test_* 档；proof 的设置使用独立 cfg。未读取或写入真实成长存档。

最终无界面结果：重组 21/21、皇冠 32/32、终局 40/40、原几何接缝 73/73。首轮暂停测试夹具曾把根节点设为 ALWAYS，导致继承的玩家也不暂停；已显式把测试 Player 设为 PAUSABLE 后重跑通过，生产时钟实现未因该夹具问题改动。

五张最终原生图片分别为 [0级皇冠](01-crown-level0.png)、[4级眩光](02-crown-level4.png)、[原身躯金缮](03-kintsugi-body.png)、[接缝近景](04-kintsugi-seams.png)、[真实皇冠光源投影](05-projected-crown-glare.png)。均已逐张打开查看。


| 独立性能进程状态 | GPU mean ms | p95 ms | max ms |
| --- | ---: | ---: | ---: |
| crown_level0 | 0.479 | 0.485 | 0.493 |
| crown_level4 | 0.776 | 0.786 | 0.791 |
| original_body | 0.801 | 0.815 | 0.843 |
| kintsugi_body | 0.849 | 0.868 | 0.871 |
| kintsugi_body_repeat | 0.918 | 0.932 | 0.960 |

这组独立场景观测值均低于 1 ms；不将不同状态的差值外推为全游戏成本，也不承诺全硬件无损耗。结构化结果见 `validation-results.json`。

## 登记与边界

负责人要求共享 ARCHITECTURE/GLOSSARY/ASSETS 不在此子任务修改；新增术语/资源在此暂存登记：皇冠星芒眩光 (`blinding_glare`)、暗金流动接缝 (`kintsugi_gold`)、身躯视觉时钟 (`KintsugiFlow`)。均为本 issue 原创代码，无外部贴图/素材/语音。

眩光固定三次屏幕采样，无模糊循环；金缮为原网格单材质，无额外几何与纹理采样。自动回归及截图不替代人工手感、光敏舒适度、完整通关或目标机群性能验收。减少移动仅沿用已有注入属性，没有新增全局设置或改变现有配置格式。
