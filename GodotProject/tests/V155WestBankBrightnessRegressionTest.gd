extends Node

const CityMap = preload("res://scripts/CommercialCityMap.gd")
const LandmarkAssets = preload("res://scripts/WestBankLandmarkAssets.gd")
const IDS := ["AuroraSpire", "HarborTwin", "TerraceHQ", "PearlFinance"]

var passed := 0
var failed := 0


func _ready() -> void:
	_test_west_bank_ground_grade()
	_test_local_fill_lighting()
	_test_landmark_material_grade()
	print("V155_WEST_BANK_BRIGHTNESS passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _test_west_bank_ground_grade() -> void:
	var city := CityMap.new()
	add_child(city)
	city.call("_make_west_bank_ground")
	var ground := city.get_node_or_null("WestBankFinancialGround") as MeshInstance3D
	var material := ground.material_override as ShaderMaterial if ground != null else null
	var lift_value: Variant = material.get_shader_parameter("brightness_lift") if material != null else null
	var tint_value: Variant = material.get_shader_parameter("cool_lift") if material != null else null
	var lift := float(lift_value) if lift_value is float else 0.0
	var tint := tint_value as Color if tint_value is Color else Color.BLACK
	_assert("西岸地表使用受控中间调提亮", lift >= 0.08 and lift <= 0.16)
	_assert("西岸提亮仍保持冷蓝通道占优", tint.b > tint.g and tint.g > tint.r)
	city.queue_free()


func _test_local_fill_lighting() -> void:
	var city := CityMap.new()
	add_child(city)
	city.call("_make_west_bank_ground")
	var lights := city.find_children("WestBankCoolFill*", "OmniLight3D", true, false)
	var valid := lights.size() == 4
	for node in lights:
		var light := node as OmniLight3D
		valid = valid and light != null and not light.shadow_enabled and light.light_color.b > light.light_color.r and light.omni_range <= 32.0
	_assert("四盏无阴影冷蓝柔光仅覆盖西岸", valid)
	city.queue_free()


func _test_landmark_material_grade() -> void:
	for landmark_id in IDS:
		var model := LandmarkAssets.instantiate(landmark_id)
		var meshes := model.find_children("*", "MeshInstance3D", true, false) if model != null else []
		var graded := not meshes.is_empty()
		for mesh_node: MeshInstance3D in meshes:
			for surface_index in mesh_node.mesh.get_surface_count():
				graded = graded and mesh_node.get_surface_override_material(surface_index) is StandardMaterial3D
		_assert("%s 保留 GLB 多材质并完成实时材质转换" % landmark_id, graded)
		if model != null:
			model.queue_free()


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s" % label)
