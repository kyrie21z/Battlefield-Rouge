# Opening → game transition proof

Pride opening 进入第一关的过渡计时证明。改动前 `ui/game_start.gd::_enter_game()`
直接同步 `change_scene_to_file()`，冷加载 `maps/zone_1.tscn` 时主线程被卡住约 5 秒，
画面停在 opening 最后一帧。

改动后 opening 期间后台预热第一关；进入时先淡黑（0.45s）、等待预热完成（不足时显示
「加载中…」）、`change_scene_to_packed()` 切换场景，黑色遮罩挂在新场景上再淡出
（0.6s），全程不阻塞主线程。

## 复现

需要真实窗口（截图是证明的一部分）：

```sh
G=/mnt/d/Godot/Godot_v4.7.2-stable_win64_console.exe
P="$(wslpath -w "$PWD")"

# 新路径：真实 opening，后台预热 8 秒后进入
timeout -k 5 300 "$G" --path "$P" res://tests/opening_transition_proof.tscn

# 旧路径：无 opening、无预热，同步 change_scene_to_file
timeout -k 5 300 "$G" --path "$P" res://tests/opening_transition_proof.tscn -- --old
```

## 结果（1280×720，Windows Godot 4.7.2，本机一次代表性运行）

| 指标 | 旧路径（同步加载） | 新路径（opening 预热 + 淡入淡出） |
| --- | --- | --- |
| 进入动作 → 新场景首帧 | 5051.7 ms | 788.8 ms |
| 切换期间最长单帧间隔（wall clock） | 4648.6 ms | 286.2 ms |
| 后台预热就绪时刻（opening 开始后） | — | 5268.7 ms |
| 遮罩自行淡出并释放 | — | 是（overlay_gone=true） |

`longest_frame_during_switch_ms` 用进程帧之间的墙钟间隔测量：Godot 会钳制 delta，
同步卡死不会体现在引擎 delta 上。

新路径的 788.8 ms 包含 0.45 s 淡黑和场景切换，主线程最长卡顿约 0.29 s，
且发生在黑屏之下；旧路径的 5 秒卡顿直接暴露在玩家眼前。

## 截图

- `01-mid-fade.jpg`：淡出中途。黑色遮罩半透明压暗了新场景的增益选择界面。
  该界面会暂停场景树，遮罩仍能继续淡出，说明 `PROCESS_MODE_ALWAYS` 生效。
- `02-game-visible.jpg`：遮罩释放后，增益选择界面完全可见。

## 备注

- 预热按 `ResourceLoader.get_dependencies(zone)` 逐个请求依赖、再请求场景本身：
  Godot 4.7.2 的线程加载器在单个请求同时拉起多个重量级依赖时会死锁（进度冻结），
  逐个加载已验证稳定。
- 玩家在预热完成前进入时，遮罩停留并显示「加载中…」，不阻塞主线程。
- 审查复核（2026-11-03）：新测试连跑 8 次、带窗口 proof 连跑 3 次都没有卡住。预热期间 opening 自身最长一帧 34–35 ms（临时给 proof 加帧间隔统计测得，未提交），说明后台加载不会让开场动画明显掉帧。
- 已知风险：如果线程加载器仍然死锁，玩家会停在「加载中…」。审查复核中没有复现。
