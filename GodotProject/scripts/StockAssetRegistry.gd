class_name StockAssetRegistry
extends RefCounted

const ICON_PATHS: = {
	"consumer": "res://assets/images/v13/stock_icons/consumer.png", 
	"technology": "res://assets/images/v13/stock_icons/technology.png", 
	"property": "res://assets/images/v13/stock_icons/real_estate.png", 
	"medical": "res://assets/images/v13/stock_icons/healthcare.png", 
	"logistics": "res://assets/images/v13/stock_icons/logistics.png", 
	"entertainment": "res://assets/images/v13/stock_icons/entertainment.png", 
	"finance": "res://assets/images/v13/stock_icons/finance.png", 
	"energy": "res://assets/images/v13/stock_icons/energy.png", 
}

static var _icon_cache: Dictionary = {}


static func icon_path(stock_id: String) -> String:
	return str(ICON_PATHS.get(stock_id, ICON_PATHS.consumer))


static func icon(stock_id: String) -> Texture2D:
	var resolved_id: = stock_id if ICON_PATHS.has(stock_id) else "consumer"
	if _icon_cache.has(resolved_id):
		return _icon_cache[resolved_id] as Texture2D
	var source: = load(icon_path(resolved_id)) as Texture2D
	if source == null:
		return null




	var image: = source.get_image()
	if image == null or image.is_empty():
		return null
	image.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	var ui_texture: = ImageTexture.create_from_image(image)
	_icon_cache[resolved_id] = ui_texture
	return ui_texture


static func clear_cache() -> void :
	_icon_cache.clear()
