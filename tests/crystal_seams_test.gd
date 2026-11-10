extends Node
const SEAMS := preload("res://actors/player/crystal_seams.gd")
const BODY := preload("res://assets/models/characters/red_crystal_enemy_animated.glb")
const SHARDS := preload("res://assets/models/characters/red_crystal_enemy_shards.glb")
var _failures := 0


func _ready() -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3(1, 1, 0), Vector3.UP])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var quad := ArrayMesh.new()
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var derived: ArrayMesh = SEAMS.with_seam_attributes(quad)
	_check("coplanar square keeps 4 boundary edges", derived.get_meta("surface_0_visible_edges") == 4)
	_check("both sides of triangulation diagonal are hidden", derived.get_meta("surface_0_hidden_diagonals") == 2)
	_check("render mesh does not modify original indices", quad.surface_get_arrays(0)[Mesh.ARRAY_INDEX] == arrays[Mesh.ARRAY_INDEX])
	_check("seam cache reuses render attributes", SEAMS.with_seam_attributes(quad) == derived)
	var hard := ArrayMesh.new()
	arrays[Mesh.ARRAY_VERTEX][3] = Vector3(0, 1, 1)
	hard.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var folded: ArrayMesh = SEAMS.with_seam_attributes(hard)
	_check("non-coplanar physical fold stays a joint", folded.get_meta("surface_0_visible_edges") == 6)
	var hidden := 0
	var visible := 0
	for scene in [BODY, SHARDS]:
		var root := scene.instantiate() as Node3D
		for node in root.find_children("*", "MeshInstance3D", true, false):
			var source := (node as MeshInstance3D).mesh as ArrayMesh
			var result: ArrayMesh = SEAMS.with_seam_attributes(source)
			_check("%s preserves every triangle attribute" % node.name, _same_geometry(source, result))
			for surface in source.get_surface_count():
				hidden += int(result.get_meta("surface_%d_hidden_diagonals" % surface))
				visible += int(result.get_meta("surface_%d_visible_edges" % surface))
		root.free()
	_check("original assets discard coplanar and near-coplanar triangulation edges", hidden > 100)
	print("FACET EDGES: %d real joint sides; %d coplanar/near-coplanar sides excluded" % [visible, hidden])
	print("CRYSTAL SEAMS: %s (%d failed)" % ["ALL PASSED" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _same_geometry(source: ArrayMesh, result: ArrayMesh) -> bool:
	if source.get_surface_count() != result.get_surface_count():
		return false
	for surface in source.get_surface_count():
		var original := source.surface_get_arrays(surface)
		var expanded := result.surface_get_arrays(surface)
		var indices: PackedInt32Array = original[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in original[Mesh.ARRAY_VERTEX].size():
				indices.append(i)
		if expanded[Mesh.ARRAY_VERTEX].size() != indices.size():
			return false
		for attribute in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT,
				Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
			if original[attribute] == null or original[attribute].is_empty():
				continue
			var stride := 4 if attribute == Mesh.ARRAY_TANGENT else 1
			if attribute == Mesh.ARRAY_BONES or attribute == Mesh.ARRAY_WEIGHTS:
				stride = 8 if (source.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0 else 4
			for corner in indices.size():
				for component in stride:
					var a = original[attribute][indices[corner] * stride + component]
					var b = expanded[attribute][corner * stride + component]
					# Vertex data is exact; renderer re-encodes normal/tangent and
					# weights in packed formats with their existing precision.
					if attribute == Mesh.ARRAY_VERTEX or attribute == Mesh.ARRAY_BONES:
						if a != b:
							return false
					elif attribute == Mesh.ARRAY_NORMAL:
						# Godot encodes normals as 16-bit octahedral vectors again.
						if (a as Vector3).distance_to(b) > 0.0002:
							return false
					elif a is float:
						if absf(a - b) > (0.0002 if attribute == Mesh.ARRAY_TANGENT else 1.0 / 65535.0):
							return false
					elif not a.is_equal_approx(b):
						return false
	return true


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
