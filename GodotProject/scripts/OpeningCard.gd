class_name OpeningCard
extends Button
const Visual = preload("res://scripts/CardVisualLanguage.gd")
const RareRevealFX = preload("res://scripts/RareCardRevealFX.gd")
const DISPLAY_FONT: Font = preload("res://Themes/V9141DisplayFont.tres")
const BODY_FONT: Font = preload("res://Themes/V9141BodyMediumFont.tres")
var selected: = false
var revealed: = false
var face: Dictionary = {}
var seed_tint: = 0
var phase: = 0.0
var premium: = false
var west_bank: = false
var rare_fx_played: = false
func setup(card_seed: int, is_premium: = false, is_west_bank: = false) -> void : seed_tint = card_seed;premium = is_premium;west_bank = is_west_bank;text = "";flat = true;focus_mode = Control.FOCUS_ALL;custom_minimum_size = Vector2(210, 300);size_flags_horizontal = Control.SIZE_SHRINK_CENTER;size_flags_vertical = Control.SIZE_SHRINK_CENTER;pivot_offset = custom_minimum_size * 0.5;tooltip_text = "西岸金融核心区专属策略" if west_bank else "云杉基金专属  已锁定红色王牌卡" if premium else "未知策略卡";queue_redraw()
func set_selected(value: bool) -> void :
	selected = value;z_index = 10 if value else 4 if premium else 0
	if GameSettings.reduce_motion:
		scale = Vector2(1.025, 1.025) if value else Vector2.ONE
		rotation = 0.0
		queue_redraw()
		return
	var tween: = create_tween().set_parallel(true);tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.025, 1.025) if value else Vector2.ONE, 0.18)
	tween.tween_property(self, "rotation", deg_to_rad(-1.0) if value else 0.0, 0.18)
	queue_redraw()
func reveal(value: Dictionary) -> void :
	face = value
	if GameSettings.reduce_motion:
		revealed = true
		scale = Vector2.ONE
		rotation = 0.0
		queue_redraw()
		AudioManager.card_flip()
		_play_rare_reveal_if_needed()
		return
	var tween: = create_tween();tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale:x", 0.04, 0.16)
	tween.parallel().tween_property(self, "rotation", deg_to_rad(2.2), 0.16)
	tween.tween_callback( func() -> void : revealed = true;queue_redraw();AudioManager.card_flip())
	tween.tween_property(self, "scale:x", 1.04, 0.2)
	tween.parallel().tween_property(self, "rotation", 0.0, 0.2)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	_play_rare_reveal_if_needed()

func _play_rare_reveal_if_needed() -> void :
	if rare_fx_played or str(face.get("rarity", "")) != "gilded" or get_tree() == null:
		return
	rare_fx_played = true
	var layer: = CanvasLayer.new()
	layer.name = "RareCardRevealLayer"
	layer.layer = 2400
	get_tree().root.add_child(layer)
	var fx: = RareRevealFX.new()
	layer.add_child(fx)
	fx.finished.connect(layer.queue_free)
	fx.play_rect(get_global_rect(), 1.18, 1.42)
	AudioManager.red_talent()
func _process(delta: float) -> void :
	if selected or premium: phase += delta;queue_redraw()
func _draw() -> void :
	if premium:
		var breathe: = 0.58 + sin(phase * 2.1) * 0.18
		var aura: = StyleBoxFlat.new();aura.bg_color = Color.TRANSPARENT;aura.border_color = Color(1.0, 0.18, 0.24, 0.34 * breathe);aura.set_border_width_all(6);aura.set_corner_radius_all(25);aura.shadow_color = Color(0.95, 0.02, 0.08, 0.18 * breathe);aura.shadow_size = 6;draw_style_box(aura, Rect2(-7, -7, size.x + 14, size.y + 14))
	if revealed: Visual.draw_face(self, size, face, selected, phase)
	elif west_bank: Visual.draw_west_bank_back(self, size, selected, phase)
	else: Visual.draw_back(self, size, selected, phase)
	if premium:
		var border: = StyleBoxFlat.new();border.bg_color = Color(0.34, 0.025, 0.045, 0.1);border.border_color = Color("ef5964");border.set_border_width_all(5 if not selected else 7);border.set_corner_radius_all(18);draw_style_box(border, Rect2(3, 3, size.x - 6, size.y - 6))
		var caption_box: = StyleBoxFlat.new();caption_box.bg_color = Color(0.09, 0.015, 0.025, 0.88);caption_box.border_color = Color("e8b95f");caption_box.set_border_width_all(1);caption_box.set_corner_radius_all(8);draw_style_box(caption_box, Rect2(22, 12, size.x - 44, 30))
		draw_string(BODY_FONT, Vector2(22, 33), "云杉专属  红色王牌", HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 44), 14, Color("ffe7a3"))
	if selected:
		var selected_box: = StyleBoxFlat.new();selected_box.bg_color = Color.TRANSPARENT;selected_box.border_color = Color("e7c66f") if not premium else Color("ef826d");selected_box.set_border_width_all(3);selected_box.set_corner_radius_all(21);selected_box.shadow_color = Color(selected_box.border_color, 0.16);selected_box.shadow_size = 4;draw_style_box(selected_box, Rect2(0, 0, size.x, size.y))

func debug_premium_profile() -> Dictionary:
	return {"premium": premium, "locked_caption": "财团优势  红色王牌", "red_visual": premium}
