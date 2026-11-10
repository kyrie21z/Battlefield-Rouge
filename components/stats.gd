class_name Stats
extends Node
## Base values plus buff modifiers. Every number a buff can change is read
## through get_value(), so adding a buff never touches player or weapon code.
##
## A value is (base + sum of adds) * product of muls. Multiplier-style stats
## (move_speed, damage, ...) have base 1.0, so a buff with mul 1.25 means +25%.

signal changed

const DASH_RECHARGE := &"dash_recharge"
const DAMAGE_TAKEN := &"damage_taken"
const CRIT_CHANCE := &"crit_chance"
const CRIT_MULTIPLIER := &"crit_multiplier"
const PROJECTILE_SPEED := &"projectile_speed"
const CLOCK_WINDOW := &"clock_window"
const CLOCK_THEME := &"clock_theme"
const CLOCK_PROGRESS := &"clock_progress"
const ARMOR := &"armor"

const MAX_HEALTH := &"max_health"
const MOVE_SPEED := &"move_speed"
const DAMAGE := &"damage"
const FIRE_RATE := &"fire_rate"
const RELOAD_SPEED := &"reload_speed"
const MAGAZINE_SIZE := &"magazine_size"
const MELEE_DAMAGE := &"melee_damage"
const MELEE_SPEED := &"melee_speed"
const MELEE_ARC := &"melee_arc"
const MELEE_RANGE := &"melee_range"
const SKILL_UNLOCKED := &"skill_unlocked"
const SHIELD_DURATION := &"shield_duration"
const SHIELD_COOLDOWN := &"shield_cooldown"
const RELOAD_BLAST_DAMAGE := &"reload_blast_damage"
const PARRY_CAPACITY := &"parry_capacity"
const SHIELD_PULSE_DAMAGE := &"shield_pulse_damage"
const SHIELD_CAPACITY := &"shield_capacity"
const SHIELD_REFLECT_MULTIPLIER := &"shield_reflect_multiplier"

@export var base := {
	DASH_RECHARGE: 1.0, DAMAGE_TAKEN: 1.0, CRIT_CHANCE: 0.0,
	CRIT_MULTIPLIER: 2.0, PROJECTILE_SPEED: 1.0, CLOCK_PROGRESS: 1.0, CLOCK_WINDOW: 1.0, CLOCK_THEME: 0.0, ARMOR: 0.0,
	MAX_HEALTH: 100.0,
	MOVE_SPEED: 1.0,
	DAMAGE: 1.0,
	FIRE_RATE: 1.0,
	RELOAD_SPEED: 1.0,
	MAGAZINE_SIZE: 1.0,
	MELEE_DAMAGE: 1.0,
	MELEE_SPEED: 1.0,
	MELEE_RANGE: 1.0,
	MELEE_ARC: 1.0,
	SKILL_UNLOCKED: 0.0,
	SHIELD_DURATION: 2.0,
	SHIELD_COOLDOWN: 8.0,
	RELOAD_BLAST_DAMAGE: 0.0,
	PARRY_CAPACITY: 0.0,
	SHIELD_PULSE_DAMAGE: 0.0,
	SHIELD_CAPACITY: 100.0,
	SHIELD_REFLECT_MULTIPLIER: 0.0,
}

var _adds := {}
var _muls := {}
var _sources: Dictionary = {}


func get_value(stat: StringName) -> float:
	var add := float(_adds.get(stat, 0.0))
	var mul := float(_muls.get(stat, 1.0))
	for modifiers: Dictionary in _sources.values():
		var entry: Dictionary = modifiers.get(stat, {})
		add += float(entry.get("add", 0.0))
		mul *= float(entry.get("mul", 1.0))
	return (float(base.get(stat, 0.0)) + add) * mul


func apply_buff(buff: Buff) -> void:
	_adds[buff.stat] = float(_adds.get(buff.stat, 0.0)) + buff.add
	_muls[buff.stat] = float(_muls.get(buff.stat, 1.0)) * buff.mul
	for stat: String in buff.extra_adds:
		_adds[StringName(stat)] = float(_adds.get(StringName(stat), 0.0)) + float(buff.extra_adds[stat])
	changed.emit()


func clear_buffs() -> void:
	_adds.clear()
	_muls.clear()
	changed.emit()


## Reapplying a source replaces its previous contribution, never compounds it.
func set_modifier(source: StringName, modifiers: Dictionary) -> void:
	_sources[source] = modifiers.duplicate(true)
	changed.emit()


func remove_modifier(source: StringName) -> void:
	if _sources.erase(source):
		changed.emit()
