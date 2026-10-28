# Issue #26 证明

Boss 关：Boss 活着时城市核心不能砸；倒下后一锤击碎（碎块一次走完四个阶段），然后胜利，不选增益。6 只小怪不挡住核心。规则见 [ADR 0004](../../adr/0004-boss-wave-and-core.md) 文末修订。下面的输出是把这条分支变基到试玩修订之后的 #25 上，2026-10-27 在这台机器上用 Godot 4.7.2 跑出来的，没有改过字。

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

每个 `tests/*_test.tscn` 都跑过（不含 `*_proof.tscn`）。退出码都是 0。

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

school_icons_test.tscn
ALL PASSED (0 failed)

weapons_test.tscn
ALL PASSED (0 failed)
WARNING: 6 ObjectDB instances were leaked at exit (run with `--verbose` for details).
ERROR: 2 resources still in use at exit (run with --verbose for details).
```

`boss_test.tscn` 里和这次规则对应的检查行：

```
== the core stays shut while the boss stands
  [ok] the zone is the boss zone
  [ok] it starts with the boss still to fell
  [ok] the core is locked
  [ok] the objective says to fell the boss
  [ok] one hammer would finish the core
  [ok] small zones still use the 8% rhythm
  [ok] seven enemies are alive and the core stays shut
  [ok] walking up to the core puts the player in reach
  [ok] hammering a locked core adds nothing
  [ok] the hint is still on screen
== the six small enemies do not open the core
  [ok] six small enemies dead, core still shut
  [ok] killing them never counted as clearing the zone
== the boss's death opens the core, and one hammer shatters it
  [ok] the boss is dead and the small enemies are not
  [ok] the core opens
  [ok] the objective names the hammer
  [ok] the bar is empty once the boss is dead
  [ok] the label says it has fallen
  [ok] one ordinary hammer reaches 100%
  [ok] that one hammer collapses every block
  [ok] the director is in FLAG_PLANTED
  [ok] a flag was planted on the core
  [ok] killing the wave never counted as clearing the zone
== victory
  [ok] no win yet while the flag is rising
  [ok] the end screen appears
  [ok] it says victory
  [ok] it names the city core
  [ok] the run is won once
  [ok] no buff is offered after the boss
== defeat
  [ok] a swing before the boss falls adds nothing
  [ok] the core is open and still empty
  [ok] the player is dead
  [ok] the end screen appears
  [ok] it says defeat
  [ok] the run is reset to the first zone
  [ok] the core was not captured
  [ok] no victory was reported
  [ok] a late capture after death does not turn it into a win
```

`reinforcement_test.tscn` 的 Boss 段：

```
== boss zone
  [ok] boss has no reinforcement markers
  [ok] boss has no reinforcement config
  [ok] boss does not spawn
  [ok] the core stays shut while the boss lives
  [ok] boss flag has no pedestal
  [ok] boss flag has no shockwave
  [ok] boss still wins with no buff offer
ALL PASSED (0 failed)
```

`ObjectDB` 和 `resources still in use` 是退出时仍有音频流，不当成失败。

## Fixture

两个进程都是 `ALL PASSED (0 failed)`，八份记录跨进程 `cmp` 逐字节相同。两进程的结果行相同：

```
   run 1: 胜利 after 2409 ticks (40.1 s), 132 trace lines, hash 4f21666af9e49eda
   run 2: 胜利 after 2409 ticks (40.1 s), 132 trace lines, hash 4f21666af9e49eda
   run 3: 胜利 after 2409 ticks (40.1 s), 132 trace lines, hash 4f21666af9e49eda
   seed 1002: 胜利 after 2419 ticks, hash 6bc59b75142b4d5e
   run 1: 胜利 after 835 ticks (13.9 s), 38 trace lines, hash a489a884d1ed0127
   run 2: 胜利 after 835 ticks (13.9 s), 38 trace lines, hash a489a884d1ed0127
   run 3: 胜利 after 835 ticks (13.9 s), 38 trace lines, hash a489a884d1ed0127
   seed 2003: 胜利 after 830 ticks, hash 8373d17dc9c8e89d
== hashes
   FX-001  4f21666af9e49eda
   FX-002  a489a884d1ed0127
```

两个进程在 `ALL PASSED` 之后都打印了：

```
WARNING: 8 ObjectDB instances were leaked at exit (run with `--verbose` for details).
ERROR: 2 resources still in use at exit (run with --verbose for details).
```

FX-002 种子 2002 的记录：tick 181 `kill Boss`，随后六名小怪，tick 751 `strike perfect +0.000 ms +1.00000` 与 `point_captured 2`，tick 835 `end 胜利`。现行哈希表在 [issue #14 证明](../issue-14/README.md)。

## 局限

没有开窗口试玩。一锤的手感和「先打倒 Boss」的提示是否看得清，这次没有结论。`tests/boss_proof.tscn` 仍按旧顺序先锤核心，这次没有重跑，也没有重拍 `docs/proof/issue-10/` 的截图。
