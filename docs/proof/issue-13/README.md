# Issue #13 Proof（AC-06）

三个流派靠剪影和方向分开。效果数值仍 Design-TBD，截图里没有新倍率。

由 `tests/school_icons_proof.tscn` 在真实窗口里跑出：

```bash
godot --path . res://tests/school_icons_proof.tscn -- --out=<输出目录>
```

无界面检查（图标能加载、三色三剪影不同、选择界面有三枚 `SchoolBadge`）：

```bash
godot --headless --path . res://tests/school_icons_test.tscn
```

| 文件 | 内容 | 证明 |
| --- | --- | --- |
| `01_three_schools.png` | 狂战士（红、斧、近战）、军火大亨（黄、弹药、弹药特性）、鹰眼（青、准星、爆头收益）。每派下面是 48 px 和 32 px | AC-06 三派对照。小尺寸仍能分开 |
| `02_buff_select.png` | 增益选择界面的「流派方向」一排，用的是同一套 `SchoolBadge` | 图标接在现有选择界面上 |

下面三个按钮仍是现在的占位增益（快速扳机、空尖弹、野战护甲），不是九条流派增益。AC-08 不在这张图里。

颜色锁在 `docs/STYLE.md`：`#E0242A` / `#6E1218`，`#F5C400` / `#8A6800`，`#14C8D4` / `#0A6670`。图标文件在 `assets/ui/schools/`。
