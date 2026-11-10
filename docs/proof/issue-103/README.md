# Issue 103 validation — single MindBlade

Base: issue 102 commit `b089e02`. Engine: Godot 4.7.2 stable (`ed1daf0bf`), Windows executable launched from WSL.

The actual Player equips one MindBlade. V and mouse side button swing it; Q cycling is absent. Wind-up / active / recovery are 80 / 120 / 150 ms, damage is 55, and target acquisition is 4.5 m within a ±40° cone. The Player integration check measures an exact 0.45 m step without residual slide and confirms the pistol stays visible and death disables further swings.

The imported Blender geometry and receipt are checked against the GLB SHA-256, flat normals, 400 mm overall length, 40 mm width, 15 mm thickness, and 340 mm grip-to-tip reach. The native `melee_proof` images show the actual staged build; full first-person body visibility belongs to issue 105.

The old `MeleePool` / `select` API and assets are temporarily retained for isolated legacy regression coverage until issue 106. `tests/melee_test.gd` explicitly opts into that compatibility loadout before entering the tree. E / Hammer capture remains functional in this stage; projectile parry and V clock strikes arrive in issue 104.

Validation: import, mind_blade_test, melee_test, hud_test, capture_hammer_test, buff_run_test, and native melee_proof all pass. Exact counts and results are in `results.json`; complete logs are beside it. The native cut frame was visually inspected.

Reproduce behavioral checks:

```sh
Godot_v4.7.2-stable_win64_console.exe --headless --path <checkout> res://tests/mind_blade_test.tscn
Godot_v4.7.2-stable_win64_console.exe --headless --path <checkout> res://tests/melee_test.tscn
```

Reproduce the native frames:

```sh
Godot_v4.7.2-stable_win64_console.exe --path <checkout> res://tests/melee_proof.tscn -- --out=res://docs/proof/issue-103
```
