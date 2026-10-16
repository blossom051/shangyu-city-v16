extends PanelContainer

signal business_chosen(type_id: String)

const Styles = preload("res://scripts/UIStyles.gd")
const BusinessOfferCardScript = preload("res://scripts/BusinessOfferCard.gd")
const Recommendations = preload("res://scripts/BusinessRecommendationEngine.gd")
const Businesses = preload("res://scripts/BusinessSystem.gd")

var land_id: = ""
var tutorial_mode: = false
var recommended_card: Control
var sticky_recommendation: Button


func _ready() -> void :
	add_theme_stylebox_override("panel", Styles.toy_panel())
	Styles.apply_toy_button($Layout / Header / Close, false, Styles.TOY_BLUE, 16)
	$Layout / Header / Close.pressed.connect(queue_free)
	$Layout / Header / Close.mouse_entered.connect(AudioManager.hover)
	var land: Dictionary = GameState.game_data.lands.get(land_id, {})
	$Layout / Header / Title.text = "%s  投资建设" % str(land.get("district_name", land_id))
	$Layout / Header / Title.add_theme_color_override("font_color", Styles.TOY_INK)
	$Layout / Guide.add_theme_color_override("font_color", Color("9fb8c1"))
	var first_button: Button
	var ranked: Array = Recommendations.rank_for_land(land)
	for result: Dictionary in ranked:
		var business: Dictionary = result.business
		var display_business: = business.duplicate(true)
		var quote: = Businesses.business_build_quote(str(GameState.active_player().get("id", "")), str(business.get("id", "")))
		display_business.display_cost = int(quote.get("total", business.get("cost", 0)))
		display_business.risk_surcharge = int(quote.get("risk_surcharge", 0))
		var button: = Button.new()
		button.set_script(BusinessOfferCardScript)
		button.setup(display_business, land, result)
		button.disabled = not tutorial_mode and int(GameState.active_player().cash) < int(display_business.display_cost)
		button.mouse_entered.connect(AudioManager.hover)
		button.pressed.connect( func() -> void :
			AudioManager.click()
			business_chosen.emit(str(business.id))
			queue_free())
		$Layout / Scroll / Businesses.add_child(button)
		if bool(result.get("recommended", false)) and recommended_card == null:
			recommended_card = button
		if first_button == null and not button.disabled:
			first_button = button
	_build_sticky_recommendation(ranked)
	if tutorial_mode and first_button != null:
		TutorialDirector.call_deferred("focus_build_choice", first_button)


func _build_sticky_recommendation(ranked: Array) -> void :
	if ranked.is_empty():
		return
	var best: Dictionary = ranked[0]
	for result: Dictionary in ranked:
		if bool(result.get("recommended", false)):
			best = result
			break
	var business: Dictionary = best.get("business", {})
	sticky_recommendation = Button.new()
	sticky_recommendation.name = "StickyRecommendation"
	sticky_recommendation.custom_minimum_size = Vector2(0, 58)
	sticky_recommendation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sticky_recommendation.text = "街区首选  ◈  %s      预计净收益 +%d 万/回合      点击定位卡牌" % [
		str(business.get("name", "推荐方案")), int(best.get("adjusted_net", 0)), 
	]
	sticky_recommendation.tooltip_text = str(best.get("reason", "最适合当前街区的经营方案"))
	Styles.apply_toy_button(sticky_recommendation, true, Styles.TOY_YELLOW, 17)
	sticky_recommendation.pressed.connect(_focus_recommended_card)
	$Layout.add_child(sticky_recommendation)
	$Layout.move_child(sticky_recommendation, $Layout / Scroll.get_index())


func _focus_recommended_card() -> void :
	if recommended_card == null or not is_instance_valid(recommended_card):
		return
	$Layout / Scroll.ensure_control_visible(recommended_card)
	recommended_card.grab_focus()
