class_name CapitalReactionWindow
extends Control

signal resolved(card_id: String)

const Styles = preload("res://scripts/UIStyles.gd")
var completed: = false


func open(data: Dictionary) -> void :
	name = "CapitalReactionWindow"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


	z_index = 4090
	var veil: = ColorRect.new();veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);veil.color = Color(0.005, 0.015, 0.03, 0.84);add_child(veil)
	var board: = PanelContainer.new();board.set_anchors_and_offsets_preset(Control.PRESET_CENTER);board.position = Vector2(-510, -310);board.size = Vector2(1020, 620);board.add_theme_stylebox_override("panel", Styles.panel(Color(0.015, 0.055, 0.085, 0.985), Color("9a73df"), 28, 3));add_child(board)
	var layout: = VBoxContainer.new();layout.add_theme_constant_override("separation", 16);board.add_child(layout)
	var kicker: = Label.new();kicker.text = "CAPITAL CHAIN RESPONSE  资本连锁响应";kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;kicker.add_theme_font_size_override("font_size", 16);kicker.add_theme_color_override("font_color", Color("b89bea"));layout.add_child(kicker)
	var title: = Label.new();title.text = "%s 发动《%s》" % [str(data.get("actor_name", "对手财团")), str(data.get("attack_name", "策略攻击"))];title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size", 30);title.add_theme_color_override("font_color", Color("f1d27a"));layout.add_child(title)
	var chain: = Label.new();chain.text = "CHAIN 1  %s   →   CHAIN 2  选择一张董事会秘策" % str(data.get("attack_name", "攻击牌"));chain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;chain.add_theme_font_size_override("font_size", 18);chain.add_theme_color_override("font_color", Color("d8e5e8"));layout.add_child(chain)
	var options: = HBoxContainer.new();options.alignment = BoxContainer.ALIGNMENT_CENTER;options.add_theme_constant_override("separation", 18);options.size_flags_vertical = Control.SIZE_EXPAND_FILL;layout.add_child(options)
	for option: Dictionary in data.get("options", []):
		var card: = Button.new();card.custom_minimum_size = Vector2(250, 270);card.text = "秘策背面揭晓\n\n%s\n\n%s\n\n发动  %s" % [str(option.name), str(option.description), " / ".join(option.get("keywords", []))];card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;card.add_theme_font_size_override("font_size", 18);Styles.apply_toy_button(card, false, Color("9a73df"), 18);card.pressed.connect(_finish.bind(str(option.id)));options.add_child(card)
	var keep: = Button.new();keep.text = "保留秘策  承受本次攻击";keep.custom_minimum_size = Vector2(360, 56);Styles.apply_toy_button(keep, false, Color("5c7c86"), 17);keep.pressed.connect(_finish.bind(""));layout.add_child(keep)
	if not _reduced_motion():
		board.scale = Vector2(0.88, 0.88);board.pivot_offset = board.size * 0.5;create_tween().tween_property(board, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _finish(card_id: String) -> void :
	if completed: return
	completed = true
	resolved.emit(card_id)
	queue_free()


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel"): get_viewport().set_input_as_handled()


func _reduced_motion() -> bool:
	var settings: Node = Engine.get_main_loop().root.get_node_or_null("GameSettings")
	return bool(settings.get("reduce_motion")) if settings != null else false
