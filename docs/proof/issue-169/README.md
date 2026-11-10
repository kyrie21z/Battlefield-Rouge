# #169 · 悲伤镜潭与白雨

范围：生产 `SorrowRealm` 的镜面水面、角色水纹和垂直细雨。保留原 0.14m 水位、地形/平台、碰撞、导航、原角色模型、武器规则与 splash 音频接口。不使用 origin 素材，不修改共享 ARCHITECTURE/GLOSSARY/ASSETS。

## 实现与依赖登记

- `water_mirror.gdshader` 留在 opaque pass，以低粗糙度镜面接收 Godot Forward+ SSR；不写 ALPHA，不借屏幕纹理做假倒影。深墨蓝底色、微弱蓝色边光与 BACKLIGHT 透光不遮蔽倒影。
- 32 槽 vec4 波纹环形池（局部 X/Z、出生时间、强度），径向阻尼波包的导数改变真实反射法线。玩家/敌人通过已存在的 `enemy_registered` 与注入的玩家引用被追踪；按真实位移采样，冲刺缩短采样间隔，平台/空中/死亡/瞬移抑制水迹。池覆盖只影响表现。
- 既有 `Events.gunshot` 成功射击信号在湿脚位置产生较轻后坐水纹，不增加武器射线、不伪造弹着点。真实 `TearCrystal` 生成后读取最终落点；已消费晶体从 physics 或 `tree_exiting` 恰好观察一次，覆盖刀发射、枪击水爆、拾取与同帧消费。只读泪晶状态，不修改伤害/奖励或消费流程。
- `rain_particles.tscn` 是 750 根 GPU 白雨丝，无狂风。`rain_layout.gdshaderinc` 共享雨格、哈希落点与相位；GPU 垂直下落抵达水面的同一相位，水面 shader 开始小型同心环。共享时钟只在未暂停、未剥夺时推进；不使用 shader TIME，不调用全局随机。GPU 节点仅在房间 ready 创建，战斗事件不分配粒子节点。
- 普通/涨水状态更新同一 GPU 落点高度；剥夺隐藏现存雨丝并停发、隐藏水面、清空旧波包，恢复不重放旧水纹。
- 生产 `RealmStage` 本来另有通用 WorldEnvironment。为避免其与领域环境的 ready 顺序影响 SSR，`set_player` 显式给实际渲染 `view_camera` 注入本领域 `mirror_environment`。Epic6 #171 合入公共 profile 时，保留其 `Environment` 复制行并保留这里的环境特性与 camera override。
- 新增环境表现术语为“法线波包”和“雨格相位”，不引入玩法概念。共享文档合并登记如需统一，由负责人集中处理。没有外部图片/音频/模型素材需要 ASSETS 许可条目。

## 可复现验证

引擎 Godot 4.7.2，Windows Vulkan Forward+，通过 WSL wrapper 运行。存档用 `--meta-test-profile=user://meta_test_issue169.json` 隔离，不读取真实玩家档案。

```bash
# GODOT 指向已验证的 Godot 4.7.2，或适配 --path 的本地 wrapper。
"$GODOT" --headless --path . --editor --import --quit
"$GODOT" --headless --path . --fixed-fps 60 --quit-after 1800 res://tests/sorrow_water_test.tscn -- --meta-test-profile=user://meta_test_issue169.json
flock /tmp/epic675-native.lock "$GODOT" --path . --fixed-fps 60 --quit-after 900 res://tests/sorrow_water_proof.tscn -- --meta-test-profile=user://meta_test_issue169_native.json
```

测试/截图均加载真实 `maps/realms/sorrow_1.tscn`，不是替换为假角色的视觉原型。截图为了观察反射，把房内既有敌人排列到水面，并关闭其 AI；敌人水迹截图期间恢复真实追击，第一人称截图操作真实 Dash/Weapon/赐福组件。截图测试隐藏 HUD，不修改生产 HUD。

新测试 `sorrow_water_test.tscn`：32/32 通过，涵盖生产 SSR override、GPU 雨、真实移动与 5m 冲刺、AI 追击、成功/拒绝射击、真实刀发射与枪击泪晶、拾取、同帧消费、平台/空中/瞬移抑制、暂停、随机流不变、32 槽上限、涨水、导航/碰撞不变、剥夺恢复及退出解绑。

既有 `sorrow_realm_test.tscn` 22/22、`sorrow_monolith_test.tscn` 22/22 通过，合计 76 项。最终三场 headless 回归与原生截图日志均无 SCRIPT ERROR / ERROR / WARNING；测试退出前等待混音器释放音频播放引用，消除了立即退出产生的临时对象警告。完整输出见 [validation.log](validation.log)，图片 SHA-256 见 [manifest.json](manifest.json)。

原生截图脚本成功生成 5 张 PNG，日志记录 `movement=24 shots=1 tears=2 pool=32 checks_failed=0`。已逐张查看：

| 截图 | 观察 |
| --- | --- |
| [mirror-ssr-on.png](mirror-ssr-on.png) / [mirror-ssr-off.png](mirror-ssr-off.png) | 同机位、同水面时钟。SSR 开启时白柱、平台、晶体人形倒映，关闭后消失；不是另造倒置模型。 |
| [enemy-wake.png](enemy-wake.png) | 原敌人真实追击后，脚底保留环状法线波。 |
| [player-dash.png](player-dash.png) | 正式第一人称身体、原手枪和皇冠，冲刺期间水面持续反射。 |
| [tear-shot.png](tear-shot.png) | 实际枪击消费泪晶后出现扩散环，日志同时检查消费完成。 |

截图运行时 GPU 为 RTX 4060 Laptop；TIME_PROCESS 粗采样先记录 16.06ms，切换第一人称/首次特效后记录到 358.28ms。此日志不支持“全程无卡顿”的声明；当时伴随相机切换与首次特效，尖峰来源未做归因，也未做跨设备基准。

## 验收边界

SSR 受屏幕内可见物体限制：镜头背后、屏幕外和被遮挡的内容不保证倒映；不新增 planar reflection 第二相机。反射质量须在 Forward+ 原生画面检查，headless 只能验证接入与状态边界。没有声明所有设备无掉帧；原生日志的 CPU 处理耗时粗采样仅是该机观察值，不是 GPU 基准。水体仅作表现，不新增浮力、阻力、地面或导航烘焙。
