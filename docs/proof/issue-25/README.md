# Issue #25 证明

小关据点后移到 z≈-8、后方增援、插旗冲击波、增益台按 F 选卡，锤击按进度把建筑拆开。规则见 [ADR 0007](../../adr/0007-reinforcements-shockwave-pedestal.md)。下面的输出是 2026-10-27 试玩修订之后，在这台机器上用 Godot 4.7.2 跑出来的，没有改过字。

从 WSL 调用 Windows 版 Godot。`$PWD` 是仓库根目录。

```bash
G=/mnt/d/Godot/Godot_v4.7.2-stable_win64_console.exe
P="$(wslpath -w "$PWD")"
"$G" --headless --path "$P" res://tests/<name>.tscn
```

Fixture 必须加 `--fixed-fps 60`。两个进程的记录目录分开：

```bash
"$G" --headless --fixed-fps 60 --path "$P" res://tests/fixture_test.tscn -- --runs=3 --trace-dir=<windows path>
```

## 无界面测试

每个 `tests/*_test.tscn` 都跑过（不含 `*_proof.tscn`）。退出码都是 0。收尾行如下。

```
boss_test.tscn
ALL PASSED (0 failed)

buff_run_test.tscn
buff-two-small-zones-and-boss-20261027-seed-40408: ALL PASSED (0 failed)

capture_hammer_test.tscn
ALL PASSED (0 failed)

combat_traits_test.tscn
COMBAT TRAITS: ALL PASSED (0 failed)

melee_test.tscn
ALL PASSED (0 failed)
WARNING: 4 ObjectDB instances were leaked at exit (run with `--verbose` for details).
ERROR: 2 resources still in use at exit (run with --verbose for details).

reflected_round_test.tscn
REFLECTED ROUND: ALL PASSED (0 failed)

reload_blast_test.tscn
RELOAD BLAST: 27 checks, 0 failed

reinforcement_test.tscn
ALL PASSED (0 failed)

school_icons_test.tscn
ALL PASSED (0 failed)

weapons_test.tscn
ALL PASSED (0 failed)
WARNING: 6 ObjectDB instances were leaked at exit (run with `--verbose` for details).
ERROR: 2 resources still in use at exit (run with --verbose for details).
```

`reinforcement_test.tscn` 的检查行：

```
== config
  [ok] cadence resource is zone/reinforcement_config.tres
  [ok] a wave is every 8 s
  [ok] a wave is 2 enemies
  [ok] at most 6 reinforcements stay out
== layout
  [ok] zone_1.tscn building is back near z=-8 (-8.00)
  [ok] zone_1.tscn player enters from the front
  [ok] zone_1.tscn has rear spawns
  [ok] zone_1.tscn spawns sit behind the building
  [ok] zone_1.tscn guard count
  [ok] zone_1.tscn guards stand around the building
  [ok] zone_1.tscn uses the cadence resource
  [ok] zone_1.tscn has not spawned yet
  [ok] zone_2.tscn building is back near z=-8 (-8.00)
  [ok] zone_2.tscn player enters from the front
  [ok] zone_2.tscn has rear spawns
  [ok] zone_2.tscn spawns sit behind the building
  [ok] zone_2.tscn guard count
  [ok] zone_2.tscn guards stand around the building
  [ok] zone_2.tscn uses the cadence resource
  [ok] zone_2.tscn has not spawned yet
== same seed, same spawns
  [ok] still locked with one guard up
  [ok] still locked with one guard up
  [ok] two enemies spawn on capture
  [ok] the spawn sequence matches
  [ok] both spawns are behind the building
== reinforcements reach the building without corner jitter
  [ok] no reinforcement jitters in a corner
  [ok] most reinforcements close on the building (8/8)
== rhythm, shockwave, pedestal
  [ok] opening the building spawns one wave
  [ok] killing a reinforcement does not move progress
  [ok] the building stays open
  [ok] later waves stop at the cap
  [ok] five bodies were spawned to hold four
  [ok] flag is planted
  [ok] shockwave mesh is in the scene
  [ok] shockwave audio plays
  [ok] nothing was killed by the shockwave
  [ok] every living minion is retreating
  [ok] the shockwave dealt no damage
  [ok] the reward is not up yet
  [ok] the objective names the pedestal
  [ok] reinforcements despawn without a kill
  [ok] spawning stopped when the flag went up
  [ok] pedestal exists
  [ok] interact out of range does nothing
  [ok] interact at the pedestal opens the choice and pauses
  [ok] the chosen card loads the next zone
== boss zone
  [ok] boss has no reinforcement markers
  [ok] boss has no reinforcement config
  [ok] boss does not spawn
  [ok] boss flag has no pedestal
  [ok] boss flag has no shockwave
  [ok] boss still wins with no buff offer
ALL PASSED (0 failed)
```

`capture_hammer_test.tscn` 里碎裂那一段：

```
== the building breaks apart as the bar fills
  [ok] eight blocks before the first quarter
  [ok] 25% drops the first pair
  [ok] an ordinary hit throws chips
  [ok] 50% drops the next pair
  [ok] 75% leaves one pair standing
  [ok] 100% collapses the rest and plants the flag
ALL PASSED (0 failed)
```

`ObjectDB` 和 `resources still in use` 是退出时仍有音频流，和 [issue #14 证明](../issue-14/README.md) 里记的同类，不当成失败。

## Fixture

两个进程都是 `ALL PASSED (0 failed)`。哈希：

```
   run 1: 胜利 after 2967 ticks (49.5 s), 158 trace lines, hash c76f382ec1614ceb
   run 2: 胜利 after 2967 ticks (49.5 s), 158 trace lines, hash c76f382ec1614ceb
   run 3: 胜利 after 2967 ticks (49.5 s), 158 trace lines, hash c76f382ec1614ceb
   seed 1002: 胜利 after 2905 ticks, hash b06f14382acf9a99
   run 1: 胜利 after 1434 ticks (23.9 s), 66 trace lines, hash bb9162c8424ff945
   run 2: 胜利 after 1434 ticks (23.9 s), 66 trace lines, hash bb9162c8424ff945
   run 3: 胜利 after 1434 ticks (23.9 s), 66 trace lines, hash bb9162c8424ff945
   seed 2003: 胜利 after 1314 ticks, hash 282bdcc8eb7623f3
== hashes
   FX-001  c76f382ec1614ceb
   FX-002  bb9162c8424ff945
```

第二进程的这几行相同。八份记录跨进程 `cmp` 逐字节相同。FX-002 的 `run1` 和种子 2003 还与 `docs/proof/issue-14/traces/` 里的对应文件逐字节相同。FX-001 变了，当前表在 [issue #14 证明](../issue-14/README.md)。

两个进程在 `ALL PASSED` 之后都打印了：

```
WARNING: 4 ObjectDB instances were leaked at exit (run with `--verbose` for details).
```

## 局限

窗口试玩指出增援卡墙、来得太慢、锤击只有发亮。这次按诊断改了碰撞层、把据点挪到 z≈-8，并加上分阶段碎裂。改完之后没有再开窗口看碎裂和走位的手感。节奏仍是 `zone/reinforcement_config.tres` 里的 8 秒、2 只、上限 6 只。
