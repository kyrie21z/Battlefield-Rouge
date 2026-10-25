# Battlefield Rouge · Bible 索引

> 给程序、美术和 AI 看的硬边界。只写已经定下的事实。
> 范围的 5 行是 [MVP_Scope.md](../MVP_Scope.md)。验收是 [Cut-001](../Cut-001.md) 的 AC-01 至 AC-07。

## 不变量

1. **两段占点**：小关先把当前波次清到 0，再用锤砸据点。普通锤 +8%。完美打击是 ±150ms 与 ×1.5。100% 插旗并冲击波。这三个数是临时默认，做成配置。
2. **线性三关**：解锁顺序小关 1 → 小关 2 → Boss。关卡选择只切换已解锁的关。
3. **增益时序**：进关前选 1 条；小关结束再选 1 条并叠加；Boss 结束后不选。池子 9 条。效果 Design-TBD。
4. **装备池**：步枪、狙击枪、霰弹枪；匕首（快/近/低）、斧（慢/中/高）、太刀（中/远/中）；技能只有自身护盾，无敌 1 秒。锤只负责砸点。
5. **增益只改 Stats**：不直接改玩家或武器脚本。只有 `RunState` 和 `zone/` 改本局状态。
6. **勘误**：不存在 ±120ms、+12%、+20% 这三项配置。
7. **代码可以暂时落后**：仓库里的站圈、两张旧图、一把步枪、六条旧增益不是本索引的目标。

## 查阅

| 要做什么 | 看 |
| --- | --- |
| 现在做不做 | [MVP_Scope.md](../MVP_Scope.md) |
| 验收编号和解锁顺序 | [Cut-001.md](../Cut-001.md) |
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
