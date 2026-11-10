# #148 随行皇冠：历史对白与指数发光

生产节点是 `actors/player/player.tscn` 中唯一的 `CrownVoiceSystem`。它复用 #147 用户纠偏后的普通简洁六尖 3D 皇冠（无眼睛、手或表情），并提供随视角可见的真实边角冠饰、材质发光、附近照明和屏幕边缘耀斑。独立可玩入口 `res://tests/crown_voice_bench.tscn`：0–4 改碎裂等级，F1–F5 试听不同历史分支，WASD/武器仍是生产 Player。

上层显式注入：

```gdscript
crown.configure_history(run_count, last_depth, death_cause, announce)
crown.set_fracture_level(defeated_count)
crown.enter_floor(depth)
```

第 4 参数 `announce` 默认为 true，普通房间转换传 false 可避免同层重复叙述。组件不读 RunDirector/RunState，不自行决定进度。`set_cinematic_hidden(true)` 同时隐藏实体冠、Camera 子冠饰和字幕/光晕，供开场避免重复皇冠。

- `crown_dialogue_database.tres` 是真实台词/AudioStream 资源库。首次、2–4 次早期失败、3/4 层失败、老练玩家分别选择不同语气文本；深渊/跌落死因有独立回应，死亡深度优先于尝试次数。第 2–5 层有各自引导。
- 11 段 WAV 使用仓库登记的 Kokoro-82M-v1.1-zh 中文模型（皇冠 zf_001）本地合成原创台词，模型许可与哈希见 `docs/ASSETS.md`。单一 AudioStreamPlayer 替换当前句，字幕和语音一起结束；死亡清空声音/字幕，禁止死者重新播放延迟回调，新的 Player 按真实历史重新开口。
- `crown_emission.gdshader` 的实际材质强度为 `0.5 * 2.4^level`：0.5、1.2、2.88、6.912、16.5888。听取 `Events.sin_defeated` 或显式注入均更新。边缘耀斑随等级增强，第 4 级有轻微全屏白雾和慢速脉动，中央保持可辨认与可操作；`reduced_motion` 可关闭脉动。
- 正式 RealmStage 已开启 Bloom。身体仍由原 BodyFracture 系统控制黑色晶体接缝，不借皇冠着色器改变身体颜色。

## 验证

```text
godot --headless --path <repo> --fixed-fps 60 res://tests/crown_voice_test.tscn
godot --path <repo> --fixed-fps 60 res://tests/crown_voice_proof.tscn
```

`mechanics.log` 的 **29 项检查全部通过**，验证生产 Player 挂载、11 真实音频、7 历史/死因分支实际播放、单声源防重叠、换层覆盖延迟旧对白、重复层通知/普通房间静音、0–4 级真实 Shader 参数、开场完整隐藏、真实死亡停音以及新 Player 重入。

`opening-regression.log` 的 16 项完整开场回归在挂载 CrownVoiceSystem 的生产 Player 上全部通过。

两张原生截图来自同一生产第一人称相机，分别展示首次轻光与深层死亡后第 4 级刺目冠饰；已实际打开查看。`audio-audit.json` 记录 PCM、时长、非静音和哈希。**当前工具不支持音频输入，未完成人工听感验收**；可直接运行 bench 或播放 WAV 复核语气与发音。波形检查不被当作听感确认。

普通皇冠与最终 Kokoro WAV 更新后，29 项对白检查、16 项开场回归以及两张原生图已重新执行并查看。`floor-five.log` 的 50 项真实 RunDirector 检查包括：返程走廊创建的生产 Player 收到深度 5 并实际启动 `floor5` 语音；死亡历史深度上限仍为 4。最终日志无引擎错误/警告。

最终头围更新 `b3dd987` 后，实体皇冠以玩家头部完整 transform 与 `CrownModel.WEAR_OFFSET` 跟随，scale 保持 ONE；其物理大小与开场、终局一致。当前两张 PNG、29 项对白日志与 16 项开场回归均已针对该版本重新生成并审阅，中央操作视野仍清晰。
