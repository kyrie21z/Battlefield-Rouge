class_name ReinforcementConfig
extends Resource
## Temporary cadence for small-zone reinforcements, plus how long a retreating
## enemy may take to reach a rear spawn. Edit zone/reinforcement_config.tres.
## The boss zone does not use this resource.

## Seconds from the moment the building opens, and between waves after that.
## The first wave spawns as the building opens; the next waits one interval.
@export_range(0.2, 60.0, 0.1, "suffix:s") var interval_seconds := 10.0
## How many enemies one wave tries to spawn.
@export_range(1, 12, 1) var per_wave := 2
## Reinforcements still on the field (including those already retreating).
## A wave spawns fewer, or nothing, when this many are already out.
@export_range(1, 24, 1) var max_alive := 5
## Removed on arrival, or when this many seconds have passed, whichever is first.
## Stuck enemies disappear too. Retreating never counts as a kill.
@export_range(0.2, 60.0, 0.1, "suffix:s") var flee_timeout_seconds := 14.0
