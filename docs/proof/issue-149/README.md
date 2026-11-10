# #149 身躯粉碎与金缮重组

正式返程长廊中，持有四枚独立碎片并步入 z=-4 后，原始白晶身体按56个真实晶体片释放为刚体，镜头倒在地面，播放四种心声及自我接纳。各句使用实际音频时长同步字幕。碎片沿原骨骼姿态回到同一具身体，原晶体接缝使用暗金 Shader，四种心魔颜色仅作为终局微光；先前普通机制剥夺持续。

`tests/body_reassembly_test.tscn` 14项通过：真实56刚体/物理位移、重复触发拒绝、暂停冻结、五句顺序、原蒙皮网格与接缝 Shader、碎片清理、控制恢复、实体出口及接纳字幕渐隐。`body_reassembly_proof.tscn` 四张原生 Forward+ 图已按最终 Kokoro 语音时长重新生成，并逐张打开检查；保留同一具原始身体和相机。

音频/波形/哈希见 tools/cinematic/climax_voice_manifest.json；听感和情绪表现仍需人工验收。截图和自动驱动不代表人工通关或手感验收。

语音替换：五段均已替换为官方 Apache-2.0 Kokoro-82M-v1.1-zh 的 `zm_010` 离线输出；原台词不变，播放仍按实际时长。来源与全部参数见 tools/cinematic/voice_assets.md，真实Godot解码播放48项证据见 docs/proof/voice-assets/playback.log；人工听感尚未验收。
