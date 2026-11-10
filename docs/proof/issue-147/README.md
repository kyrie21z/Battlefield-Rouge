# #147 同一真实第一人称镜头的开场

入口：`res://ui/cinematics/opening_sequence.tscn`。单独运行时点击“开始游戏”；正式 GameStart 的首次 Run 调用 `start()`。后续死亡重开、fixture 和 `--skip-opening` 直接进入各自路线，动态历史对白由 #148 承接。

演出使用真实 `Player` 的原始 24 骨白晶身躯和唯一 `ViewCamera`，不切换摄影机、不用独立假手。五阶段依次为现实提问/心跳/耳鸣沉入低通、两次眨眼及强光散焦、平滑低头查看双手胸腹双腿、原创普通六尖象牙白皇冠与画外语音、升起加冕与微沉回弹。随后实际四模块黑晶手枪重组，两个带碰撞的门叶打开，真实移动恢复；玩家走过门槛才发单次 `combat_entry_requested`。

六段中文 WAV 使用仓库登记的 Kokoro-82M-v1.1-zh 中文模型（皇冠 zf_001，面试 zm_010）本地合成项目原创台词，并配字幕；来源、模型许可与音频哈希见 `docs/ASSETS.md`。低通、音调和音量随坠落阶段连续变化；心跳与耳鸣为原创数学波形。可随时跳过；减少移动选项关闭散焦和加冕抖动并缩短低头幅度。没有旧版逐句点击/确认弹窗。

旧 `ui/pride_opening/` 已从运行树删除。旧 atlas PNG 和对白 JSON 原样移入 `docs/levels/sloth-opening/` 归档，未丢弃源文件。旧命令入口 `pride_opening_flow_test.gd` 转发到新生产流程测试，`pride_avatar_bounds_test.gd` 改测普通 3D 皇冠的42个网格和20个旋转角度投影边界。原 Sloth 三关回归现在显式使用 FX-001 fixture，当前主路线归新 boot 测试。

## 实际验证

Godot 4.7.2：

```text
godot --headless --path <repo> --fixed-fps 60 res://tests/opening_sequence_test.tscn
godot --headless --path <repo> --script res://tests/pride_avatar_bounds_test.gd
godot --path <repo> --fixed-fps 60 res://tests/opening_sequence_proof.tscn
```

- `sequence.log`：16 项全部通过，包含真实 Player/相机身份、音频资源、完整阶段顺序、暂停、连续俯仰、两次眨眼、全部对白进入播放器、手枪真实重组、真实 CharacterBody 穿门后唯一交接、皇冠跟随玩家、减少移动和跳过。
- `crown-bounds.log`：24项检查普通皇冠实际头围尺寸、结构、无眼睛/手节点、20个角度完整几何投影不越界与佩戴轮廓稳定。
- `native.log` 与五张 PNG：原生 Vulkan / Forward+ / RTX 4060 Laptop，由同一生产 ViewCamera 输出；全部打开查看。`02` 为真实白晶完整身躯；`03` 为用户纠偏后的普通简洁六尖 3D 皇冠，无眼睛与手；`04` 为生产手枪四模块凝聚；`05` 为交权后的真门与持枪。
- `audio-audit.json`：六段 PCM 的时长、采样率、非静音 RMS/峰值和 SHA-256。当前工具不支持音频输入，**未完成人工听感验收**，不能以波形检查代替听感判断。

`boot-integration.log`：在独立集成树（基础 `41e69c3`，含全部 12 地图，再加入 #148 生产皇冠）执行 `res://tests/opening_boot_test.tscn`，**22 项全部通过、无引擎错误/警告**。完整演出与跳过均实际经过 GameStart → 随机领域 → 真实选卡 → 手枪开火 → Health 死亡 → 直接重开；FX-001 / FX-002 旧入口各自隔离。此测试验证首次房间交接与重开，不声称遍历整条战役。

该次 Windows Godot / WSL UNC 冷加载最长帧为 10774 ms，发生在加载覆盖层期间；资源仍采用同步加载以避开已知线程加载卡死。演出原生截图不被用作对冷加载流畅度的保证。

用户最终纠偏：皇冠只保留普通简洁造型，完全移除眼睛、手及拟人表情；皇冠台词以画外语音呈现，不通过怪物化模型表达。

本轮普通皇冠纠偏验证以 `4786cce` 集成树为基线，加载最终 Kokoro 开场 WAV 后重新执行上述 16 / 24 项检查及五张原生截图，全部通过且无引擎错误/警告。`audio-audit.json` 已重算为 24 kHz PCM16 源文件，不沿用旧语音时长或哈希。

最终头围纠偏：在上述基线追加 `c5266a6` / `b3dd987` / `9a11ba3` 后，重新运行 16 / 24 项检查并逐张审阅五张原生图。引擎实测皇冠 AABB 为 0.2171 × 0.1351 × 0.2610 m，内圈为 0.17125 × 0.2055 m；穿门后按真实头部锚点跟随，佩戴 scale 保持 ONE。当前 PNG 与 `sequence.log` / `crown-bounds.log` / `native.log` 均来自这一最终尺寸。
