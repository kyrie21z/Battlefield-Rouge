# #150 资产来源与生成

- 白晶人形、手枪、短刃及56碎片均复用已登记原始GLB，未改写原文件。
- 皇冠复用#147简洁普通CrownModel；墙板、打印环、护盾和超新星为本issue源码几何/Shader。
- 原始台词“你简直无药可救了！！”已改由官方Apache-2.0 `hexgrad/Kokoro-82M-v1.1-zh`固定版本离线生成，标准女声zf_001、speed1.12，24kHz/PCM16/mono、2.825秒。
- 桌面Huihui输出不再用于交付；旧SAPI脚本明确拒绝执行。统一复现：`tools/cinematic/generate_voice_assets.py`，来源/许可/模型哈希见 `tools/cinematic/voice_assets.md`，逐句清单见 `tools/cinematic/voice_assets_manifest.json`。
- 输出WAV不标为CC0，不分发模型/音色/引擎；没有私人录音或身份克隆。

WAV SHA-256: `6c8c2003662b3e8d414949eb935a36172cbf5dc5c0c99e7ae7abef217481b828`。

23段真实Godot资源/时长/播放进度/finished共48项通过；本段也经实际Boss演出播放。波形和播放生命周期不代表人工听感、发音与情绪表演验收。
