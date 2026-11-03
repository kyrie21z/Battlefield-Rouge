# PR 审查标准

本文件规定 PR 什么情况能合并、什么情况不能，以及常驻审查者 kk（Grok Bot，运行在 Cursor Cloud Agent 上）怎么审。人审查也用同一套标准。改本文件走 PR，并且需要 Kyrie 本人批准。

## 一、三种结论

每次审查只给一种结论：

| 结论 | 含义 | 之后 |
| --- | --- | --- |
| ✅ **Approve** | 没有阻断项，所属级别的检查全部通过 | Kyrie 可以直接 Squash and merge |
| ❌ **Request changes** | 至少一条阻断项（第二节），或者检查脚本有 `FAIL` | 作者修改后重新审 |
| ⚠️ **需要 Kyrie** | 没发现错误，但属于第四节那几类 | kk 写审查意见，不点 Approve，由 Kyrie 决定 |

## 二、阻断项（任何一条都不能合并）

**流程**

- B1. PR 描述缺“改了什么 / 怎么测 / 风险”中任何一项，或者只写“测过了”“没问题”这类空话。
- B2. 目标分支不是 `main`，或者和最新 `main` 有冲突（R1）。
- B3. 一个 PR 做了几件不相关的事：标题一句话概括不了全部改动，或者同时改了两个以上没有依赖关系的模块。
- B4. 手写代码超过约 800 行（素材、生成的场景、证明图片不算），又没说明为什么不拆。

**素材与许可**

- B5. 新增或替换的素材（模型、贴图、音频、字体）没有在 `docs/ASSETS.md` 登记来源、许可和哈希。
- B6. 许可不明确，或者不是 CC0、CC-BY、MIT 这类允许再分发的许可；或者写着“待确认”“暂时”“先用着”。
- B7. 素材来自商业游戏、游戏资源包解包，或者从旧工程 `origin` 拷贝。
- B8. 提交了下载的原始压缩包、`third_party_sources/` 里的文件，或者没用上的素材。

**架构**（`ARCHITECTURE.md` 依赖规则）

- B9. `components/`、`weapons/`、`actors/` 读写 `RunState`，或者用绝对路径、分组去找别的系统。
- B10. `RunState` 和 `zone/` 战区控制以外的代码修改本局状态。
- B11. 增益不经过 `Stats`，直接改玩家或武器脚本。
- B12. 依赖方向反了（应该是 `ui → zone → actors → components`，反向只能用信号）。
- B13. 战区玩法代码读墙钟或调用 `randomize()`（AC-07，见 ADR 0005）。
- B14. 碰撞层直接写数字，没用 `CollisionLayers` 常量。

**文件卫生**

- B15. 提交了 `.godot/`、`export_presets.cfg`、本机绝对路径、密钥或个人信息。
- B16. 新加的 `.gd` 没有 `.gd.uid`，新加的素材没有 `.import`。
- B17. 手改了 `maps/zone_*.tscn`，或者改了 `tools/gen_zones.py` 却没重新生成（R5）。
- B18. diff 里夹着和任务无关的 `.tscn` / `.tres` 改动（编辑器自动重存产生的）。
- B19. 没说明理由就删除别人负责模块的代码或文件。

**运行**

- B20. 检查脚本的 R2 到 R5 出现 `FAIL`：导入报错、测试失败、地图和脚本不一致。

下面三条不算硬阻断，但要作者回应：新逻辑没有新测试，也没说明为什么不加；代码风格和周围不一致（Tab 缩进、`snake_case`、类型标注）；新概念没写进 `GLOSSARY.md`，重要取舍没写 `docs/adr/`。作者给出合理解释，就可以 Approve。

## 三、分级检查

kk 在云端虚拟机上运行 `tools/review/run_checks.sh`。脚本按改动的文件自动定级，取所有文件里最高的一级，只跑这一级需要的检查：

| 级别 | 改了哪些文件 | 跑哪些检查 |
| --- | --- | --- |
| docs | 只有 `*.md`、`docs/`、`.github/`、`.cursor/` | R1、R6 |
| assets | `assets/`、`art_source/` | 再加 R2 |
| map | `maps/`、`tools/gen_zones.py` | 再加 R5 |
| code | 其他文件（`.gd`、场景、`.tres`、`project.godot` 等） | 再加 R3、R4 |

| 编号 | 检查 | 做法 |
| --- | --- | --- |
| R1 | 能否合并 | `git merge-tree` 和 `origin/main` 试合并 |
| R2 | 导入 | `godot --headless --import`，出现报错行就失败 |
| R3 | 无界面测试 | 逐个跑 `tests/*_test.tscn`，以退出码为准 |
| R4 | 可复现 | 在同一台虚拟机上分别跑 PR 和 `origin/main` 的 `fixture_test`（`--fixed-fps 60`），比较哈希。哈希和机器有关，所以不拿文档里的数字比 |
| R5 | 地图是生成的 | 重新跑 `tools/gen_zones.py`，`maps/` 必须没有变化 |
| R6 | 文件卫生 | `.uid` / `.import` 齐全，`ASSETS.md` 已登记，许可写清楚，没有本机路径和密钥；再按依赖规则做文本匹配提示（`WARN`） |

`FAIL` 是硬失败。`WARN` 是脚本的提示，kk 要打开对应代码确认：确实违规就按第二节阻断，是误报就在审查里说明原因。

**截图**：虚拟机上没有显卡，`*_proof.tscn` 截图还没在虚拟机上验证过。有画面变化的 PR 仍然要作者自己附截图。

## 四、kk 不能单独放行，必须由 Kyrie 批准

检查脚本遇到下面几种情况会打出 `WARN needs Kyrie`：

- 改了 `ARCHITECTURE.md`、`CONTRIBUTING.md`、`AGENTS.md`、本文件、`docs/adr/`；
- 改了 `autoload/`（`Events` 信号、`RunState`）、`project.godot`、`components/collision_layers.gd`；
- 改了 `.github/`、`.cursor/`、`tools/review/`（审查流程本身）；
- 删除了文件；
- fixture 哈希变了（R4）。

另外两种情况脚本识别不了，kk 要自己判断：引入新的第三方代码或新的许可类型；B19 所说的删除别人负责的代码。

## 五、kk 的工作方式

**触发**：PR 打开、更新、或者从草稿转为 Ready for review 时自动触发。草稿 PR 不审。

**每次审查的步骤**

1. 先读 PR 描述，检查 B1。
2. 运行 `bash tools/review/run_checks.sh origin/main`（`origin/main` 要先 fetch 到最新）。
3. **只读脚本输出的摘要。** 完整日志在 `/tmp/review_logs/`，只有某一项 `FAIL` 或 `WARN` 时才看，而且只看对应日志的相关部分（`grep`、`tail -n 50`），不要整份读进来。
4. 读 diff，按第二节审。重新审同一个 PR 时，只读上次审查之后新增的提交；检查脚本仍然整体重跑，它不占多少模型用量。
5. 二进制文件（`.glb`、`.blend`、图片、音频）只看文件名、大小和 `ASSETS.md` 登记，不读内容。
6. 按下面的格式发一条审查评论，并给出结论。

**权限**

- 只审查。不往 PR 分支推提交，不合并、不关闭 PR，不改 Issue。需要修改的地方写成建议，由作者自己改。
- 不配置也不读取任何密钥。
- 不能确定的地方写“不确定”，不要猜。

**审查评论格式**

```
结论：Approve / Request changes / 需要 Kyrie
级别：docs / assets / map / code

检查结果：（贴脚本摘要里的 FAIL、WARN 和 summary 行，不贴完整日志）

阻断项：
- B? 文件:行 —— 问题，以及要怎么改

建议项（不阻断）：
- ...

未验证：手感、画面观感，以及截图（虚拟机没有显卡）。
```

## 六、作者要做什么

- 按 `.github/pull_request_template.md` 填写。机器能跑的测试 kk 会自己跑，“怎么测”里只写**手动玩过的流程**和看到的结果。
- 有画面变化附截图。
- 开 PR 前可以自己先跑一遍检查：`GODOT=你的 godot 路径 bash tools/review/run_checks.sh`。
- 对 kk 的意见有不同看法，在评论里回复理由；争议由 Kyrie 决定。
