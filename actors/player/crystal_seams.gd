extends RefCounted
## Adds distances to the ORIGINAL non-coplanar facet edges in CUSTOM0. Imported
## GLBs stay untouched. Expanding the index buffer only supplies per-triangle
## attributes: positions, normals, UVs, skin weights and triangles are preserved.
static var _cache: Dictionary = {}


static func with_seam_attributes(source: ArrayMesh) -> ArrayMesh:
	var key := source.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var derived := ArrayMesh.new()
	derived.resource_name = source.resource_name + "_FacetSeams"
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size():
				indices.append(i)
		var edges: Dictionary = {}
		var normals: Array[Vector3] = []
		for triangle in range(0, indices.size(), 3):
			var a := vertices[indices[triangle]]
			var b := vertices[indices[triangle + 1]]
			var c := vertices[indices[triangle + 2]]
			var normal := (b - a).cross(c - a).normalized()
			normals.append(normal)
			for edge in [[a, b], [b, c], [c, a]]:
				var edge_key := _edge_key(edge[0], edge[1])
				if not edges.has(edge_key):
					edges[edge_key] = []
				(edges[edge_key] as Array).append(normal)
		var custom := PackedFloat32Array()
		var active_edges := 0
		var hidden_edges := 0
		for triangle in range(0, indices.size(), 3):
			var p := [vertices[indices[triangle]], vertices[indices[triangle + 1]], vertices[indices[triangle + 2]]]
			var twice_area: float = (p[1] - p[0]).cross(p[2] - p[0]).length()
			var mask := 0
			var heights := Vector3.ZERO
			for edge in 3:
				var a: Vector3 = p[(edge + 1) % 3]
				var b: Vector3 = p[(edge + 2) % 3]
				heights[edge] = twice_area / maxf(a.distance_to(b), 0.000001)
				var adjacent: Array = edges[_edge_key(a, b)]
				var seam := adjacent.size() == 1
				for normal: Vector3 in adjacent:
					# Coplanar diagonals and shallow (<10 degree) tessellation
					# edges are not emphasized as structural crystal joints.
					if normal.dot(normals[int(float(triangle) / 3.0)]) < 0.985:
						seam = true
				if seam:
					mask |= 1 << edge
					active_edges += 1
				else:
					hidden_edges += 1
			for corner in 3:
				custom.append(heights.x if corner == 0 else 0.0)
				custom.append(heights.y if corner == 1 else 0.0)
				custom.append(heights.z if corner == 2 else 0.0)
				custom.append(float(mask))
		var result := arrays.duplicate()
		var eight_weights := (source.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0
		for attribute in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT,
				Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
			if arrays[attribute] == null:
				continue
			var original = arrays[attribute]
			if original.is_empty():
				continue
			var expanded = original.duplicate()
			expanded.clear()
			var stride := 4 if attribute == Mesh.ARRAY_TANGENT else 1
			if attribute == Mesh.ARRAY_BONES or attribute == Mesh.ARRAY_WEIGHTS:
				stride = 8 if eight_weights else 4
			for index in indices:
				for component in stride:
					expanded.append(original[index * stride + component])
			result[attribute] = expanded
		result[Mesh.ARRAY_INDEX] = null
		result[Mesh.ARRAY_CUSTOM0] = custom
		var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		if eight_weights:
			flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		derived.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, result, [], {}, flags)
		derived.surface_set_material(surface, source.surface_get_material(surface))
		derived.set_meta("surface_%d_visible_edges" % surface, active_edges)
		derived.set_meta("surface_%d_hidden_diagonals" % surface, hidden_edges)
	_cache[key] = derived
	return derived


static func _edge_key(a: Vector3, b: Vector3) -> String:
	var first := "%d,%d,%d" % [roundi(a.x * 100000), roundi(a.y * 100000), roundi(a.z * 100000)]
	var second := "%d,%d,%d" % [roundi(b.x * 100000), roundi(b.y * 100000), roundi(b.z * 100000)]
	return first + ":" + second if first < second else second + ":" + first
