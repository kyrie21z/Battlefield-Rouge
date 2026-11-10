# #176 怠惰领域声景

生产 `RealmStage` 在玩家、敌人与 HUD 就绪后创建注入式 `RealmAudioDirector`。
怠惰子类使用 60 BPM 钟摆与双脉冲心跳、暖调 55/82.5 Hz 无人声底音。
真实 `realm_defeated` 将它切换到 148 BPM 机械秒针及 130/780 Hz 齿轮噪声；
两条环境音轨在 0.35 秒内交叉淡入淡出。存量剥夺由 Stage 注入，换房不会误回平静。
`BoonManager.event_dispatched` 的 `sloth_burst` 驱动延爆低频碎裂反馈。

环境音走已有 Music 总线并响应设置；特技使用最多 16 个空间音源。
暂停冻结音源与节拍，死亡停止全部声道，换场景释放节点。声音合成使用私有固定种子的
`RandomNumberGenerator` 和 PCM 缓存，不消费玩法随机序列，不改伤害或事件时序。

## 来源

`audio/realms/realm_sound_bank.gd` 是本次原创数学合成代码，遵循仓库 MIT 许可。
所有声音均由正弦波、指数包络、局部白噪声和低通计算，不使用下载素材、录音或第三方采样。
PCM 为 22050 Hz、16-bit、立体声；环境音循环 4 秒，音效 0.8 秒，峰值受限并有边缘包络。
未修改既有音频原件。

## 验证

`tests/sloth_audio_test.tscn` 覆盖真实生产 Stage、真实 Boss 死亡到 148 BPM、Music 设置、
暂停拒收新提示、音源上限、缓存 PCM、死亡停止与退出。最终功能日志 `sloth_audio_test.log` 为 14 项通过；该次退出出现 12 个 ObjectDB 警告。
同一代码 `--verbose` 复验 14 项通过且正常退出，无 Script/ERROR/泄漏标记，原始完整日志为
`sloth_audio_verbose.log`。不将后一次干净退出解释为已定位偶发退出诊断根因。

此处只验证接线、时序和音频数据；未将自动测试称为人工听感、情绪或最终混音验收。

追加保护：已停止的声景不会因迟到的状态刷新重新播放，相同循环不会无谓重启。
`sloth_audio_guard.log` 为最终 15 项通过；该次退出保留 8 个 ObjectDB 诊断。

最终暂停检查显式启用音频 `_process` 后暂停，验证真实 SceneTree 暂停；退出前给混音线程
0.15 秒退役已停止的播放实例。`sloth_audio_lifecycle.log` 15 项通过且无退出警告。
此前诊断日志保留，不据此宣称平台上的所有退出警告均已根治。
