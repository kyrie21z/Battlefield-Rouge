# #178 愤怒声景

`WrathAudioDirector` 使用Stage注入的演员列表。穿刺者的真实WINDUP剩余时间控制蓄压音升调，实际RUSH及23 m/s速度改为急促破风；侵犯者在移动/锯刃攻击阶段发出谐波齿噪，冲锋时加速，硬直、死亡和撤退则停止。关闭预警后不再发出蓄力提示，实际冲锋的物理声保留。没有新增攻击、假碰撞或战役单例读取。

熔炉背景由低频炉鸣、局部种子噪声蒸汽和左右略有不同的高压喷口组成。远处热变形金属按表现层累计delta调度，不读墙钟或消费全局玩法RNG。共享持续声音池固定8声部，瞬态沿用父基类16声部。

撞墙声通过真实 `wall_slam` 事件位置触发，保留伤害、击退和破片玩法代码，删除被替代的旧 `_play_slam` / `ProceduralAudio.clock_break` 播放器，避免重复声音和无界分配。穿刺者自身的实际墙碰撞自爆按 `wall_detonations` 增量单独发出重撞。尖刺破风由父基类监听实际 `WrathSpike` 注册、核对source是当前玩家后触发，不因普通撞墙就虚构尖刺。

`WrathRealm.set_audio_managed(true)` 明确把环境音交给director：停止旧loop，后续 `set_deprivation(false)` 也不能重播；独立旧realm默认不接管，仍保留原声音。真实Boss死亡后托管熔炉停止，旧声不复活。退出场景不会恢复即将销毁的环境loop。

## 验证入口

Godot 4.7.2 / Jolt：

```sh
/tmp/epic34-plan/godot-wsl --headless --path . res://tests/wrath_audio_test.tscn
```

测试使用生产Wrath房间与演员、实际滑动接触产生的 `SpiteStatus` 撞墙、5枚真实尖刺、自爆以及Boss死亡。覆盖蓄力、真实速度/状态切换、预警剥夺、硬直/撤退静音、地板接触不冒充墙、环境单声源、暂停、声部上限、死亡和局部RNG。21/21通过，无错误或警告；结果见 `wrath-audio.log`。旧 `wrath_realm_test.tscn` 回归28/28通过，证明独立环境默认声源及熄灭流程保留，见 `wrath-realm-regression.log`。带 `-- --audio-proof` 可重导本目录WAV；普通测试不写文件。

`pcm-analysis.json` 给出导出的16位双声道PCM、SHA-256、RMS和峰值。重撞约88.6%的左声道能量在20–120 Hz，峰值约0.696，低频体积与高频石屑由独立包络构成。预听为可审阅产物，尚未进行人工打击感或音箱低频响应验收。

## 父集成所需登记

- `ARCHITECTURE.md`：领域表现层读取真实演员阶段，公开 `WrathRealm.set_audio_managed` 接管原环境音；仅父Stage负责装配。`RealmActorAudioVoices` 来自先行 #177 提交。
- `GLOSSARY.md`：熔炉声景=`WrathAudioDirector`；撞墙爆破=`WrathSoundBank`，真实wall_slam及穿刺者碰撞自毁，不是虚构音频触发器。
- `ASSETS.md`：`audio/realms/wrath_sound_bank.gd` 是原创数学合成，无外部采样/旧工程素材。本目录WAV为证据预听，hash见json；现有 `docs/proof/.gdignore` 排除其Godot导入，因此不应生成.import。
- 父共享base需要动态加载Wrath bank的KINDS/boon_cues，并监听 `Events.projectile_registered`；父持有的这些共享修改不在本提交内。
