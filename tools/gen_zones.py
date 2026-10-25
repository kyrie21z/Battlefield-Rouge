"""Generates the greybox zones maps/zone_1.tscn and maps/zone_2.tscn.

Edit the layouts in `zones` at the bottom, then run from the project root:
    python3 tools/gen_zones.py
This overwrites both scenes, so make layout changes here, not in the editor.
Each box named Cover* gets four cover points around it.
"""

def zone(name, boxes, enemies, capture, spawn, grey):
    walls = [("Floor",(60,1,60),(0,-0.5,0)),("WallN",(60,4,1),(0,2,-30)),("WallS",(60,4,1),(0,2,30)),
             ("WallE",(1,4,60),(30,2,0)),("WallW",(1,4,60),(-30,2,0))]
    boxes = walls + boxes
    ext = ['[ext_resource type="PackedScene" path="res://actors/player/player.tscn" id="1_player"]',
           '[ext_resource type="PackedScene" path="res://actors/enemy/enemy.tscn" id="2_enemy"]',
           '[ext_resource type="PackedScene" path="res://ui/hud.tscn" id="3_hud"]',
           '[ext_resource type="Script" path="res://zone/zone_director.gd" id="4_director"]',
           '[ext_resource type="Script" path="res://zone/cover_point.gd" id="5_cover"]',
           '[ext_resource type="Script" path="res://zone/capture_point.gd" id="6_capture"]']
    sub = ['[sub_resource type="ProceduralSkyMaterial" id="Sky_mat"]','',
           '[sub_resource type="Sky" id="Sky_sky"]','sky_material = SubResource("Sky_mat")','',
           '[sub_resource type="Environment" id="Env"]','background_mode = 2','sky = SubResource("Sky_sky")','ambient_light_source = 3','tonemap_mode = 2','glow_enabled = true','',
           '[sub_resource type="StandardMaterial3D" id="Mat_grey"]',f'albedo_color = Color({grey[0]}, {grey[1]}, {grey[2]}, 1)','',
           '[sub_resource type="NavigationMesh" id="NavMesh"]','geometry_parsed_geometry_type = 1','geometry_source_geometry_mode = 1','geometry_source_group_name = &"navigation_geometry"','cell_size = 0.25','cell_height = 0.25','agent_height = 1.75','agent_radius = 0.5','agent_max_climb = 0.25','',
           # Hammer reach around the objective building, and the building itself.
           '[sub_resource type="CylinderShape3D" id="Shape_capture"]','height = 3.0','radius = 3.2','',
           '[sub_resource type="BoxMesh" id="Mesh_objective"]','material = SubResource("Mat_grey")','size = Vector3(2.4, 2, 2.4)','',
           '[sub_resource type="BoxShape3D" id="Shape_objective"]','size = Vector3(2.4, 2, 2.4)','']
    for i,(n,s,p) in enumerate(boxes):
        v = 'Vector3(%s, %s, %s)' % s
        sub += [f'[sub_resource type="BoxMesh" id="Mesh_{i}"]','material = SubResource("Mat_grey")',f'size = {v}','',
                f'[sub_resource type="BoxShape3D" id="Shape_{i}"]',f'size = {v}','']
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
    nodes += ['[node name="CoverPoints" type="Node3D" parent="."]','']
    k = 0
    for n,s,p in boxes:
        if not n.startswith("Cover"): continue
        for dx,dz in [(s[0]/2+0.6,0),(-s[0]/2-0.6,0),(0,s[2]/2+0.6),(0,-s[2]/2-0.6)]:
            k += 1
            nodes += [f'[node name="Cover{k:02d}" type="Marker3D" parent="CoverPoints" groups=["cover_point"]]',f'transform = {T(round(p[0]+dx,2),0,round(p[2]+dz,2))}','script = ExtResource("5_cover")','']
    nodes += ['[node name="CapturePoint" type="Area3D" parent="."]',f'transform = {T(capture[0],0,capture[1])}','script = ExtResource("6_capture")','',
              '[node name="Shape" type="CollisionShape3D" parent="CapturePoint"]',f'transform = {T(0,1.5,0)}','shape = SubResource("Shape_capture")','',
              # In the navigation group so the baked mesh routes enemies around the building.
              '[node name="Objective" type="StaticBody3D" parent="CapturePoint" groups=["navigation_geometry"]]',f'transform = {T(0,1,0)}','',
              '[node name="Mesh" type="MeshInstance3D" parent="CapturePoint/Objective"]','mesh = SubResource("Mesh_objective")','',
              '[node name="Shape" type="CollisionShape3D" parent="CapturePoint/Objective"]','shape = SubResource("Shape_objective")','',
              '[node name="Player" parent="." instance=ExtResource("1_player")]',f'transform = {T(spawn[0],0,spawn[1])}','']
    for i,(x,z) in enumerate(enemies):
        nodes += [f'[node name="Enemy{i+1}" parent="." instance=ExtResource("2_enemy")]',f'transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, {x}, 0, {z})','']
    nodes += ['[node name="ZoneDirector" type="Node" parent="." node_paths=PackedStringArray("navigation_region", "capture_point")]','script = ExtResource("4_director")','navigation_region = NodePath("../NavigationRegion3D")','capture_point = NodePath("../CapturePoint")','',
              '[node name="HUD" parent="." instance=ExtResource("3_hud")]','']
    nsub = sum(1 for l in sub if l.startswith('[sub_resource'))
    out = [f'[gd_scene load_steps={nsub+len(ext)+1} format=3]',''] + ext + [''] + sub + nodes
    return "\n".join(out), k

zones = {
 "maps/zone_1.tscn": dict(name="Zone1", grey=(0.55,0.56,0.58), spawn=(0,22), capture=(0,-22),
   enemies=[(-8,-24),(8,-25),(-2,-26),(3,-14)],
   boxes=[("Cover1",(3,1.2,1),(-6,0.6,8)),("Cover2",(3,1.2,1),(6,0.6,8)),
          ("Cover3",(1,2.5,4),(-10,1.25,-4)),("Cover4",(1,2.5,4),(10,1.25,-4)),
          ("Cover5",(4,1.2,1),(0,0.6,-10)),("Cover6",(2,2.5,2),(-4,1.25,-18)),("Cover7",(2,2.5,2),(5,1.25,-20))]),
 "maps/zone_2.tscn": dict(name="Zone2", grey=(0.6,0.55,0.5), spawn=(0,24), capture=(0,-21),
   enemies=[(-12,-22),(12,-22),(-4,-25),(4,-25),(-14,-8),(14,-8)],
   boxes=[("Cover1",(4,1.2,1),(-8,0.6,13)),("Cover2",(4,1.2,1),(8,0.6,13)),
          ("Cover3",(1,2.5,6),(0,1.25,4)),
          ("Cover4",(6,2.5,1),(-14,1.25,0)),("Cover5",(6,2.5,1),(14,1.25,0)),
          ("Cover6",(3,1.2,1),(-5,0.6,-6)),("Cover7",(3,1.2,1),(5,0.6,-6)),
          ("Cover8",(2,2.5,2),(-10,1.25,-14)),("Cover9",(2,2.5,2),(10,1.25,-14)),
          ("Cover10",(5,1.2,1),(0,0.6,-15))]),
}
for path, z in zones.items():
    text, k = zone(**z)
    open(path, "w").write(text)
    print(path, len(z["enemies"]), "enemies", k, "cover points")
