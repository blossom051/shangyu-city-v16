extends Node

const CityMapVisual = preload("res://scripts/CommercialCityMap.gd")

var passed := 0
var failed := 0


func _ready() -> void:
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15803)
	var city_map := CityMapVisual.new()
	add_child(city_map)
	city_map.call("_make_west_river_surface")
	var surface := city_map.get_node_or_null("WestRiverSurface") as MeshInstance3D
	var material := surface.material_override as ShaderMaterial if surface != null else null
	var shader_code := material.shader.code if material != null and material.shader != null else ""
	_assert("河面不再使用碎玻璃式随机噪声", not shader_code.contains("hash(") and not shader_code.contains("noise(") and not shader_code.contains("fbm("))
	_assert("河面使用 UE 烘焙贴图双层纵向水流", shader_code.contains("ue_flow_color") and shader_code.contains("flow_a") and shader_code.contains("flow_b") and shader_code.contains("bank_distance"))
	var profile := city_map.call("water_flow_profile") as Dictionary
	_assert("水面合同为 UE 5.8 双层城市河流且无冰裂噪声", str(profile.get("surface_model", "")) == "ue58_baked_dual_flow_city_river" and str(profile.get("bake_source", "")) == "unreal_engine_5_8" and not bool(profile.get("fracture_noise", true)) and bool(profile.get("shoreline_gradient", false)))
	print("V158_WEST_BANK_RIVER passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL %s" % label)
