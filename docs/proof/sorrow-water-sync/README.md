# 场景分支同步新版轻柔水声

2026-11-15，用户要求恐惧场景版也要包含新水声。PR #210 已合并后，将最新 main `a41d1af` 合入场景分支 `art/fear-white-cathedral`（原场景提交 `10b0b10`），继续更新同一个正式 PR #212，不另开重复PR。

当前工作区同时包含白色断裂圣殿、每房6只高空幽魂与新版轻柔涉水声。解决README顶部两段说明的文本冲突，保留两项更新。地图、幽魂、敌人/Boss、随机编排和坠落30HP规则保持。

## 水声默认与验证

- 合成增益0.38，播放电平-17dB，75ms淡入/180ms淡出，0.30系数平滑高频。当前三个水声实现文件与最新main逐字节一致。
- Godot 4.7.2 / Vulkan Forward+ 原生 `sorrow_audio_test` 16项通过，覆盖实际落地涉水、冲刺、站立与干台不触发、暂停、剥夺和死亡停止。
- 相关无界面检查全部通过：涉水音频集成12、水面32、雨底13；恐惧场景保留检查37项通过（幽魂、侧台真实通行与导航、三房保留）。本次合计110项，不将前轮场景测试当作此次重跑。
- 从当前引擎实际导出步行/冲刺WAV，与已合并PR #210的两份轻柔试听逐字节一致，确认运行的音色也是新版。试听仍见 [轻柔水声记录](../sorrow-water-soft/README.md)，未新增或复制第三方录音。
- 本次6份运行日志无脚本、导航、音频或退出诊断。未重新改动水声参数，未新增重复测试；恐惧画面和原生截图沿用 [场景记录](../fear-sanctum/README.md)。

```sh
godot --path . res://tests/sorrow_audio_test.tscn
godot --headless --path . res://tests/sorrow_audio_integration_test.tscn
godot --headless --path . res://tests/sorrow_water_test.tscn
godot --headless --path . res://tests/sorrow_ambience_test.tscn
godot --headless --path . res://tests/fear_sanctum_test.tscn
```

`validation.json` 记录本次源码、证据和导出WAV的SHA-256、字节数以及合并父提交。文本使用Git LF，日志仅移除终端色码和行末空白。用户存档与原有未跟踪导入设置保留。
