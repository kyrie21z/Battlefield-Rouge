# Issue 104 validation — blade parry and clock strike

Base: issue 103 head `7cb5df2` (including its model-source registration). Engine: Godot 4.7.2 stable (`ed1daf0bf`), Windows executable launched from WSL.

During the 120 ms active window, the frontal parry area intercepts swept enemy projectiles. Reflection changes their owner and exclusions, returns them toward the enemy at increased speed, plays a crystal ring, and notifies the HUD to request 50 ms hitstop outside fixtures. Coverage includes projectiles crossing the full area in one step, returned damage, front/rear constraints, walls, idle, pause and cancellation.

V / mouse side button now strikes the clock on physical blade contact. The production resolver checks Area membership, facing, nearest building surface distance, and world obstruction. Ordinary strikes add 10%; the ±150 ms perfect window adds 20%. Hammer code/node/input and its event are removed together; clock phase, HUD, enemy hearing, proofs and the bot all use the new path. Legacy gun/melee compatibility APIs remain until issue 106.

Import and all 11 behavioral suites passed: mind_blade_test, capture_hammer_test, hammer_feel_test, keybinding_test, hud_test, phase_banner_test, music_test, sloth_integration_test, fixture_test, enemy_bullet_test, buff_run_test. Counts and full logs are beside this file. Sloth integration reports 146 checks and zero failures, including real physical V input across all three scenes, the locked Boss core, victory, death and restarts.

The fixed-step fixture uses the real melee action, anticipates wind-up plus the active contact offset, and never calls the clock resolver directly:

| Fixture | Repeated outcome | Repeated trace hash | Alternate seed |
| --- | --- | --- | --- |
| FX-001 / seed 1001 | victory twice, 2497 ticks | `0e2d74409c9f95da` | seed 1002: death, 1675 ticks, no timeout |
| FX-002 / seed 2002 | victory twice, 938 ticks | `fee8155806b7883c` | seed 2003: victory, 860 ticks, no timeout |

These hashes describe this stack stage, before the issue 105 body/camera changes.

Native proof uses default bindings and actual melee input. `03_perfect_strike.png` shows +20%; `04_ordinary_strike.png` shows +10%; the complete run records five perfect strikes and one ordinary strike. Both feedback frames were visually inspected. The proof script was corrected to anticipate actual blade contact and wait for the `struck` event before capturing; its earlier instant-Hammer scheduling could label a pre-contact frame as a perfect strike. It now rejects missing strikes or incomplete capture. This proof-only correction is intentionally retained beyond the reference implementation.

Reproduce:

```sh
Godot_v4.7.2-stable_win64_console.exe --headless --path <checkout> res://tests/mind_blade_test.tscn
Godot_v4.7.2-stable_win64_console.exe --headless --path <checkout> res://tests/sloth_integration_test.tscn
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path <checkout> res://tests/fixture_test.tscn
Godot_v4.7.2-stable_win64_console.exe --path <checkout> res://tests/capture_proof.tscn -- --out=res://docs/proof/issue-104
```
