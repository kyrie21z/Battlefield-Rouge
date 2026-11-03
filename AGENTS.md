# Agent 说明

给在本仓库里工作的 AI 编程工具（Claude Code、Codex、Cursor 等）看。

- 用中文交流。代码、标识符和提交说明可以用英文。
- 动手前先读 `ARCHITECTURE.md`（依赖规则）和 `GLOSSARY.md`（术语），并遵守 `CONTRIBUTING.md` 的贡献流程：不直接提交到 `main`，提交前检查 `git diff`，地图改 `tools/gen_zones.py` 后重新生成。
- 游戏方向以 `docs/CREATIVE_VISION.md`（Mind Freak 创作愿景）为准；早期的据点 / 锤砸 / 增援规则是原型，现有代码可复用，但做设计时不要把它当目标形态。文档里的【候选】【待定】不是已批准需求。
- 引擎是 Godot 4.7.2。`../origin/` 旧工程只作参考：可以迁移代码，不能拷素材。
