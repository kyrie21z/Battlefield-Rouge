# #174 双重共鸣图鉴：生产接入与验收

战斗中按 TAB / 手柄 View 打开心智矩阵，再选“赐福图鉴”。生产 HUD 绑定当前 Player 的 BoonManager，发现列表由 MetaProgression 注入；打开与关闭沿用 #173 的暂停所有权。图鉴读取实际 48 张心魔卡和 6 张双重资源，资格由 BoonManager.can_equip 决定，前置说明仅解释资源字段，不另建合成判定。

四种核心和六组路线显示装备状态；满足条件的双重边缘微光脉冲，已持有的双重不会重复提示可获得。任一前置、全部前置、核心心魔与传奇特质数量均按资源解释。LB/RB 环绕切换分类；方向键/D-pad 访问卡片与独立滚动详情，详情顶部再次向上返回卡片。图鉴不装备卡牌。

成功选卡的 Events.boon_chosen 记录发现；RunDirector 恢复真实装备时补记初始赐福。发现信息随既有版本 1 校验存档持久化，旧档缺字段安全默认，写盘失败保留内存并在下次成功保存重试。面板显示待保存提示。存档细节与旧档/失败路径测试见 [persistence.md](persistence.md)。

## 验收结果

- 集成后的 `dual_boon_codex_test.tscn`：207 checks，0 failed。六组合、同槽替换、装备后资格变化、全部 48 卡效果、任一前置、传奇数量、真实肩键/D-pad 注入、两分辨率与滚动均覆盖。[日志](integration-codex.log)
- `codex_modal_test.tscn`：8 checks，0 failed。真实 Player/BoonManager、选卡事件持久化、生产宿主页签注入、暂停、肩键、返回构筑与恢复。[日志](production-modal.log)
- 发现存档：10 checks；原 meta_forge 回归31 checks，均通过。[存档证据](persistence.md)
- 子代理原生运行216 checks，0 failed，包含9张PNG写入检查；[日志](standalone-native.log) 与 [尺寸/哈希清单](standalone-screenshots.json)。9张独立页面均由实现代理逐张 view_image 审阅。
- 主管另从真实 `sloth_1` RealmStage 的 HUD 打开检视器，装备实际怠惰枪/暴怒刀，生成 [production-modal.png](production-modal.png)，已 view_image 审阅。1280×720 下六路线、当前核心、可获得蓄压熔岩、列表/详情滚动布局清晰；[原生日志](production-native.log)。该画面为隔离测试运行，不写玩家存档。

引擎为 Godot 4.7.2 stable，原生 Forward+ / Vulkan / RTX 4060 Laptop。所有测试从 `res://tests/` 启动，MetaProgression 在 autoload 初始化时隔离配置；原生运行持有共享 flock。导入日志见 [integration-import.log](integration-import.log)。本轮日志没有 ERROR / SCRIPT ERROR / WARNING / FAIL。

```bash
/tmp/epic34-plan/godot-wsl --headless --editor --path . --import
/tmp/epic34-plan/godot-wsl --headless --path . res://tests/dual_boon_codex_test.tscn
/tmp/epic34-plan/godot-wsl --headless --path . res://tests/codex_modal_test.tscn
flock /tmp/epic675-native.lock /tmp/epic34-plan/godot-wsl --path . res://tests/codex_modal_proof.tscn
```

最低按1280×720验收，长文通过滚动阅读。手柄为 InputEventJoypadButton 注入，未声称实体手柄长时间游玩。本 issue 不含 #175 日记；全库回归与 PR 合并由集成负责人验收。架构关系为 UI → actors/buffs，autoload 只记录真实流程事件；不增加 actors 对 RunDirector 的反向依赖。
