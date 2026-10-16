extends Control

const Styles = preload("res://scripts/UIStyles.gd")
const Bank = preload("res://scripts/BankSystem.gd")
const Settlement = preload("res://scripts/TurnSettlement.gd")
const Risks = preload("res://scripts/RiskSystem.gd")
const ReportBuilder = preload("res://scripts/RoundReportBuilder.gd")
const ForcedCollectionAlertScene = preload("res://scripts/ForcedCollectionAlert.gd")
const DelinquencyBankruptcyDialogScene = preload("res://scripts/DelinquencyBankruptcyDialog.gd")

var profile: Dictionary = {}
var compact_layer: PanelContainer
var compact_content: Control
var details_button: Button
var ledger_player_tabs: HBoxContainer
var selected_ledger_player_id: = ""


func _ready() -> void :
	_apply_responsive_layout()
	AudioManager.settlement()
	profile = presentation_profile()
	selected_ledger_player_id = str(profile.get("player_id", ""))
	_create_ledger_player_tabs()
	_build()
	_build_compact_layer()
	if EndlessOperationsSystem.is_final_round():
		$Layout / Continue.text = "进行终局债务清算"
	else:
		var starter: = ReportBuilder.next_round_starter()
		$Layout / Continue.text = "确认战报  第%d组先行" % int(starter.get("group_number", 1))
	Styles.apply_toy_button($Layout / Continue, true, Color("e5bd59"), 19)
	$Layout / Continue.mouse_entered.connect(AudioManager.hover);$Layout / Continue.pressed.connect(_continue)
	if not _pending_bankruptcy_notice().is_empty():
		call_deferred("_show_bankruptcy_notice")


func _apply_responsive_layout() -> void :
	if get_viewport_rect().size.y >= 900.0: return
	$Layout.offset_left = 20;$Layout.offset_top = 8;$Layout.offset_right = -20;$Layout.offset_bottom = -8;$Layout.add_theme_constant_override("separation", 6)
	$Layout / Header.custom_minimum_size.y = 44;$Layout / Header / Titles / Title.add_theme_font_size_override("font_size", 24);$Layout / Header / Outcome.custom_minimum_size = Vector2(320, 44);$Layout / Header / Outcome.add_theme_font_size_override("font_size", 17);$Layout / KpiStrip.custom_minimum_size.y = 76;$Layout / Continue.custom_minimum_size.y = 48
	$Layout / Main / InsightRail.custom_minimum_size.x = 292


func presentation_profile() -> Dictionary:
	var player: = _focus_player()
	return presentation_profile_for_player(str(player.get("id", "")))


func presentation_profile_for_player(player_id: String) -> Dictionary:
	var report: Dictionary = GameState.game_data.get("last_report", {}); var player: = _player_by_id(player_id)
	if player.is_empty(): return {}
	var item: Dictionary = report.get("players", {}).get(str(player.id), {}); var audit: Dictionary = item.get("cash_audit", {}); var cash_before: = int(audit.get("opening_cash", item.get("cash_before", player.get("cash", 0)))); var cash_after: = int(audit.get("closing_cash", item.get("cash_after", player.get("cash", 0)))); var asset_change: = int(item.get("asset_change", 0)); var cash_change: = int(audit.get("actual_change", item.get("cash_change", cash_after - cash_before))); var risk: = Risks.profile(str(player.id)); var rank_after: = int(item.get("rank_after", player.get("rank", 0))); var rank_change: = int(item.get("rank_change", 0))
	var cash_categories: = _cash_categories(audit, item)
	var stock_activity: Dictionary = item.get("stock_activity", {})
	return {
		"round": int(report.get("round", GameState.game_data.get("round", 0))), "player_id": str(player.id), "player_name": str(player.name), 
		"headline": "净资产 %s%d 万  排名 #%d" % ["+" if asset_change >= 0 else "", asset_change, rank_after], "evaluation": _evaluation(asset_change, int(player.risk)), 
		"core_metrics": [
			{"label": "本轮排名", "value": "#%d" % rank_after, "note": "%s%d 位" % ["上升 " if rank_change > 0 else "下降 " if rank_change < 0 else "保持 ", abs(rank_change)], "accent": "e5bd59"}, 
			{"label": "净资产变化", "value": "%+d 万" % asset_change, "note": "当前 %s" % Styles.money(int(item.get("asset_after", player.asset_value))), "accent": "5fc99c" if asset_change >= 0 else "e06e6d"}, 
			{"label": "现金变化", "value": "%+d 万" % cash_change, "note": "%s → %s" % [Styles.money(cash_before), Styles.money(cash_after)], "accent": "5eb5d6" if cash_change >= 0 else "e48a63"}, 
			{"label": "负债 / 风险", "value": "%s / %d" % [Styles.money(int(item.get("debt_after", player.debt))), int(player.risk)], "note": "%s  风险 %+d" % [str(risk.get("tier", "稳健")), int(item.get("risk_change", 0))], "accent": str(risk.get("tier_color", Color("d6ad54")).to_html())}, 
		], 
		"income_sources": cash_categories, 
		"outflows": [{"label": "竞争成本", "value": int(item.get("competition_cost", 0))}, {"label": "贷款利息", "value": int(item.get("interest", 0))}, {"label": "偿还本金", "value": int(item.get("loan_principal_paid", 0))}], 
		"cash_audit": audit, "stock_activity": stock_activity, 
		"talent_value": int(item.get("talent_value", 0)), "business_lines": item.get("lines", []).duplicate(true), "loan_settlement": item.get("loan_settlement", {}).duplicate(true), "risk_profile": risk, "raw": item, 
	}


func _create_ledger_player_tabs() -> void :
	ledger_player_tabs = HBoxContainer.new()
	ledger_player_tabs.name = "LedgerPlayerTabs"
	ledger_player_tabs.add_theme_constant_override("separation", 8)
	ledger_player_tabs.visible = false
	var group: = ButtonGroup.new()
	for player: Dictionary in GameState.game_data.players:
		var button: = Button.new()
		button.name = "LedgerGroup%s" % str(player.get("id", ""))
		button.text = "第%d组" % int(player.get("group_number", GameState.game_data.players.find(player) + 1))
		button.tooltip_text = str(player.get("name", "财团"))
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_pressed = str(player.get("id", "")) == selected_ledger_player_id
		Styles.apply_toy_button(button, button.button_pressed, Color("d6ad54"), 14)
		button.pressed.connect(_select_ledger_player.bind(str(player.get("id", ""))))
		ledger_player_tabs.add_child(button)
	$Layout.add_child(ledger_player_tabs)
	$Layout.move_child(ledger_player_tabs, $Layout / KpiStrip.get_index())


func _select_ledger_player(player_id: String) -> void :
	if player_id.is_empty():
		return
	selected_ledger_player_id = player_id
	profile = presentation_profile_for_player(player_id)
	_clear_full_ledger()
	_build()
	for child: Node in ledger_player_tabs.get_children():
		var button: = child as Button
		if button == null:
			continue
		var active: = button.name == "LedgerGroup%s" % player_id
		button.set_pressed_no_signal(active)
		Styles.apply_toy_button(button, active, Color("d6ad54"), 14)
	AudioManager.click()


func _clear_full_ledger() -> void :
	for container: Control in [$Layout / KpiStrip, $Layout / Main / CashflowBoard]:
		for child: Node in container.get_children():
			container.remove_child(child)
			child.free()
	for card: Control in [$Layout / Main / InsightRail / RiskCard, $Layout / Main / InsightRail / TalentCard, $Layout / Main / InsightRail / LoanCard]:
		for child: Node in card.get_children():
			card.remove_child(child)
			child.free()


func compact_summary_profile() -> Dictionary:
	var lines: Array = profile.get("business_lines", [])
	var best: Dictionary = {}
	var worst: Dictionary = {}
	for line: Dictionary in lines:
		if bool(line.get("informational", false)): continue
		if best.is_empty() or int(line.get("value", 0)) > int(best.get("value", 0)): best = line
		if worst.is_empty() or int(line.get("value", 0)) < int(worst.get("value", 0)): worst = line
	var radar: Array = GameState.game_data.get("opportunity_radar", [])
	var competition: Array = GameState.game_data.get("competition_feed", [])
	return {"headline": str(profile.get("headline", "本轮经营完成")), "cash_change": int(profile.get("raw", {}).get("cash_change", 0)), "rank_after": int(profile.get("raw", {}).get("rank_after", 0)), "rank_before": int(profile.get("raw", {}).get("rank_before", 0)), "best_gain": "暂无经营收益" if best.is_empty() else "%s %+d 万" % [str(best.get("label", "经营收益")), int(best.get("value", 0))], "largest_loss": "本轮无重大损失" if worst.is_empty() or int(worst.get("value", 0)) >= 0 else "%s %d 万" % [str(worst.get("label", "经营损失")), int(worst.get("value", 0))], "opportunity": "暂无高优先机会" if radar.is_empty() else str(radar[0].get("text", "暂无高优先机会")), "threat": "暂无重大竞争威胁" if competition.is_empty() else str(competition[-1].get("title", "暂无重大竞争威胁"))}


func _build_compact_layer() -> void :
	compact_layer = PanelContainer.new();compact_layer.name = "CompactResult";compact_layer.add_theme_stylebox_override("panel", _transparent_line(Color("d6ad54")))
	var box: = VBoxContainer.new();box.add_theme_constant_override("separation", 8);compact_layer.add_child(box)
	var header: = HBoxContainer.new();header.add_theme_constant_override("separation", 14);box.add_child(header)
	var heading: = Styles.label("本轮经营结果", 24, Color("efcf78"));heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL;header.add_child(heading)
	details_button = Button.new();details_button.name = "ShowFullLedger";details_button.text = "查看完整经营对账";details_button.custom_minimum_size = Vector2(280, 46);Styles.apply_toy_button(details_button, false, Color("5eb5d6"), 17);details_button.pressed.connect(_toggle_full_ledger);header.add_child(details_button)
	compact_content = VBoxContainer.new();compact_content.name = "CompactConclusions";box.add_child(compact_content)
	_build_all_player_board(compact_content)
	var summary: = compact_summary_profile()
	var cards: = HBoxContainer.new();cards.name = "DecisionReadyCards";cards.add_theme_constant_override("separation", 12);compact_content.add_child(cards)
	_compact_signal_card(cards, "01  本轮战果", str(summary.headline), "现金 %+d 万" % int(summary.cash_change), Color("e2bd5b"))
	_compact_signal_card(cards, "02  经营峰谷", str(summary.best_gain), str(summary.largest_loss), Color("5fc99c"))
	_compact_signal_card(cards, "03  下轮情报", str(summary.opportunity), str(summary.threat), Color("5eb5d6"))
	_build_next_round_callout(compact_content)
	$Layout.add_child(compact_layer);$Layout.move_child(compact_layer, $Layout / Main.get_index());$Layout / Main.visible = false


func _build_all_player_board(parent: VBoxContainer) -> void :
	var board: Dictionary = GameState.game_data.get("last_report", {}).get("competition", {})
	if board.is_empty():
		board = ReportBuilder.build(GameState.game_data.get("last_report", {}))
	var highlights: = HBoxContainer.new()
	highlights.name = "RoundHighlights"
	highlights.add_theme_constant_override("separation", 10)
	parent.add_child(highlights)
	for item in [
		["本轮最大增长", board.get("biggest_winner", {}), Color("5fc99c"), "round_change"], 
		["本轮最大回撤", board.get("biggest_loss", {}), Color("e77a73"), "round_change"], 
		["风险预警", board.get("risk_alert", {}), Color("e5bd59"), "risk"], 
	]:
		var data: Dictionary = item[1]
		var text: = "%s  %s" % [str(item[0]), str(data.get("player_name", "暂无"))]
		if not data.is_empty():
			text += "  %+d万" % int(data.get(item[3], 0)) if str(item[3]) == "round_change" else "  风险%d" % int(data.get(item[3], 0))
		var badge: = PanelContainer.new()
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		badge.custom_minimum_size.y = 32
		badge.add_theme_stylebox_override("panel", _result_badge_style(item[2]))
		var label: = Styles.label(text, 14, item[2].lightened(0.12))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(label)
		highlights.add_child(badge)
	var grid: = GridContainer.new()
	grid.name = "AllPlayerRoundBoard"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	for row: Dictionary in board.get("players", []):
		var change_value: = int(row.get("round_change", 0))
		var accent: = Color("66d29f") if change_value > 0 else Color("ed8076") if change_value < 0 else Color("69b7cf")
		var card: = PanelContainer.new()
		card.name = "Group%02dResult" % int(row.get("group_number", 0))
		card.custom_minimum_size = Vector2(0, 86)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _player_result_style(accent, str(row.get("player_id", "")) == str(profile.get("player_id", ""))))
		grid.add_child(card)
		var stack: = VBoxContainer.new()
		stack.add_theme_constant_override("separation", 1)
		card.add_child(stack)
		var top: = HBoxContainer.new()
		top.add_theme_constant_override("separation", 7)
		stack.add_child(top)
		var group: = Styles.label("%02d组" % int(row.get("group_number", 0)), 13, accent)
		group.custom_minimum_size.x = 38
		top.add_child(group)
		var name: = Styles.label(str(row.get("player_name", "财团")), 17, Color("f0f4f2"))
		name.clip_text = true
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name)
		var rank: = Styles.label("#%d" % int(row.get("rank", 0)), 16, Color("e5bd59"))
		top.add_child(rank)
		var figures: = HBoxContainer.new()
		figures.add_theme_constant_override("separation", 9)
		stack.add_child(figures)
		var net_worth: = Styles.label("净资产 %s" % Styles.money(int(row.get("net_worth", 0))), 13, Color("c6d7da"))
		net_worth.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		figures.add_child(net_worth)
		var change: = Styles.label("本轮 %+d万" % change_value, 17, accent)
		figures.add_child(change)
		var event: = Styles.label(str(row.get("key_event", "稳健经营")), 12, Color("a9bec4"))
		event.clip_text = true
		event.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		event.tooltip_text = event.text
		stack.add_child(event)


func _build_next_round_callout(parent: VBoxContainer) -> void :
	var final_round: = EndlessOperationsSystem.is_final_round()
	var panel: = PanelContainer.new()
	panel.name = "NextRoundStarter"
	panel.custom_minimum_size.y = 50
	panel.add_theme_stylebox_override("panel", _next_round_style())
	parent.add_child(panel)
	var row: = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	if final_round:
		row.add_child(Styles.label("◆  本局回合已完成  下一步进入终局债务清算", 18, Color("f3d47b")))
		return
	var starter: = ReportBuilder.next_round_starter()
	var command: = Styles.label("下一轮首位操作", 13, Color("a8bec4"))
	row.add_child(command)
	var group: = Styles.label("第%d组" % int(starter.get("group_number", 1)), 22, Color("f4d26f"))
	row.add_child(group)
	var name: = Styles.label(str(starter.get("player_name", "财团")), 20, Color("f2f5f3"))
	row.add_child(name)
	row.add_child(Styles.label("   请做好决策准备", 14, Color("75cfd7")))


func _player_result_style(accent: Color, focused: bool) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.075, 0.105, 0.9)
	style.border_color = Color("efd277", 0.92) if focused else Color(accent, 0.7)
	style.set_border_width_all(1)
	style.border_width_left = 4
	style.set_corner_radius_all(9)
	style.content_margin_left = 11
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 4
	return style


func _result_badge_style(accent: Color) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = Color(accent, 0.08)
	style.border_color = Color(accent, 0.48)
	style.border_width_bottom = 1
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _next_round_style() -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.105, 0.13, 0.96)
	style.border_color = Color("e6c260", 0.86)
	style.border_width_top = 1
	style.border_width_bottom = 2
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _compact_signal_card(parent: HBoxContainer, kicker: String, headline: String, note: String, accent: Color) -> void :
	var card: = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 132)
	card.add_theme_stylebox_override("panel", Styles.panel(Color("0a2834d9"), Color(accent, 0.78), 16, 3))
	parent.add_child(card)
	var margin: = MarginContainer.new()
	for side in ["margin_left", "margin_right"]: margin.add_theme_constant_override(side, 16)
	for side in ["margin_top", "margin_bottom"]: margin.add_theme_constant_override(side, 12)
	card.add_child(margin)
	var stack: = VBoxContainer.new();stack.add_theme_constant_override("separation", 7);margin.add_child(stack)
	stack.add_child(Styles.label(kicker, 13, accent))
	var main: = Styles.label(headline, 21, Color("eef3f1"));main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;main.max_lines_visible = 2;main.tooltip_text = headline;stack.add_child(main)
	var detail: = Styles.label(note, 14, Color("abc0c6"));detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;detail.max_lines_visible = 2;detail.tooltip_text = note;stack.add_child(detail)


func _toggle_full_ledger() -> void :
	var show_full: bool = not $Layout / Main.visible
	$Layout / Main.visible = show_full
	ledger_player_tabs.visible = show_full
	compact_layer.visible = true
	if compact_content != null: compact_content.visible = not show_full
	details_button.text = "收起完整经营对账" if show_full else "查看完整经营对账"
	AudioManager.click()


func _cash_categories(audit: Dictionary, item: Dictionary) -> Array[Dictionary]:
	var specs: Array[Dictionary] = [
		{"id": "operating", "label": "经营", "accent": "59c295"}, {"id": "investment", "label": "投资建设", "accent": "dfaa55"}, 
		{"id": "stock", "label": "证券交易", "accent": "58a9d5"}, {"id": "financing", "label": "融资还款", "accent": "e47969"}, 
		{"id": "event", "label": "事件与卡牌", "accent": "a77ed3"}, {"id": "other", "label": "其他", "accent": "8397a4"}, 
	]
	var buckets: Dictionary = audit.get("categories", {})
	if buckets.is_empty():
		return [{"label": "企业经营", "value": int(item.get("business_income", 0)), "inflow": maxi(0, int(item.get("business_income", 0))), "outflow": maxi(0, - int(item.get("business_income", 0))), "accent": "59c295"}, {"label": "客流收益", "value": int(item.get("traffic_income", 0)), "inflow": maxi(0, int(item.get("traffic_income", 0))), "outflow": 0, "accent": "58a9d5"}, {"label": "商圈控制", "value": int(item.get("control_income", 0)), "inflow": maxi(0, int(item.get("control_income", 0))), "outflow": int(item.get("competition_cost", 0)), "accent": "a77ed3"}, {"label": "证券价格损益", "value": int(item.get("stock_pnl", 0)), "inflow": maxi(0, int(item.get("stock_pnl", 0))), "outflow": maxi(0, - int(item.get("stock_pnl", 0))), "accent": "d5ad52"}]
	var result: Array[Dictionary] = []
	for spec: Dictionary in specs:
		var bucket: Dictionary = buckets.get(str(spec.id), {})
		result.append({"label": str(spec.label), "value": int(bucket.get("net", 0)), "inflow": int(bucket.get("inflow", 0)), "outflow": int(bucket.get("outflow", 0)), "accent": str(spec.accent)})
	return result


func _build() -> void :
	$Layout / Header / Titles / Title.text = "第 %d 回合  %s经营战报" % [int(profile.get("round", 0)), str(profile.get("player_name", "财团"))]
	$Layout / Header / Outcome.text = str(profile.get("headline", "本轮经营完成"));$Layout / Header / Outcome.add_theme_color_override("font_color", Color("f2d477"));$Layout / Header / Outcome.add_theme_stylebox_override("normal", _transparent_line(Color("d6ad54")))
	for metric: Dictionary in profile.get("core_metrics", []):
		_add_metric($Layout / KpiStrip, metric)
	_build_cashflow();_build_insights()


func _add_metric(parent: HBoxContainer, metric: Dictionary) -> void :
	var accent: = Color(str(metric.get("accent", "5ca7d8"))); var box: = VBoxContainer.new();box.size_flags_horizontal = Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation", 1);box.add_child(Styles.label(str(metric.label), 13, Color("a9bec4")));box.add_child(Styles.label(str(metric.value), 27, accent));box.add_child(Styles.label(str(metric.note), 12, Color("d4dfe1")));parent.add_child(box)
	if parent.get_child_count() < 4: var divider: = VSeparator.new();divider.add_theme_color_override("color", Color(accent, 0.38));parent.add_child(divider)


func _build_cashflow() -> void :
	var board: VBoxContainer = $Layout / Main / CashflowBoard;board.add_theme_constant_override("separation", 10)
	var audit: Dictionary = profile.get("cash_audit", {})
	var title_row: = HBoxContainer.new();board.add_child(title_row); var title: = Styles.label("本轮资金航线", 25, Color("efcf78"));title.size_flags_horizontal = Control.SIZE_EXPAND_FILL;title_row.add_child(title)
	var audit_ok: = bool(audit.get("balanced", true)); var badge: = Styles.label("✓ 账目已对平" if audit_ok else "! 账目差额 %+d 万" % int(audit.get("difference", 0)), 15, Color("69d5a2") if audit_ok else Color("ef776f"));title_row.add_child(badge)
	var income_total: = int(audit.get("total_inflow", 0)); var outflow_total: = int(audit.get("total_outflow", 0))
	if audit.is_empty():
		for source: Dictionary in profile.get("income_sources", []): income_total += maxi(0, int(source.value))
		for item: Dictionary in profile.get("outflows", []): outflow_total += int(item.value)
	var flow: = HBoxContainer.new();flow.name = "FlowHeadline";flow.custom_minimum_size.y = 84;flow.add_theme_constant_override("separation", 12);board.add_child(flow)
	_add_flow_step(flow, "期初现金", Styles.money(int(audit.get("opening_cash", profile.get("raw", {}).get("cash_before", 0)))), Color("b9cbd0"));flow.add_child(Styles.label("+", 26, Color("d7bd73")));_add_flow_step(flow, "全部流入", "+%d 万" % income_total, Color("62d29f"));flow.add_child(Styles.label("−", 26, Color("d7bd73")));_add_flow_step(flow, "全部流出", "-%d 万" % outflow_total, Color("ed8076"));flow.add_child(Styles.label("=", 26, Color("d7bd73")));_add_flow_step(flow, "期末现金", Styles.money(int(audit.get("closing_cash", profile.get("raw", {}).get("cash_after", 0)))), Color("5eb5d6"))
	var source_title: = Styles.label("资金分类  直接来自本轮真实交易记录", 17, Color("b8cbd0"));board.add_child(source_title)
	var max_value: = 1
	for source: Dictionary in profile.get("income_sources", []):
		max_value = maxi(max_value, absi(int(source.value)))
	for source: Dictionary in profile.get("income_sources", []):
		board.add_child(_source_bar(source, max_value))
	var separator: = HSeparator.new();separator.add_theme_color_override("color", Color("d6ad54"));board.add_child(separator)
	var trajectory: = HBoxContainer.new();trajectory.name = "AssetTrajectory";trajectory.add_theme_constant_override("separation", 18);board.add_child(trajectory)
	_add_compact_result(trajectory, "人才贡献", "%+d 万" % int(profile.get("talent_value", 0)), Color("e2bd5b"))
	var best: = _best_business(profile.get("business_lines", []));_add_compact_result(trajectory, "最佳企业", str(best.get("label", "暂无经营企业")), Color("60c99b"))
	var decision: = _latest_decision(str(profile.get("player_id", "")), int(profile.get("round", 0)));_add_compact_result(trajectory, "本轮抉择", str(decision.get("choice_title", "未触发")), Color("62b5dc"))
	_build_ranking(board)


func _add_flow_step(parent: HBoxContainer, title: String, value: String, accent: Color) -> void :
	var box: = VBoxContainer.new();box.size_flags_horizontal = Control.SIZE_EXPAND_FILL;box.add_child(Styles.label(title, 14, Color("a9bec4")));box.add_child(Styles.label(value, 29, accent));parent.add_child(box)


func _source_bar(source: Dictionary, maximum: int) -> Control:
	var row: = HBoxContainer.new();row.custom_minimum_size.y = 32;row.add_theme_constant_override("separation", 10); var label: = Styles.label(str(source.label), 14, Color("d6e0e2"));label.custom_minimum_size.x = 90;row.add_child(label); var bar: = ProgressBar.new();bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL;bar.max_value = maximum;bar.value = absi(int(source.value));bar.show_percentage = false; var bg: = StyleBoxFlat.new();bg.bg_color = Color(0.02, 0.07, 0.11, 0.76);bg.set_corner_radius_all(7); var fill: = StyleBoxFlat.new();fill.bg_color = Color(str(source.accent));fill.set_corner_radius_all(7);bar.add_theme_stylebox_override("background", bg);bar.add_theme_stylebox_override("fill", fill);row.add_child(bar); var movement: = Styles.label("入 %d  /  出 %d" % [int(source.get("inflow", maxi(0, int(source.value)))), int(source.get("outflow", maxi(0, - int(source.value))))], 12, Color("a9bec4"));movement.custom_minimum_size.x = 115;movement.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT;row.add_child(movement); var value: = Styles.label("净 %+d" % int(source.value), 16, Color(str(source.accent)));value.custom_minimum_size.x = 76;value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT;row.add_child(value);return row


func _add_compact_result(parent: HBoxContainer, title: String, value: String, accent: Color) -> void :
	var box: = VBoxContainer.new();box.size_flags_horizontal = Control.SIZE_EXPAND_FILL;box.add_child(Styles.label(title, 13, Color("9fb5bd"))); var label: = Styles.label(value, 20, accent);label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;box.add_child(label);parent.add_child(box)


func _build_ranking(parent: VBoxContainer) -> void :
	var ranking: = GridContainer.new();ranking.name = "Ranking";ranking.columns = 2;ranking.add_theme_constant_override("h_separation", 20);ranking.add_theme_constant_override("v_separation", 4);parent.add_child(ranking); var players: Array = GameState.game_data.players.duplicate(true);players.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a.rank) < int(b.rank))
	for player: Dictionary in players:
		var report: Dictionary = GameState.game_data.get("last_report", {}).get("players", {}).get(str(player.id), {})
		var line: = Styles.label("#%d  %s    净资产 %s    本轮 %+d 万" % [int(player.rank), str(player.name), Styles.money(int(player.asset_value)), int(report.get("asset_change", 0))], 13, Color("f0d277") if str(player.id) == str(profile.get("player_id", "")) else Color("b9cbd0"))
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ranking.add_child(line)


func _build_insights() -> void :
	var risk: Dictionary = profile.get("risk_profile", {});_fill_signal($Layout / Main / InsightRail / RiskCard, "风险结果", "%d  %s" % [int(risk.get("score", 0)), str(risk.get("tier", "稳健"))], "估值 -%d 万  授信 -%d 万" % [int(risk.get("valuation_penalty", 0)), int(risk.get("credit_penalty", 0))], Color(str(risk.get("tier_color", Color("d6ad54")).to_html())))
	var stock: Dictionary = profile.get("stock_activity", {}); var stock_pnl: = int(stock.get("market_pnl", profile.get("raw", {}).get("stock_pnl", 0))); var stock_note: = "买入 %d  卖出 %d  已实现 %+d" % [int(stock.get("buy_cash", 0)), int(stock.get("sell_gross_cash", 0)), int(stock.get("realized_pnl", 0))]
	_fill_signal($Layout / Main / InsightRail / TalentCard, "证券价格损益", "%+d 万" % stock_pnl, stock_note, Color("5eb5d6") if stock_pnl >= 0 else Color("e08463"))
	var raw: Dictionary = profile.get("raw", {}); var debt: = int(raw.get("debt_after", 0)); var notice: = Bank.final_debt_notice(str(profile.get("player_id", ""))); var note: = "逾期记录会在银行持续保留"; if EndlessOperationsSystem.is_final_round() and debt > 0: note = "终局将先清偿，再折价处置资产" if bool(notice.get("requires_liquidation", false)) else "终局现金足够自动清偿"
	_fill_signal($Layout / Main / InsightRail / LoanCard, "银行结果", Styles.money(debt), note, Color("e08463") if debt > 0 else Color("61c89a"))


func _fill_signal(card: PanelContainer, title: String, value: String, note: String, accent: Color) -> void :
	card.add_theme_stylebox_override("panel", _transparent_line(accent)); var box: = VBoxContainer.new();box.add_theme_constant_override("separation", 5);card.add_child(box);box.add_child(Styles.label(title, 14, Color("aabec3")));box.add_child(Styles.label(value, 27, accent)); var detail: = Styles.label(note, 13, Color("d4dfe1"));detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;box.add_child(detail)


func _transparent_line(accent: Color) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new();style.bg_color = Color(0.015, 0.045, 0.075, 0.52);style.border_color = Color(accent, 0.76);style.border_width_left = 4;style.content_margin_left = 16;style.content_margin_right = 10;style.content_margin_top = 8;style.content_margin_bottom = 8;return style


func _best_business(lines: Array) -> Dictionary:
	var best: Dictionary = {}
	for line: Dictionary in lines:
		if not bool(line.get("informational", false)) and (best.is_empty() or int(line.get("value", 0)) > int(best.get("value", 0))):
			best = line
	return best


func _latest_decision(player_id: String, round_number: int) -> Dictionary:
	var history: Array = GameState.game_data.get("round_decision_history", [])
	for index in range(history.size() - 1, -1, -1):
		var item: Dictionary = history[index]
		if str(item.get("player_id", "")) == player_id and int(item.get("round", -1)) == round_number:
			return item.get("result", {})
	return {}


func _focus_player() -> Dictionary:
	for player: Dictionary in GameState.game_data.players:
		if bool(player.get("human", false)):
			return player
	return GameState.game_data.players[0] if not GameState.game_data.players.is_empty() else {}


func _player_by_id(player_id: String) -> Dictionary:
	for player: Dictionary in GameState.game_data.players:
		if str(player.get("id", "")) == player_id:
			return player
	return {}


func _evaluation(asset_change: int, risk: int) -> String:
	if asset_change > 300 and risk < 35: return "资产增长强劲，仍需留意现金储备"
	if asset_change > 0 and risk < 20: return "现金流稳健，可以寻找下一项投资"
	if risk >= 55: return "风险偏高，下轮优先降负债"
	if asset_change < 0: return "资产收缩，下轮先修复现金流"
	return "本轮攻守平衡"


func _continue() -> void :
	AudioManager.click()
	if _show_next_judicial_notice():
		return
	if EndlessOperationsSystem.is_final_round(): Settlement.finalize_match();GameFlow.go("final")
	else: GameFlow.return_to_city(true)


func _show_next_judicial_notice() -> bool:
	var pending: = Bank.pending_judicial_notices(true)
	if pending.is_empty() or has_node("JudicialNoticeLayer"):
		return false
	var layer: = Control.new()
	layer.name = "JudicialNoticeLayer"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	var alert: Dictionary = pending[0]
	var dialog: = ForcedCollectionAlertScene.new()
	dialog.open_alert(alert)
	dialog.acknowledged.connect( func(receipt: Dictionary) -> void :
		Bank.confirm_judicial_foreclosure(str(receipt.get("player_id", "")), str(receipt.get("loan_id", "")))
		layer.queue_free()
		call_deferred("_continue"))
	layer.add_child(dialog)
	return true


func _pending_bankruptcy_notice() -> Dictionary:
	for notice: Dictionary in GameState.game_data.get("bankruptcy_notices", []):
		if not bool(notice.get("acknowledged", false)):
			return notice
	return GameState.game_data.get("solo_bankruptcy_defeat", {})


func _show_bankruptcy_notice() -> void :
	if has_node("DelinquencyBankruptcyDialog"):
		return
	var payload: = _pending_bankruptcy_notice()
	if payload.is_empty():
		return
	var dialog: = DelinquencyBankruptcyDialogScene.new()
	dialog.open(payload)
	dialog.confirmed.connect( func() -> void :
		for notice: Dictionary in GameState.game_data.get("bankruptcy_notices", []):
			if str(notice.get("player_id", "")) == str(payload.get("player_id", "")) and int(notice.get("round", -1)) == int(payload.get("round", -1)):
				notice.acknowledged = true
		if bool(payload.get("solo", false)):
			GameState.game_data.erase("solo_bankruptcy_defeat")
			GameFlow.go("menu")
		else:
			call_deferred("_show_bankruptcy_notice"))
	add_child(dialog)
