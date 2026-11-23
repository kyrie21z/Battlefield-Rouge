# 01: 战斗音频 44.1kHz 升级与冲击音色重塑

- **GitHub Issue**: `#242`
- **Parent Spec**: `#241` (`.specs/combat-hit-feel/spec.md`)
- **Blocked by**: None
- **Status**: `ready-for-agent`

## What to build

将战斗程序化音效管线（`ProceduralAudio`）从 22050 Hz 单声道升级至 **44100 Hz**，在不引入任何外部版权素材、不破坏 AC-07 确定性的前提下，重塑核心战斗冲击音色并补齐缺失的战斗反馈音：

1. **高采样率适配**：将 `ProceduralAudio` 采样率提升至 `44100 Hz`，检查并确保所有一阶低通/高通滤波系数与时间包络在 44.1kHz 下保持自然音色与准确时长，避免倍频后滤波器截止频率漂移。
2. **黑晶手枪音色重塑（`gun_pistol`）**：保留四层结构（胸腔低频下潜 + 高频脆裂 + 膛压主体 + 早期反射尾音），加强低频下潜深度与胸腔厚度（约 `165 → 48 Hz`），叠加短促的黑晶矿物高频泛音瞬态（`3.2–6.8 kHz`），彻底消除“闷拍”感。
3. **意志短刃命中音色重塑（`melee_hit`）**：在滤波冲击噪声之上叠加低频打击体（`135 → 50 Hz`）与短促晶体切裂泛音，提升整体响度与辨识度。
4. **新增战斗交互音色**：
   - `hit_block`：盾牌格挡专属金属/硬晶钝响，用于区分被格挡与真实命中。
   - `pistol_low_ammo`：轻脆高频晶体/机械叠加提示音，供手枪低弹量（剩余 ≤ 2 发）开火时混叠。
5. **预热与确定性**：将新增音色纳入通用预热列表（`COMMON_KINDS`），全部使用独立固定种子生成，绝不消耗全局模拟 RNG。

## Acceptance Criteria

- [ ] `ProceduralAudio.SAMPLE_RATE` 升级为 `44100`，所有既有名目与新增 `hit_block`、`pistol_low_ammo` 均可正常生成、无静音且无削波失真。
- [ ] `gun_pistol` 保持柔起音（1 ms 内振幅 < 峰值 50%）、峰值归一化在 `-3 dBFS ± 1 dB`、多次生成字节完全确定一致。
- [ ] `melee_hit`、`hit_block`、`pistol_low_ammo` 均纳入通用预热集合，且与现有 `hit_kill` / `hit_kill_head` 波形互不雷同。
- [ ] 全程不消耗全局模拟 RNG（生成前后全局 `randi()` 序列不变）。
- [ ] 既有回归套件全绿：`tests/hit_feel_test.tscn`、`tests/gun_feel_test.tscn`、`tests/fixture_test.tscn`。
