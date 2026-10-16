class_name TalentCardView
extends PanelContainer

const UIStyles = preload("res://scripts/UIStyles.gd")
const PORTRAIT_ATLAS = preload("res://assets/ui/talents/talent_portrait_atlas.png")

signal resolved(talent_id: String, keep: bool, source_view: Control)
signal choice_selected(talent_id: String)
signal showcase_requested(view: Control)

var talent: Dictionary = {}
var revealed: = false
var choice_mode: = false
var swapping: = false


func setup(value: Dictionary) -> void :
	talent = value

	custom_minimum_size = Vector2(278, 429)
	pivot_offset = custom_minimum_size * 0.5
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	$Body / Back.custom_minimum_size = Vector2(244, 325)
	$Body / Back.setup(str(talent.quality))
	$Body / Actions / Keep.text = "保留招募"
	$Body / Actions / Convert.text = "转化"
	$Body / Back.pressed.connect(_reveal)
	$Body / Actions / Keep.pressed.connect(_keep)
	$Body / Actions / Convert.pressed.connect(_convert)
	$Body / Front.visible = false
	$Body / Actions.visible = false
	var color: = _quality_color(str(talent.quality))
	add_theme_stylebox_override("panel", _quality_frame(color))
	tooltip_text = "%s  %s\n%s\n适合安排到%s" % [talent.name, talent.role, talent.effect, _industry_hint(str(talent.get("stat", "")))]
	_style_button($Body / Actions / Keep, color)
	_style_button($Body / Actions / Convert, color)
	_style_front_text()


func setup_choice(value: Dictionary) -> void :
	choice_mode = true
	setup(value)
	$Body / Actions / Keep.text = "选择这位人才"
	$Body / Actions / Convert.visible = false


func presentation_profile() -> Dictionary:
	var quality: = str(talent.get("quality", "blue"))
	return {
		"quality": quality, 
		"center_showcase": quality == "red", 
		"glow_rings": 3 if quality == "red" else 1 if quality in ["gold", "platinum"] else 0, 
		"accent": _quality_color(quality), 
	}


func show_front_immediately() -> void :
	swapping = false
	_show_front(false)


func _reveal() -> void :
	if revealed or swapping:
		return
	swapping = true
	if GameSettings.reduce_motion:
		_show_front()
		swapping = false
		return
	var tween: = create_tween()
	$Body / Back.pivot_offset = $Body / Back.size * 0.5
	tween.tween_property($Body / Back, "scale:x", 0.04, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_show_front_animated)
	tween.tween_property($Body / Front, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback( func() -> void : swapping = false)


func reveal_with_delay(delay: float) -> void :
	if delay > 0.0:
		await _owned_delay(delay)
	if not GameSettings.reduce_motion:
		modulate.a = 0.0
		scale = Vector2(0.84, 0.84)
		var entrance: = create_tween().set_parallel(true)
		entrance.tween_property(self, "modulate:a", 1.0, 0.18)
		entrance.tween_property(self, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await entrance.finished
		await _owned_delay(0.08)
	_reveal()


func _owned_delay(seconds: float) -> void :
	var timer: = Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(0.001, seconds)
	add_child(timer)
	timer.start()
	await timer.timeout
	if is_instance_valid(timer):
		timer.queue_free()


func _show_front(request_showcase: = true) -> void :
	revealed = true
	$Body / Back.visible = false
	$Body / Front.visible = true
	$Body / Actions.visible = true
	$Body / Front / Portrait.texture = _portrait_texture(str(talent.id))
	$Body / Front / Name.text = str(talent.name)
	$Body / Front / Quality.text = "%s  %s  招募费已含" % [_quality_name(str(talent.quality)), talent.role]
	$Body / Front / Effect.text = "%s\n适用：%s" % [str(talent.effect), _industry_hint(str(talent.get("stat", "")))]
	AudioManager.talent_flip()
	if str(talent.quality) == "red":
		AudioManager.red_talent()
	_play_quality_burst(str(talent.quality))
	if request_showcase and str(talent.quality) == "red" and not choice_mode:
		call_deferred("_request_red_showcase")


func _show_front_animated() -> void :
	$Body / Front.scale.x = 0.04
	$Body / Front.pivot_offset = $Body / Front.size * 0.5
	_show_front()


func _request_red_showcase() -> void :
	showcase_requested.emit(self)


func _make_custom_tooltip(for_text: String) -> Object:
	var panel: = PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 118)
	var style: = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.07, 0.1, 0.985)
	style.border_color = _quality_color(str(talent.get("quality", "blue")))
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	var label: = Label.new()
	label.text = for_text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("edf4f5"))
	panel.add_child(label)
	return panel


func _lock(text: String) -> void :
	$Body / Actions / Keep.disabled = true
	$Body / Actions / Convert.disabled = true
	$Body / Actions / Keep.text = text


func apply_resolution_result(result: Dictionary, keep: bool) -> void :
	if bool(result.get("ok", false)):
		_lock("已保留" if keep else "已转化")
		return
	$Body / Actions / Keep.disabled = false
	$Body / Actions / Convert.disabled = false
	$Body / Actions / Keep.text = "释放名额后再招募" if str(result.get("code", "")) == "capacity_full" else "保留招募"


func _keep() -> void :
	if choice_mode:
		choice_selected.emit(str(talent.id))
		_lock("已选择")
	else:
		resolved.emit(str(talent.id), true, self)


func _convert() -> void :
	resolved.emit(str(talent.id), false, self)


func _style_button(button: Button, color: Color) -> void :
	UIStyles.apply_toy_button(button, false, color.lightened(0.18), 16)
	button.mouse_entered.connect(AudioManager.hover)


func _style_front_text() -> void :
	for label in [$Body / Front / Name, $Body / Front / Quality, $Body / Front / Effect]:
		label.add_theme_color_override("font_color", Color("18262d"))
		label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 0.26))
		label.add_theme_constant_override("outline_size", 1)


func _portrait_texture(talent_id: String) -> Texture2D:
	var external: = VisualAssets.get_talent_portrait(str(talent.get("quality", "blue")), talent_id)
	if external:
		return external
	var index: = clampi(int(talent_id.trim_prefix("t")) - 1, 0, 19)
	var columns: = 5
	var rows: = 4
	var cell_width: = float(PORTRAIT_ATLAS.get_width()) / float(columns)
	var cell_height: = float(PORTRAIT_ATLAS.get_height()) / float(rows)
	var atlas: = AtlasTexture.new()
	atlas.atlas = PORTRAIT_ATLAS
	atlas.region = Rect2(
		float(index % columns) * cell_width, 
		float(index / columns) * cell_height, 
		cell_width, 
		cell_height
	)
	return atlas


func _play_quality_burst(quality: String) -> void :
	var glow: = Panel.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var color: = _quality_color(quality)
	var strength: float = float({"blue": 0.12, "platinum": 0.18, "gold": 0.28, "red": 0.38}.get(quality, 0.12))
	var frame: = StyleBoxFlat.new()
	frame.bg_color = Color(color, strength * 0.22)
	frame.border_color = Color(color, minf(0.96, strength + 0.42))
	frame.set_border_width_all(4 if quality in ["gold", "red"] else 2)
	frame.set_corner_radius_all(16)
	glow.add_theme_stylebox_override("panel", frame)
	glow.modulate = Color.WHITE
	add_child(glow)
	move_child(glow, 0)
	var tween: = create_tween()
	tween.set_parallel(true)
	tween.tween_property(glow, "modulate:a", 0.0, 0.46 if quality in ["blue", "platinum"] else 0.7)
	tween.tween_property(glow, "scale", Vector2(1.035, 1.035) if quality in ["blue", "platinum"] else Vector2(1.075, 1.075), 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Callable(glow, "queue_free")).set_delay(0.72)


func _quality_frame(color: Color) -> StyleBoxFlat:
	var frame: = StyleBoxFlat.new()
	frame.bg_color = Color("e8e0cf")
	frame.border_color = color
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(15)
	frame.shadow_color = Color(0, 0, 0, 0.34)
	frame.shadow_size = 10
	frame.content_margin_left = 10
	frame.content_margin_right = 10
	frame.content_margin_top = 10
	frame.content_margin_bottom = 10
	return frame


func _quality_color(value: String) -> Color:
	return {"blue": Color("4b8fbd"), "platinum": Color("a7b8bd"), "gold": Color("e6b94d"), "red": Color("e0524d")}.get(value, Color.WHITE)


func _quality_fill(value: String) -> Color:
	return {
		"blue": Color(0.05, 0.12, 0.18, 0.98), 
		"platinum": Color(0.1, 0.13, 0.15, 0.98), 
		"gold": Color(0.17, 0.13, 0.04, 0.98), 
		"red": Color(0.18, 0.05, 0.045, 0.98)
	}.get(value, UIStyles.TOY_CREAM)


func _quality_name(value: String) -> String:
	return {"blue": "蓝色", "platinum": "铂金", "gold": "金色", "red": "红色"}.get(value, value)


func _industry_hint(stat: String) -> String:
	return {
		"income": "消费、文娱与高收入企业", "cost": "固定成本较高的企业", "build": "在建项目", "risk": "高风险商圈", 
		"interest": "银行融资", "supply": "物流、商超与供应链", "pr": "客诉敏感企业", "invest": "证券与创投", 
		"guard": "核心企业防守", "guard_once": "核心企业防守", "spy": "竞争与扰动策略", 
	}.get(stat, "匹配岗位的经营企业")


func _back_mark(value: String) -> String:
	return {"blue": "蓝", "platinum": "铂", "gold": "金", "red": "红"}.get(value, "才")
