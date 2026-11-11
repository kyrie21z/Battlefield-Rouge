# 正式领域受击红边、连续雨声与随机编排

2026-11-11，Issue [#207](https://github.com/kyrie21z/Battlefield-Rouge/issues/207)。基于已合并PR #206的main `c6c33a079dfcc2e53640817234888149074b296b`，源码树 `3f6355ffb2af150477fdecae05ae1d896847244f`。历史固定顺序、Boss调试及旧证明不改写；当前默认以下述随机编排为准。

## 改动与默认值

- 旧 `HUD` 已有红边，但正式四领域使用的 `RealmHUD` 没有接入。新增 `RealmHurtFeedback`，显式注入Health，复用现有红边shader；只响应真实扣血与死亡。位于悲伤单色覆盖之后、准星/生命/菜单之前，不给画面增加抖动。
- 强度 `clamp(0.30 + 2 × 同次伤害 / 最大生命, 0.30, 0.82)`，0.06秒内受击合并，0.55秒淡出；中心半径0.5保持透明，边缘半径1.0达到完整强度，shader最大强度0.9。无敌/护盾完全挡住则不触发；暂停冻结、死亡清除、鼠标穿透。恐惧的预警剥夺仍隐藏方向弧线，但不会隐藏已经受到伤害的非方向红边。
- 用户确认悲伤的背景枪声“站着不动也会出现”。检查实际雨底：每4秒循环包含13个相隔0.307秒、720–1284Hz、快速衰减的共鸣，并且循环首尾存在跳变。替换为连续双层滤波噪声和缓慢起伏，额外0.25秒尾部平滑重叠到开头，移除规律短促音。保持4秒、22050Hz、PCM16单声道、同一路由和音量设置、私有种子179；不是将整个领域静音。
- 其他六种悲伤音色的PCM逐字节不变；正常玩家枪声仍触发实际武器音源和枪声事件。静止时追踪不到实际玩家或旧敌人枪声播放，因此本次处理的是背景雨底中的类枪声瞬态，不声称发现了误播的枪声素材。主观听感仍需用户回听。
- 正式新局恢复 `randomize_realm_order=true`，沿用私有RNG的种子洗牌，同种子可复现，每局包含四领域且不重复；不同新局允许偶然得到同一排列。每领域仍两战斗房加Boss、深度倍率 `1+0.18×depth`、碎片/剥夺与前轮30生命坠落规则保留。显式固定恐惧路线仅作诊断。

## 原生与相关验证

Godot4.7.2 / Windows / Forward+ / Vulkan / RTX4060 Laptop。测试使用独立APPDATA与测试档案，不操作正式钱包。原生自动操作真实生产演员/输入/物理并查看截图，不称作手工完整通关。

- `realm_feedback_test` 无界面37项、原生44项：四个真实领域的即时红边、暂停、0.55秒淡出、无敌/护盾不触发、剥夺保留非方向反馈、多击合并封顶、死亡清理；原生恐惧/悲伤画面逐像素比较边缘更红且准星中心基本不变，保存2图并完整结束四个场景。
- `sorrow_ambience_test` 最终无界面13项、原生14项（多一次试听文件保存）：连续观察520个物理帧、超过两个4秒循环，站立且冻结敌人，枪声事件为0，也没有任何音源播放真实玩家或旧敌人枪声PCM；只有托管雨底在环境池播放，无旧涉水声叠加。随后实际手枪开火仍播放并产生一次事件。暂停、剥夺、确定性、不消耗全局RNG、PCM响度/无削波/循环衔接均通过。
- `run_director_test` 54项：96个种子覆盖全部24种排列，四领域开局计数为怠惰21、恐惧22、愤怒28、悲伤25；同种子准确复现，保留深度/门控/跨房恢复/死亡历史。
- 18组相关回归断言全部通过：反馈37、雨声12（最终增加实际音源断言另验13/14）、编排54、十二房98、恐惧专用路线30、悲伤音频16/集成12/水面32、领域Stage27/BossStage20/玩家效果15、旧受击反馈、反击盾28、前轮Boss修订21、局外战役23/锻造31/结算16、开场22。列表和原始日志见 `validation.json` 与 `regression-*.log`。
- 原生正常入口走跳过开场、锻造、实际随机领域、初始选卡、手枪、死亡重开与两旧fixture入口，14项通过；本次开局实际为愤怒，没有强制恐惧。原生入口日志的最长帧包含加载，不作本轮帧率保证。
- 基线/修复同机各6次fixture，同seed重复一致、换seed不同且均胜利，FX001/002两版一致。基线工作区head是PR #206 head `1299361`，与合并main c6c33a0的源码树完全相同，未将旧日期的哈希当本轮测量。
- 最终原生反馈、雨声与入口无脚本/导航错误或退出诊断。相关旧悲伤音频测试断言16项通过，退出出现10个ObjectDB诊断，前轮已有同类记录；最后verbose复查16项未复现。编辑器导入退出0，保留宿主Safe save诊断；未修改系统权限、安全保存或证书设置。不宣称所有历史运行零诊断，未完成人工听感或其他平台验收。

## 雨底信号对比

两版均导出实际 `SorrowSoundBank.get_sound("rain",true)` 的4秒PCM。统计为归一化振幅，不代表扬声器上的声压级，也不替代人工听辨。

| 数据 | 基线 | 修复 |
| --- | ---: | ---: |
| RMS | 0.038160 | 0.035739 |
| 峰值 | 0.142120 | 0.142639 |
| 循环首尾相邻样本差 | 0.086029 | 0.003021 |
| 旧13个起点/频率前40ms的平均匹配投影 | 0.021177 | 0.003724 |

最后一项只用于确认旧规律性窄带脉冲降低，不能据此宣称人耳不可能听到类似枪声。[修复前试听](audio/rain-before.wav) / [修复后试听](audio/rain-after.wav)；完整统计、其他音色字节一致性见 `rain-analysis.json`，通用复算脚本 `analyze_rain.py.txt`。

## 图像与复现

`fear-red-edge.jpg`、`sorrow-red-edge.jpg`为真实10生命受击后的生产第一人称画面，生命100→90；原生PNG用Godot转存JPEG，质量0.84，无重绘，PNG保留本机。素材和新音频来源在 `docs/ASSETS.md`，清单记录全部证据的实际Git LF/二进制字节和SHA256；日志仅规范行尾空白，verbose节录去逐资源加载噪声。

```text
godot --headless --path . res://tests/realm_feedback_test.tscn
godot --path . res://tests/realm_feedback_test.tscn -- --out=res://.runtime/feedback-native
godot --path . res://tests/sorrow_ambience_test.tscn -- --out=res://.runtime/audio-after
godot --headless --path . res://tests/run_director_test.tscn
godot --headless --path . res://tests/campaign_realms_test.tscn
godot --path . res://tests/opening_boot_test.tscn -- --route=skip
godot --headless --fixed-fps 60 --path . res://tests/fixture_test.tscn
python analyze_rain.py audio/rain-before.wav audio/rain-after.wav
```
