# 背景音乐（PR-H）证明

三首曲子都是运行时程序合成的原创音乐，没有外部素材。规格是 D 小调、单声道、16-bit、22050 Hz，每首 8 小节无缝循环，峰值统一到 −6 dBFS。生成代码在 `ui/procedural_music.gd`。

| 曲目 | BPM | 小节 | 时长 s | 峰值 dBFS | RMS dBFS | 生成 ms |
| --- | --- | --- | --- | --- | --- | --- |
| calm | 84 | 8 | 22.86 | −6.00 | −20.25 | 439 |
| combat | 128 | 8 | 15.00 | −6.00 | −21.38 | 488 |
| boss | 140 | 8 | 13.71 | −6.00 | −20.28 | 296 |

生成耗时在本机 Windows Godot 4.7.2 上测得，数字用 `tests/music_proof.gd` 打印。三首合计超过 300 ms，所以游戏里放在 `WorkerThreadPool` 后台线程生成，每次启动只生成一次，calm 最先生成。生成好之前不出声，不卡主线程。

## 试听

前 10 秒的片段，每个 441 KB：
- [calm_10s.wav](calm_10s.wav)：慢速 pad，稀疏的钟声旋律。底下是嘀嗒声，在第 4 和第 8 小节末拍「停摆」一下，对应「停摆之钟」。
- [combat_10s.wav](combat_10s.wav)：底鼓、钟表嘀嗒、八分音符推进的贝斯、拨弦琶音和一段小调动机。
- [boss_10s.wav](boss_10s.wav)：四拍底鼓、十六分音符嘀嗒、泵动的贝斯、低音和弦短奏，以及 Dm–Eb 的弗里几亚转折。

重新生成片段的命令：`godot --headless --path . --script tests/music_proof.gd`。

## 切换规则（`ui/music_director.gd`）

**谁来创建**：由 HUD 创建，fixture 和 headless 下不创建，所以 fixture 回放不受影响。

**选曲**：
- 清守卫阶段，或锤据点阶段场上还有敌人 → combat。
- Boss 阶段，或 Boss 关里 Boss 还活着 → boss。
- 其余情况 → calm。

**过渡**：
- 换曲用 1.5 s 交叉淡入淡出。
- 回 calm 前要先连续 6 s 没有战斗，避免增援间隙里音乐来回切。
- 选增益和暂停菜单打开时压低 6 dB，用 0.4 s 过渡。
- 阵亡或胜利后 2 s 淡出。

**换关**：每首曲子记住自己放到哪里，进下一关接着放，不会从第一小节重来。

**音量**：曲目播放在 `Music` 总线上，基准电平 −7 dB。总线由 `default_bus_layout.tres` 定义，发往 Master。暂停菜单里的「音乐音量」滑条（0–100 %，默认 70 %）调节这条总线，拉到 0 % 就静音。设置保存在 `settings.cfg` 的 `[audio]` 段。

## `tests/music_test` 状态记录

```
calm 起播 → 1.5 s 淡入到满
→ combat（立即交叉淡入，0.5 s 时 0.33，1.5 s 满）
→ 5 s 平静：仍是 combat
→ 中间又打了一下：6 s 计时重来
→ 再平静 6.2 s：回到 calm
→ boss（立即）
→ 选增益：压到 0.50（−6 dB），结束后恢复 1.00
→ 阵亡：1 s 时 0.50，2 s 内静音
```

## 截图

[pause_menu_music.jpg](pause_menu_music.jpg)：暂停菜单里新增的「音乐音量 70%」。
