"""Generate additive Epic 3 maps only when their local provider exists."""
from pathlib import Path
REALMS = ("sloth", "fear", "wrath", "sorrow")


def generate(root: Path) -> list[Path]:
    paths = []
    for realm, name in enumerate(REALMS):
        if not (root / f"environments/{name}/realm.gd").exists():
            continue
        if not (root / f"actors/enemy/{name}/{name}_realm_enemy.tscn").exists():
            continue
        for room in range(2):
            path = root / f"maps/realms/{name}_{room + 1}.tscn"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f'''[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://zone/realm_stage.gd" id="1"]
[ext_resource type="Script" path="res://environments/{name}/realm.gd" id="2"]
[ext_resource type="PackedScene" path="res://actors/player/player.tscn" id="3"]

[node name="{name.title()}Realm{room + 1}" type="Node3D"]
script = ExtResource("1")
realm = {realm}
room_index = {room}

[node name="Geometry" type="Node3D" parent="."]
script = ExtResource("2")

[node name="Player" parent="." instance=ExtResource("3")]
position = Vector3(0, 0.1, 16)
''', encoding="utf-8", newline="\n")
            paths.append(path)
    return paths


if __name__ == "__main__":
    for generated in generate(Path(__file__).resolve().parents[1]):
        print(generated)
