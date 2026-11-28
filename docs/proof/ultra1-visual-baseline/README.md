# Ultra-1 视觉基线落地验证（四域 + StasisHub）

本目录记录 `art/ultra1-visual-baseline` 在 Godot 4.7.2 Forward+ `AgX` 下的正式生产场景原生截图（无任何运行时覆盖），由 `tests/monument_optics_proof.tscn` 采集。

## 实机画面

- Sloth 怠惰庭院：`01-sloth.jpg`
- Fear 恐惧哥特殿堂：`02-fear.jpg`
- Wrath 愤怒熔窑：`03-wrath.jpg`
- Sorrow 悲伤水镜回廊：`04-sorrow.jpg`
- StasisHub 静滞之门大厅：`05-stasis-hub.jpg`

## 复现命令

```bash
godot --path . --resolution 1280x720 --windowed res://tests/monument_optics_proof.tscn
godot --headless --path . res://tests/monument_optics_test.tscn
```
