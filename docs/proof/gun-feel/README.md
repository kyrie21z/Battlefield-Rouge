# Gun feel proof frames

Real-window frames (1280x720, Vulkan) from `tests/gun_feel_proof.tscn`:

    godot --path . res://tests/gun_feel_proof.tscn -- --out=docs/proof/gun-feel

Needs a real display; headless has no renderer. FX-001, zone 1, an enemy frozen
in place as the target.

| Frame | Shows |
| --- | --- |
| 01_rifle_recoil_frame1 | Rifle the frame after a shot: viewmodel kicked back/up |
| 02_rifle_tracer_impact_flash | Muzzle flash, tracer streak, enemy white flash and flinch |
| 03_rifle_settled | Spring back at rest |
| 04_enemy_flash / 05_enemy_after | Enemy hit flash, then recovered |
| 06_shotgun_blast | Shotgun: heavy kick, several tracers, flesh impacts |
| 07_kill_marker | Kill: bigger red marker, debris. |
