class_name CardArtRegistry
extends RefCounted

const LEGACY_ATLAS = preload("res://assets/Cards/v96/strategy_art_atlas.png")
const GILDED_SELF_ATLAS = preload("res://assets/images/v12/collection/gilded_self_atlas.png")
const GILDED_RIVAL_ATLAS = preload("res://assets/images/v12/collection/gilded_rival_atlas.png")
const ATLAS_PATHS: = [
	"res://assets/images/v12/cards/capital_conflict_atlas.png", 
	"res://assets/images/v12/cards/capital_defense_atlas.png", 
	"res://assets/images/v12/cards/capital_operations_atlas.png", 
	"res://assets/images/v12/cards/capital_finance_atlas.png", 
	"res://assets/images/v12/cards/capital_city_atlas.png", 
	"res://assets/images/v12/cards/capital_trump_atlas.png", 
]
static var _resolved_cache: Dictionary = {}


static func composition_count() -> int:
	return 36


static func resolve(card: Dictionary) -> Dictionary:
	var key: = str(card.get("art_key", "capital_art_01"))
	if _resolved_cache.has(key):
		return _resolved_cache[key]
	if key.begins_with("west_bank_art_"):
		var west_number := clampi(int(card.get("catalog_no", int(key.trim_prefix("west_bank_art_")))), 1, 42)
		var west_path := "res://assets/ui/west_bank/cards/v101_ai/west_bank_ai_%03d.png" % west_number
		if ResourceLoader.exists(west_path):
			var west_render := ResourceLoader.load(west_path) as Texture2D
			var render_result := {
				"key": key,
				"texture": west_render,
				"display_texture": west_render,
				"region": Rect2(Vector2.ZERO, Vector2(west_render.get_width(), west_render.get_height())),
				"fallback": false,
				"series": "west_bank",
				"source": "ai_generated_v101_ue58_fx" if west_number <= 3 else "ai_generated_v101",
			}
			_resolved_cache[key] = render_result
			return render_result
		push_error("Missing West Bank AI card art: %s" % west_path)
		var west_result := {
			"key": key,
			"texture": LEGACY_ATLAS,
			"display_texture": LEGACY_ATLAS,
			"region": Rect2(Vector2.ZERO, Vector2(LEGACY_ATLAS.get_width(), LEGACY_ATLAS.get_height())),
			"fallback": true,
			"series": "west_bank",
			"source": "missing_asset",
		}
		_resolved_cache[key] = west_result
		return west_result
	if key.begins_with("gilded_art_"):
		var gilded_number: = clampi(int(key.trim_prefix("gilded_art_")), 1, 6)
		var gilded_atlas: Texture2D = GILDED_SELF_ATLAS if gilded_number <= 3 else GILDED_RIVAL_ATLAS
		var gilded_index: = (gilded_number - 1) % 3
		var gilded_region: = Rect2(float(gilded_index) * float(gilded_atlas.get_width()) / 3.0, 0.0, float(gilded_atlas.get_width()) / 3.0, float(gilded_atlas.get_height()))
		var gilded_texture: = AtlasTexture.new()
		gilded_texture.atlas = gilded_atlas
		gilded_texture.region = gilded_region
		var gilded_result: = {"key": key, "texture": gilded_atlas, "display_texture": gilded_texture, "region": gilded_region, "fallback": false}
		_resolved_cache[key] = gilded_result
		return gilded_result
	var number: = clampi(int(key.trim_prefix("capital_art_")), 1, composition_count())
	var atlas_index: = int((number - 1) / 6)
	var cell_index: = (number - 1) % 6
	var path: String = ATLAS_PATHS[atlas_index]
	var texture: Texture2D = ResourceLoader.load(path) as Texture2D if ResourceLoader.exists(path) else LEGACY_ATLAS
	if texture == null:
		texture = LEGACY_ATLAS
	var columns: = 3
	var rows: = 2
	var cell_width: = float(texture.get_width()) / float(columns)
	var cell_height: = float(texture.get_height()) / float(rows)
	var region: = Rect2(float(cell_index % columns) * cell_width, float(cell_index / columns) * cell_height, cell_width, cell_height)
	var display_texture: = AtlasTexture.new()
	display_texture.atlas = texture
	display_texture.region = region
	var result: = {
		"key": key, 
		"texture": texture, 
		"display_texture": display_texture, 
		"region": region, 
		"fallback": not ResourceLoader.exists(path), 
	}
	_resolved_cache[key] = result
	return result
