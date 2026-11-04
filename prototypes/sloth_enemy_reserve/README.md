# Sloth 红晶体敌人 · 独立备用方案

**状态：备用评审原型。主游戏不接入。** 跟踪任务：[Issue #89](https://github.com/kyrie21z/Battlefield-Rouge/issues/89)。 本目录由 `.gdignore` 隔离，不改变正式入口、玩家、地图、敌人、数值或 fixture。不要把 `overlay/` 直接覆盖到正式工程。

内容：破洞兜帽披风迟滞者、断环链节锚定者、六瓣茧壳退缩者，以及对应攻击、真实物理检查和模型展厅。[设计与参数](DESIGN.md) · [原生画面与已知问题](proof/README.md) · [素材来源](ASSETS.md)。

## 生成独立副本

需要 Git、Python 3.10+、Godot 4.7.2。请从本仓库的 Git 克隆使用，ZIP 下载不包含所需历史对象。若使用浅克隆，请先获取基线提交 `5004e8c`。

```powershell
python prototypes/sloth_enemy_reserve/prepare.py --out "../Sloth-Enemy-Review"
godot --editor --path "../Sloth-Enemy-Review" --import --quit
godot --path "../Sloth-Enemy-Review"
```

`--out` 必须是尚不存在的新目录；可选本目录中已忽略的 `.build/新名字`。工具只读取仓库基线，以 `git archive` 导出、校验并应用本包；不会切换分支、改写正式文件或携带 `.git/.godot`。Git 克隆须拥有基线 `5004e8cd64d8d7dec12e879033e43d356168d74f`。Godot 不在 PATH 时，使用自己安装的引擎绝对路径代替命令中的 `godot`。

默认只打开展厅：**0** 三类并排，**1/2/3** 单体；左键拖动环绕、滚轮缩放、空格切换蓄力和开壳。第一次请等待资源导入。

仅在生成的独立副本中试玩战斗和检查：

```powershell
godot --path "../Sloth-Enemy-Review" res://maps/zone_1.tscn -- --skip-opening
godot --headless --fixed-fps 60 --path "../Sloth-Enemy-Review" res://tests/sloth_enemy_test.tscn
```

## 文件组织与审核边界

- `overlay/`：新增敌人、模型构建、布料材质、展厅、检查与备用 project.godot；既有红晶体GLB从基线复用，不重复上传。
- `integration.patch`：独立副本的玩家减速接口、敌人编排、增援与相关旧断言调整；该补丁只由还原工具应用到新目录。
- `payload.json`：还原所需文件的 SHA-256；`proof/`：实机 JPEG 和原始验证日志。

代码量主要来自三套几何附件、技能与行为检查，保留为一个相互依赖的备用实验；没有并入正式敌人、地图或关卡任务。既有 #47（迟滞者正式接入）、#46（完整关卡）继续独立跟踪，不因本包标成完成。

## 当前验证与待办

原备用工程无界面 **42/42通过**；原生 **40/42通过**。原生冲刺控制组5.349米、减速组1.144米，两项距离验证未通过；保留严格断言与失败日志，未把原因认定为已定位或已修复。其余双弹、领域、掩体、跳跃、核心弱点和暂停检查通过。

本轮仅作为**草稿PR供审查**，不声称可正式接入；原生冲刺、真人平衡、性能、美术最终评审与跨平台仍待验证。完整Sloth场景、沉眠巨像、Rest Zone与战后叙事未制作。
