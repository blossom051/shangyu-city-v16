extends Control

var modal_token: = 0

signal closed

const Styles = preload("res://scripts/UIStyles.gd")
const Cards = preload("res://scripts/CardSystem.gd")
const CardScene = preload("res://scenes/CardView.tscn")
const Selection = preload("res://scripts/SelectionState.gd")
const TargetChoiceCardScript = preload("res://scripts/TargetChoiceCard.gd")
const CardUseGlow = preload("res://scripts/CardUseGlow.gd")
const CardEffectBurst = preload("res://scripts/CardEffectBurst.gd")
const DrawPolicy = preload("res://scripts/CardDrawPolicy.gd")
const RewardChoiceOverlay = preload("res://scripts/CardRewardChoiceOverlay.gd")
const ArcaneFX = preload("res://scripts/CapitalArcaneFX.gd")
const Taxonomy = preload("res://scripts/CardTaxonomy.gd")
const ReactionWindow = preload("res://scripts/CapitalReactionWindow.gd")
const TUTORIAL_CARD_ID: = "g03"

const CARD_REST_Y: = 16.0
const CARD_SELECTED_Y: = -18.0

var selected_card_id: = ""
var target_ids: Array[String] = []
var selection: = Selection.new()
var card_views: Dictionary = {}
var card_wrappers: Dictionary = {}
var selected_target_index: = 0
var is_playing: = false
var reward_overlay: Control


func _ready() -> void :
	add_to_group("managed_modal_owner")
	modal_token = ModalManager.open_modal("strategy_hand", self, self)
	tree_exiting.connect( func() -> void : ModalManager.close_modal(modal_token, "card_hand_closed"))
	name = "CardHandOverlay" if get_parent() != get_tree().root else "CardHandPanel"
	_style()
	$Layout / Header / Back.pressed.connect(_close)
	$Layout / Actions / Play.pressed.connect(_play)
	$Layout / Actions / Cancel.pressed.connect(_clear_selection)
	$Layout / Actions / RedeemNormal.pressed.connect(_open_redemption.bind(false))
	$Layout / Actions / RedeemRed.pressed.connect(_open_redemption.bind(true))
	$Layout / Actions / Discard.pressed.connect(_discard_selected)
	$Background.gui_input.connect(_on_blank_input)
	_rebuild()
	_build_v12_battlefield()
	call_deferred("_animate_open")
	call_deferred("_resume_pending_reward")


func selected_lift_pixels() -> int:
	return int(CARD_SELECTED_Y - CARD_REST_Y)


func _rebuild() -> void :
	for child in $Layout / Hand.get_children():
		child.queue_free()
	card_views.clear()
	card_wrappers.clear()
	selection.clear()
	selected_card_id = ""
	target_ids.clear()
	_clear_targets()
	_set_play_enabled(false)
	$Layout / Actions / Discard.disabled = true
	$Layout / Actions / Discard.text = "选中卡牌后弃置"
	$Layout / Actions / Cancel.visible = false
	var active: = GameState.active_player()
	$Layout / Header / Title.text = "%s  VS  城市资本对手  策略战场" % str(active.get("name", "当前财团"))
	$Layout / Header / Points.text = "卡牌积分  %d" % int(active.get("card_points", 0))
	var guide: = DrawPolicy.points_guide()
	var rarity_points: Dictionary = guide.get("rarity_points", {})
	$Layout / PointsGuide.text = "弃牌积分：蓝%d / 金%d / 铂金%d / 红%d / 曜金%d  主动弃牌和超限弃牌均计分  曜金典藏不可积分兑换" % [
		int(rarity_points.get("blue", 1)), int(rarity_points.get("gold", 2)), 
		int(rarity_points.get("platinum", 4)), int(rarity_points.get("red", 8)), int(rarity_points.get("gilded", 12)), 
	]
	$Layout / Actions / RedeemNormal.disabled = int(active.get("card_points", 0)) < DrawPolicy.NORMAL_REDEEM_COST
	$Layout / Actions / RedeemRed.disabled = int(active.get("card_points", 0)) < DrawPolicy.RED_REDEEM_COST
	$Layout / DiscardNotice.visible = active.hand.size() > 5
	$Layout / DiscardNotice.text = "手牌超过上限：必须选牌并点击“弃牌换积分”，直到不超过 5 张"
	var displayed_hand: Array = active.hand.duplicate()
	if TutorialDirector.active and TutorialDirector.current_step_id() == "play_strategy":
		displayed_hand = [TUTORIAL_CARD_ID]
		$Layout / DiscardNotice.visible = false
	for card_id: String in displayed_hand:
		var view: = _make_card(card_id)
		view.pressed.connect(_select_card.bind(card_id))
	$Layout / Message.text = "教学沙盘  点击《稳定经营》，选择己方财团并发动；不会消耗正式手牌或策略点。" if TutorialDirector.active and TutorialDirector.current_step_id() == "play_strategy" else "策略点  %d/%d  ◆  秘策 %d/2  ◆  持续策略 %d/2\n点击卡牌选择目标；防御/反制牌会背面部署到董事会秘策区。" % [int(active.get("strategy_points", 3)), int(active.get("strategy_points_max", 3)), active.get("secret_zone", []).size(), active.get("continuous_zone", []).size()]


func _open_redemption(red_only: bool) -> void :
	if is_playing:
		return
	var active: = GameState.active_player()
	var cost: = DrawPolicy.RED_REDEEM_COST if red_only else DrawPolicy.NORMAL_REDEEM_COST
	if int(active.get("card_points", 0)) < cost:
		_show_message("卡牌积分不足：需要 %d 分" % cost, Color("e67a82"))
		return
	var choices: = DrawPolicy.redemption_choices(str(active.id), red_only)
	if choices.is_empty():
		_show_message("当前没有可兑换的卡牌", Color("e67a82"))
		return
	var overlay: = ColorRect.new()
	overlay.name = "RedemptionOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.005, 0.018, 0.028, 0.9)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 500
	add_child(overlay)
	var shell: = PanelContainer.new()
	shell.set_anchors_preset(Control.PRESET_CENTER)
	shell.offset_left = -590.0
	shell.offset_top = -350.0
	shell.offset_right = 590.0
	shell.offset_bottom = 350.0
	shell.add_theme_stylebox_override("panel", Styles.panel(Color("081923"), Color("b28b46") if red_only else Color("3f9bb4"), 24, 18))
	overlay.add_child(shell)
	var margin: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	shell.add_child(margin)
	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var title: = Label.new()
	title.text = "红卡兑换  三张明牌选一张" if red_only else "策略研选  三选一"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("f1cf73"))
	box.add_child(title)
	var explanation: = Label.new()
	explanation.text = "将消耗 %d 积分；只有点击具体卡牌后才扣分。%s" % [cost, "本轮候选已锁定，以下三张均为最高强度红卡。" if red_only else "以下3张为本次候选，选择最符合当前局势的一张。"]
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explanation.add_theme_font_size_override("font_size", 16)
	explanation.add_theme_color_override("font_color", Color("b8cbd0"))
	box.add_child(explanation)
	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var stage: = HBoxContainer.new()
	stage.name = "RedemptionCardStage"
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.add_theme_constant_override("separation", 18)
	scroll.add_child(stage)
	var card_index: = 0
	for card_id: String in choices:
		var card: = GameConfig.by_id("cards", card_id)
		var choice: = CardScene.instantiate() as CardView
		card_index += 1
		choice.name = "RedemptionCard%d" % card_index
		choice.setup(card)
		choice.custom_minimum_size = Vector2(252, 354)
		choice.tooltip_text = "%s\n点击兑换此卡；确认后才扣除 %d 积分" % [str(card.get("description", "")), cost]
		choice.pressed.connect(_choose_redemption.bind(card_id, red_only, overlay, choice))
		choice.mouse_entered.connect(AudioManager.hover)
		stage.add_child(choice)
	var cancel: = Button.new()
	cancel.text = "取消  不扣积分"
	cancel.custom_minimum_size = Vector2(0, 46)
	Styles.apply_button(cancel, false, Color("496978"), 16)
	cancel.pressed.connect( func() -> void : overlay.queue_free())
	box.add_child(cancel)
	AudioManager.card_flip()


func _choose_redemption(card_id: String, red_only: bool, overlay: Control, source_view: Control) -> void :
	if is_playing:
		return
	is_playing = true
	var result: = DrawPolicy.redeem_choice(str(GameState.active_player().id), card_id, red_only)
	if not bool(result.get("ok", false)):
		is_playing = false
		_show_message(str(result.get("message", "兑换失败")), Color("e67a82"))
		if is_instance_valid(overlay):
			overlay.queue_free()
		return
	var card: = GameConfig.by_id("cards", str(result.get("card_id", "")))
	if is_instance_valid(source_view) and is_instance_valid(overlay):
		var fx: = ArcaneFX.new()
		overlay.add_child(fx)
		var rect: = source_view.get_global_rect()
		fx.play_rect(rect, _rarity_color(str(card.get("rarity", ""))), 1.12)
		if not GameSettings.reduce_motion:
			var pulse: = source_view.create_tween().set_parallel(true)
			pulse.tween_property(source_view, "scale", Vector2(1.055, 1.055), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.1 if GameSettings.reduce_motion else 0.34).timeout
	if is_instance_valid(overlay):
		overlay.queue_free()
	is_playing = false
	_rebuild()
	_show_message("已自选：%s；剩余 %d 积分" % [str(card.get("name", "策略卡")), int(result.get("remaining_points", 0))], Color("e2bd66"))
	AudioManager.card_flip()


func _rarity_name(rarity: String) -> String:
	return {"blue": "蓝色  基础", "gold": "金色  进阶", "platinum": "铂金  强力", "red": "红色  顶级", "gilded": "曜金  典藏", "west_bank": "西岸专属  不分等级"}.get(rarity, rarity)


func _rarity_color(rarity: String) -> Color:
	return {"blue": Color("3f9bb4"), "gold": Color("c99a3e"), "platinum": Color("8f82c9"), "red": Color("bd3e52"), "gilded": Color("c9f5ff"), "west_bank": Color("72e0e6")}.get(rarity, Color("3f9bb4"))


func _make_card(card_id: String) -> CardView:
	var count: = maxi(1, GameState.active_player().hand.size())
	var available_width: = maxf(900.0, get_viewport_rect().size.x - 130.0)
	var wrapper_width: = clampf((available_width - float(count - 1) * 8.0) / float(count), 180.0, 276.0)
	var card_width: = wrapper_width - 14.0
	var card_height: = card_width * 1.4
	var wrapper: = Control.new()
	wrapper.custom_minimum_size = Vector2(wrapper_width, card_height + 34.0)
	wrapper.mouse_filter = Control.MOUSE_FILTER_PASS
	$Layout / Hand.add_child(wrapper)
	var view: = CardScene.instantiate() as CardView
	view.setup(GameConfig.by_id("cards", card_id))
	view.custom_minimum_size = Vector2(card_width, card_height)
	view.size = Vector2(card_width, card_height)
	view.position = Vector2(7, CARD_REST_Y)
	view.pivot_offset = view.size * 0.5
	wrapper.add_child(view)
	card_views[card_id] = view
	card_wrappers[card_id] = wrapper
	return view


func _select_card(card_id: String) -> void :
	if is_playing:
		return
	var active: = GameState.active_player()
	selected_card_id = selection.toggle(card_id)
	_sync_card_states()
	if selected_card_id.is_empty():
		_clear_selection(false)
		return
	var legal: = Cards.legal_targets(str(active.id), card_id)
	_build_target_cards(legal)
	var card: = GameConfig.by_id("cards", card_id)
	var play_limit_reached: = int(active.get("strategy_points", 0)) < int(card.get("cost", 0))
	_set_play_enabled( not legal.is_empty() and not play_limit_reached)
	var discard_points: = DrawPolicy.discard_value(card_id)
	$Layout / Actions / Discard.disabled = TutorialDirector.active and TutorialDirector.current_step_id() == "play_strategy"
	$Layout / Actions / Discard.text = "弃牌换 %d 积分" % discard_points
	$Layout / Actions / Cancel.visible = true
	var selected_view: CardView = card_views.get(card_id) as CardView
	var detail: = selected_view.detail_text() if selected_view else str(GameConfig.by_id("cards", card_id).get("effect", "策略效果"))
	var permission: = "SP不足：需要%d，当前%d" % [int(card.get("cost", 0)), int(active.get("strategy_points", 0))] if play_limit_reached else "%d SP  %s" % [int(card.get("cost", 0)), "部署秘策" if str(card.get("type", "")) in ["defense", "counter"] else "可发动"]
	$Layout / Message.text = "%s  %s / %s  %s  %s" % [str(card.name), Taxonomy.family_name(card), Taxonomy.effect_tier_name(card), detail, permission]
	AudioManager.card_flip()


func _discard_selected() -> void :
	if is_playing or selected_card_id.is_empty():
		return
	var result: = Cards.discard_for_points(str(GameState.active_player().id), selected_card_id)
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("message", "弃牌失败")), Color("e67a82"))
		return
	AudioManager.card_flip()
	_rebuild()
	_show_message("%s；当前积分 %d" % [str(result.get("message", "弃牌完成")), int(result.get("remaining_points", 0))], Color("e2bd66"))


func _sync_card_states() -> void :
	for id: String in card_views:
		var selected_state: = id == selected_card_id
		var view: CardView = card_views[id]
		view.set_selected_state(selected_state)
		var target_y: = CARD_SELECTED_Y if selected_state else CARD_REST_Y
		if GameSettings.reduce_motion:
			view.position.y = target_y
		else:
			var tween: = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(view, "position:y", target_y, 0.18)


func _clear_selection(play_sound: = true) -> void :
	selection.clear()
	selected_card_id = ""
	target_ids.clear()
	_clear_targets()
	_set_play_enabled(false)
	$Layout / Actions / Discard.disabled = true
	$Layout / Actions / Discard.text = "选中卡牌后弃置"
	$Layout / Actions / Cancel.visible = false
	$Layout / Message.text = "点击卡牌使其上浮；悬停可查看用途、目标和使用时机。"
	_sync_card_states()
	if play_sound:
		AudioManager.click()


func _on_blank_input(event: InputEvent) -> void :
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		var redemption_overlay: = get_node_or_null("RedemptionOverlay")
		if redemption_overlay:
			redemption_overlay.queue_free()
			get_viewport().set_input_as_handled()
			return
		if selected_card_id.is_empty():
			_close()
		else:
			_clear_selection()
		get_viewport().set_input_as_handled()


func _play() -> void :
	if is_playing or selected_card_id.is_empty() or target_ids.is_empty():
		return
	is_playing = true
	var active: = GameState.active_player()
	var played_id: = selected_card_id
	var result: = Cards.play(str(active.id), played_id, target_ids[selected_target_index])
	if bool(result.get("requires_reaction_choice", false)):
		var choice: String = await _open_reaction_window(result)
		result = Cards.play(str(active.id), played_id, target_ids[selected_target_index], choice)
	if not bool(result.ok):
		is_playing = false
		_show_message(str(result.message), Color("e67a82"))
		return
	_set_play_enabled(false)
	$Layout / Actions / Cancel.disabled = true
	await animate_card_use(played_id, result)
	if bool(result.get("simulated", false)):
		_close()
		return
	if bool(result.get("requires_card_choice", false)):
		var chosen: = await _resolve_card_reward(str(active.id), result.get("reward_offer", []))
		result.reward_selected = chosen
		result.message = "已从三张红色明牌中收入两张"
	if bool(result.get("guarded", false)):
		AudioManager.guard()
	else:
		AudioManager.attack_hit() if str(result.get("effect_kind", "")).contains("attack") or int(result.get("damage", 0)) > 0 else AudioManager.card_play()
	_show_city_result("%s  %s" % [str(result.message), str(result.get("settlement", "效果已生效"))], bool(result.get("guarded", false)), bool(result.get("countered", false)))
	await _owned_delay(0.55 if not GameSettings.reduce_motion else 0.12)
	if int(active.get("strategy_points", 0)) > 0 and not active.hand.is_empty():
		is_playing = false
		$Layout / Actions / Cancel.disabled = false
		_rebuild()
		$Layout / Message.text = "卡牌已结算；本回合仍可继续使用策略卡。"
	else:
		_close()


func _open_reaction_window(data: Dictionary) -> String:
	var window: = ReactionWindow.new()
	add_child(window)
	window.open(data)
	return await window.resolved


func _build_v12_battlefield() -> void :
	if has_node("V12BattlefieldHUD"):
		return
	var hud: = HBoxContainer.new()
	hud.name = "V12BattlefieldHUD"
	hud.position = Vector2(36, 92)
	hud.size = Vector2(get_viewport_rect().size.x - 72, 64)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_theme_constant_override("separation", 14)
	add_child(hud)
	var active: = GameState.active_player()
	for spec: Array in [["SPEnergy", "策略点  ◆ %d/%d" % [int(active.get("strategy_points", 3)), int(active.get("strategy_points_max", 3))], Color("e7c45d")], ["SecretZone", "董事会秘策  ▣ %d/2" % active.get("secret_zone", []).size(), Color("9b7be5")], ["ContinuousZone", "持续策略  ◇ %d/2" % active.get("continuous_zone", []).size(), Color("63cdb0")], ["DiscardPile", "弃牌堆  %d" % active.get("discard", []).size(), Color("7695a1")]]:
		var chip: = PanelContainer.new();chip.name = str(spec[0]);chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL;chip.add_theme_stylebox_override("panel", Styles.panel(Color("081d2b"), spec[2], 14, 3)); var label: = Label.new();label.text = str(spec[1]);label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size", 16);label.add_theme_color_override("font_color", Color("edf6f4"));chip.add_child(label);hud.add_child(chip)


func _resolve_card_reward(player_id: String, offer: Array) -> Array[String]:
	if offer.is_empty():
		offer = GameState.player(player_id).get("pending_card_reward", {}).get("offer", [])
	if offer.is_empty():
		return []
	reward_overlay = RewardChoiceOverlay.new()
	reward_overlay.setup(player_id, offer)
	get_parent().add_child(reward_overlay)
	ModalManager.open_modal("strategy_hand", self, reward_overlay)
	var chosen: Array[String] = await reward_overlay.completed
	if is_instance_valid(reward_overlay):
		reward_overlay.queue_free()
	reward_overlay = null
	ModalManager.open_modal("strategy_hand", self, self)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	return chosen


func _resume_pending_reward() -> void :
	if is_playing or is_instance_valid(reward_overlay):
		return
	var active: = GameState.active_player()
	var pending: Dictionary = active.get("pending_card_reward", {})
	if pending.is_empty():
		return
	is_playing = true
	var chosen: = await _resolve_card_reward(str(active.get("id", "")), pending.get("offer", []))
	is_playing = false
	if chosen.size() == 2:
		_rebuild()
		_show_message("红色机密档案已恢复并完成：两张红卡已收入手牌", Color("e2bd66"))


func animate_card_use(card_id: String, result: = {}) -> void :
	var source: CardView = card_views.get(card_id) as CardView
	if source == null:
		return
	var accent: = source.selection_color()
	var stage: = Control.new()
	stage.name = "CardUseStage"
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.z_index = 300
	add_child(stage)
	var veil: = ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.01, 0.025, 0.04, 0.28)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(veil)
	var glow: = Control.new()
	glow.set_script(CardUseGlow)
	glow.size = Vector2(560, 560)
	glow.position = get_viewport_rect().size * 0.5 - glow.size * 0.5
	glow.call("setup", accent, source.size * 1.24)
	stage.add_child(glow)
	var effect_burst: = Control.new()
	effect_burst.set_script(CardEffectBurst)
	effect_burst.size = Vector2(760, 560)
	effect_burst.position = get_viewport_rect().size * 0.5 - effect_burst.size * 0.5
	effect_burst.call("setup", str(result.get("presentation", {}).get("animation", "card_settlement")), accent)
	stage.add_child(effect_burst)
	var flying: = CardScene.instantiate() as CardView
	flying.setup(GameConfig.by_id("cards", card_id))
	flying.size = source.size
	flying.custom_minimum_size = source.size
	flying.pivot_offset = flying.size * 0.5
	flying.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flying.position = source.get_global_rect().position
	stage.add_child(flying)
	stage.move_child(glow, stage.get_child_count() - 3)
	stage.move_child(effect_burst, stage.get_child_count() - 2)
	source.modulate.a = 0.0
	var center_target: = get_viewport_rect().size * 0.5 - flying.size * 0.5
	var flight_time: = 0.08 if GameSettings.reduce_motion else 0.34
	var tween: = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(flying, "position", center_target, flight_time)
	tween.tween_property(flying, "scale", Vector2(1.24, 1.24), flight_time)
	tween.tween_property(veil, "color:a", 0.54, flight_time)
	await tween.finished
	var status: = Label.new()
	status.position = Vector2(center_target.x - 180, center_target.y + flying.size.y * 1.26 + 34)
	status.size = Vector2(flying.size.x + 360, 54)
	status.text = "%s  ◆  %s\n%s" % [str(result.get("presentation", {}).get("headline", "卡牌已结算")), str(result.get("message", "效果已生效")), str(result.get("settlement", ""))]
	status.size.y = 82
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_color_override("font_color", Color("f4e5b3"))
	status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.86))
	status.add_theme_constant_override("outline_size", 6)
	stage.add_child(status)
	await _owned_delay(0.42 if not GameSettings.reduce_motion else 0.08)
	var finish: = create_tween().set_parallel(true)
	finish.tween_property(flying, "scale", Vector2(1.42, 1.42), 0.2)
	finish.tween_property(flying, "modulate:a", 0.0, 0.2)
	finish.tween_property(glow, "modulate:a", 0.0, 0.26)
	finish.tween_property(effect_burst, "modulate:a", 0.0, 0.26)
	finish.tween_property(status, "modulate:a", 0.0, 0.2)
	await finish.finished
	stage.queue_free()


func _owned_delay(seconds: float) -> void :
	var timer: = Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(0.001, seconds)
	add_child(timer)
	timer.start()
	await timer.timeout
	if is_instance_valid(timer):
		timer.queue_free()


func _show_city_result(message: String, guarded: bool, countered: bool) -> void :
	var color: = Color("e2bd66")
	if guarded:
		color = Color("63b8e5")
	if countered:
		color = Color("e67a82")
	_show_message(message, color)


func _show_message(message: String, color: Color) -> void :
	$Layout / Message.text = message
	$Layout / Message.add_theme_color_override("font_color", color)


func _style() -> void :
	var drawer_style: = Styles.panel(Color("081923fa"), Color("b28b46"), 20, 20)
	drawer_style.border_width_top = 3
	$Drawer.add_theme_stylebox_override("panel", drawer_style)
	Styles.apply_button($Layout / Header / Back, false, Color("3f9bb4"), 16)
	Styles.apply_button($Layout / Actions / Cancel, false, Color("5a8d9d"), 16)
	Styles.apply_button($Layout / Actions / Play, true, Color("d3aa55"), 18)
	Styles.apply_button($Layout / Actions / RedeemNormal, false, Color("3f9bb4"), 15)
	Styles.apply_button($Layout / Actions / RedeemRed, false, Color("a93343"), 15)
	for button: Button in [$Layout / Header / Back, $Layout / Actions / Cancel, $Layout / Actions / Play, $Layout / Actions / RedeemNormal, $Layout / Actions / RedeemRed]:
		button.mouse_entered.connect(AudioManager.hover)
	$Layout / Header / Title.add_theme_color_override("font_color", Color("f0f4ef"))
	$Layout / Header / Hint.add_theme_color_override("font_color", Color("8fb4ba"))
	$Layout / Header / Points.add_theme_color_override("font_color", Color("f0cf73"))
	$Layout / PointsGuide.add_theme_color_override("font_color", Color("9fc1c8"))
	$Layout / DiscardNotice.add_theme_color_override("font_color", Color("e2bd66"))
	$Layout / Message.add_theme_color_override("font_color", Color("c4d8dc"))


func _animate_open() -> void :
	if GameSettings.reduce_motion:
		return
	$Drawer.modulate.a = 0.0
	$Layout.modulate.a = 0.0
	var tween: = create_tween().set_parallel(true)
	tween.tween_property($Drawer, "modulate:a", 1.0, 0.18)
	tween.tween_property($Layout, "modulate:a", 1.0, 0.18)


func _close() -> void :
	if is_playing and has_node("CardUseStage"):
		return
	closed.emit()
	queue_free()


func _exit_tree() -> void :
	if is_instance_valid(reward_overlay):
		reward_overlay.queue_free()


func _set_play_enabled(value: bool) -> void :
	$Layout / Actions / Play.disabled = not value


func _clear_targets() -> void :
	for child in $Layout / Targets / TargetRow.get_children():
		child.queue_free()
	target_ids.clear()
	selected_target_index = 0


func _build_target_cards(legal: Array) -> void :
	_clear_targets()
	for target: Dictionary in legal:
		var index: = target_ids.size()
		target_ids.append(str(target.id))
		var target_button: = Button.new()
		target_button.set_script(TargetChoiceCardScript)
		target_button.setup(target)
		target_button.pressed.connect(_select_target.bind(index))
		target_button.mouse_entered.connect(AudioManager.hover)
		$Layout / Targets / TargetRow.add_child(target_button)
	_select_target(0)


func _select_target(index: int) -> void :
	selected_target_index = clampi(index, 0, maxi(0, target_ids.size() - 1))
	for child_index in range($Layout / Targets / TargetRow.get_child_count()):
		var target_button: = $Layout / Targets / TargetRow.get_child(child_index) as Button
		target_button.set_selected(child_index == selected_target_index)
