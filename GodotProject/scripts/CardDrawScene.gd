extends Control

const Styles = preload("res://scripts/UIStyles.gd")
const OpeningCardScript = preload("res://scripts/OpeningCard.gd")
const OpeningOffers = preload("res://scripts/OpeningCardOffer.gd")
const ScreenDecorator = preload("res://scripts/V7ScreenDecorator.gd")
const DISPLAY_FONT: Font = preload("res://Themes/V9141DisplayFont.tres")
const BODY_FONT: Font = preload("res://Themes/V9141BodyMediumFont.tres")

var player_index: = 0
var choices: Array[String] = []
var pool: Array = []
var locked_ids: Array[String] = []
var premium_id: = ""


func _ready() -> void :
	ScreenDecorator.decorate(self, "cards")
	$Layout / Header / Player.add_theme_font_override("font", DISPLAY_FONT)
	$Layout / Header / Player.add_theme_font_size_override("font_size", 31)
	$Layout / Header / Player.add_theme_color_override("font_color", Color("fff0c8"))
	$Layout / Header / Player.add_theme_color_override("font_outline_color", Color(0.005, 0.015, 0.025, 0.94))
	$Layout / Header / Player.add_theme_constant_override("outline_size", 6)
	$Layout / Header / Count.add_theme_font_override("font", BODY_FONT)
	$Layout / Header / Count.add_theme_font_size_override("font_size", 18)
	$Layout / Prompt.add_theme_font_override("font", BODY_FONT)
	$Layout / Prompt.add_theme_font_size_override("font_size", 17)
	$Layout / Prompt.add_theme_stylebox_override("normal", Styles.panel(Color(0.01, 0.04, 0.058, 0.88), Color("8b7442"), 14, 1))
	Styles.apply_toy_button($Layout / Footer / Confirm, true, Styles.TOY_YELLOW, 20)
	$Layout / Footer / Confirm.pressed.connect(_confirm)
	GameFlow.prepare_scene("city")
	_prepare_player()


func _prepare_player() -> void :
	choices.clear()
	var current: Dictionary = GameState.game_data.players[player_index]
	$Layout / Header / Player.text = "%s  /  开局签约手牌" % current.name
	var offer: = OpeningOffers.build_offer(str(current.company_id))
	pool = offer.pool
	locked_ids.assign(offer.locked_ids)
	premium_id = str(offer.premium_id)
	choices.assign(offer.preselected_ids)
	$Layout / Header / Count.text = "已选择 %d / 3" % choices.size()
	$Layout / Prompt.text = "红色王牌已锁定  再选 2 张组成开局策略" if not premium_id.is_empty() else "从未知策略中选择 3 张  确认后统一揭晓"
	_build_backs(current)


func _build_backs(current: Dictionary) -> void :
	for child in $Layout / Cards.get_children():
		child.queue_free()
	for index in pool.size():
		var back: = Button.new()
		back.set_script(OpeningCardScript)
		var card_id: = str(pool[index])
		back.setup(index, card_id == premium_id)
		back.set_meta("card_id", card_id)
		back.set_meta("locked", locked_ids.has(card_id))
		back.set_selected(choices.has(card_id))
		back.pressed.connect( func() -> void : _choose(back))
		back.mouse_entered.connect(AudioManager.hover)
		$Layout / Cards.add_child(back)


func _choose(button: Button) -> void :
	var card_id: = str(button.get_meta("card_id"))
	if choices.has(card_id):
		if bool(button.get_meta("locked", false)):
			$Layout / Prompt.text = "云杉专属红色王牌  已列入开局策略"
			return
		choices.erase(card_id)
		button.call("set_selected", false)
		$Layout / Header / Count.text = "已选择 %d / 3" % choices.size()
		$Layout / Footer / Confirm.disabled = choices.size() != 3
		AudioManager.click()
		return
	if choices.size() >= 3:
		return
	choices.append(card_id)
	button.call("set_selected", true)
	AudioManager.click()
	$Layout / Header / Count.text = "已选择 %d / 3" % choices.size()
	$Layout / Footer / Confirm.disabled = choices.size() != 3


func _confirm() -> void :
	if choices.size() != 3:
		return
	$Layout / Footer / Confirm.disabled = true
	for back: Button in $Layout / Cards.get_children():
		var card_id: = str(back.get_meta("card_id"))
		if choices.has(card_id):
			await back.call("reveal", GameConfig.by_id("cards", card_id))
	await _owned_delay(0.65)
	var current: Dictionary = GameState.game_data.players[player_index]
	GameState.set_opening_hand(str(current.id), choices)
	player_index += 1
	if player_index >= GameState.game_data.players.size():
		GameFlow.finish_opening()
		return
	var next_player: Dictionary = GameState.game_data.players[player_index]
	if not bool(next_player.human):
		_auto_choose_remaining()
	else:
		_prepare_player()


func _owned_delay(seconds: float) -> void :
	var timer: = Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(0.001, seconds)
	add_child(timer)
	timer.start()
	await timer.timeout
	if is_instance_valid(timer):
		timer.queue_free()


func _auto_choose_remaining() -> void :
	while player_index < GameState.game_data.players.size():
		var current: Dictionary = GameState.game_data.players[player_index]
		GameState.set_opening_hand(str(current.id), OpeningOffers.build_auto_hand(str(current.company_id)))
		player_index += 1
	GameFlow.finish_opening()
