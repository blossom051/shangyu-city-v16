class_name VisualAssetManager
extends Node

const MAP_PATHS: = {
	"buildings": "res://data/visual_maps/building_visual_map.json", 
	"ui": "res://data/visual_maps/ui_skin_map.json", 
	"cards": "res://data/visual_maps/card_visual_map.json", 
	"portraits": "res://data/visual_maps/talent_portrait_map.json", 
	"icons": "res://data/visual_maps/icon_map.json", 
	"audio": "res://data/visual_maps/audio_map.json"
}

var maps: Dictionary = {}
var missing_assets: Array[String] = []

func _ready() -> void :
	reload_maps()

func reload_maps() -> void :
	maps.clear()
	missing_assets.clear()
	for key: String in MAP_PATHS:
		maps[key] = _read_json(MAP_PATHS[key])
	print("[VisualAssetManager] loaded %d visual maps; missing external assets use fallback" % maps.size())

func get_building_visual(business_type: String) -> Dictionary:
	var entry: Dictionary = maps.get("buildings", {}).get(business_type, {}).duplicate(true)
	if entry.is_empty():
		_note_missing("building mapping: " + business_type)
		return {}
	entry["uses_external"] = has_external_asset(str(entry.get("model_path", "")))
	entry["resolved_path"] = str(entry.model_path) if entry.uses_external else str(entry.get("fallback_scene", ""))
	if not entry.uses_external:
		_note_missing(str(entry.get("model_path", "")))
	return entry

func get_building_scene(business_type: String) -> PackedScene:
	var visual: = get_building_visual(business_type)
	return _load_scene(str(visual.get("resolved_path", "")))

func instantiate_building(business_type: String) -> Node3D:
	var visual: = get_building_visual(business_type)
	var scene: = _load_scene(str(visual.get("resolved_path", "")))
	if scene == null:
		return null
	var node: = scene.instantiate() as Node3D
	if node == null:
		return null
	var transform_data: Dictionary = visual.get("transform", {})
	var p: Array = transform_data.get("position", [0, 0.2, -0.15])
	var s: Array = transform_data.get("scale", [1, 1, 1])
	node.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	node.scale = Vector3(float(s[0]), float(s[1]), float(s[2]))
	node.rotation_degrees.y = float(transform_data.get("rotation_y", 0.0))
	node.set_meta("visual_source", "external" if bool(visual.get("uses_external", false)) else "fallback")
	return node

func get_ui_skin(key: String = "default") -> Dictionary:
	var entry: Dictionary = maps.get("ui", {}).get(key, {}).duplicate(true)
	entry["fallback_theme_resource"] = _load_resource(str(entry.get("fallback_theme", "")))
	for field in ["panel_bg", "window_bg", "button_normal", "button_hover", "button_pressed", "button_disabled", "hud_bg"]:
		entry[field + "_resource"] = _load_texture(str(entry.get(field, "")))
	return entry

func get_card_visual(card_type: String) -> Dictionary:
	var entry: Dictionary = maps.get("cards", {}).get(card_type, maps.get("cards", {}).get("special", {})).duplicate(true)
	entry["frame_texture"] = _load_texture(str(entry.get("frame", "")))
	entry["background_texture"] = _load_texture(str(entry.get("background", "")))
	entry["icon_texture"] = _load_texture(str(entry.get("icon", "")))
	return entry

func get_talent_portrait(rarity: String, talent_id: String = "") -> Texture2D:
	var canonical: = _canonical_rarity(rarity)
	var entry: Dictionary = maps.get("portraits", {}).get(canonical, {})
	if not talent_id.is_empty():
		var direct: = "res://assets/Portraits/%s/%s.png" % [canonical, talent_id]
		if has_external_asset(direct):
			return load(direct) as Texture2D
		# A default portrait may itself be a contact sheet. Returning that entire
		# sheet for one talent produced the reported "group portrait" on red cards.
		# Let the caller crop the canonical 5 x 4 talent atlas instead.
		return null
	for path: String in entry.get("default_portraits", []):
		if has_external_asset(path):
			return load(path) as Texture2D
	var fallback: = str(entry.get("fallback_icon", ""))
	return load(fallback) as Texture2D if has_external_asset(fallback) else null

func get_icon(icon_key: String) -> Texture2D:
	return _load_texture(str(maps.get("icons", {}).get(icon_key, {}).get("path", "")))

func get_icon_fallback(icon_key: String) -> String:
	return str(maps.get("icons", {}).get(icon_key, {}).get("fallback", icon_key.left(1).to_upper()))

func get_audio_path(audio_key: String) -> String:
	var entry: Dictionary = maps.get("audio", {}).get(audio_key, {})
	var external: = str(entry.get("path", ""))
	if has_external_asset(external): return external
	return str(entry.get("fallback", "")) if has_external_asset(str(entry.get("fallback", ""))) else ""

func has_external_asset(path: String) -> bool:
	return not path.is_empty() and ResourceLoader.exists(path)

func get_missing_asset_report() -> Array:
	return missing_assets.duplicate()

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_note_missing(path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary: return parsed
	push_warning("[VisualAssetManager] invalid JSON: " + path)
	return {}

func _load_scene(path: String) -> PackedScene:
	var resource: = _load_resource(path)
	return resource as PackedScene

func _load_texture(path: String) -> Texture2D:
	var resource: = _load_resource(path)
	return resource as Texture2D

func _load_resource(path: String) -> Resource:
	if not has_external_asset(path):
		_note_missing(path)
		return null
	return load(path)

func _canonical_rarity(value: String) -> String:
	for rarity: String in maps.get("portraits", {}):
		if value == rarity or value in maps.portraits[rarity].get("aliases", []): return rarity
	return "common"

func _note_missing(path: String) -> void :
	if path.is_empty() or path in missing_assets: return
	missing_assets.append(path)
	print("[VisualAssetManager][fallback] missing: " + path)
