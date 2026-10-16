class_name RoundDecisionDialog
extends CanvasLayer

signal completed(result: Dictionary)

const Styles = preload("res://scripts/UIStyles.gd")
const Decisions = preload("res://scripts/RoundDecisionSystem.gd")
const OpeningFX = preload("res://scripts/EventOpeningFX.gd")

const EVENT_ART: = {
	"night_market_inspection": "res://assets/ui/events/v9188/night_market_inspection.png", 
	"supply_chain_choice": "res://assets/ui/events/v9188/supply_chain_choice.png", 
	"brand_public_opinion": "res://assets/ui/events/v9188/brand_public_opinion.png", 
	"talent_retention": "res://assets/ui/events/v9188/talent_retention.png", 
	"green_upgrade": "res://assets/ui/events/v9188/green_upgrade.png", 
}

const NAVY: = Color("071624")
const DEEP: = Color("0b2133")
const GLASS: = Color(0.025, 0.095, 0.15, 0.92)
const GOLD: = Color("d8ae52")
const GOLD_LIGHT: = Color("f1d681")
const CYAN: = Color("73c8d6")
const WHITE: = Color("edf3f2")
const MUTED: = Color("a9bcc2")
const RED: = Color("ef7777")
const GREEN: = Color("78d0a5")

var player_id: = ""
var offer: Dictionary = {}
var selected_index: = -1
var choice_buttons: Array[Button] = []
var confirm_button: Button
var message_label: Label
var result_receipt: PanelContainer
var receipt_title: Label
var receipt_detail: Label
var modal_token: = 0
var resolving: = false
var background_rect: TextureRect
var opening_fx: Control
var opening_tweens: Array[Tween] = []
var card_rest_positions: Dictionary = {}
var card_rest_modulates: Dictionary = {}
var opening_started: = false


func open_for_player(value: String) -> void :
	player_id = value
	offer = Decisions.pending(value)


func _ready() -> void :
	name = "RoundDecisionDialog"
	layer = 2100
	add_to_group("managed_modal_owner")
	_build()
	_prepare_opening()
	var surface: = get_node("Surface") as Control
	modal_token = ModalManager.open_modal("event_card", self, surface, self)
	tree_exiting.connect( func() -> void : ModalManager.close_modal(modal_token, "round_decision_closed"))
	call_deferred("_play_opening")


func readability_profile() -> Dictionary:
	return {
		"body_font_min": 18, 
		"decision_title_min": 22, 
		"layout": "briefing_choice_split", 
		"event_dossier": has_node("Surface/Safe/Layout/DecisionStage/EventDossier"), 
		"has_effect_receipt": has_node("Surface/ResultReceipt"), 
		"canvas_layer": layer, 
		"choice_count": choice_buttons.size(), 
		"event_art": str(EVENT_ART.get(str(offer.get("event_id", "")), "")), 
	}


func opening_profile() -> Dictionary:
	return {
		"background_push": background_rect != null, 
		"staggered_card_count": choice_buttons.size(), 
		"particle_sweep": opening_fx != null, 
		"input_during_opening": choice_buttons.all( func(button: Button) -> bool: return button.disabled == not _choice_affordable(offer.get("choices", [])[choice_buttons.find(button)])), 
		"reduce_motion": GameSettings.reduce_motion, 
		"started": opening_started, 
	}


func on_modal_force_close() -> void :
	queue_free()


func _exit_tree() -> void :
	for tween: Tween in opening_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	opening_tweens.clear()


func _build() -> void :
	var surface: = Control.new()
	surface.name = "Surface"
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(surface)

	var hero: = Control.new()
	hero.name = "Hero"
	hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(hero)
	background_rect = TextureRect.new()
	background_rect.name = "Background"
	background_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_rect.texture = load(str(EVENT_ART.get(str(offer.get("event_id", "")), EVENT_ART.night_market_inspection))) as Texture2D
	background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(background_rect)
	var atmosphere: = ColorRect.new()
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere.color = Color(0.005, 0.025, 0.045, 0.54)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(atmosphere)
	var lower_shade: = ColorRect.new()
	lower_shade.anchor_top = 0.3
	lower_shade.anchor_right = 1.0
	lower_shade.anchor_bottom = 1.0
	lower_shade.color = Color(0.008, 0.035, 0.06, 0.7)
	lower_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(lower_shade)
	opening_fx = OpeningFX.new()
	opening_fx.name = "OpeningFX"
	surface.add_child(opening_fx)

	var safe: = MarginContainer.new()
	safe.name = "Safe"
	var viewport_size: = get_viewport().get_visible_rect().size
	var content_size: = Vector2(minf(viewport_size.x - 36.0, 1840.0), minf(viewport_size.y - 24.0, 900.0))
	safe.set_anchors_preset(Control.PRESET_CENTER)
	safe.position = - content_size * 0.5
	safe.size = content_size
	for side in ["margin_left", "margin_right"]:
		safe.add_theme_constant_override(side, 32)
	for side in ["margin_top", "margin_bottom"]:
		safe.add_theme_constant_override(side, 18)
	surface.add_child(safe)
	var layout: = VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 14)
	safe.add_child(layout)
	_build_header(layout)
	var stage: = HBoxContainer.new()
	stage.name = "DecisionStage"
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_constant_override("separation", 20)
	layout.add_child(stage)
	_build_event_dossier(stage)
	var rail: = VBoxContainer.new()
	rail.name = "ChoiceRail"
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail.alignment = BoxContainer.ALIGNMENT_CENTER
	rail.add_theme_constant_override("separation", 12)
	rail.size_flags_stretch_ratio = 1.12
	stage.add_child(rail)
	_build_choices(rail)
	_build_footer(layout)
	_build_receipt(surface)


func _build_header(layout: VBoxContainer) -> void :
	var header: = PanelContainer.new()
	header.name = "EventHeader"
	header.custom_minimum_size = Vector2(0, 86)
	header.add_theme_stylebox_override("panel", _panel(Color(0.012, 0.06, 0.095, 0.88), Color(0.85, 0.68, 0.32, 0.72), 26, 20, 12))
	layout.add_child(header)
	var margin: = MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 26)
	for side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	header.add_child(margin)
	var stack: = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)
	var top: = HBoxContainer.new()
	stack.add_child(top)
	var kicker: = _label("第 %d 回合   %s" % [int(offer.get("round", 0)), str(offer.get("section", "城市经营"))], 13, GOLD_LIGHT, true)
	kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(kicker)
	var player: = GameState.player(player_id)
	var player_badge: = _label("当前决策  %s" % str(player.get("name", "本组财团")), 15, CYAN, true)
	player_badge.name = "CurrentPlayer"
	top.add_child(player_badge)
	var title: = _label(str(offer.get("title", "城市经营抉择")), 27, WHITE, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(title)


func _build_event_dossier(stage: HBoxContainer) -> void :
	var dossier: = PanelContainer.new()
	dossier.name = "EventDossier"
	dossier.custom_minimum_size = Vector2(500, 0)
	dossier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dossier.size_flags_stretch_ratio = 0.86
	dossier.add_theme_stylebox_override("panel", _panel(Color(0.012, 0.055, 0.082, 0.93), Color(0.38, 0.66, 0.72, 0.72), 24, 18, 16))
	stage.add_child(dossier)
	var stack: = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	dossier.add_child(stack)
	var art_frame: = PanelContainer.new()
	art_frame.custom_minimum_size = Vector2(0, 300)
	art_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_frame.add_theme_stylebox_override("panel", _panel(Color(0.01, 0.03, 0.05, 0.96), GOLD, 18, 3, 10))
	stack.add_child(art_frame)
	var art: = TextureRect.new()
	art.name = "EventArtwork"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = background_rect.texture
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_child(art)
	var brief: = _label(str(offer.get("brief", "选择本组的应对方案。")), 21, WHITE, true)
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.max_lines_visible = 2
	brief.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(brief)
	dossier.tooltip_text = "方案产生的资源变化会立即写入本轮经营账本"


func _build_choices(rail: VBoxContainer) -> void :
	var choices: Array = offer.get("choices", [])
	for index in choices.size():
		rail.add_child(_choice_card(index, choices[index]))


func _choice_card(index: int, choice: Dictionary) -> Button:
	var button: = Button.new()
	button.name = "Choice%d" % (index + 1)
	var viewport_height: = get_viewport().get_visible_rect().size.y
	var responsive_height: = 108.0 if viewport_height <= 768.0 else 118.0 if viewport_height <= 900.0 else 128.0
	button.custom_minimum_size = Vector2(0, responsive_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.flat = false
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = str(choice.get("detail", ""))
	button.add_to_group("modal_action_button")
	button.add_theme_stylebox_override("normal", _card_style(Color(0.018, 0.105, 0.15, 0.88), Color(0.34, 0.64, 0.7, 0.34), 3))
	button.add_theme_stylebox_override("hover", _card_style(Color(0.035, 0.16, 0.21, 0.99), GOLD, 13))
	button.add_theme_stylebox_override("pressed", _card_style(Color(0.055, 0.2, 0.26, 1.0), GOLD_LIGHT, 15))
	button.pressed.connect(_select.bind(index))

	var affordable: = _choice_affordable(choice)
	if not affordable:
		button.disabled = true
		button.modulate = Color(0.62, 0.66, 0.68, 0.82)
		button.tooltip_text = "可用现金不足\n%s" % str(choice.get("detail", ""))

	var body: = HBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 14
	body.offset_top = 10
	body.offset_right = -14
	body.offset_bottom = -10
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 13)
	button.add_child(body)
	body.add_child(_choice_emblem(index, choice))
	var center: = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 5)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(center)
	var title: = _label(str(choice.get("title", "方案")), 21, WHITE, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(title)
	center.add_child(_choice_resource_flow(choice))
	var impact: = VBoxContainer.new()
	impact.custom_minimum_size = Vector2(54, 0)
	impact.alignment = BoxContainer.ALIGNMENT_CENTER
	impact.add_theme_constant_override("separation", 8)
	impact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(impact)
	var footer_text: = "×" if not affordable else "›"
	var footer: = _label(footer_text, 24, RED if not affordable else GOLD_LIGHT, true)
	footer.name = "ChoiceAction"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.custom_minimum_size = Vector2(42, 42)
	footer.add_theme_stylebox_override("normal", _panel(Color("0b2633"), RED if not affordable else GOLD, 14, 2, 0))
	impact.add_child(footer)
	choice_buttons.append(button)
	return button


func _choice_emblem(index: int, choice: Dictionary) -> Control:
	var emblem: = Control.new()
	emblem.name = "EventChoiceEmblem"
	var compact: = get_viewport().get_visible_rect().size.y <= 768.0
	emblem.custom_minimum_size = Vector2(46, 46) if compact else Vector2(52, 52)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview: = str(choice.get("preview", ""))
	var negative: = preview.contains("风险+") or preview.contains("现金-")
	var accent: = RED if negative else GREEN if preview.contains("现金+") or preview.contains("风险-") else GOLD
	emblem.draw.connect( func() -> void :
		var c: = emblem.size * 0.5
		var outer_radius: = 21.0 if compact else 24.0
		var inner_radius: = 17.0 if compact else 20.0
		emblem.draw_circle(c, outer_radius, Color(accent, 0.15))
		emblem.draw_circle(c, inner_radius, Color(0.02, 0.085, 0.12, 0.96))
		emblem.draw_circle(c, inner_radius, accent, false, 2.5)
		var font: = ThemeDB.fallback_font
		emblem.draw_string(font, c + Vector2(-10, 7), "%02d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, 24, 18, GOLD_LIGHT)
	)
	emblem.queue_redraw()
	return emblem


func _choice_resource_flow(choice: Dictionary) -> Control:
	var flow: = HBoxContainer.new()
	flow.name = "DecisionResourceFlow"
	flow.custom_minimum_size = Vector2(0, 54)
	flow.add_theme_constant_override("separation", 8)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cash_delta: = int(choice.get("cash", 0))
	var risk_delta: = int(choice.get("risk", 0))
	var has_input: = cash_delta < 0
	if has_input:
		flow.add_child(_resource_badge("cash", "投入", "%d万" % abs(cash_delta), RED))
		flow.add_child(_flow_separator("→", GOLD_LIGHT))
	if cash_delta > 0:
		flow.add_child(_resource_badge("cash", "现金", "+%d万" % cash_delta, GREEN))
	if risk_delta != 0:
		if flow.get_child_count() > (2 if has_input else 0):
			flow.add_child(_flow_separator("→", Color(MUTED, 0.72)))
		flow.add_child(_resource_badge("risk", "风险", "%s%d" % ["↓" if risk_delta < 0 else "↑", abs(risk_delta)], GREEN if risk_delta < 0 else RED))
	var draw_count: = int(choice.get("draw", 0))
	if draw_count > 0:
		flow.add_child(_flow_separator("→", Color(MUTED, 0.72)))
		flow.add_child(_resource_badge("card", "策略牌", "×%d" % draw_count, GOLD_LIGHT))
	if choice.has("effect"):
		var effect: Dictionary = choice.get("effect", {})
		var bonus: = roundi((float(effect.get("value", 1.0)) - 1.0) * 100.0)
		var duration: = int(effect.get("duration", 0))
		flow.add_child(_flow_separator("→", Color(MUTED, 0.72)))
		flow.add_child(_resource_badge("growth", "经营", "+%d%% %d轮" % [bonus, duration], CYAN))
	return flow


func _resource_badge(kind: String, caption: String, value: String, tone: Color) -> PanelContainer:
	var badge: = PanelContainer.new()
	badge.custom_minimum_size = Vector2(118, 52)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _panel(Color(0.022, 0.115, 0.145, 0.35), Color(tone, 0.24), 11, 2, 0))
	badge.tooltip_text = "%s %s" % [caption, value]
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(row)
	var icon: = Control.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_resource_icon.bind(icon, kind, tone))
	row.add_child(icon)
	var texts: = VBoxContainer.new()
	texts.add_theme_constant_override("separation", -2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var caption_label: = _label(caption, 12, Color(MUTED, 0.9), true)
	texts.add_child(caption_label)
	var value_label: = _label(value, 18, tone, true)
	texts.add_child(value_label)
	return badge


func _flow_separator(value: String, color: Color) -> Label:
	var separator: = _label(value, 22, color, true)
	separator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	separator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	separator.custom_minimum_size = Vector2(24, 52)
	return separator


func _draw_resource_icon(icon: Control, kind: String, tone: Color) -> void :
	var center: = icon.size * 0.5
	match kind:
		"cash":
			icon.draw_rect(Rect2(center - Vector2(10, 6), Vector2(20, 12)), Color(tone, 0.18), true)
			icon.draw_rect(Rect2(center - Vector2(10, 6), Vector2(20, 12)), tone, false, 1.6)
			icon.draw_circle(center, 3.0, tone, false, 1.4)
			icon.draw_line(center - Vector2(7, 3), center - Vector2(7, -3), tone, 1.2)
			icon.draw_line(center + Vector2(7, -3), center + Vector2(7, 3), tone, 1.2)
		"risk":
			var shield: = PackedVector2Array([center + Vector2(0, -10), center + Vector2(8, -6), center + Vector2(7, 3), center + Vector2(0, 10), center + Vector2(-7, 3), center + Vector2(-8, -6)])
			icon.draw_colored_polygon(shield, Color(tone, 0.16))
			icon.draw_polyline(PackedVector2Array(Array(shield) + [shield[0]]), tone, 1.7, true)
			icon.draw_line(center + Vector2(0, -5), center + Vector2(0, 3), tone, 1.8)
			icon.draw_circle(center + Vector2(0, 6), 1.1, tone)
		"card":
			icon.draw_rect(Rect2(center - Vector2(7, 9), Vector2(14, 18)), Color(tone, 0.18), true)
			icon.draw_rect(Rect2(center - Vector2(7, 9), Vector2(14, 18)), tone, false, 1.6)
			icon.draw_line(center - Vector2(3, 3), center + Vector2(3, -3), tone, 1.4)
			icon.draw_line(center - Vector2(3, 0), center + Vector2(3, 0), tone, 1.4)
		"growth":
			icon.draw_polyline(PackedVector2Array([center + Vector2(-9, 7), center + Vector2(-3, 1), center + Vector2(2, 4), center + Vector2(9, -7)]), tone, 2.0, true)
			icon.draw_line(center + Vector2(4, -7), center + Vector2(9, -7), tone, 1.6)
			icon.draw_line(center + Vector2(9, -7), center + Vector2(9, -2), tone, 1.6)


func _build_footer(layout: VBoxContainer) -> void :
	var footer: = HBoxContainer.new()
	footer.name = "EventFooter"
	footer.custom_minimum_size = Vector2(0, 58)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 18)
	layout.add_child(footer)
	message_label = _label("选择方案", 17, MUTED)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(message_label)
	confirm_button = Button.new()
	confirm_button.name = "Confirm"
	confirm_button.text = "请先选择经营方案"
	confirm_button.custom_minimum_size = Vector2(330, 52)
	confirm_button.disabled = true
	confirm_button.add_to_group("modal_action_button")
	Styles.apply_toy_button(confirm_button, true, Styles.TOY_YELLOW, 20)
	confirm_button.pressed.connect(_confirm)
	footer.add_child(confirm_button)


func _build_receipt(surface: Control) -> void :
	result_receipt = PanelContainer.new()
	result_receipt.name = "ResultReceipt"
	result_receipt.set_anchors_preset(Control.PRESET_CENTER)
	result_receipt.position = Vector2(-280, -100)
	result_receipt.size = Vector2(560, 200)
	result_receipt.visible = false
	result_receipt.mouse_filter = Control.MOUSE_FILTER_STOP
	result_receipt.add_theme_stylebox_override("panel", _panel(Color(0.015, 0.09, 0.13, 0.98), GOLD, 24, 24, 14))
	surface.add_child(result_receipt)
	var box: = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	result_receipt.add_child(box)
	receipt_title = _label("方案已执行", 28, GOLD_LIGHT, true)
	receipt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(receipt_title)
	receipt_detail = _label("", 18, WHITE, true)
	receipt_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	receipt_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(receipt_detail)
	var hint: = _label("效果已写入本轮经营战报", 14, CYAN)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _select(index: int) -> void :
	if resolving or index < 0 or index >= choice_buttons.size() or choice_buttons[index].disabled:
		return
	selected_index = index
	for item_index in choice_buttons.size():
		_finish_card_entry(choice_buttons[item_index])
		var selected: = item_index == selected_index
		choice_buttons[item_index].add_theme_stylebox_override("normal", _card_style(Color(0.055, 0.19, 0.24, 1.0) if selected else Color(0.018, 0.105, 0.15, 0.97), GOLD_LIGHT if selected else Color(0.34, 0.64, 0.7, 0.78), 15 if selected else 7))
		choice_buttons[item_index].scale = Vector2(1.018, 1.018) if selected else Vector2.ONE
	confirm_button.disabled = false
	var choice: Dictionary = offer.get("choices", [])[selected_index]
	confirm_button.text = "确认执行  %s" % str(choice.get("title", "经营方案"))
	message_label.text = str(choice.get("preview", ""))
	AudioManager.click()


func _play_opening() -> void :
	opening_started = true
	if GameSettings.reduce_motion or not is_inside_tree():
		if opening_fx != null:
			opening_fx.visible = false
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	background_rect.pivot_offset = background_rect.size * 0.5
	var background_tween: = create_tween().set_parallel(true)
	background_tween.tween_property(background_rect, "scale", Vector2.ONE, 1.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	background_tween.tween_property(background_rect, "modulate", Color.WHITE, 0.72).set_trans(Tween.TRANS_SINE)
	opening_tweens.append(background_tween)
	var header: = get_node_or_null("Surface/Safe/Layout/EventHeader") as Control
	if header != null:
		var rest: = header.position
		header.position = rest + Vector2(0, -22)
		var header_tween: = create_tween().set_parallel(true)
		header_tween.tween_property(header, "position", rest, 0.42).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		header_tween.tween_property(header, "modulate", Color.WHITE, 0.3)
		opening_tweens.append(header_tween)
	for index in choice_buttons.size():
		var button: = choice_buttons[index]
		button.pivot_offset = button.size * 0.5
		card_rest_positions[button] = button.position
		button.position += Vector2(0, 64)
		var target_modulate: Color = card_rest_modulates[button]
		var delay: = float(index) * 0.11 + 0.1
		var card_tween: = create_tween().set_parallel(true)
		card_tween.tween_property(button, "position", card_rest_positions[button], 0.44).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		card_tween.tween_property(button, "scale", Vector2.ONE, 0.4).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		card_tween.tween_property(button, "modulate", target_modulate, 0.3).set_delay(delay)
		button.set_meta("opening_tween", card_tween)
		opening_tweens.append(card_tween)
	var footer: = get_node_or_null("Surface/Safe/Layout/EventFooter") as Control
	if footer != null:
		var footer_tween: = create_tween()
		footer_tween.tween_property(footer, "modulate", Color.WHITE, 0.32).set_delay(0.43)
		opening_tweens.append(footer_tween)


func _prepare_opening() -> void :
	if GameSettings.reduce_motion:
		return
	background_rect.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	background_rect.scale = Vector2(1.06, 1.06)
	background_rect.modulate = Color(0.72, 0.78, 0.84, 0.76)
	var header: = get_node_or_null("Surface/Safe/Layout/EventHeader") as Control
	if header != null:
		header.modulate = Color(1, 1, 1, 0)
	for button: Button in choice_buttons:
		card_rest_modulates[button] = button.modulate
		button.scale = Vector2(0.94, 0.94)
		# Keep every choice readable while the entrance motion is playing.
		button.modulate.a = 0.82
	var footer: = get_node_or_null("Surface/Safe/Layout/EventFooter") as Control
	if footer != null:
		footer.modulate = Color(1, 1, 1, 0)


func _finish_card_entry(button: Button) -> void :
	if button == null or not card_rest_positions.has(button):
		return
	var tween: Tween = button.get_meta("opening_tween", null)
	if tween != null and tween.is_valid():
		tween.kill()
	button.remove_meta("opening_tween")
	button.position = card_rest_positions[button]
	button.modulate = card_rest_modulates[button]


func _confirm() -> void :
	if resolving or selected_index < 0:
		return
	resolving = true
	confirm_button.disabled = true
	for button: Button in choice_buttons:
		button.disabled = true
	var result: = Decisions.resolve(player_id, selected_index)
	if not bool(result.get("ok", false)):
		resolving = false
		message_label.text = str(result.get("message", "无法执行该方案"))
		for index in choice_buttons.size():
			choice_buttons[index].disabled = not _choice_affordable(offer.get("choices", [])[index])
		confirm_button.disabled = false
		return
	_show_result_receipt(result)
	AudioManager.click()
	if GameSettings.reduce_motion:
		await get_tree().process_frame
		await get_tree().process_frame
	else:
		await get_tree().create_timer(0.82).timeout
	completed.emit(result)
	queue_free()


func _show_result_receipt(result: Dictionary) -> void :
	result_receipt.visible = true
	result_receipt.scale = Vector2(0.86, 0.86)
	result_receipt.modulate = Color(1, 1, 1, 0)
	receipt_title.text = "已执行  %s" % str(result.get("choice_title", "经营方案"))
	receipt_detail.text = "现金  %s → %s     风险  %d → %d" % [
		Styles.money(int(result.get("cash_before", 0))), 
		Styles.money(int(result.get("cash_after", 0))), 
		int(result.get("risk_before", 0)), 
		int(result.get("risk_after", 0)), 
	]
	if not GameSettings.reduce_motion:
		var tween: = create_tween().set_parallel(true)
		tween.tween_property(result_receipt, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(result_receipt, "modulate", Color.WHITE, 0.18)
	else:
		result_receipt.scale = Vector2.ONE
		result_receipt.modulate = Color.WHITE


func _choice_affordable(choice: Dictionary) -> bool:
	var cash_delta: = int(choice.get("cash", 0))
	return cash_delta >= 0 or GameState.available_cash(player_id) >= abs(cash_delta)


func _label(value: String, size_value: int, color: Color, medium: = false) -> Label:
	var label: = Styles.label(value, size_value, color)
	if medium:
		label.add_theme_font_override("font", load("res://Themes/V9141BodyMediumFont.tres") as Font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _card_style(fill: Color, border: Color, shadow_size: int) -> StyleBoxFlat:
	return _panel(fill, border, 22, 12, shadow_size)


func _panel(fill: Color, border: Color, radius: int, padding: int, shadow_size: int) -> StyleBoxFlat:
	var style: = Styles.panel(fill, border, radius, padding)
	style.shadow_color = Color(0, 0, 0, 0.46)
	style.shadow_size = shadow_size
	return style
