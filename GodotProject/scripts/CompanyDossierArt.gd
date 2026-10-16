class_name CompanyDossierArt
extends Control

const FACTION_ATLAS = preload("res://assets/images/v12/faction_headquarters_atlas.png")
const ORDER: = ["hengyue", "xingchao", "qiming", "jinding", "wangang", "qinghe", "chiyan", "yunshan"]

var art: TextureRect
var shade: ColorRect
var title: Label


func _ready() -> void :
	clip_contents = true
	_build_hero()


func show_company(company: Dictionary) -> void :
	if art == null: _build_hero()
	var index: = maxi(0, ORDER.find(str(company.get("id", "hengyue"))))
	var atlas: = AtlasTexture.new()
	atlas.atlas = FACTION_ATLAS
	var cell: = Vector2(float(FACTION_ATLAS.get_width()) / 4.0, float(FACTION_ATLAS.get_height()) / 2.0)
	atlas.region = Rect2(Vector2(float(index % 4) * cell.x, float(index / 4) * cell.y), cell)
	art.texture = atlas
	var accent: = Color(str(company.get("color", "#56b9c8")))
	shade.color = Color(accent, 0.1)
	title.text = "等待财团入场" if company.is_empty() else "%s\n%s" % [str(company.get("name", "资本财团")), str(company.get("type", "资本阵营"))]
	if not _reduced_motion():


		art.modulate = Color.WHITE
		art.scale = Vector2(1.018, 1.018)
		var tween: = create_tween()
		tween.tween_property(art, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_QUAD)
	else:
		art.modulate = Color.WHITE


func _build_hero() -> void :
	if art != null: return
	art = TextureRect.new()
	art.name = "FactionHeadquartersHero"
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.modulate = Color.WHITE
	art.pivot_offset = size * 0.5
	add_child(art)
	shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.1, 0.7, 0.8, 0.05)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var bottom: = ColorRect.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -132
	bottom.color = Color(0.005, 0.02, 0.03, 0.72)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	title = Label.new()
	title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	title.offset_left = 32
	title.offset_top = -118
	title.offset_right = -24
	title.offset_bottom = -24
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Color("f3e7c7"))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 7)
	add_child(title)
	show_company({})


func _reduced_motion() -> bool:
	var settings: Node = Engine.get_main_loop().root.get_node_or_null("GameSettings")
	return bool(settings.get("reduce_motion")) if settings != null else false
