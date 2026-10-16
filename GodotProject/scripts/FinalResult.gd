extends Control

const UIStyles = preload("res://scripts/UIStyles.gd")
const ScreenDecorator = preload("res://scripts/V7ScreenDecorator.gd")
const Settlement = preload("res://scripts/TurnSettlement.gd")
const CompositionBar = preload("res://scripts/FinalCompositionBar.gd")
const Risks = preload("res://scripts/RiskSystem.gd")
const CelebrationCanvas = preload("res://scripts/FinalCelebrationCanvas.gd")
const MedalBadge = preload("res://scripts/FinalMedalBadge.gd")

var podium_page: VBoxContainer
var ranking_page: VBoxContainer


func _ready() -> void :
	ScreenDecorator.decorate(self, "final")

	$Backdrop.z_index = 1
	$BG.z_index = 2
	$BG.color = Color(0.008, 0.025, 0.045, 0.12)
	$Layout.z_index = 10
	_build_champion_atmosphere()
	_build_victory_confetti()
	AudioManager.victory()
	var report: Dictionary = Settlement.finalize_match()
	var players: Array = GameState.game_data.players.duplicate()
	players.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		var av: = int(report.get("players", {}).get(str(a.get("id", "")), {}).get("final_value", a.get("asset_value", 0)))
		var bv: = int(report.get("players", {}).get(str(b.get("id", "")), {}).get("final_value", b.get("asset_value", 0)))
		return av > bv)
	$Layout / Kicker.text = "CITY CROWN  本局城市资本授勋"
	$Layout / Title.text = "最终资本版图"
	$Layout / Formula.text = "冠军由最终净值决定  现金 + 经营资产 + 投资资产 − 负债 − 风险惩罚"
	$Layout.move_child($Layout / Kicker, 0)
	var results_root: = $Layout / ResultsScroll / Results as VBoxContainer
	for child in results_root.get_children():
		child.queue_free()
	podium_page = VBoxContainer.new()
	podium_page.name = "PodiumPage"
	podium_page.add_theme_constant_override("separation", 12)
	results_root.add_child(podium_page)
	podium_page.add_child(_champion_podium(players, report))
	if not players.is_empty():
		var champion: Dictionary = players[0]
		podium_page.add_child(_winner_metric_ribbon(champion, report.get("players", {}).get(str(champion.id), {})))
	podium_page.add_child(_ranking_details_toggle())
	ranking_page = VBoxContainer.new()
	ranking_page.name = "RankingPage"
	ranking_page.visible = false
	ranking_page.add_theme_constant_override("separation", 12)
	results_root.add_child(ranking_page)
	ranking_page.add_child(_ranking_page_header())
	var detail_holder: = VBoxContainer.new()
	detail_holder.name = "DetailedStandings"
	detail_holder.add_theme_constant_override("separation", 10)
	ranking_page.add_child(detail_holder)
	for index in players.size():
		var player: Dictionary = players[index]
		var result: Dictionary = report.get("players", {}).get(str(player.id), {})
		detail_holder.add_child(_standing_card(player, result, index + 1))
	ranking_page.add_child(_back_to_podium_button())
	UIStyles.apply_toy_button($Layout / Menu, true, UIStyles.TOY_YELLOW, 20)
	$Layout / Menu.text = "完成本局  返回主菜单"
	$Layout / Menu.pressed.connect( func() -> void :
		GameState.reset()
		GameFlow.go("menu"))


func _build_champion_atmosphere() -> void :
	var effect: = CelebrationCanvas.new()
	effect.name = "ChampionAtmosphere"
	effect.z_index = 5
	add_child(effect)
	move_child(effect, $Layout.get_index())


func _build_victory_confetti() -> void :
	var layer: = Control.new()
	layer.name = "VictoryConfetti"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 30
	add_child(layer)
	var colors: = [Color("f2c85d"), Color("5fd0b1"), Color("59b8d5"), Color("ef7d86")]
	var viewport: = get_viewport_rect().size
	for index in range(28):
		var piece: = ColorRect.new()
		piece.color = colors[index % colors.size()]
		piece.size = Vector2(6 + index % 4 * 2, 14 + index % 3 * 3)
		piece.position = Vector2(fmod(float(index * 137), maxf(1.0, viewport.x)), -30.0 - float(index % 7) * 34.0)
		piece.rotation = float(index) * 0.67
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(piece)
		if not bool(GameSettings.reduce_motion):
			var tween: = piece.create_tween().set_loops()
			tween.tween_property(piece, "position:y", viewport.y + 50.0, 4.2 + float(index % 6) * 0.48).set_delay(float(index % 9) * 0.16)
			tween.parallel().tween_property(piece, "rotation", piece.rotation + TAU * 2.5, 4.2 + float(index % 6) * 0.48)
			tween.tween_property(piece, "position:y", -50.0, 0.0)


func _champion_podium(players: Array, report: Dictionary) -> Control:
	var podium: = HBoxContainer.new()
	podium.name = "ChampionPodium"
	podium.custom_minimum_size.y = 430
	podium.alignment = BoxContainer.ALIGNMENT_END
	podium.add_theme_constant_override("separation", 22)
	var order: = [1, 0, 2]
	for player_index in order:
		if player_index >= players.size():
			continue
		var player: Dictionary = players[player_index]
		var result: Dictionary = report.get("players", {}).get(str(player.id), {})
		podium.add_child(_podium_card(player, result, player_index + 1))
	return podium


func _podium_card(player: Dictionary, result: Dictionary, rank: int) -> PanelContainer:
	var accent: = Color("e4bf5d") if rank == 1 else Color("aabcc4") if rank == 2 else Color("c8895c")
	var card: = PanelContainer.new()
	card.name = "Podium%d" % rank
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 382 if rank == 1 else 310 if rank == 2 else 278)
	var plinth: = StyleBoxFlat.new()
	plinth.bg_color = Color(0.035, 0.105, 0.135, 0.92 if rank == 1 else 0.8)
	plinth.border_color = accent
	plinth.set_border_width_all(2)
	plinth.border_width_bottom = 12 if rank == 1 else 7
	plinth.set_corner_radius_all(18)
	plinth.shadow_color = Color(0, 0, 0, 0.38)
	plinth.shadow_size = 28 if rank == 1 else 14
	if rank == 1:
		plinth.shadow_color = Color(1.0, 0.73, 0.22, 0.34)
	card.add_theme_stylebox_override("panel", plinth)
	var box: = VBoxContainer.new();box.alignment = BoxContainer.ALIGNMENT_CENTER;box.add_theme_constant_override("separation", 8);card.add_child(box)
	var medal: = MedalBadge.new()
	medal.setup(rank)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(medal)
	var title: = UIStyles.label("冠军" if rank == 1 else "亚军" if rank == 2 else "季军", 20, accent);title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;box.add_child(title)
	var name_label: = UIStyles.label(str(player.get("name", "财团")), 25 if rank == 1 else 21, Color("f5eee0"));name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;box.add_child(name_label)
	var net: = UIStyles.label(UIStyles.money(int(result.get("final_value", 0))), 32 if rank == 1 else 26, Color("65d39f"));net.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;box.add_child(net)
	var risk: = int(result.get("risk", 0))
	var risk_label: = UIStyles.label("风险 %d  %s" % [risk, Risks.tier_name(risk)], 15, Risks.tier_color(risk));risk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;box.add_child(risk_label)
	return card


func _winner_metric_ribbon(player: Dictionary, result: Dictionary) -> Control:
	var ribbon: = HBoxContainer.new()
	ribbon.name = "ChampionMetricRibbon"
	ribbon.custom_minimum_size.y = 82
	ribbon.add_theme_constant_override("separation", 8)
	var values: = [
		["净值", UIStyles.money(int(result.get("final_value", 0))), Color("65d39f")], 
		["现金", UIStyles.money(int(result.get("cash_after", 0))), Color("dfbd63")], 
		["地产", "%d 块" % player.get("land_ids", []).size(), Color("64b8a7")], 
		["企业", "%d 家" % player.get("business_ids", []).size(), Color("63a8d2")], 
		["股票", UIStyles.money(int(result.get("stock_value", 0))), Color("8a9cdb")], 
		["负债", UIStyles.money(int(result.get("residual_debt", 0))), Color("ef7d86")], 
		["风险", "%d  %s" % [int(result.get("risk", 0)), Risks.tier_name(int(result.get("risk", 0)))], Risks.tier_color(int(result.get("risk", 0)))], 
	]
	for spec: Array in values:
		var chip: = VBoxContainer.new();chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label: = UIStyles.label(str(spec[0]), 13, Color("a6bbc1"));label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;chip.add_child(label)
		var value: = UIStyles.label(str(spec[1]), 20, spec[2]);value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;chip.add_child(value)
		ribbon.add_child(chip)
	return ribbon


func _ranking_details_toggle() -> Button:
	var toggle: = Button.new()
	toggle.name = "RankingDetailsToggle"
	toggle.text = "查看全部排名  →"
	toggle.custom_minimum_size = Vector2(340, 46)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIStyles.apply_toy_button(toggle, false, UIStyles.TOY_BLUE, 16)
	toggle.pressed.connect( func() -> void :
		_show_ranking_page())
	return toggle


func _ranking_page_header() -> PanelContainer:
	var panel: = PanelContainer.new()
	panel.name = "RankingHeader"
	panel.custom_minimum_size = Vector2(0, 92)
	panel.add_theme_stylebox_override("panel", UIStyles.panel(Color("0b2834"), Color("d7b65e"), 16, 3))
	var margin: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	panel.add_child(margin)
	var row: = HBoxContainer.new()
	margin.add_child(row)
	var title: = UIStyles.label("完整资本排名", 28, Color("f4e7c8"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var hint: = UIStyles.label("前三名保留奖牌色，其余按财团色展示净值结构", 16, Color("9fc8d2"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(hint)
	return panel


func _back_to_podium_button() -> Button:
	var back: = Button.new()
	back.name = "BackToPodium"
	back.text = "返回前三名颁奖台"
	back.custom_minimum_size = Vector2(340, 46)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIStyles.apply_toy_button(back, false, UIStyles.TOY_YELLOW, 16)
	back.pressed.connect(_show_podium_page)
	return back


func _show_ranking_page() -> void :
	if podium_page != null:
		podium_page.visible = false
	if ranking_page != null:
		ranking_page.visible = true
	AudioManager.click()


func _show_podium_page() -> void :
	if podium_page != null:
		podium_page.visible = true
	if ranking_page != null:
		ranking_page.visible = false
	AudioManager.click()


func _standing_card(player: Dictionary, result: Dictionary, rank: int) -> PanelContainer:
	var accent: = Color(str(player.get("color", "#5aa9d6")))
	var final_value: = int(result.get("final_value", player.get("asset_value", 0)))
	var card: = PanelContainer.new()
	card.name = "RankCard%d" % rank
	card.custom_minimum_size = Vector2(0, 286)
	card.set_meta("breakdown_component_count", 7)
	card.add_theme_stylebox_override("panel", UIStyles.panel(Color("0a2632"), Color(accent, 0.82), 18, 3 if rank > 1 else 5))
	var margin: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	card.add_child(margin)
	var stack: = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	var header: = HBoxContainer.new()
	stack.add_child(header)
	if rank <= 3:
		var badge: = MedalBadge.new()
		badge.setup(rank)
		badge.custom_minimum_size = Vector2(72, 72)
		header.add_child(badge)
	else:
		var rank_label: = UIStyles.label("#%d" % rank, 30, accent.lightened(0.28))
		rank_label.custom_minimum_size = Vector2(52, 0)
		header.add_child(rank_label)
	var identity: = VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	identity.add_child(UIStyles.label(str(player.get("name", "财团")), 25, Color("edf4f5")))
	var risk: = int(result.get("risk", 0))
	var state: = UIStyles.label("风险 %d  %s" % [risk, Risks.tier_name(risk)], 16, Risks.tier_color(risk))
	state.set_meta("final_body", true)
	identity.add_child(state)
	var net: = UIStyles.label("最终净值  %s" % UIStyles.money(final_value), 28, Color("64d7a2") if final_value >= 0 else Color("ef7883"))
	net.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	net.custom_minimum_size = Vector2(300, 0)
	header.add_child(net)

	var breakdown: = HBoxContainer.new()
	breakdown.name = "Breakdown"
	breakdown.add_theme_constant_override("separation", 8)
	stack.add_child(breakdown)
	_add_metric(breakdown, "现金", int(result.get("cash_after", 0)), "可自由支配", Color("d9b557"))
	_add_metric(breakdown, "经营资产", int(result.get("property_value", 0)), "土地与企业", Color("63b8a5"))
	_add_metric(breakdown, "投资资产", int(result.get("stock_value", 0)) + int(result.get("project_value", 0)) + int(result.get("enterprise_value", 0)), "证券  创投  公司", Color("7fa8d7"))
	_add_metric(breakdown, "扣减合计", - int(result.get("residual_debt", 0)) - int(result.get("risk_penalty", 0)), "负债与风险", Color("ef7d86"))

	var composition: = CompositionBar.new()
	composition.name = "NetValueComposition"
	composition.set_segments([
		{"value": maxi(0, int(result.get("cash_after", 0))), "color": Color("d9b557")}, 
		{"value": maxi(0, int(result.get("property_value", 0))), "color": Color("63b8a5")}, 
		{"value": maxi(0, int(result.get("stock_value", 0))), "color": Color("6aa7ce")}, 
		{"value": maxi(0, int(result.get("project_value", 0)) + int(result.get("enterprise_value", 0))), "color": Color("bd8bd2")}, 
	])
	stack.add_child(composition)
	stack.add_child(_liquidation_track(result))
	var detail: = _detail_drawer(result)
	stack.add_child(detail)
	return card


func _liquidation_track(result: Dictionary) -> Control:
	var track: = HBoxContainer.new()
	track.name = "LiquidationTrack"
	track.add_theme_constant_override("separation", 8)
	var debt_before: = int(result.get("debt_before", 0))
	var recovery: = int(result.get("property_recovery", 0)) + int(result.get("stock_recovery", 0)) + int(result.get("project_recovery", 0))
	_add_flow_step(track, "清算前债务", debt_before, Color("ef8a81"))
	_add_flow_arrow(track)
	_add_flow_step(track, "现金偿还", int(result.get("cash_applied", 0)), Color("d9b557"))
	_add_flow_arrow(track)
	_add_flow_step(track, "折价处置", recovery, Color("6ab9aa"))
	_add_flow_arrow(track)
	_add_flow_step(track, "残余负债", int(result.get("residual_debt", 0)), Color("ef7883") if int(result.get("residual_debt", 0)) > 0 else Color("64d7a2"))
	var status: = UIStyles.label(_settlement_status(result), 16, Color("ef7883") if int(result.get("residual_debt", 0)) > 0 else Color("64d7a2"))
	status.custom_minimum_size = Vector2(240, 0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.set_meta("final_body", true)
	track.add_child(status)
	return track


func _detail_drawer(result: Dictionary) -> VBoxContainer:
	var holder: = VBoxContainer.new()
	holder.name = "SettlementDetails"
	var detail: = UIStyles.label("证券 %s  创投 %s  公司估值 %s  风险扣减 %s" % [
		UIStyles.money(int(result.get("stock_value", 0))), UIStyles.money(int(result.get("project_value", 0))), 
		UIStyles.money(int(result.get("enterprise_value", 0))), UIStyles.money(int(result.get("risk_penalty", 0))), 
	], 16, Color("b7cbd0"))
	detail.name = "ExpandedDetail"
	detail.visible = false
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.set_meta("final_body", true)
	holder.add_child(detail)
	var toggle: = Button.new()
	toggle.name = "ToggleDetails"
	toggle.text = "展开资产细项"
	toggle.custom_minimum_size = Vector2(210, 38)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIStyles.apply_toy_button(toggle, false, UIStyles.TOY_BLUE, 15)
	toggle.pressed.connect( func() -> void :
		detail.visible = not detail.visible
		toggle.text = "收起资产细项" if detail.visible else "展开资产细项")
	holder.add_child(toggle)
	return holder


func _add_metric(parent: HBoxContainer, title: String, value: int, note: String, accent: Color) -> void :
	var metric: = VBoxContainer.new()
	metric.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metric.custom_minimum_size = Vector2(0, 64)
	metric.add_child(UIStyles.label(title, 15, Color("9fb6bf")))
	var amount: = UIStyles.label("%s%s" % ["+" if value > 0 else "", UIStyles.money(value)], 24, accent)
	amount.set_meta("final_body", true)
	metric.add_child(amount)
	var note_label: = UIStyles.label(note, 16, Color("829ca5"))
	note_label.set_meta("final_body", true)
	metric.add_child(note_label)
	parent.add_child(metric)


func _add_hero_pill(parent: HBoxContainer, title: String, value: String, accent: Color) -> void :
	var pill: = HBoxContainer.new()
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.add_theme_constant_override("separation", 8)
	var mark: = ColorRect.new()
	mark.custom_minimum_size = Vector2(5, 34)
	mark.color = accent
	pill.add_child(mark)
	var text: = UIStyles.label("%s\n%s" % [title, value], 15, Color("dce8e9"))
	pill.add_child(text)
	parent.add_child(pill)


func _add_flow_step(parent: HBoxContainer, title: String, value: int, accent: Color) -> void :
	var step: = VBoxContainer.new()
	step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step.add_child(UIStyles.label(title, 14, Color("91aab2")))
	var amount: = UIStyles.label(UIStyles.money(value), 20, accent)
	amount.set_meta("final_body", true)
	step.add_child(amount)
	parent.add_child(step)


func _add_flow_arrow(parent: HBoxContainer) -> void :
	var arrow: = UIStyles.label("›", 24, Color("688690"))
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(arrow)


func _champion_verdict(player: Dictionary, result: Dictionary) -> String:
	var value: = int(result.get("final_value", 0))
	var debt: = int(result.get("residual_debt", 0))
	if debt > 0:
		return "以最高净值胜出，但仍有残余负债需要关注"
	if int(result.get("risk", 0)) >= 60:
		return "以扩张速度取得领先，风险控制是下一局关键"
	return "资产结构与现金留存更均衡，赢得本局城市经营"


func _settlement_status(result: Dictionary) -> String:
	match str(result.get("settlement_status", "no_debt")):
		"cash_cleared": return "现金清偿  已结清"
		"assets_cleared": return "折价处置  已结清"
		"residual_debt": return "资产已处置  仍负债"
		_: return "无需强制清算"


func presentation_profile() -> Dictionary:
	var holder: = get_node_or_null("Layout/ResultsScroll/Results/RankingPage/DetailedStandings") as Control
	return {
		"hero_stage": has_node("Layout/ResultsScroll/Results/PodiumPage/ChampionPodium"), 
		"champion_podium": has_node("Layout/ResultsScroll/Results/PodiumPage/ChampionPodium"), 
		"victory_confetti": has_node("VictoryConfetti"), 
		"ranking_page": has_node("Layout/ResultsScroll/Results/RankingPage"), 
		"standing_cards": 0 if holder == null else holder.get_child_count(), 
		"core_metrics": ["现金", "经营资产", "投资资产", "扣减合计"], 
		"liquidation_flow": ["清算前债务", "现金偿还", "折价处置", "残余负债"], 
	}


func debug_final_result_summary() -> Dictionary:
	var results: = get_node_or_null("Layout/ResultsScroll/Results/RankingPage/DetailedStandings") as Control
	var results_board: = get_node_or_null("Layout/ResultsScroll/Results") as Control
	var cards_with_breakdown: = 0
	var component_count: = 0
	var body_font_min: = 0
	if results != null:
		for card: Node in results.get_children():
			if card.find_child("Breakdown", true, false) != null:
				cards_with_breakdown += 1
				component_count = maxi(component_count, int(card.get_meta("breakdown_component_count", 0)))
			for label: Node in card.find_children("*", "Label", true, false):
				if bool(label.get_meta("final_body", false)):
					var font_size: = (label as Label).get_theme_font_size("font_size")
					body_font_min = font_size if body_font_min == 0 else mini(body_font_min, font_size)
	return {
		"card_count": 0 if results == null else results.get_child_count(), 
		"cards_with_breakdown": cards_with_breakdown, 
		"breakdown_component_count": component_count, 
		"body_font_min": body_font_min, 
		"results_width_ratio": 0.0 if results_board == null or size.x <= 0.0 else results_board.size.x / size.x, 
	}
