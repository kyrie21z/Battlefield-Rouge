# 悲伤涉水原创音色续改

2026-11-11，更新Issue #207 / PR #208。基于其已发布头 `9114c09d6b5ee17b5e3624dc85eff097fbe8295d`，不重复修改雨底、红边或随机顺序。

用户指出行走声有空洞敲击，应是水波荡漾；提供“水波2”录音作为音色参考，最后明确要求制作自己的版本并上传PR。本轮提交的是原创程序合成代码和从它生成的证明音频，不包含参考录音、其裁剪片段，或本地录音预览提交 `0924d39` 的任何历史。该提交不是本分支祖先。

## 当前音色

- `SorrowSoundBank._motion_water` 用私有种子17970/17971生成步行/冲刺，22050Hz/PCM16单声道，时长0.60/约0.65秒。滤波噪声形成水流，缓慢变化的带通共鸣形成液体涟漪；45ms淡入/120ms淡出，移除原260Hz低频敲击。没有读取、变换、拼接或混入用户录音的波形数据。
- 正式领域和独立几何的_splash_sound共用新的water_step；两种声音在加载时预热并缓存，避免首次步行/冲刺时生成。距离门槛0.55米、步行0.30秒/冲刺0.14秒间隔、湿区/着地/暂停/死亡/剥夺等条件保留。
- rain、water_bell、tear_return、tear_spray、glass五种PCM逐字节与前提交相同，真实玩家枪声不改。未添加下载素材、运行时采样文件或外部音频依赖。

## 验证与试听

Godot4.7.2 Windows Forward+/Vulkan原生 `sorrow_audio_test`16项通过，覆盖实际涉水/冲刺、站立/干台、暂停/剥夺与死亡清理。相关无界面集成12、水面32、雨底13项通过，最终四份日志无脚本/导航错误或退出诊断。测试采用真实生产演员/物理和自动操作，不称作人工听辨。

| 幅度统计 | 旧步行 | 新步行 | 旧冲刺 | 新冲刺 |
| --- | ---: | ---: | ---: | ---: |
| RMS | 0.045777 | 0.033103 | 0.056546 | 0.035470 |
| 峰值 | 0.560242 | 0.172791 | 0.592163 | 0.155090 |
| 前40ms RMS | 0.158696 | 0.030769 | 0.172757 | 0.010800 |

数值是归一化PCM幅度，只辅助核对更柔和的起音/无削波，不等于扬声器声压级或人工主观验收。完整数据、五音色哈希和文件校验见 `validation.json`。

[旧步行敲击](audio/step-before.wav) · [新步行水声](audio/step-after.wav) · [新冲刺水声](audio/slide-after.wav) · [六步连续试听](audio/walk-preview.wav)

前三份从真实音库导出；连续试听只把新生成步行声按0.30秒间隔叠加六次，保留原幅度，无参考录音成分，不冒充完整游戏混音。证明WAV受 `docs/proof/.gdignore` 隔离，不进入运行时导入。没有画面变化，不新增场景截图。

```text
godot --path . res://tests/sorrow_audio_test.tscn
godot --headless --path . res://tests/sorrow_audio_integration_test.tscn
godot --headless --path . res://tests/sorrow_water_test.tscn
godot --headless --path . res://tests/sorrow_ambience_test.tscn
```

试听导出脚本见 `export_motion.gd.txt`，声音生成源码位于 `audio/realms/sorrow_sound_bank.gd`。日志仅规范行尾空白。当前检查限本机与相应音频流程，原始PR其他游戏规则与验证记录保留；真人听感仍待用户试玩反馈。
