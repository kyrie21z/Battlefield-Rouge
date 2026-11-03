"""Generates the greybox zones maps/zone_1.tscn, maps/zone_2.tscn and maps/boss.tscn.

Edit the layouts in `zones` at the bottom, then run from the project root:
    python3 tools/gen_zones.py
This overwrites all three scenes, so make layout changes here, not in the editor.
Each box named Cover* gets four cover points around it.
A layout with `boss` adds one big enemy there; `enemies` are then the small ones
around it. A layout with `core` has a bigger objective. The core stays shut
until the boss dies, and one hammer then finishes it (`boss_capture_config.tres`).
`spawns` are reinforcement markers (small zones only): rear, flank and rear
corners, so the director can pick one outside the player's view. The boss zone
has none.

Enemies are `(x, z, yaw_degrees)`. The yaw is the Godot rotation around Y:
0 faces -z, 90 faces -x, 180 faces +z. Guards are spread over three depth
thirds (front/mid/point) so an idle guard near the spawn never has the player
inside its 120 degree view cone: they look across or down the battlefield, not
back at the entrance.
"""

import math


def facing(x, z, yaw_deg):
    """Transform3D for an enemy at (x, z) turned `yaw_deg` around Y.

    A Godot Y rotation of 0 faces -z and 180 faces +z; the basis is written
    row by row, the way the .tscn format stores it.
    """
    r = math.radians(yaw_deg)
    c = round(math.cos(r), 6) + 0.0
    s = round(math.sin(r), 6) + 0.0
    ns = 0.0 if s == 0.0 else -s
    return f'Transform3D({c:g}, 0, {s:g}, 0, 1, 0, {ns:g}, 0, {c:g}, {x}, 0, {z})'


def zone(name, boxes, enemies, capture, spawn, grey, boss=None, core=False, spawns=None):
    walls = [("Floor",(60,1,60),(0,-0.5,0)),("WallN",(60,4,1),(0,2,-30)),("WallS",(60,4,1),(0,2,30)),
             ("WallE",(1,4,60),(30,2,0)),("WallW",(1,4,60),(-30,2,0))]
    # Invisible collision above the visible walls: a pitched dash can lift the
    # player over the 4 m rim. They sit outside the navigation group, so the
    # baked mesh ignores them. The highest reachable spot is the 3.5 m core plus
    # a jump and one 5 m dash, under 10 m, well below the 30 m top.
    bounds = [("WallNHigh",(60,26,1),(0,17,-30)),("WallSHigh",(60,26,1),(0,17,30)),
              ("WallEHigh",(1,26,60),(30,17,0)),("WallWHigh",(1,26,60),(-30,17,0))]
    boxes = walls + boxes
    # The city core of the boss zone: a bigger building with a wider hammer reach.
    size = "Vector3(4.4, 3.5, 4.4)" if core else "Vector3(2.4, 2, 2.4)"
    reach = 4.2 if core else 3.2
    objective_y = 1.75 if core else 1
    ext = ['[ext_resource type="PackedScene" path="res://actors/player/player.tscn" id="1_player"]',
           '[ext_resource type="PackedScene" path="res://actors/enemy/enemy.tscn" id="2_enemy"]',
           '[ext_resource type="PackedScene" path="res://ui/hud.tscn" id="3_hud"]',
           '[ext_resource type="Script" path="res://zone/zone_director.gd" id="4_director"]',
           '[ext_resource type="Script" path="res://zone/cover_point.gd" id="5_cover"]',
           '[ext_resource type="Script" path="res://zone/capture_point.gd" id="6_capture"]']
    if boss:
        ext.append('[ext_resource type="PackedScene" path="res://actors/enemy/boss.tscn" id="7_boss"]')
    if core:
        ext.append('[ext_resource type="Resource" path="res://zone/boss_capture_config.tres" id="9_bosscap"]')
    if spawns:
        ext.append('[ext_resource type="Resource" path="res://zone/reinforcement_config.tres" id="8_reinf"]')
    sub = ['[sub_resource type="ProceduralSkyMaterial" id="Sky_mat"]','',
           '[sub_resource type="Sky" id="Sky_sky"]','sky_material = SubResource("Sky_mat")','',
           '[sub_resource type="Environment" id="Env"]','background_mode = 2','sky = SubResource("Sky_sky")','ambient_light_source = 3','tonemap_mode = 2','glow_enabled = true','',
           '[sub_resource type="StandardMaterial3D" id="Mat_grey"]',f'albedo_color = Color({grey[0]}, {grey[1]}, {grey[2]}, 1)','',
           '[sub_resource type="NavigationMesh" id="NavMesh"]','geometry_parsed_geometry_type = 1','geometry_source_geometry_mode = 1','geometry_source_group_name = &"navigation_geometry"','cell_size = 0.25','cell_height = 0.25','agent_height = 1.75','agent_radius = 0.5','agent_max_climb = 0.25','',
           # Hammer reach around the objective building, and the building itself.
           '[sub_resource type="CylinderShape3D" id="Shape_capture"]','height = 3.0',f'radius = {reach}','',
           '[sub_resource type="BoxMesh" id="Mesh_objective"]','material = SubResource("Mat_grey")',f'size = {size}','',
           '[sub_resource type="BoxShape3D" id="Shape_objective"]',f'size = {size}','']
    for i,(n,s,p) in enumerate(boxes):
        v = 'Vector3(%s, %s, %s)' % s
        sub += [f'[sub_resource type="BoxMesh" id="Mesh_{i}"]','material = SubResource("Mat_grey")',f'size = {v}','',
                f'[sub_resource type="BoxShape3D" id="Shape_{i}"]',f'size = {v}','']
    for i,(n,s,p) in enumerate(bounds):
        v = 'Vector3(%s, %s, %s)' % s
        sub += [f'[sub_resource type="BoxShape3D" id="Shape_bound{i}"]',f'size = {v}','']
    T = lambda x,y,z: f'Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})'
    nodes = [f'[node name="{name}" type="Node3D"]','',
             '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]','environment = SubResource("Env")','',
             '[node name="Sun" type="DirectionalLight3D" parent="."]','transform = Transform3D(0.866, -0.354, 0.354, 0, 0.707, 0.707, -0.5, -0.612, 0.612, 0, 10, 0)','shadow_enabled = true','',
             '[node name="NavigationRegion3D" type="NavigationRegion3D" parent="."]','navigation_mesh = SubResource("NavMesh")','',
             '[node name="Geometry" type="Node3D" parent="." groups=["navigation_geometry"]]','']
    for i,(n,s,p) in enumerate(boxes):
        nodes += [f'[node name="{n}" type="StaticBody3D" parent="Geometry"]',f'transform = {T(*p)}','',
                  f'[node name="Mesh" type="MeshInstance3D" parent="Geometry/{n}"]',f'mesh = SubResource("Mesh_{i}")','',
                  f'[node name="Shape" type="CollisionShape3D" parent="Geometry/{n}"]',f'shape = SubResource("Shape_{i}")','']
    nodes += ['[node name="Boundary" type="Node3D" parent="."]','']
    for i,(n,s,p) in enumerate(bounds):
        # Layer 5 (CollisionLayers.BOUNDARY): the player collides with it, the
        # WORLD|HITBOXES bullet ray does not, so shots still leave the map.
        nodes += [f'[node name="{n}" type="StaticBody3D" parent="Boundary"]',f'transform = {T(*p)}',
                  'collision_layer = 16','',
                  f'[node name="Shape" type="CollisionShape3D" parent="Boundary/{n}"]',f'shape = SubResource("Shape_bound{i}")','']
    nodes += ['[node name="CoverPoints" type="Node3D" parent="."]','']
    k = 0
    for n,s,p in boxes:
        if not n.startswith("Cover"): continue
        for dx,dz in [(s[0]/2+0.6,0),(-s[0]/2-0.6,0),(0,s[2]/2+0.6),(0,-s[2]/2-0.6)]:
            k += 1
            nodes += [f'[node name="Cover{k:02d}" type="Marker3D" parent="CoverPoints" groups=["cover_point"]]',f'transform = {T(round(p[0]+dx,2),0,round(p[2]+dz,2))}','script = ExtResource("5_cover")','']
    capture_node = ['[node name="CapturePoint" type="Area3D" parent="."]',f'transform = {T(capture[0],0,capture[1])}','script = ExtResource("6_capture")']
    if core:
        capture_node.append('config = ExtResource("9_bosscap")')
    nodes += capture_node + ['',
              '[node name="Shape" type="CollisionShape3D" parent="CapturePoint"]',f'transform = {T(0,1.5,0)}','shape = SubResource("Shape_capture")','',
              # In the navigation group so the baked mesh routes enemies around the building.
              '[node name="Objective" type="StaticBody3D" parent="CapturePoint" groups=["navigation_geometry"]]',f'transform = {T(0,objective_y,0)}','',
              '[node name="Mesh" type="MeshInstance3D" parent="CapturePoint/Objective"]','mesh = SubResource("Mesh_objective")','',
              '[node name="Shape" type="CollisionShape3D" parent="CapturePoint/Objective"]','shape = SubResource("Shape_objective")','',
              '[node name="Player" parent="." instance=ExtResource("1_player")]',f'transform = {T(spawn[0],0,spawn[1])}','']
    for i,(x,z,yaw) in enumerate(enemies):
        nodes += [f'[node name="Enemy{i+1}" parent="." instance=ExtResource("2_enemy")]',f'transform = {facing(x, z, yaw)}','']
    if boss:
        nodes += ['[node name="Boss" parent="." instance=ExtResource("7_boss")]',f'transform = {facing(*boss)}','']
    if spawns:
        nodes += ['[node name="ReinforcementSpawns" type="Node3D" parent="."]','']
        for i, (x, z) in enumerate(spawns):
            nodes += [f'[node name="Spawn{i+1}" type="Marker3D" parent="ReinforcementSpawns" groups=["reinforcement_spawn"]]',
                      f'transform = {T(x, 0, z)}','']
    director = ['[node name="ZoneDirector" type="Node" parent="." node_paths=PackedStringArray("navigation_region", "capture_point")]',
                'script = ExtResource("4_director")',
                'navigation_region = NodePath("../NavigationRegion3D")',
                'capture_point = NodePath("../CapturePoint")']
    if spawns:
        director.append('reinforcement_config = ExtResource("8_reinf")')
    if core:
        director.append('is_boss_zone = true')
    nodes += director + ['', '[node name="HUD" parent="." instance=ExtResource("3_hud")]', '']
    nsub = sum(1 for l in sub if l.startswith('[sub_resource'))
    out = [f'[gd_scene load_steps={nsub+len(ext)+1} format=3]',''] + ext + [''] + sub + nodes
    return "\n".join(out), k

# The boss stands in front of the city core with two escorts at its side; the
# other four small enemies hold the front and middle of the arena.
BOSS_AT = (0, -19, 180)

# Small zones: the player enters from +z. The building sits back at z=-8. Rear
# markers are a few seconds of running; flank markers hide behind the tall
# Cover3/Cover4 walls and rear-corner markers sit at the far corners, so the
# director can usually pick somewhere the player is not looking. The guards are
# spread over the whole run-in: the front third (closest to the spawn), the
# middle third and around the building. Each one
# stands beside a cover crate, and the idle ones face across the arena instead
# of back at the entrance, so the player is outside every 120 degree view cone
# at spawn (issue #42). The centre corridor (x near 0, from the spawns up to
# the building) stays open.
zones = {
 # 4 guards: 1 front / 1 middle / 2 at the building.
 "maps/zone_1.tscn": dict(name="Zone1", grey=(0.55,0.56,0.58), spawn=(0,14), capture=(0,-8),
   enemies=[(13.5,7.2,30),(-9.5,1.5,-45),(-7,-6,-60),(7,-6,60)],
   spawns=[(-8,-21),(0,-20),(8,-21),(-17,-8),(17,-8),(-22,-24),(22,-24)],
   boxes=[("Cover1",(3,1.2,1),(-8,0.6,6)),("Cover2",(3,1.2,1),(8,0.6,6)),
          ("Cover3",(1,2.5,4),(-14,1.25,-8)),("Cover4",(1,2.5,4),(14,1.25,-8)),
          ("Cover5",(3,1.2,1),(-12,0.6,-16)),("Cover6",(3,1.2,1),(12,0.6,-16)),
          ("Cover7",(2,1.2,1),(13.5,0.6,5.4)),("Cover8",(2,1.2,1),(-9.5,0.6,-0.3)),
          ("Cover9",(2,1.2,1),(-7,0.6,-4.2)),("Cover10",(2,1.2,1),(7,0.6,-4.2))]),
 # 6 guards: 2 front / 2 middle / 2 at the building.
 "maps/zone_2.tscn": dict(name="Zone2", grey=(0.6,0.55,0.5), spawn=(0,16), capture=(0,-8),
   enemies=[(-13.5,9,-30),(13.5,9,30),(-8.5,1.8,-45),(8.5,1.8,45),(-14,-1.5,-60),(14,-1.5,60)],
   spawns=[(-10,-21),(0,-20),(10,-21),(-19,-2),(19,-2),(-22,-24),(22,-24)],
   boxes=[("Cover1",(4,1.2,1),(-9,0.6,8)),("Cover2",(4,1.2,1),(9,0.6,8)),
          ("Cover3",(1,2.5,5),(-16,1.25,-2)),("Cover4",(1,2.5,5),(16,1.25,-2)),
          ("Cover5",(3,1.2,1),(-12,0.6,-14)),("Cover6",(3,1.2,1),(12,0.6,-14)),
          ("Cover7",(2,2.5,2),(-14,1.25,-18)),("Cover8",(2,2.5,2),(14,1.25,-18)),
          ("Cover9",(3,1.2,1),(-6,0.6,2)),("Cover10",(3,1.2,1),(6,0.6,2)),
          ("Cover11",(1.5,1.2,2),(-15.5,0.6,9)),("Cover12",(1.5,1.2,2),(15.5,0.6,9))]),
 # 6 small enemies: 2 front / 2 middle / 2 escorts beside the boss at the core.
 "maps/boss.tscn": dict(name="Boss", grey=(0.45,0.47,0.52), spawn=(0,26), capture=(0,-26.5),
   enemies=[(-11,15,-45),(11,15,45),(-13,0.5,-45),(13,0.5,45),(-3.5,-22.5,-90),(3.5,-22.5,90)],
   boss=BOSS_AT, core=True,
   boxes=[("Cover1",(4,1.2,1),(-8,0.6,16)),("Cover2",(4,1.2,1),(8,0.6,16)),
          ("Cover3",(1,2.5,5),(0,1.25,8)),
          ("Cover4",(5,1.2,1),(-12,0.6,2)),("Cover5",(5,1.2,1),(12,0.6,2)),
          ("Cover6",(2,2.5,2),(-6,1.25,-6)),("Cover7",(2,2.5,2),(6,1.25,-6)),
          ("Cover8",(3,1.2,1),(-9,0.6,-12)),("Cover9",(3,1.2,1),(9,0.6,-12))]),
}
for path, z in zones.items():
    text, k = zone(**z)
    open(path, "w").write(text)
    print(path, len(z["enemies"]), "enemies" + (" + boss" if z.get("boss") else ""), k, "cover points")
