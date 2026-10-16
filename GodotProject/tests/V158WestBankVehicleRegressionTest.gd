extends Node

const CityMapVisual = preload("res://scripts/CommercialCityMap.gd")

var passed := 0
var failed := 0


func _ready() -> void:
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15802)
	var city_map := CityMapVisual.new()
	add_child(city_map)
	var model_names: Array[String] = []
	var all_materials_ready := true
	for index in range(6):
		var vehicle := city_map.call("_place_premium_vehicle", Vector3(index * 2.0, 0.0, 0.0), index) as Node3D
		if vehicle == null:
			all_materials_ready = false
			continue
		model_names.append(str(vehicle.get_meta("premium_model", "")))
		all_materials_ready = all_materials_ready and bool(vehicle.get_meta("premium_material_ready", false))
		var mesh_count := 0
		for node_value in vehicle.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := node_value as MeshInstance3D
			mesh_count += 1
			var material := mesh_node.material_override as StandardMaterial3D
			all_materials_ready = all_materials_ready and material != null and material.albedo_texture != null
		all_materials_ready = all_materials_ready and mesh_count >= 5
	_assert("西岸道路保留六种可辨识车型", model_names.size() == 6 and _unique_count(model_names) == 6)
	_assert("西岸车辆显式绑定车漆调色板而非纯白材质", all_materials_ready)
	var ecology := city_map.call("premium_vehicle_visual_profile") as Dictionary if city_map.has_method("premium_vehicle_visual_profile") else {}
	_assert("车辆视觉合同包含车漆、玻璃、轮胎和灯组层次", bool(ecology.get("palette_texture", false)) and int(ecology.get("model_variants", 0)) == 6 and int(ecology.get("material_layers", 0)) >= 4)
	print("V158_WEST_BANK_VEHICLES passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _unique_count(values: Array[String]) -> int:
	var unique := {}
	for value in values:
		unique[value] = true
	return unique.size()


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL %s" % label)
