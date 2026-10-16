class_name OperatingDashboard
extends Control

const Styles = preload("res://scripts/UIStyles.gd")
const Risks = preload("res://scripts/RiskSystem.gd")
const Bank = preload("res://scripts/BankSystem.gd")
const BACKDROP = preload("res://assets/ui/operations/ai_operations_manager_v9186.png")

var player_id: = ""
var private_view: = true
var modal_token: = 0
var tutorial_context: = false


static func snapshot(target_player_id: String, include_private: = true) -> Dictionary:
	var player: = GameState.player(target_player_id)
	if player.is_empty():
		return {}
	var risk: = Risks.profile(target_player_id)
	var result: = {
		"player_id": target_player_id, 
		"player_name": str(player.get("name", "未知财团")), 
		"cash_label": "现金", "cash": int(player.get("cash", 0)), 
		"net_worth_label": "净资产", "asset_value": int(player.get("asset_value", 0)), 
		"debt_label": "负债", "debt": int(player.get("debt", 0)), 
		"risk_label": "风险", "risk": int(player.get("risk", 0)), 
		"risk_tier": str(risk.get("tier", "稳健")), 
		"risk_range": str(risk.get("range_text", "0–19")), 
		"business_count": player.get("business_ids", []).size(), 
		"land_count": player.get("land_ids", []).size(), 
		"talent_count": player.get("talent_ids", []).size(), 
		"rank": int(player.get("rank", 0)), 
	}
	if not include_private:
		return result
	var report: Dictionary = GameState.game_data.get("last_report", {}).get("players", {}).get(target_player_id, {})
	var audit: Dictionary = report.get("cash_audit", {})
	var before: = int(audit.get("opening_cash", report.get("cash_before", player.get("cash", 0))))
	var after: = int(audit.get("closing_cash", report.get("cash_after", player.get("cash", 0))))
	var last_round: = {
		"round": int(GameState.game_data.get("last_report", {}).get("round", 0)), 
		"cash_before": before, "cash_after": after, 
		"cash_change": int(audit.get("actual_change", report.get("cash_change", after - before))), 
		"asset_change": int(report.get("asset_change", 0)), 
		"business_income": int(report.get("business_income", 0)), 
		"talent_value": int(report.get("talent_value", 0)), 
		"traffic_income": int(report.get("traffic_income", 0)), 
		"control_income": int(report.get("control_income", 0)), 
		"competition_cost": int(report.get("competition_cost", 0)), 
		"loan_interest": int(report.get("loan_interest", report.get("interest", 0))), 
		"stock_pnl": int(report.get("stock_pnl", 0)), 
		"cash_audit": audit.duplicate(true), 
		"stock_activity": report.get("stock_activity", {}).duplicate(true), 
		"risk_change": int(report.get("risk_change", 0)), 
	}
	var estimated_business: = 0
	for business_id: String in player.get("business_ids", []):
		var business: Dictionary = GameState.game_data.get("businesses", {}).get(business_id, {})
		if str(business.get("state", "")) in ["operating", "loss_watch", "mortgaged"]:
			estimated_business += int(business.get("last_net", 0))
	result["estimated_business_income"] = estimated_business
	result["last_round"] = last_round
	result["income_sources"] = _cash_categories(audit, last_round)
	result["loan_summary"] = Bank.loan_summary(target_player_id)
	result["risk_profile"] = risk
	return result


static func _cash_categories(audit: Dictionary, fallback: Dictionary) -> Array[Dictionary]:
	var specs: Array[Dictionary] = [
		{"id": "operating", "label": "经营", "accent": "65d9a8"}, {"id": "investment", "label": "投资建设", "accent": "f1c85b"}, 
		{"id": "stock", "label": "证券交易", "accent": "63c8ef"}, {"id": "financing", "label": "融资还款", "accent": "ef8a68"}, 
		{"id": "event", "label": "事件卡牌", "accent": "b693f0"}, {"id": "other", "label": "其他", "accent": "8ca0ac"}, 
	]
	var buckets: Dictionary = audit.get("categories", {})
	if buckets.is_empty():
		return [{"label": "企业经营", "value": int(fallback.get("business_income", 0)), "accent": "65d9a8"}, {"label": "人才贡献", "value": int(fallback.get("talent_value", 0)), "accent": "f1c85b"}, {"label": "客流收益", "value": int(fallback.get("traffic_income", 0)), "accent": "63c8ef"}, {"label": "控制收益", "value": int(fallback.get("control_income", 0)), "accent": "b693f0"}]
	var result: Array[Dictionary] = []
	for spec: Dictionary in specs:
		var bucket: Dictionary = buckets.get(str(spec.id), {})
		result.append({"label": str(spec.label), "value": int(bucket.get("net", 0)), "inflow": int(bucket.get("inflow", 0)), "outflow": int(bucket.get("outflow", 0)), "accent": str(spec.accent)})
	return result


func open_for_player(target_player_id: String, include_private: = true) -> void :
	player_id = target_player_id
	private_view = include_private


func _ready() -> void :
	name = "OperatingDashboard"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("managed_modal_owner")
	modal_token = ModalManager.open_modal("operating_dashboard", self, self)
	tree_exiting.connect( func() -> void : ModalManager.close_modal(modal_token, "operating_dashboard_closed"))
	_build()


func _build() -> void :
	var data: = snapshot(player_id, private_view)
	var background: = TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = BACKDROP
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var tint: = ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.01, 0.025, 0.08, 0.28)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)
	var left_glass: = PanelContainer.new()
	left_glass.set_anchors_preset(Control.PRESET_FULL_RECT)
	left_glass.offset_left = 24;left_glass.offset_top = 22;left_glass.offset_right = - get_viewport_rect().size.x * 0.34;left_glass.offset_bottom = -22
	left_glass.add_theme_stylebox_override("panel", Styles.panel(Color(0.018, 0.045, 0.13, 0.94), Color("d8b45c"), 22, 10))
	add_child(left_glass)
	var margin: = MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	left_glass.add_child(margin)
	var column: = VBoxContainer.new();column.add_theme_constant_override("separation", 14);margin.add_child(column)
	var header: = HBoxContainer.new();column.add_child(header)
	var titles: = VBoxContainer.new();titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL;header.add_child(titles)
	titles.add_child(_label("CAPITAL COMMAND  AI 经营中枢", 13, Color("e9c96d")))
	titles.add_child(_label("经营驾驶舱", 34, Color("f6f2e8")))
	titles.add_child(_label("%s  第 %d 回合" % [str(data.get("player_name", "财团")), int(GameState.game_data.get("round", 0))], 17, Color("9fd9ef")))
	var close: = Button.new();close.name = "ReturnToCity";close.text = "返回城市";close.custom_minimum_size = Vector2(126, 48);Styles.apply_toy_button(close, true, Styles.TOY_YELLOW, 17);close.pressed.connect(_return_to_city);header.add_child(close)
	var rule: = HSeparator.new();rule.add_theme_color_override("color", Color("d5b45f"));column.add_child(rule)
	if tutorial_context:
		column.add_child(_tutorial_metric_legend())
	var hero: = HBoxContainer.new();hero.add_theme_constant_override("separation", 24);column.add_child(hero)
	_add_hero_metric(hero, "可用现金", int(data.get("cash", 0)), Color("65d9e8"), "本回合可支配")
	_add_hero_metric(hero, "净资产", int(data.get("asset_value", 0)), Color("65d9a8"), "当前排名 #%d" % int(data.get("rank", 0)))
	_add_hero_metric(hero, "银行负债", int(data.get("debt", 0)), Color("ef8a68"), "未偿本金")
	_add_hero_metric(hero, "风险指数", int(data.get("risk", 0)), Risks.tier_color(int(data.get("risk", 0))), str(data.get("risk_tier", "稳健")), false)
	if not private_view:
		column.add_child(_label("公开经营档案", 22, Color("e9c96d")))
		column.add_child(_label("企业 %d 家  土地 %d 块  人才 %d 位\n现金流、贷款账单与人才收益仅本组可见。" % [int(data.get("business_count", 0)), int(data.get("land_count", 0)), int(data.get("talent_count", 0))], 18, Color("d9e7ee")))
		return
	var last: Dictionary = data.get("last_round", {})
	var section: = HBoxContainer.new();section.size_flags_vertical = Control.SIZE_EXPAND_FILL;section.add_theme_constant_override("separation", 26);column.add_child(section)
	var flow: = VBoxContainer.new();flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL;flow.add_theme_constant_override("separation", 9);section.add_child(flow)
	flow.add_child(_label("上一轮资金轨迹", 22, Color("e9c96d")))
	var cash_delta: = int(last.get("cash_change", 0))
	var flow_line: = HBoxContainer.new();flow_line.add_theme_constant_override("separation", 10);flow.add_child(flow_line)
	flow_line.add_child(_flow_number("期初", int(last.get("cash_before", data.get("cash", 0))), Color("a8c0cb")))
	flow_line.add_child(_label("→", 28, Color("d5b45f")))
	flow_line.add_child(_flow_number("本轮变化", cash_delta, Color("65d9a8") if cash_delta >= 0 else Color("ef776f"), true))
	flow_line.add_child(_label("→", 28, Color("d5b45f")))
	flow_line.add_child(_flow_number("期末", int(last.get("cash_after", data.get("cash", 0))), Color("f4f0e5")))
	flow.add_child(_label("资金分类  与回合战报同一账本", 18, Color("b9d6df")))
	var max_source: = 1
	for source: Dictionary in data.get("income_sources", []): max_source = maxi(max_source, absi(int(source.get("value", 0))))
	for source: Dictionary in data.get("income_sources", []):
		flow.add_child(_source_bar(source, max_source))
	var outlook: = VBoxContainer.new();outlook.custom_minimum_size = Vector2(260, 0);outlook.add_theme_constant_override("separation", 10);section.add_child(outlook)
	outlook.add_child(_label("AI 经营经理", 22, Color("e9c96d")))
	var advice: = _manager_advice(data)
	var speech: = _label(advice, 17, Color("edf4f5"));speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;speech.custom_minimum_size = Vector2(0, 128);speech.add_theme_stylebox_override("normal", Styles.panel(Color(0.05, 0.1, 0.21, 0.88), Color("63c8ef"), 18, 7));outlook.add_child(speech)
	var trend: = int(last.get("asset_change", 0))
	outlook.add_child(_signal_line("净值趋势", "%+d 万" % trend, Color("65d9a8") if trend >= 0 else Color("ef776f")))
	outlook.add_child(_signal_line("下轮经营预测", "%+d 万" % int(data.get("estimated_business_income", 0)), Color("f1c85b")))
	outlook.add_child(_signal_line("风险区间", "%s  %s" % [str(data.get("risk_tier", "稳健")), str(data.get("risk_range", "0–19"))], Risks.tier_color(int(data.get("risk", 0)))))


func _tutorial_metric_legend() -> Control:
	var panel: = PanelContainer.new()
	panel.name = "TutorialMetricLegend"
	panel.add_theme_stylebox_override("panel", Styles.panel(Color("0b3040"), Color("63c8ef"), 16, 2))
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	for item: Array in [
		["现金", "决定本回合能否买地、建设、招聘与还款", Color("65d9e8")], 
		["净资产", "决定当前排名与最终胜负", Color("65d9a8")], 
		["负债", "产生利息；终局未结清会直接扣减", Color("ef8a68")], 
		["风险", "提高成本并折损终局净值", Color("e87876")], 
	]:
		var box: = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(_label(str(item[0]), 17, item[2] as Color))
		var explanation: = _label(str(item[1]), 13, Color("dbe8eb"))
		explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(explanation)
		row.add_child(box)
	return panel


func _return_to_city() -> void :
	if tutorial_context and TutorialDirector.active:
		TutorialDirector.resume_from_auxiliary("operating_dashboard", "dashboard_reviewed")
	tutorial_context = false
	queue_free()


func _manager_advice(data: Dictionary) -> String:
	var debt: = int(data.get("debt", 0)); var risk: = int(data.get("risk", 0)); var cash: = int(data.get("cash", 0))
	if risk >= 60: return "风险已经进入危险区。\n先降低风险，再进行扩张；避免新增高波动资产。"
	if debt > cash: return "负债高于可用现金。\n优先保留本轮应还款，再选择收益稳定的经营动作。"
	if int(data.get("business_count", 0)) == 0: return "当前还没有经营中的企业。\n先完成一块土地建设，让现金开始产生持续收益。"
	return "经营状态稳定。\n可以围绕高收益街区扩张，并把人才安排到已运营企业。"


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label: = Styles.label(text_value, font_size, color);return label


func _add_hero_metric(parent: HBoxContainer, title: String, value: int, color: Color, note: String, money: = true) -> void :
	var box: = VBoxContainer.new();box.size_flags_horizontal = Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation", 1);parent.add_child(box)
	box.add_child(_label(title, 14, Color("9eb7c4")))
	box.add_child(_label(Styles.money(value) if money else str(value), 29, color))
	box.add_child(_label(note, 12, Color("c5d2d7")))


func _flow_number(title: String, value: int, color: Color, signed: = false) -> VBoxContainer:
	var box: = VBoxContainer.new();box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_label(title, 13, Color("94aeb9")))
	box.add_child(_label(("%+d 万" % value) if signed else Styles.money(value), 23, color))
	return box


func _source_bar(source: Dictionary, maximum: int) -> Control:
	var row: = HBoxContainer.new();row.custom_minimum_size = Vector2(0, 36);row.add_theme_constant_override("separation", 10)
	var name_label: = _label(str(source.get("label", "收益")), 15, Color("d8e4e8"));name_label.custom_minimum_size.x = 82;row.add_child(name_label)
	var bar: = ProgressBar.new();bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL;bar.max_value = maximum;bar.value = absi(int(source.get("value", 0)));bar.show_percentage = false
	var accent: = Color(str(source.get("accent", "65d9a8"))); var bg: = StyleBoxFlat.new();bg.bg_color = Color(0.04, 0.1, 0.17, 0.72);bg.set_corner_radius_all(8); var fill: = StyleBoxFlat.new();fill.bg_color = accent;fill.set_corner_radius_all(8);bar.add_theme_stylebox_override("background", bg);bar.add_theme_stylebox_override("fill", fill);row.add_child(bar)
	var value_label: = _label("净 %+d" % int(source.get("value", 0)), 17, accent);value_label.custom_minimum_size.x = 84;value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT;row.add_child(value_label)
	return row


func _signal_line(title: String, value: String, accent: Color) -> Control:
	var row: = HBoxContainer.new();row.custom_minimum_size.y = 42
	var title_label: = _label(title, 14, Color("a8bec8"));title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL;row.add_child(title_label)
	row.add_child(_label(value, 17, accent));return row
