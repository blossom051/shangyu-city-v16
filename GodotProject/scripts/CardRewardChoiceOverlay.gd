class_name CardRewardChoiceOverlay
extends Control

signal completed(selected_ids: Array[String])

const Styles = preload("res://scripts/UIStyles.gd")
const CardScene = preload("res://scenes/CardView.tscn")
const Rewards = preload("res://scripts/CardRewardSystem.gd")
const ArcaneFX = preload("res://scripts/CapitalArcaneFX.gd")

var player_id: = ""
var offer: Array[String] = []
var selected: Array[String] = []
var card_views: Dictionary = {}
var confirm_button: Button
var status_label: Label


func setup(value_player_id: String, value_offer: Array) -> void :
	player_id = value_player_id
	for value: Variant in value_offer:
		offer.append(str(value))


func _ready() -> void :
	name = "CardRewardChoiceOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1450
	_build()


func _build() -> void :
	var shade: = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.02, 0.035, 0.92)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var panel: = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-410, -318)
	panel.size = Vector2(820, 636)
	panel.add_theme_stylebox_override("panel", Styles.toy_panel(Color("0b2330"), Color("e15b62"), 20, 14))
	add_child(panel)
	var body: = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)
	var kicker: = Styles.label("RED STRATEGY VAULT  董事会红色机密档案", 13, Color("ef8a8f"))
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(kicker)
	var title: = Styles.label("三张红卡明牌  选择其中两张", 30, Color("f4eadf"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(title)
	var note: = Styles.label("点击卡牌进行选择；两张确认后立即收入手牌。", 15, Color("b7c8cd"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(note)
	var cards: = HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 18)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cards)
	for card_id: String in offer:
		var card: = CardScene.instantiate()
		card.setup(GameConfig.by_id("cards", card_id))
		card.custom_minimum_size = Vector2(220, 316)
		card.pressed.connect(_toggle.bind(card_id))
		card_views[card_id] = card
		cards.add_child(card)
	status_label = Styles.label("已选择 0/2", 17, Color("efc66c"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(status_label)
	confirm_button = Button.new()
	confirm_button.text = "请先选择两张红卡"
	confirm_button.disabled = true
	confirm_button.custom_minimum_size = Vector2(280, 54)
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Styles.apply_toy_button(confirm_button, true, Styles.TOY_YELLOW, 18)
	confirm_button.pressed.connect(_confirm)
	body.add_child(confirm_button)


func _toggle(card_id: String) -> void :
	if card_id in selected:
		selected.erase(card_id)
	elif selected.size() < 2:
		selected.append(card_id)
	else:
		return
	for value: String in card_views:
		card_views[value].set_selected_state(value in selected)
	status_label.text = "已选择 %d/2%s" % [selected.size(), "" if selected.size() < 2 else "  可以确认"]
	confirm_button.disabled = selected.size() != 2
	confirm_button.text = "确认领取两张红卡" if selected.size() == 2 else "请先选择两张红卡"
	if card_id in selected:
		_play_arcane(card_views[card_id] as Control, Color("e45d68"), 0.72)
	AudioManager.card_flip()


func _confirm() -> void :
	if selected.size() != 2:
		return
	var acquired: Array[String] = []
	for card_id: String in selected:
		var result: = Rewards.choose(player_id, card_id)
		if bool(result.get("ok", false)):
			acquired.append(card_id)
	if acquired.size() != 2:
		status_label.text = "奖励结算异常，请重新选择"
		return
	AudioManager.card_play()
	for card_id: String in selected:
		_play_arcane(card_views[card_id] as Control, Color("f2c76b"), 1.0)
	completed.emit(acquired)


func _play_arcane(target: Control, accent: Color, strength: float) -> void :
	if not is_instance_valid(target):
		return
	var fx: = ArcaneFX.new()
	add_child(fx)
	var rect: = target.get_global_rect()
	fx.play_rect(rect, accent, strength)
