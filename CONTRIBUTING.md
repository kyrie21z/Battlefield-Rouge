# 贡献指南

本文件是本仓库的贡献指南。规则少，但每条都要执行。不清楚先在群里问，不要猜。

## 一、第一次上手

1. 安装 **Godot 4.7.2**（标准版，不是 .NET 版）。所有人必须用同一个版本：版本不同时，编辑器会改写场景文件，制造大量无意义的改动。
2. 安装 Git，设置自己的名字和邮箱（提交记录里会显示）：
   ```bash
   git config --global user.name "你的名字"
   git config --global user.email "你的 GitHub 邮箱"
   ```
3. 让仓库管理员在 GitHub 的 Settings → Collaborators 里邀请你，接受邀请后克隆：
   ```bash
   git clone https://github.com/kyrie21z/Battlefield-Rouge.git
   ```
4. 用 Godot 打开仓库根目录的 `project.godot`。第一次打开会导入素材，需要等一会儿。
5. 按 F5 运行，确认能进游戏。然后读一遍 `README.md`、`ARCHITECTURE.md`、`GLOSSARY.md`。

## 二、分工

每个模块有一个负责人。改别人负责的模块前，先跟负责人说一声。模块负责人可以做同行审查；常驻审查者和合并规则见第三节。

| 模块 | 目录 | 负责人 |
| --- | --- | --- |
| 玩家、武器 | `actors/player/`、`weapons/` | 待定 |
| 敌人 AI | `actors/enemy/` | 待定 |
| 战区流程、据点、增益 | `zone/`、`buffs/`、`autoload/` | 待定 |
| 地图、素材 | `maps/`、`tools/`、`assets/` | 待定 |
| 界面 | `ui/` | 待定 |

任务记在 GitHub Issues 里，一个任务一个 Issue，开工前把 Issue 分配给自己，避免两个人做同一件事。`TODO.md` 里的条目要开工时，先转成 Issue。

## 三、日常流程

`main` 分支始终保持能运行。**不要直接往 `main` 提交**，所有改动都走“分支 → PR → 审查 → 合并”。

### 1. 开工前：从最新的 main 开分支

```bash
git switch main
git pull
git switch -c feat/capture-contest
```

分支名用 `类型/简短英文描述`：

| 前缀 | 用途 | 例子 |
| --- | --- | --- |
| `feat/` | 新功能 | `feat/enemy-reinforcements` |
| `fix/` | 修 bug | `fix/buff-not-applied` |
| `art/` | 换素材、改地图 | `art/zone1-containers` |
| `docs/` | 只改文档 | `docs/contributing` |

一个分支、一个 PR 只做一件事。工作量大约超过半天，或者同时碰到多个模块，就拆开。分支存活时间越短越好，最好 1–3 天内合并。

### 2. 做的过程中：小步提交

```bash
git status            # 看改了哪些文件
git diff              # 看具体改了什么
git add 要提交的文件    # 不要无脑 git add .
git commit -m "Enemies retreat to cover when health is low"
```

- 每次提交前**一定先看 `git status` 和 `git diff`**。Godot 编辑器会自动改写你没动过的文件（比如打开一个场景就把它重新保存），这类改动不要提交，用 `git restore 文件名` 撤回。
- 提交说明写清楚“做了什么”，一句话即可，中英文都行。不要写“update”“改了一下”。
- 每天收工前把分支推到 GitHub，防止本机数据丢失：`git push -u origin 分支名`。

### 3. 做完后：同步 main，再开 PR

```bash
git switch main && git pull
git switch feat/capture-contest
git merge main        # 把别人已合并的改动并进来，有冲突在这里解决
```

玩法、碰撞、存档的改动，合并完再在本地用 Godot 跑一遍。纯文档、错别字核对 diff。然后推送，在 GitHub 上开 Pull Request（PR）。

描述里必须写这三行：

- **改了什么**
- **怎么测**
- **风险**

有画面变化再附截图。按 `.github/pull_request_template.md` 填写。

### 4. 审查和合并

#### PR 审查者

- **HydrogenJr** 是本仓库的常驻 PR 审查 Agent（替代原 Cursor Cloud Agent 上的 kk）。PR 打开或更新时，CI（`.github/workflows/pr-checks.yml`）自动运行 `tools/review/run_checks.sh`，并由 HydrogenJr 按 [`docs/REVIEW.md`](docs/REVIEW.md) 审 diff。能不能合并以该文件为准。
- HydrogenJr 只审查，不推提交、不合并。
- 组员之间觉得有用时，仍然互相审查。
- 原则上每个 PR 都等 HydrogenJr 审完再合并。HydrogenJr 暂时无法审查时，仍要满足下面的合并规则，由 Kyrie 决定是否先合。
- **Kyrie**（仓库管理员，GitHub `kyrie21z`）负责点击合并。其他人不把 PR 合并进 `main`。

#### 合并规则

- 至少 **1 个 Approve**。HydrogenJr 的审查算这一票，组员的 Approve 也同样算。`docs/REVIEW.md` 第四节列出的情况（架构文档、`autoload/`、`project.godot`、删除文件、fixture 哈希变化等）必须由 Kyrie 本人批准。
- 由 Kyrie 使用 **Squash and merge** 合并，合并后删除远端分支。
- 不要对 `main` force-push（禁止 `git push --force` 到 `main`）。
- 合并后所有人 `git pull` 更新本地 `main`。

审查意见对事不对人。看不懂的地方直接问，作者负责解释或改得更清楚。

纯文档、错别字看 diff 即可。无界面测试和 fixture 由 CI / HydrogenJr 跑；玩法、碰撞、存档仍然要作者在本地用 Godot 实际玩过，因为手感和画面机器看不出来。自查项见第六节。

## 四、Godot 特有的注意事项

### 场景文件（.tscn）最容易冲突

`.tscn` 和 `.tres` 是文本文件，但两个人同时改同一个场景，冲突几乎没法手工合并。所以：

- **同一个场景同一时间只能一个人改。** 要改某个场景前，在群里说一声“我在改 `ui/hud.tscn`”，改完合并后再说一声。
- 能用脚本解决的，尽量写在 `.gd` 里，而不是在场景里堆节点，因为脚本冲突好解决得多。
- 万一场景冲突了：不要手改冲突标记。保留一方的版本（`git checkout --theirs 文件` 或 `--ours`），另一方在编辑器里把自己的改动重新做一遍。

### 这些文件要提交

- `*.gd.uid`、`*.import`：Godot 用来识别文件的 ID 和导入设置，缺了别人那边会报错或丢引用。
- 新加的素材本身（模型、贴图、音频），以及它在 `docs/ASSETS.md` 里的登记。

### 这些文件不要提交

- `.godot/` 目录（本机缓存，已在 `.gitignore` 里）。
- `export_presets.cfg`（导出设置，含本机路径）。
- 编辑器自动改写的、和你这次任务无关的文件（见第三节第 2 步）。

### 地图由脚本生成

`maps/zone_*.tscn` 由 `tools/gen_zones.py` 生成，**不要在编辑器里直接改地图**，否则下次生成会把改动覆盖掉。改布局就改脚本里的数据，然后运行：

```bash
python3 tools/gen_zones.py
```

把脚本和生成的场景一起提交。

### 移动或重命名文件要在编辑器里做

在 Godot 的文件系统面板里拖动或重命名，编辑器会同时更新所有引用。在资源管理器或命令行里直接改名，会导致引用断掉。

## 五、代码规则

- 遵守 `ARCHITECTURE.md` 的依赖规则：组件只发信号、只有 `RunState` 和战区控制改本局状态、增益只改 `Stats`。审查时这几条是重点。
- 新出现的游戏概念，在 `GLOSSARY.md` 里加一行；重要的设计取舍（比如“占点改成争夺机制”）写一篇 `docs/adr/`。
- 代码风格跟周围的代码保持一致：GDScript 用 Tab 缩进，变量和函数用 `snake_case`，类名用 `PascalCase`，变量尽量写类型。
- 新素材只能用许可明确允许的（CC0 等）。下载的原始压缩包放在仓库外面，只把用到的文件拷进 `assets/`，并在 `docs/ASSETS.md` 登记来源、许可和哈希。**不要从 `../origin/` 旧工程拷素材**，那边的素材没有许可记录。
- AI 辅助完成的代码与手写代码使用同一套 PR 标准（一件事、三行描述、审查和合并）。作者必须能解释每一处改动，不要把大段自己讲不清的生成代码一次性丢进 PR。

## 六、合并前自查清单

纯文档、错别字只核对 diff。玩法、碰撞、存档必须在本地用 Godot 跑过，再勾选和运行有关的项。

- [ ] 分支已经并入最新的 `main`，并且能正常运行（纯文档、错别字改为核对 diff）
- [ ] 完整玩过一遍受影响的流程（比如改了据点，就从战区 1 打到胜利，再测一次阵亡重开）；纯文档、错别字跳过
- [ ] 本地跑过 Godot 时，输出面板没有新的报错或警告
- [ ] `git diff` 里只有这次任务相关的改动
- [ ] 新概念、新素材、新决策已经写进对应文档

## 七、出问题了怎么办

| 情况 | 做法 |
| --- | --- |
| `git pull` 提示有冲突 | 先别慌，也别乱删文件。打开冲突文件，保留正确的内容，删掉 `<<<<<<<`、`=======`、`>>>>>>>` 标记，然后 `git add` 再 `git commit`。场景文件冲突见第四节。 |
| 改乱了，想回到上次提交 | `git restore 文件名`（撤回单个文件）或 `git stash`（暂存全部改动，之后可以 `git stash pop` 找回）。 |
| 不小心提交到了 main | 还没推送的话，在群里说一声，再一起处理；不要用 `git push --force`。 |
| 拉下来的代码跑不起来 | 先删掉本地的 `.godot/` 目录，重新打开项目让它重新导入。还不行就在群里发报错截图。 |

**禁止**：`git push --force` 到 `main`；提交密码、密钥或个人信息；未经讨论删除别人的代码或文件。
