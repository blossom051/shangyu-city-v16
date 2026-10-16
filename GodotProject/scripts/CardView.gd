class_name CardView
extends Button

const Visual = preload("res://scripts/CardVisualLanguage.gd")
const Taxonomy = preload("res://scripts/CardTaxonomy.gd")
const GildedReflection = preload("res://scripts/GildedMetalReflection.gd")

var card_id: = ""
var data: Dictionary = {}
var selected: = false
var hovered: = false
var pulse: = 0.0
var gilded_reflection: GildedMetalReflection
var advanced_fx: TextureRect


func setup(value: Dictionary) -> void :
	data = value
	card_id = str(value.get("id", ""))
	text = ""
	toggle_mode = false
	custom_minimum_size = Vector2(220, 316)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pivot_offset = custom_minimum_size * 0.5
	tooltip_text = help_text()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	if not mouse_entered.is_connected(_hover.bind(true)):
		mouse_entered.connect(_hover.bind(true))
		mouse_exited.connect(_hover.bind(false))
	_configure_gilded_reflection()
	_configure_advanced_fx()
	queue_redraw()


func set_selected_state(value: bool, animate: = true) -> void :
	selected = value
	z_index = 20 if value else 10 if hovered else 0
	var target: = Vector2(1.035, 1.035) if value else Vector2(1.018, 1.018) if hovered else Vector2.ONE
	if animate and not GameSettings.reduce_motion:
		_pose(target)
	else:
		scale = target
	if gilded_reflection != null:
		gilded_reflection.set_state(hovered, selected)
	queue_redraw()


func detail_text() -> String:
	return "%s  %s  %s" % [Taxonomy.family_name(data), Taxonomy.effect_tier_name(data), Visual.effect_name(data)]


func help_text() -> String:
	return "%s\n类型　%s  %s\n用途　%s\n目标　%s\n使用时机　%s" % [
		str(data.get("name", "策略卡")), 
		Taxonomy.family_name(data), 
		Taxonomy.effect_tier_name(data), 
		Visual.effect_name(data), 
		_target_name(str(data.get("target", "self"))), 
		_timing_name()
	]


func selection_color() -> Color:
	return Visual.type_color(str(data.get("type", "operation")))


func layout_regions() -> Dictionary:
	return Visual.layout_regions(size)


func selection_glow_layers() -> int:
	return 3 if str(data.get("rarity", "")) == "west_bank_advanced" else 1


func _make_custom_tooltip(for_text: String) -> Object:
	var panel: = PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 142)
	var box: = StyleBoxFlat.new()
	box.bg_color = Color(0.025, 0.075, 0.105, 0.985)
	box.border_color = Color(selection_color(), 0.92)
	box.set_border_width_all(2)
	box.set_corner_radius_all(12)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", box)
	var label: = Label.new()
	label.text = for_text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("edf4f5"))
	label.add_theme_constant_override("line_spacing", 5)
	panel.add_child(label)
	return panel


func play_burst() -> Tween:
	z_index = 100
	var target: = get_viewport_rect().size * 0.5 - size * 0.5
	var tween: = create_tween().set_parallel(true)
	var duration: = 0.12 if GameSettings.reduce_motion else 0.3
	tween.tween_property(self, "global_position", target, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.16, 1.16), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", 0.0, duration)
	tween.tween_property(self, "modulate:a", 0.0, 0.28 if GameSettings.reduce_motion else 0.42).set_delay(duration)
	return tween


func play_unavailable_feedback() -> void :
	if GameSettings.reduce_motion:
		modulate = Color("e98678")
		create_tween().tween_property(self, "modulate", Color.WHITE, 0.16)
		return
	var x: = position.x
	var tween: = create_tween()
	tween.tween_property(self, "position:x", x - 9, 0.05)
	tween.tween_property(self, "position:x", x + 8, 0.06)
	tween.tween_property(self, "position:x", x, 0.07)
	tween.parallel().tween_property(self, "modulate", Color("e98678"), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)


func _process(delta: float) -> void :
	var advanced := str(data.get("rarity", "")) == "west_bank_advanced"
	if (selected or advanced) and not GameSettings.reduce_motion:
		pulse += delta
		queue_redraw()
	if advanced_fx != null:
		var art_rect: Rect2 = layout_regions().art.grow(-3)
		advanced_fx.position = art_rect.position
		advanced_fx.size = art_rect.size
		advanced_fx.self_modulate = Color(1.0, 0.84 + sin(pulse * 1.9) * 0.12, 1.0, 0.18 + (sin(pulse * 2.4) + 1.0) * 0.09)


func _hover(value: bool) -> void :
	hovered = value
	if value:
		AudioManager.hover()
	z_index = 20 if selected else 10 if value else 0
	var target: = Vector2(1.08, 1.08) if selected else Vector2(1.035, 1.035) if value else Vector2.ONE
	if GameSettings.reduce_motion:
		scale = target
	else:
		_pose(target)
	if gilded_reflection != null:
		gilded_reflection.set_state(hovered, selected)
	queue_redraw()


func _configure_gilded_reflection() -> void :
	var is_gilded: = str(data.get("rarity", "")) == "gilded"
	if not is_gilded:
		if gilded_reflection != null:
			gilded_reflection.queue_free()
			gilded_reflection = null
		return
	if gilded_reflection == null:
		gilded_reflection = GildedReflection.new()
		add_child(gilded_reflection)
	gilded_reflection.setup(card_id)
	gilded_reflection.set_state(hovered, selected)


func _configure_advanced_fx() -> void:
	var is_advanced := str(data.get("rarity", "")) == "west_bank_advanced"
	if not is_advanced:
		if advanced_fx != null:
			advanced_fx.queue_free()
			advanced_fx = null
		return
	var catalog_no := clampi(int(data.get("catalog_no", 1)), 1, 3)
	var path := "res://assets/ui/west_bank/cards/v101_ue58_fx/west_bank_advanced_fx_%03d.png" % catalog_no
	if not ResourceLoader.exists(path):
		push_error("Missing UE 5.8 advanced card FX: %s" % path)
		return
	if advanced_fx == null:
		advanced_fx = TextureRect.new()
		advanced_fx.name = "UE58AdvancedCardFX"
		advanced_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		advanced_fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		advanced_fx.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		advanced_fx.z_index = 4
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		advanced_fx.material = additive
		add_child(advanced_fx)
	advanced_fx.texture = ResourceLoader.load(path) as Texture2D


func _pose(target: Vector2) -> void :
	var tween: = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", target, 0.14)


func _target_name(target: String) -> String:
	return {
		"self": "自己", 
		"own_business": "己方企业", 
		"own_construction": "己方在建项目", 
		"enemy": "一名对手", 
		"enemy_business": "对手企业", 
		"enemy_construction": "对手在建项目", 
		"stock": "一个证券标的", 
		"district": "一个城市商圈"
	}.get(target, "当前合法目标")


func _timing_name() -> String:
	var duration: = int(data.get("duration", 0))
	var type: = str(data.get("type", "operation"))
	if type in ["defense", "counter"]:
		return "部署后受袭时自动触发"
	if type == "attack":
		return "对手暴露弱点时"
	if duration > 0:
		return "效果持续 %d 回合" % duration
	return "行动阶段可立即使用"


func _draw() -> void :
	Visual.draw_face(self, size, data, selected, pulse)
