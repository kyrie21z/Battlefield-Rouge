# 暂停菜单 / 准星设置证明图

`tests/settings_proof.tscn` 在真实窗口（1280×720，画布 1920×1080）里开一局普通游戏（不是 fixture），
打开暂停菜单并切换准星设置。

| 文件 | 内容 |
| --- | --- |
| `01_pause_menu.jpg` | Esc 暂停菜单：鼠标/开镜灵敏度、准星样式、颜色、大小、粗细、透明度、动态准星、3 倍放大的实时预览、恢复默认 / 继续。面板使用 HUD 的深色底，改动立即生效，关闭时保存。 |
| `02_green_cross.jpg` | 绿色「十字+点」，大小 1.7、粗细 2.5 px，明显比默认准星大，在灰白场景里清楚可见。 |
| `03_ring.jpg` | 品红「圆环」样式，中心没有十字和点。 |

重新生成（需要真实显示，headless 没有渲染器）：

```
godot --path . res://tests/settings_proof.tscn -- --out=docs/proof/settings-menu
```

证明脚本把设置写到 `user://settings_proof.cfg` 并在结束时删除，不会碰 `user://settings.cfg`。
默认值（灵敏度倍率 1.0、ADS 倍率 1.0、白 0.9、大小 1.0、粗细 1.5、动态准星开、十字+点）与加入设置菜单之前完全一致。
