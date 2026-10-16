extends Node

const CityMapScript = preload("res://scripts/CommercialCityMap.gd")
const ASSET_DIR := "res://assets/ui/city/river_ue58"
const REQUIRED_TEXTURES := [
	"ue58_river_flow_color.png",
	"ue58_river_normal.png",
	"ue58_river_foam.png",
]

var passed := 0
var failed := 0


func _ready() -> void:
	_check_bake_manifest()
	_check_texture_quality()
	_check_runtime_material_binding()
	print("V155_UE58_RIVER_BAKE passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _check_bake_manifest() -> void:
	var path := "%s/ue58_river_bake_manifest.json" % ASSET_DIR
	_assert("UE 5.8 河流烘焙清单存在", FileAccess.file_exists(path))
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	_assert("烘焙清单是有效 JSON", parsed is Dictionary)
	if not parsed is Dictionary:
		return
	var manifest := parsed as Dictionary
	_assert("清单记录真实 Unreal Engine 5.8 来源", str(manifest.get("engine", "")).begins_with("Unreal Engine 5.8"))
	_assert("清单记录 2048 像素烘焙分辨率", int(manifest.get("width", 0)) == 2048 and int(manifest.get("height", 0)) == 2048)
	_assert("清单包含三张贴图校验值", (manifest.get("files", {}) as Dictionary).size() == 3)


func _check_texture_quality() -> void:
	for file_name in REQUIRED_TEXTURES:
		var path := "%s/%s" % [ASSET_DIR, file_name]
		_assert("%s 存在" % file_name, FileAccess.file_exists(path))
		if not FileAccess.file_exists(path):
			continue
		var texture := load(path) as Texture2D
		var image := texture.get_image() if texture != null else null
		_assert("%s 分辨率不少于 1024×1024" % file_name, image != null and image.get_width() >= 1024 and image.get_height() >= 1024)
		if image == null or image.is_empty():
			continue
		var colors := {}
		for y in range(0, image.get_height(), maxi(1, image.get_height() / 16)):
			for x in range(0, image.get_width(), maxi(1, image.get_width() / 16)):
				colors[image.get_pixel(x, y).to_html(false)] = true
		_assert("%s 不是白图或纯色图" % file_name, colors.size() >= 12)


func _check_runtime_material_binding() -> void:
	var map := CityMapScript.new() as Node3D
	map.call("_make_west_river_surface")
	var river := map.get_node_or_null("WestRiverSurface") as MeshInstance3D
	_assert("运行时创建西岸河流节点", river != null)
	if river != null:
		var material := river.material_override as ShaderMaterial
		_assert("河流使用实时 ShaderMaterial", material != null)
		if material != null:
			_assert("河流绑定 UE 水色贴图", material.get_shader_parameter("ue_flow_color") is Texture2D)
			_assert("河流绑定 UE 法线贴图", material.get_shader_parameter("ue_flow_normal") is Texture2D)
			_assert("河流绑定 UE 泡沫贴图", material.get_shader_parameter("ue_foam_mask") is Texture2D)
			_assert("完整资源启用 UE 贴图渲染路径", is_equal_approx(float(material.get_shader_parameter("texture_ready")), 1.0))
	var profile := map.call("water_flow_profile") as Dictionary
	_assert("运行时档案标识 UE 5.8 烘焙", profile.get("bake_source", "") == "unreal_engine_5_8")
	_assert("河流保留双层定向流动", int(profile.get("normal_detail_layers", 0)) == 2 and int(profile.get("flow_directions", 0)) == 2)
	_assert("河流明确禁用碎裂噪声", profile.get("fracture_noise", true) == false)
	_assert("河流支持减少动态效果", profile.get("reduced_motion_supported", false) == true)
	map.free()
	var original_reduce_motion := GameSettings.reduce_motion
	GameSettings.reduce_motion = true
	var calm_map := CityMapScript.new() as Node3D
	calm_map.call("_make_west_river_surface")
	var calm_surface := calm_map.get_node("WestRiverSurface") as MeshInstance3D
	var calm_material := calm_surface.material_override as ShaderMaterial
	_assert("减少动态效果会停止河流 UV 移动", is_equal_approx(float(calm_material.get_shader_parameter("flow_strength")), 0.0))
	calm_map.free()
	GameSettings.reduce_motion = original_reduce_motion


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  ", label)
	else:
		failed += 1
		push_error("FAIL  %s" % label)
