"""Generate the playable Sloth draft maps from shared authored layouts.

Run from the project root: python tools/gen_zones.py
The runtime Geometry child builds before ZoneDirector bakes explicit WORLD
colliders. Floating art and player-only BOUNDARY rims do not enter navigation.
Keep scene-generation changes here; the three maps are generated outputs.
"""
from pathlib import Path
import math


def transform(position, yaw=0):
    r = math.radians(yaw)
    c, s = round(math.cos(r), 6) + 0.0, round(math.sin(r), 6) + 0.0
    x, y, z = position
    return f"Transform3D({c:g}, 0, {s:g}, 0, 1, 0, {-s:g}, 0, {c:g}, {x:g}, {y:g}, {z:g})"


def zone(name, room_index, spawn, capture, enemies, spawns=(), boss=None):
    is_boss = boss is not None
    architecture = "architecture.gd" if is_boss else "courtyard.gd"
    ext = [
        f'[ext_resource type="Script" path="res://environments/sloth/{architecture}" id="1_geometry"]',
        '[ext_resource type="PackedScene" path="res://actors/player/player.tscn" id="2_player"]',
        '[ext_resource type="PackedScene" path="res://actors/enemy/sloth/sloth_enemy.tscn" id="3_enemy"]',
        '[ext_resource type="Script" path="res://zone/zone_director.gd" id="4_director"]',
        '[ext_resource type="Script" path="res://zone/capture_point.gd" id="5_capture"]',
        '[ext_resource type="PackedScene" path="res://ui/hud.tscn" id="6_hud"]',
    ]
    if is_boss:
        ext.extend([
            '[ext_resource type="PackedScene" path="res://actors/enemy/boss.tscn" id="7_boss"]',
            '[ext_resource type="Resource" path="res://zone/boss_capture_config.tres" id="8_capture_config"]',
        ])
    else:
        ext.append('[ext_resource type="Resource" path="res://zone/reinforcement_config.tres" id="9_reinforcements"]')
    size = "Vector3(4.4, 3.5, 4.4)" if is_boss else "Vector3(2.4, 2, 2.4)"
    sub = [
        '[sub_resource type="NavigationMesh" id="NavMesh"]',
        'geometry_parsed_geometry_type = 1',
        'geometry_collision_mask = 1',
        'geometry_source_geometry_mode = 2',
        'geometry_source_group_name = &"navigation_geometry"',
        'cell_size = 0.5', 'cell_height = 0.25', 'agent_height = 2.0',
        'agent_radius = 0.5', 'agent_max_climb = 0.25', 'agent_max_slope = 45.0', '',
        '[sub_resource type="CylinderShape3D" id="CaptureReach"]',
        'height = 3.0', f'radius = {4.2 if is_boss else 3.2}', '',
        '[sub_resource type="StandardMaterial3D" id="ObjectiveMaterial"]',
        'albedo_color = Color(0.52, 0.58, 0.61, 1)', '',
        '[sub_resource type="BoxMesh" id="ObjectiveMesh"]',
        'material = SubResource("ObjectiveMaterial")', f'size = {size}', '',
        '[sub_resource type="BoxShape3D" id="ObjectiveShape"]', f'size = {size}', '',
    ]
    nodes = [f'[node name="{name}" type="Node3D"]', '',
        '[node name="Geometry" type="Node3D" parent="."]',
        'script = ExtResource("1_geometry")']
    if not is_boss:
        nodes.append(f'room_index = {room_index}')
    nodes.extend(['',
        '[node name="NavigationRegion3D" type="NavigationRegion3D" parent="."]',
        'navigation_mesh = SubResource("NavMesh")', '',
        '[node name="CoverPoints" type="Node3D" parent="."]', '',
        '[node name="CapturePoint" type="Area3D" parent="."]',
        f'transform = {transform(capture)}', 'script = ExtResource("5_capture")'])
    if is_boss:
        nodes.append('config = ExtResource("8_capture_config")')
    nodes.extend(['',
        '[node name="Shape" type="CollisionShape3D" parent="CapturePoint"]',
        'position = Vector3(0, 1.5, 0)', 'shape = SubResource("CaptureReach")', '',
        '[node name="Objective" type="StaticBody3D" parent="CapturePoint" groups=["navigation_geometry"]]',
        f'position = Vector3(0, {1.75 if is_boss else 1}, 0)', '',
        '[node name="Mesh" type="MeshInstance3D" parent="CapturePoint/Objective"]',
        'mesh = SubResource("ObjectiveMesh")', '',
        '[node name="Shape" type="CollisionShape3D" parent="CapturePoint/Objective"]',
        'shape = SubResource("ObjectiveShape")', '',
        '[node name="Player" parent="." instance=ExtResource("2_player")]',
        f'transform = {transform(spawn)}', '',
    ])
    for i, (position, kind, yaw) in enumerate(enemies):
        nodes.extend([f'[node name="Enemy{i+1}" parent="." instance=ExtResource("3_enemy")]',
            f'transform = {transform(position, yaw)}', f'kind = {kind}', ''])
    if is_boss:
        nodes.extend(['[node name="Boss" parent="." instance=ExtResource("7_boss")]',
            f'transform = {transform(boss, 180)}', ''])
    if spawns:
        nodes.extend(['[node name="ReinforcementSpawns" type="Node3D" parent="."]', ''])
        for i, position in enumerate(spawns):
            nodes.extend([f'[node name="Spawn{i+1}" type="Marker3D" parent="ReinforcementSpawns" groups=["reinforcement_spawn"]]',
                f'transform = {transform(position)}', ''])
    nodes.extend([
        '[node name="ZoneDirector" type="Node" parent="." node_paths=PackedStringArray("navigation_region", "capture_point")]',
        'script = ExtResource("4_director")',
        'navigation_region = NodePath("../NavigationRegion3D")',
        'capture_point = NodePath("../CapturePoint")',
    ])
    if is_boss:
        nodes.append('is_boss_zone = true')
    else:
        nodes.extend(['reinforcement_config = ExtResource("9_reinforcements")',
            'reinforcement_scene = ExtResource("3_enemy")'])
    nodes.extend(['', '[node name="HUD" parent="." instance=ExtResource("6_hud")]', ''])
    count = len(ext) + sum(x.startswith('[sub_resource') for x in sub) + 1
    return "\n".join([f'[gd_scene load_steps={count} format=3]', ''] + ext + [''] + sub + nodes)


# Restore the original short objective run-in while keeping full-size actors.
SPAWNS = [(-11.5, 0, -20), (0, 0, -21), (11.5, 0, -20),
          (-17, 0, -8), (17, 0, -8), (-16.5, 3, -6), (16.5, 4, -6)]
LAYOUTS = {
    "maps/zone_1.tscn": dict(name="Zone1", room_index=0, spawn=(0, 0.1, 14), capture=(0, 0, -8),
        enemies=[((13.5, 0, 7.2), 0, 30), ((-8.5, -1.2, 1.5), 1, -45),
                 ((-7, 0, -10), 0, -60), ((7, 0, -10), 0, 60)], spawns=SPAWNS),
    "maps/zone_2.tscn": dict(name="Zone2", room_index=1, spawn=(0, 0.1, 16), capture=(0, 0, -8),
        enemies=[((-13.5, 0, 9), 0, -30), ((13.5, 0, 9), 0, 30),
                 ((-8.5, -1.2, 1.8), 0, -45), ((8.5, -1.2, 1.8), 1, 45),
                 ((-14, 0, -1.5), 2, -60), ((14, 0, -1.5), 1, 60)], spawns=SPAWNS),
    "maps/boss.tscn": dict(name="Boss", room_index=0, spawn=(0, 0.1, 18), capture=(0, 0, -17),
        enemies=[((-12, 0, 7), 0, 0), ((12, 0, 7), 0, 0),
                 ((-15, 0, 1), 1, 0), ((15, 0, 1), 1, 0),
                 ((-4, 0.46, -6), 0, 0), ((4, 0.46, -6), 0, 0)], boss=(0, 0.46, -6)),
}

if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    for path, spec in LAYOUTS.items():
        target = root / path
        target.write_text(zone(**spec), encoding="utf-8", newline="\n")
        print(path, len(spec["enemies"]), "Sloth guards" + (" + boss" if spec.get("boss") else ""))
