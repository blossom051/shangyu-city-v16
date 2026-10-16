class_name AITurnPresenter
extends Control

const DecisionBadge = preload("res://scripts/AIDecisionBadge.gd")

signal focus_land_requested(land_id: String)
signal skip_all_requested

var veil: ColorRect
var panel: PanelContainer
var company_label: Label
var progress_label: Label
var headline_label: Label
var detail_label: Label
var cash_label: Label
var action_badge: AIDecisionBadge
var stage_bar: ProgressBar
var action_strip: ColorRect
var speed_button: Button
var skip_button: Button
var speed_multiplier: = 1.0
var skip_replay: = false
var skip_until_human: = false
var action_index: = 0
var total_stages: = 0
var modal_token: = 0
var delay_timer: Timer


func _ready() -> void :
	name = "AITurnPresenter"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 700
	_build()
	delay_timer = Timer.new()
	delay_timer.name = "AIActionDelay"
	delay_timer.one_shot = true
	add_child(delay_timer)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func begin_turn(player: Dictionary, stage_count: int) -> void :
	_ensure_ready()
	if skip_until_human:
		return
	var replay_layer: = get_parent() as CanvasLayer if get_parent() is CanvasLayer else null
	modal_token = ModalManager.open_modal("ai_action", self, self, replay_layer)
	mouse_filter = Control.MOUSE_FILTER_STOP
	skip_replay = false
	action_index = 0
	total_stages = stage_count
	company_label.text = "AI 决策回放  %s" % str(player.get("name", "电脑财团"))
	company_label.add_theme_color_override("font_color", Color(str(player.get("color", "#d6ad54"))).lightened(0.24))
	progress_label.text = "正在制定本回合行动…"
	stage_bar.value = 0.0
	action_badge.set_action("decision")
	headline_label.text = "进入决策阶段"
	detail_label.text = "只播放已真实执行的操作"
	cash_label.text = ""
	visible = true
	panel.modulate.a = 0.0
	panel.position.y += 18.0
	if GameSettings.reduce_motion:
		panel.modulate.a = 1.0
	else:
		var tween: = create_tween().set_parallel(true)
		tween.tween_property(panel, "modulate:a", 1.0, 0.18)
		tween.tween_property(panel, "position:y", panel.position.y - 18.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween.finished
	await _wait(_duration(0.32))


func play_action(event: Dictionary) -> void :
	_ensure_ready()
	if skip_until_human:
		return
	action_index += 1
	progress_label.text = "行动 %02d  %s" % [action_index, _action_name(str(event.get("action", "")))]
	stage_bar.value = clampf(float(action_index) / float(maxi(1, total_stages)) * 100.0, 0.0, 100.0)
	action_badge.set_action(str(event.get("action", "")))
	action_strip.color = Color(action_badge.presentation_profile().get("accent", Color("62c8d8")))
	headline_label.text = str(event.get("headline", "AI 完成一项决策"))
	detail_label.text = str(event.get("detail", "状态已更新"))
	var cash_delta: = int(event.get("cash_delta", 0))
	cash_label.text = "现金 %s%d 万" % ["+" if cash_delta > 0 else "", cash_delta] if cash_delta != 0 else "无直接现金变化"
	cash_label.add_theme_color_override("font_color", Color("69d39b") if cash_delta >= 0 else Color("ef8179"))
	var land_id: = str(event.get("land_id", ""))
	if not land_id.is_empty():
		focus_land_requested.emit(land_id)
	if skip_replay:
		return
	panel.scale = Vector2(0.985, 0.985)
	panel.pivot_offset = panel.size * 0.5
	action_strip.scale.x = 0.04
	action_badge.scale = Vector2(0.35, 0.35)
	action_badge.modulate.a = 0.45
	action_badge.pivot_offset = action_badge.size * 0.5
	var tween: = create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, _duration(0.16)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(action_strip, "scale:x", 1.0, _duration(0.28)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(action_badge, "scale", Vector2.ONE, _duration(0.24)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(action_badge, "modulate:a", 1.0, _duration(0.18))
	await tween.finished
	await _wait(_duration(0.48))


func finish_turn(summary: Array[String] = []) -> void :
	_ensure_ready()
	if skip_until_human:
		return
	if not skip_replay:
		progress_label.text = "本席行动完成"
		headline_label.text = "AI 财团已结束回合"
		detail_label.text = "  ".join(summary) if not summary.is_empty() else "本回合未执行额外操作"
		cash_label.text = "即将进入下一席位"
		await _wait(_duration(0.42))
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ModalManager.close_modal(modal_token, "ai_turn_finished")
	modal_token = 0


func _set_speed() -> void :
	speed_multiplier = 2.0 if speed_multiplier < 1.5 else 1.0
	speed_button.text = "2倍速：开" if speed_multiplier > 1.5 else "2倍速"


func _skip() -> void :
	skip_replay = true
	skip_until_human = true
	skip_all_requested.emit()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(delay_timer):
		delay_timer.stop()
	ModalManager.close_modal(modal_token, "ai_turn_skipped")
	modal_token = 0


func reset_sequence_skip() -> void :
	skip_until_human = false
	skip_replay = false


func interaction_profile() -> Dictionary:
	return {
		"speed_button": speed_button, 
		"skip_button": skip_button, 
		"speed_multiplier": speed_multiplier, 
		"skip_until_human": skip_until_human, 
		"canvas_layer": (get_parent() as CanvasLayer).layer if get_parent() is CanvasLayer else -1, 
	}


func _wait(seconds: float) -> void :
	if seconds <= 0.0 or not is_instance_valid(delay_timer):
		return
	delay_timer.start(seconds)
	while is_instance_valid(delay_timer) and delay_timer.time_left > 0.0 and visible:
		await get_tree().process_frame


func on_modal_force_close() -> void :
	skip_replay = true
	if is_instance_valid(delay_timer):
		delay_timer.stop()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_token = 0


func _duration(base: float) -> float:
	if GameSettings.reduce_motion:
		return minf(0.08, base)
	return base / speed_multiplier


func _ensure_ready() -> void :
	if panel == null:
		_build()


func _build() -> void :
	if panel != null:
		return
	veil = ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.01, 0.035, 0.045, 0.46)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	panel = PanelContainer.new()
	panel.name = "DecisionCard"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-330, -158)
	panel.size = Vector2(700, 350)
	var style: = StyleBoxFlat.new()
	style.bg_color = Color("092733f7")
	style.border_color = Color("d6ad54")
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 20
	style.shadow_color = Color(0, 0, 0, 0.58)
	style.shadow_size = 20
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var stack: = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)
	var top: = HBoxContainer.new()
	stack.add_child(top)
	company_label = _label("AI 决策回放", 20, Color("f1d27e"))
	company_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(company_label)
	speed_button = Button.new()
	speed_button.name = "SpeedButton"
	speed_button.text = "2倍速"
	speed_button.custom_minimum_size = Vector2(96, 38)
	speed_button.mouse_filter = Control.MOUSE_FILTER_STOP
	speed_button.pressed.connect(_set_speed)
	top.add_child(speed_button)
	skip_button = Button.new()
	skip_button.name = "SkipButton"
	skip_button.text = "跳过全部 AI"
	skip_button.custom_minimum_size = Vector2(116, 38)
	skip_button.mouse_filter = Control.MOUSE_FILTER_STOP
	skip_button.pressed.connect(_skip)
	top.add_child(skip_button)
	progress_label = _label("准备中", 13, Color("9eb7c0"))
	stack.add_child(progress_label)
	stage_bar = ProgressBar.new()
	stage_bar.name = "DecisionProgress"
	stage_bar.show_percentage = false
	stage_bar.custom_minimum_size = Vector2(0, 7)
	stage_bar.value = 0.0
	stack.add_child(stage_bar)
	var rule: = ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = Color(Color("d6ad54"), 0.72)
	stack.add_child(rule)
	var action_row: = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 16)
	stack.add_child(action_row)
	action_badge = DecisionBadge.new()
	action_badge.name = "ActionBadge"
	action_row.add_child(action_badge)
	headline_label = _label("进入决策阶段", 29, Color("f1f5f3"))
	headline_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headline_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_row.add_child(headline_label)
	action_strip = ColorRect.new()
	action_strip.custom_minimum_size = Vector2(0, 3)
	action_strip.color = Color("62c8d8")
	stack.add_child(action_strip)
	detail_label = _label("只显示真实执行的操作", 17, Color("c8d7d9"))
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.max_lines_visible = 2
	detail_label.custom_minimum_size = Vector2(0, 52)
	stack.add_child(detail_label)
	cash_label = _label("", 16, Color("69d39b"))
	stack.add_child(cash_label)


func _label(value: String, size_value: int, color: Color) -> Label:
	var label: = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	return label


func _action_name(action: String) -> String:
	return {
		"round_card": "策略选择", "buy_land": "土地交易", "build": "企业建设", "talent": "人才安排", 
		"discard": "手牌整理", "card": "策略卡", "stock": "证券交易", "loan": "银行融资", 
		"startup": "创业投资", "recovery": "经营整改", 
	}.get(action, "经营决策")
