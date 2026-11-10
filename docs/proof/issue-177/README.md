# #177 恐惧声景

`FearAudioDirector` 由 `RealmStage` 注入真实玩家、敌人及剥夺状态。环境低音由25、33、46 Hz构成，附加很轻的92 Hz泛音以保留小扬声器上的风感。窥视者蜂鸣按 `attack_elapsed / windup()` 从0.7升至1.6倍音调；`gaze_progress` 是玩家对视打断计时，不用于伪造锁定进度。真实对视打断、关闭预警、剥夺、死亡、撤退和失去目标均移除持续声源。闪现只监听实际 `blink_count` 增量，左右声道使用不同的相位扫频；失败闪现不发声。

持续演员声音使用固定8声部，短音沿用共享基类16声部。暂停冻结时间与实际播放，玩家死亡停止声源，换房释放节点。源码合成仅使用固定种子的局部RNG，不消耗玩法随机序列，不读取战役单例。

`FearSoundBank.boon_cues` 把真实 `fear_flaw_broken` 的命中位置映射为晶碎音；父框架统一接线，所以在Sloth等其它领域装备恐惧赐福仍可发声。`FearCriticalFeedback` 保留伤害字与普通非破绽暴击声音，仅在实际破绽事件已发出时关闭旧声，避免叠播。

## 验证入口

Godot 4.7.2 / Jolt：

```sh
/tmp/epic34-plan/godot-wsl --headless --path . res://tests/fear_audio_test.tscn
```

测试使用生产Fear和Sloth房间、真实对视/闪现/物理破绽命中链路，并检查暂停、剥夺、声部上限、死亡与释放。带 `-- --audio-proof` 可重导本目录预听WAV；普通测试不写入仓库。实际测试日志见 `fear-audio.log`。

`pcm-analysis.json` 从导出的16位双声道WAV计算峰值、RMS、声道差异与指定频率的DFT能量。深渊音约95.3%的左声道能量位于25/33/46 Hz三个目标频点；闪现左右声道差异RMS约0.171。波形/行为验证不代替人工听感验收；尚未宣称扬声器低频响应、压迫感或“爽感”已人工通过。

## 父集成所需文档登记

- `ARCHITECTURE.md`：`audio/realms` 是Stage注入的表现层，单向读演员状态，持续8声部+短音16声部，不改玩法。
- `GLOSSARY.md`：锁定蜂鸣=`FearAudioDirector`，实际蓄力进度升调；闪现相位声=`FearSoundBank`，真实瞬移计数触发。
- `ASSETS.md`：本issue全部声音为仓库原创数学合成，无外部采样/模型/授权素材；源码 `audio/realms/fear_sound_bank.gd`。本目录WAV为可复算预听证据，SHA-256见 `pcm-analysis.json`。不从旧工程复制素材。
- 依赖父 #176 的 `RealmAudioDirector.get_sound` 扩展接口及父 #177 动态bank事件路由；本提交不包含借用的共享基类或Stage文件。

## 集中集成与旧入口兼容

共享 RealmAudioDirector 在所有房间路由 FearSoundBank 的真实破绽事件；只有消费该事件的控制器写入同步 `fear_flaw_audio_managed` 标记，FearEffect 才关闭旧晶碎音。无控制器的独立/旧入口保留一个旧音源，普通非破绽暴击仍沿用原反馈。新增真实背面晶面命中回归，连同原生产路径共 **24 checks, 0 failures**，Godot 4.7.2 headless 无脚本错误或退出警告，见 `integration.log`。
