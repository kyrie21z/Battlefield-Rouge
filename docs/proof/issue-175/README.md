# #175 心象档案：UI、内容与生产接入

基线：`b9457c7`。独立组件包括 LoreDiary、LoreEntries 与隔离测试；整合提交另含 MetaProgression/RunDirector 的进度记录、战斗 BuildInspector 日记页和结局菜单阅读入口。真实事件与最终验收见 [integration.md](integration.md) 和 [persistence.md](persistence.md)。下文的只读接口与独立组件证据保留。

## 接入接口

```gdscript
var diary := preload("res://ui/codex/lore_diary.tscn").instantiate() as LoreDiary
page_container.add_child(diary)
diary.setup({
	"visited_realms": [0, 1],
	"defeated_realms": [0],
	"reconciled": false,
})
```

`LoreDiary extends Control`，横纵 `EXPAND_FILL`。父容器提供完整页面空间，内部自行管理目录和正文滚动。`setup(archive: Dictionary)` 可在入树前或后调用；保留字典引用，原字典内更新后调用 `refresh()`。若主管替换整个字典，请再次 `setup(new_archive)`。不发起存档、不管理暂停/鼠标、不监听全局输入、不消费 TAB/ESC；这些行为由宿主负责。页面显示时给当前目录按钮焦点，普通 `refresh()` 不夺取焦点。

领域索引固定为怠惰 0、恐惧 1、愤怒 2、悲伤 3，与 BoonData.Sin / RunDirector.REALMS 一致。主管负责记录真实进入/死亡、真实 Boss 击败、实际和解；UI 不推断事件。

| 条件 | 日记 | 双面档案 |
| --- | --- | --- |
| 未访问 | 通用封存页与条件提示 | 通用封存页与条件提示 |
| visited 含该领域 | 对应完整手记 | 皇冠的绊脚石评论 |
| visited 和 defeated 均含该领域 | 对应完整手记 | 评论 + 人性保护价值 |
| reconciled 为 true | 第五篇终局完整手记 | 各领域仍按独立 visited/defeated 门槛 |

`LoreEntries.project()` 返回经过门槛筛选的页面字典，未解锁正文/评论/保护价值为空字符串，未解锁手记标题也不投影。UI 仅接收投影结果。换页、栏目切换、进度回退/换档时立即释放旧正文控件；无隐藏正文、正文 metadata 或 tooltip。源码是本地游戏内容，不做加密或防数据挖掘的承诺。

五篇手记遵循 issue 指定标题；四系档案均有皇冠评语与第一人称反思。现实背景为学术答辩，皇冠的建议真诚且曾有用，前期不透露 Pride 身份。保护价值描写不把愤怒等同于伤害许可，也不将胜利当作休息或自我价值的前提。所有叙事为虚构文学文案，无心理诊断或治疗建议。

## 交互与布局

黑曜石底、细金线、低饱和领域色；阅读区在右，目录和正文各自滚动。1280×720 使用更紧凑的边距/字体，1920×1080 使用较大留白和行距。长文允许滚动，避免缩字塞进一屏。

- 方向键/D-pad 移动焦点，Enter/手柄确认或 A 打开条目及栏目。
- 目录向右进入正文，向左返回当前条目。
- 正文支持滚轮、方向键/D-pad、PageUp/PageDown、Home/End。
- `ui_accept` 遵循 Godot 平台默认；若默认不含 A，页面内额外支持 A，不修改全局 InputMap。
- TAB 保留默认焦点导航与宿主处理权；ESC 保留宿主关闭权。

## 验证

本机 Godot `4.7.2.stable.official.ed1daf0bf`，Windows 引擎经 WSL wrapper 在当前 worktree 运行。先完成新的 headless editor import。

```bash
/tmp/epic34-plan/godot-wsl --headless --editor --path . --import
/tmp/epic34-plan/godot-wsl --headless --path . res://tests/lore_diary_test.tscn
flock /tmp/epic675-native.lock /tmp/epic34-plan/godot-wsl \
  --path . --audio-driver Dummy res://tests/lore_diary_proof.tscn
```

`lore_diary_test`：**43 checks，0 failed**，无脚本错误。覆盖空档、乱序逐领域访问/击败、四次击败不能解锁终局、和解解锁、所有页面和栏目递归文本/tooltip防剧透、进度回退、缺失字段、只击败不访问不推断、输入焦点、A 确认/切栏目、两种尺寸换行、滚动至首尾，以及无暂停/鼠标副作用。日志见 [checks.log](checks.log)。

测试和截图均从 `res://tests/` 入口运行，MetaProgression 在 autoload 初始化就改用 `user://meta_test_autoload_<pid>.json`，其 `isolated_profile` 在测试开头断言；不读取、覆盖真实存档。测试只注入内存 archive，不伪造正式进度。无真实奖励或存档写入调用。

原生截图采用 Forward+ / Vulkan、RTX 4060 Laptop GPU，同一 `flock /tmp/epic675-native.lock` 串行运行。原生脚本拒绝 headless 或非隔离档，保存后检查 Image.save_png 状态。每个状态均有 1280×720 和 1920×1080 原始帧，均已用 `view_image` 人工查看；[native.log](native.log) 保留图像尺寸和写入结果。

| 原始帧前缀 | 状态 |
| --- | --- |
| `01-locked` | 空档封存页，无隐藏正文 |
| `02-visited-diary` | 初访怠惰，显示第一篇手记 |
| `03-crown-only` | 皇冠评论已开，人性另一面仍封存 |
| `04-dual-dossier` / `04b-dual-dossier-end` | 愤怒双面档案顶部/底部，含保护边界与不认可伤害的正文 |
| `05-reconciled` / `06-final-line` | 终局手记顶部/底部，最后一行可达 |

独立组件测试证明注入 archive 后的 UI 门槛和交互；主管已整合生产 BuildInspector、结局菜单及真实事件存档，端到端结果见 [integration.md](integration.md)。手柄输入为原生 InputEventJoypadButton 注入，未声称实体手柄人工实玩。全库回归与最终 PR 合并由集成负责人执行。
