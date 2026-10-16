class_name RoundCardDraftDialog
extends Control

signal card_chosen(result: Dictionary)

const Cards = preload("res://scripts/CardSystem.gd")
const Styles = preload("res://scripts/UIStyles.gd")
const OpeningCardScript = preload("res://scripts/OpeningCard.gd")
const ArcaneFX = preload("res://scripts/CapitalArcaneFX.gd")

var player_id: = ""
var selected_id: = ""
var selected_card: Button
var confirm_button: Button
var choice_buttons: Dictionary = {}
var resolving: = false
var phase: = "selection"
var chosen_result: Dictionary = {}
var title_label: Label
var hint_label: Label
var card_layer: CanvasLayer
var modal_root: Control
var recovery_timer: Timer
var modal_token: = 0
var card_select_open_time: = 0
var card_press_callables: Dictionary = {}


func open_for_player(next_player_id: String) -> void :
	player_id = next_player_id


func _ready() -> void :
	name = "RoundCardDraftDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("managed_modal_owner")
	card_layer = CanvasLayer.new()
	card_layer.name = "RoundCardDraftLayer"
	card_layer.layer = 2000
	add_child(card_layer)
	modal_root = Control.new()
	modal_root.name = "CardSelectPanel"
	modal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	card_layer.add_child(modal_root)
	_build()
	card_select_open_time = Time.get_ticks_msec()
	recovery_timer = Timer.new()
	recovery_timer.name = "CardSelectRecoveryTimer"
	recovery_timer.one_shot = true
	recovery_timer.wait_time = 15.0
	recovery_timer.timeout.connect(_request_input_recovery)
	add_child(recovery_timer)
	modal_token = ModalManager.open_modal("round_card_draft", self, modal_root, card_layer, _repair_input_state)
	recovery_timer.start()
	tree_exiting.connect(_close_modal)


func _build() -> void :
	var offer_kind := Cards.round_offer_kind(player_id)
	var is_west_bank := offer_kind == "west_bank"
	var shade: = ColorRect.new()
	shade.name = "CardSelectShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.03, 0.055, 0.94)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_root.add_child(shade)

	var safe_margin: = MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		safe_margin.add_theme_constant_override("margin_%s" % side, 38)
	for side in ["top", "bottom"]:
		safe_margin.add_theme_constant_override("margin_%s" % side, 22)
	modal_root.add_child(safe_margin)

	var panel: = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.panel(Color("082332"), Color("438aa1"), 24, 12))
	safe_margin.add_child(panel)

	var stack: = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)

	title_label = Label.new()
	title_label.text = "西岸霓虹策略库  五选一" if is_west_bank else "原城区策略补给  五选一"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color("f3ead1"))
	stack.add_child(title_label)

	var active: = GameState.player(player_id)
	hint_label = Label.new()
	hint_label.text = ("第二阶段：选择1张西岸卡收入手牌  普通卡2 SP · 高级卡3 SP · 高级卡合计出现率8%% · 每次最多1张  当前手牌 %d/5  每回合6 SP" if is_west_bank else "第一阶段：从5张原城区卡中选择1张；随后还可选择1张西岸卡  当前手牌 %d/5") % active.get("hand", []).size()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 17)
	hint_label.add_theme_color_override("font_color", Styles.TOY_MUTED)
	stack.add_child(hint_label)

	var scroll: = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 386)
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.add_child(scroll)

	var row: = HBoxContainer.new()
	row.name = "CardBacks"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	scroll.add_child(row)

	var offer: Array = Cards.round_offer(player_id)
	for index in offer.size():
		var card_id: String = str(offer[index])
		var back: = Button.new()
		back.name = "CardButton%d" % (index + 1)
		back.set_script(OpeningCardScript)
		back.call("setup", index + int(GameState.game_data.get("round", 1)) * 11, false, is_west_bank)
		back.set_meta("card_id", card_id)
		back.tooltip_text = "点击选择这张未知策略牌"
		var press_callable: = _card_pressed.bind(card_id, back)
		card_press_callables[card_id] = press_callable
		back.pressed.connect(press_callable)
		back.mouse_entered.connect(AudioManager.hover)
		row.add_child(back)
		choice_buttons[card_id] = back

	confirm_button = Button.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.text = "请先选择一张卡牌"
	confirm_button.custom_minimum_size = Vector2(420, 58)
	confirm_button.disabled = true
	Styles.apply_toy_button(confirm_button, true, Styles.TOY_YELLOW, 20)
	confirm_button.pressed.connect(_confirm_card)
	var center: = CenterContainer.new()
	center.add_child(confirm_button)
	stack.add_child(center)


func _card_pressed(card_id: String, button: Button) -> void :
	if resolving or phase != "selection":
		return
	_select_card(card_id, button)


func _select_card(card_id: String, button: Button) -> void :
	selected_card = button
	selected_id = card_id
	for choice_id: String in choice_buttons:
		(choice_buttons[choice_id] as Button).call("set_selected", choice_id == selected_id)
	confirm_button.disabled = false
	confirm_button.text = "确认选择"
	_play_arcane(button, _card_accent(card_id), 0.45)
	AudioManager.click()


func _request_input_recovery() -> void :
	if phase == "selection" and selected_id.is_empty() and ModalManager.is_active("round_card_draft"):
		ModalManager.recover_active("card_selection_timeout")


func _repair_input_state() -> void :
	if phase != "selection" or not selected_id.is_empty():
		return
	for card_id: String in choice_buttons:
		var button: = choice_buttons[card_id] as Button
		if not is_instance_valid(button):
			continue
		button.disabled = false
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		var press_callable: Callable = card_press_callables.get(card_id, Callable())
		if press_callable.is_valid() and not button.pressed.is_connected(press_callable):
			button.pressed.connect(press_callable)
	if is_instance_valid(modal_root):
		modal_root.visible = true
		modal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(recovery_timer):
		recovery_timer.start()


func _close_modal() -> void :
	if is_instance_valid(recovery_timer):
		recovery_timer.stop()
	if is_instance_valid(modal_root):
		modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ModalManager.close_modal(modal_token, "round_card_closed")


func _input(event: InputEvent) -> void :
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	match phase:
		"ready_to_return":
			continue_after_reveal()
		"selection":
			hint_label.text = "策略补给是本回合必选流程：请先选择并翻开一张；Esc 不会关闭或丢失本次补给。"
			AudioManager.cancel()
		"revealing":
			hint_label.text = "卡牌正在揭晓，请稍候；完成后可点击按钮或按 Esc 安全返回。"


func on_modal_force_close() -> void :
	_close_modal()
	queue_free()


func _confirm_card() -> void :
	if phase == "ready_to_return":
		continue_after_reveal()
		return
	if selected_id.is_empty() or selected_card == null or resolving:
		return
	resolving = true
	phase = "revealing"
	confirm_button.disabled = true
	confirm_button.text = "正在翻开……"
	for card_id: String in choice_buttons:
		var back: = choice_buttons[card_id] as Button
		back.disabled = true
		if card_id != selected_id:
			if GameSettings.reduce_motion:
				back.modulate.a = 0.16
			else:
				create_tween().tween_property(back, "modulate:a", 0.16, 0.18)
	selected_card.call("reveal", GameConfig.by_id("cards", selected_id))
	_play_arcane(selected_card, _card_accent(selected_id), 0.68)
	var reveal_started_at: = Time.get_ticks_msec()
	while is_instance_valid(selected_card) and not bool(selected_card.get("revealed")) and Time.get_ticks_msec() - reveal_started_at < 1400:
		await get_tree().process_frame
	if not is_instance_valid(selected_card):
		resolving = false
		phase = "selection"
		return
	if not bool(selected_card.get("revealed")):
		selected_card.set("revealed", true)
		selected_card.queue_redraw()
	var result: = Cards.choose_round_card(player_id, selected_id)
	if not bool(result.get("ok", false)):
		resolving = false
		confirm_button.disabled = false
		confirm_button.text = str(result.get("message", "选择失败"))
		return
	chosen_result = result
	_enter_reveal_phase()


func _enter_reveal_phase() -> void :
	phase = "ready_to_return"
	resolving = false
	for card_id: String in choice_buttons:
		var back: = choice_buttons[card_id] as Button
		if card_id != selected_id:
			back.visible = false
	selected_card.custom_minimum_size = Vector2(260, 370)
	selected_card.scale = Vector2.ONE
	selected_card.rotation = 0.0
	selected_card.disabled = true
	title_label.text = "西岸策略已签收" if str(chosen_result.get("offer_kind", "")) == "west_bank" else "原城区策略已签收"
	var card: = GameConfig.by_id("cards", selected_id)
	var player: = GameState.player(player_id)
	var over_limit: bool = player.get("hand", []).size() > 5
	hint_label.text = ("%s已加入手牌  返回后需要整理超限手牌" if over_limit else "%s已加入手牌  请阅读卡面效果后继续") % str(card.get("name", "所选策略"))
	hint_label.add_theme_font_size_override("font_size", 19)
	confirm_button.disabled = false
	var has_next_draft := not Cards.round_offer(player_id).is_empty()
	confirm_button.text = "继续选择西岸策略" if has_next_draft else "返回城市并整理手牌" if over_limit else "收入手牌并返回城市"
	AudioManager.click()


func continue_after_reveal() -> void :
	if phase != "ready_to_return" or chosen_result.is_empty():
		return
	phase = "complete"
	confirm_button.disabled = true
	card_chosen.emit(chosen_result)
	queue_free()


func presentation_state() -> Dictionary:
	return {
		"phase": phase, 
		"selected_card_id": selected_id, 
		"card_added": bool(chosen_result.get("ok", false)), 
		"card_revealed": selected_card != null and bool(selected_card.get("revealed")), 
		"can_continue": phase == "ready_to_return" and not chosen_result.is_empty(), 
		"open_time": card_select_open_time, 
		"modal_layer": card_layer.layer if is_instance_valid(card_layer) else -1, 
	}


func _play_arcane(target: Control, accent: Color, strength: float) -> void :
	if not is_instance_valid(target) or not is_instance_valid(modal_root):
		return
	var fx: = ArcaneFX.new()
	modal_root.add_child(fx)
	var rect: = target.get_global_rect()
	fx.play_rect(rect, accent, strength)


func _card_accent(card_id: String) -> Color:
	var card: = GameConfig.by_id("cards", card_id)
	var category: = str(card.get("category", card.get("type", "strategy")))
	return {
		"risk": Color("70d7d0"), "finance": Color("e8bd58"), "growth": Color("6fd3a1"), 
		"attack": Color("ea6470"), "control": Color("a98df0"), "strategy": Color("65b9e8")
	}.get(category, Color("65b9e8"))
