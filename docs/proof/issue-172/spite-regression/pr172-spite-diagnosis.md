# Spite fragment fixture diagnosis

Fixed full-suite head: `03c1a360e6c57631f66bab5f0e436f1ce7a8ed61`.
Original full suite: 89/90 passing; only `spite_fragment_test` failed its real cannon damage/no-knockback assertion. No engine errors. The original failed log remains in `pr172-suite/spite_fragment_test.log`.

The temporary diagnostic recreated the real Player/Enemy, floor, rear wall, boon and deprivation state for each sample. Seeds 1–16 were set immediately before `try_fire`, to isolate the real projectile spread. It recorded actual bone-attached hitbox centers, eye/forward, post-shot spread, projectile direction/travel, full ray collision, HP and impact state for 6 physics frames. No production code was changed.

Original fixture: 3/16 failed (seeds 5, 13, 14). For seed 5, eye Y=1.646114, head center Y=1.440033 with world radius 0.24, and bullet direction Y=0.014510. At physics frame 2 the bullet reached (−0.006109, 1.689645, −3.101989), above the head; initial full ray hit the rear wall. HP remained 1000 and impact_left remained 0 through frame 6. Thus this reproduced missed aim/spread, not a late collision or improper knockback.

Comparison with explicit aim at actual torso center and a private zero-spread WeaponData: 16/16 passed, all HP=965 / impact_left=0 at frame 3, actual TorsoHitbox impacts by frame 2. The production test fix duplicates only its weapon resource, zeros hip_spread and spread_per_shot, and calls aim_at the real torso; the original 3-frame wait and all 13 assertions remain unchanged.

Evidence: `spite_diagnostic.gd.txt`, `spite_diagnostic.tscn.txt`, `pr172-spite-diagnostic.log`, `pr172-spite-diagnostic-summary.json`. After fixing, three independent original-scene runs passed all 13 checks: `pr172-spite-fixed-{1,2,3}.log`, no errors/warnings. This does not replace or rewrite the original full-suite result.

## Archive and reproduction

Classification: shared project verification evidence. These records contain only project engine/test behavior, source code and commit identities. `/root/SpiteDiagnostic` in trace records is a Godot scene-tree node path, not a filesystem path. The original full-suite and repeated-run logs were copied byte-for-byte.

The formal test-only fix is commit `6445dcc926f7946c05ffa5c68e8d6d998192311c`. The original full suite was 89/90, with one assertion failure and zero engine errors. The original `hurt_feedback_test` teardown warning and clean separate rerun are both retained. The original fixture hashes were `18f02a294f3e538a` / `ad3703cd93d3073e`; full fixture output is archived alongside the failed run.

The probe sources are archived as `.txt` to distinguish them from imported runtime resources; their bytes are unchanged. Historical trace names retain the executed `.gd` filename.

To reproduce the probe in an isolated checkout with Godot 4.7.2, import the project first, then copy the two probe files into the temporary paths used by the scene (do not overwrite existing files):

```sh
cp docs/proof/issue-172/spite-regression/spite_diagnostic.gd.txt tests/spite_diagnostic.gd
cp docs/proof/issue-172/spite-regression/spite_diagnostic.tscn.txt tests/spite_diagnostic.tscn
godot --headless --path . res://tests/spite_diagnostic.tscn
```

The probe recreates the original setup explicitly, so the formal test fix does not erase its original comparison arm. Seeds are set immediately before each real shot; 16 samples per arm are recorded. The per-frame trace distinguishes a missed target from a collision arriving after the original three-frame assertion. The diagnostic comparison also explicitly resets ADS/bloom to zero, which are already inactive/zero in the formal fixture. The final production regression test only changes the necessary hip spread/per-shot fields on a duplicate resource.

Run `godot --headless --path . res://tests/spite_fragment_test.tscn` for the unchanged 13 assertions with the corrected fixture. This archive is supplemental; the parent directory's original 15-entry `SHA256SUMS` remains unchanged.
