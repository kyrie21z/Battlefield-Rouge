# Battlefield Rouge · Bible 索引

> 2026-11-03：本文是早期 Battlefield Rouge 原型的规则，描述当前代码的行为，改动现有系统时仍以它为依据。游戏方向以 [Creative Vision](../CREATIVE_VISION.md) 为准，冲突时以愿景为准；新的玩法范围按轮次写在 Cut 文档里（当前是 [Cut-002](../Cut-002.md)）。

> 给程序、美术和 AI 看的硬边界。只写已经定下的事实。
> 范围的 5 行是 [MVP_Scope.md](../MVP_Scope.md)。验收是 [Cut-001b](../Cut-001b.md) 的 AC-01 至 AC-08。

## 不变量

1. **两段占点**：小关先把当前波次清到 0，再用锤砸据点。普通锤 +8%。完美打击是 ±150ms 与 ×1.5。100% 插旗并冲击波。这三个数是临时默认，做成配置。
2. **线性三关**：解锁顺序小关 1 → 小关 2 → Boss。关卡选择只切换已解锁的关。
3. **增益时序**：3 次：开局前 1 次 + 两个小关结束各 1 次；小关 2 和 Boss 进场不选；Boss 后不选。本局叠加。池子 9 条。效果 Design-TBD。2026-10-27 由 issue #22 修订 D-002（原为每关入场，一局 5 次）。
4. **装备池**：步枪、狙击枪、霰弹枪；匕首（快/近/低）、斧（慢/中/高）、太刀（中/远/中）；技能只有自身护盾，无敌 1 秒。锤只负责砸点。
5. **增益只改 Stats**：不直接改玩家或武器脚本。只有 `RunState` 和 `zone/` 改本局状态。
6. **勘误**：不存在 ±120ms、+12%、+20% 这三项配置。
7. **代码可以暂时落后**：仓库里的两张旧图、一把步枪、六条旧增益不是本索引的目标。

## 查阅

| 要做什么 | 看 |
| --- | --- |
| 现在做不做 | [MVP_Scope.md](../MVP_Scope.md) |
| 验收编号和解锁顺序 | [Cut-001b.md](../Cut-001b.md) |
| 循环和动词 | [Core_Loop.md](../Core_Loop.md) |
| 优先级 | [Priority_Backlog.md](../Priority_Backlog.md) |
| 玩法说明 | [GDD.md](../GDD.md) |
| 规则 | [03_rules.md](03_rules.md) |
| 数值边界 | [SPEC.md](SPEC.md) |
| 手感 | [EXPERIENCE.md](EXPERIENCE.md) |
| 已锁定条目 | [99_decisions.md](99_decisions.md) |
| 为什么放弃战地征服和站圈 | [ADR 0002](../adr/0002-mvp-deadzone-occupy.md) |
| 目录和谁能改本局 | [ARCHITECTURE.md](../../ARCHITECTURE.md) |
| 术语 | [GLOSSARY.md](../../GLOSSARY.md) |
