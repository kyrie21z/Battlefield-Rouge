# 按键绑定验证截图

`tests/settings_proof.tscn --out=docs/proof/keybindings` 产出（1920x1080 canvas，
1280x720 窗口）。

| 帧 | 内容 | 检查点 |
| --- | --- | --- |
| 04_key_bindings | 暂停菜单「按键绑定」页，挥锤刚改绑为 Q | 菜单默认开在「设置」页、高亮同步（由测试覆盖）；两列网格一屏放下全部 15 个动作（8+7），无滚动；改绑后「挥锤」行显示 Q，原持有 Q 的「切换近战」自动换成 E，状态行出现「已与「切换近战」互换」；面板底色接近不透明，增益卡不透过；面板完整落在画面内 |
| 05_menu_over_buff | 开局三选一（BUFF_SELECT，已暂停）上打开的 Esc 菜单 | 菜单默认开在「设置」页且全部设置行（含准星预览）无滚动可见；菜单出现在增益选择界面之上（PauseLayer 20 > 选择层 10），背景卡片不透过面板；菜单开着时其身后的 1/2/3 数字键无响应；关闭菜单后树保持暂停、增益界面继续可用 |

配套无头测试 `tests/keybinding_test.tscn` 覆盖：encode/decode 往返、保留键拒绝、
assign+apply 改写 InputMap 与 KeyHint、冲突互换、改回默认清除覆盖、
`user://keybinding_test.cfg` 存取往返、reset_defaults 还原 InputMap、
菜单默认开在「设置」页且 tab 高亮与内容同步、菜单捕捉流程（按键 / Esc 取消 /
保留键拒绝 / 点击另一行切换捕捉目标 / 空白处左键仍绑定左键）、
BUFF_SELECT 上开与关、提示文案（目标面板「按 T 挥锤」）跟随改绑。
