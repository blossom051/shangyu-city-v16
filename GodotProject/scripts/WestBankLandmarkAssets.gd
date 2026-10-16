class_name WestBankLandmarkAssets
extends RefCounted

const MANIFEST_PATH := "res://assets/Buildings/west_bank_blender/manifest.json"
static var _entries: Dictionary = {}

static func _ensure_manifest() -> void:
	if not _entries.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		push_error("West-bank Blender landmark manifest is invalid")
		return
	for item: Dictionary in parsed.get("landmarks", []):
		_entries[str(item.get("id", ""))] = item.duplicate(true)

static func entry(landmark_id: String) -> Dictionary:
	_ensure_manifest()
	return Dictionary(_entries.get(landmark_id, {})).duplicate(true)

static func instantiate(landmark_id: String) -> Node3D:
	var model_path := str(entry(landmark_id).get("model_path", ""))
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		push_error("Blender landmark unavailable: %s" % landmark_id)
		return null
	var scene := load(model_path) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate() as Node3D
	if root == null:
		return null
	_apply_game_materials(root)
	return root

static func _apply_game_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in mesh_node.mesh.get_surface_count():
			var original := mesh_node.get_active_material(i) as StandardMaterial3D
			if original == null:
				continue
			var mat := original.duplicate() as StandardMaterial3D
			if mat.albedo_texture != null:
				mat.albedo_color = Color.WHITE
			# Keep Blender's distinct glass, stone and metal values unchanged.
			mesh_node.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_game_materials(child)

static func bounds(landmark_id: String) -> Vector3:
	var values: Array = entry(landmark_id).get("bounds", [6.4, 14.4, 6.4])
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
