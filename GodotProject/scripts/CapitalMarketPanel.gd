class_name CapitalMarketPanel
extends Control

const Styles = preload("res://scripts/UIStyles.gd")
const ADVISORS = preload("res://assets/ui/characters/ipo_advisory_team_v154.png")
const ListedMarket = preload("res://scripts/ListedCompanyMarketSystem.gd")
const PriceSparkline = preload("res://scripts/ListedPriceSparkline.gd")

var message: Label
var content: VBoxContainer
var selected_capital_action := "disclose"
var operation_detail_host: VBoxContainer


func _ready() -> void:
	_build()


func _build() -> void:
	var background := TextureRect.new(); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); background.texture = ADVISORS; background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; background.modulate = Color(0.36, 0.48, 0.55, 0.48); add_child(background)
	var veil := ColorRect.new(); veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); veil.color = Color(0.008, 0.04, 0.065, 0.9); add_child(veil)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for horizontal_side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(horizontal_side, 46)
	for vertical_side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(vertical_side, 30)
	add_child(margin)
	var root := VBoxContainer.new(); root.add_theme_constant_override("separation", 18); margin.add_child(root)
	var header := HBoxContainer.new(); root.add_child(header)
	var title := Styles.label("资本市场", 38, Color("f2d27a")); title.name = "CapitalMarketTitle"; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title)
	var back := Button.new(); back.text = "返回城市"; back.custom_minimum_size = Vector2(150, 50); Styles.apply_toy_button(back, false, Styles.TOY_BLUE, 18); back.pressed.connect(func() -> void: GameFlow.return_to_city(false)); header.add_child(back)
	message = Styles.label("交易所提示｜先选择经营议案查看完整代价，确认后才会执行。", 19, Color("f0d588")); message.name = "CapitalActionReceipt"; message.custom_minimum_size.y = 68; message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; message.add_theme_stylebox_override("normal", Styles.panel(Color("092631f2"), Color("806d3f"), 16, 12)); root.add_child(message)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(scroll)
	content = VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation", 16); scroll.add_child(content)
	_refresh()


func _refresh() -> void:
	for child in content.get_children(): child.queue_free()
	var player := GameState.active_player()
	var player_id := str(player.get("id", ""))
	var profile := EndlessOperationsSystem.capital_market_profile(player_id)
	content.add_child(_status_panel(profile))
	if bool(profile.get("listed", false)):
		content.add_child(_listed_market_board())
		_build_listed_operations(profile, player_id)
	elif bool(profile.get("preparing", false)):
		_build_review_status(profile)
		content.add_child(_listed_market_board())
	else:
		_build_listing_plans(profile, player_id)
		content.add_child(_listed_market_board())
	content.add_child(_advisor_panel(bool(profile.get("listed", false))))


func _listed_market_board() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.panel(Color("061b28ef"), Color("5dabb9"), 20, 16))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(Styles.label("财团挂牌市场  西岸板", 29, Color("f2d27a")))
	box.add_child(Styles.label("成熟证券在证券市场交易  玩家与 AI 财团上市后在此独立定价", 18, Color("c3d2d4")))
	var quotes := ListedMarket.snapshot()
	if quotes.is_empty():
		box.add_child(Styles.label("暂无挂牌财团。达到上市要求并通过审核后，将生成股票代码与价格走势。", 18, Color("7ea4ad")))
		return panel
	for quote: Dictionary in quotes:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 92)
		row.add_theme_constant_override("separation", 18)
		box.add_child(row)
		var identity := VBoxContainer.new()
		identity.custom_minimum_size = Vector2(270, 0)
		identity.add_child(Styles.label("%s  %s" % [str(quote.get("ticker", "XA--")), str(quote.get("company_name", "财团"))], 21, Color("edf3f2")))
		identity.add_child(Styles.label("市值 %d万  %s" % [int(quote.get("market_cap", 0)), str(quote.get("status", "正常交易"))], 16, Color("aec2c6")))
		row.add_child(identity)
		var change := float(quote.get("change", 0.0))
		var price_color := Color("67d2ad") if change >= 0.0 else Color("e87982")
		var price := Styles.label("%.2f\n%+.2f%%" % [float(quote.get("price", 0.0)), change * 100.0], 22, price_color)
		price.custom_minimum_size = Vector2(132, 0)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(price)
		var chart := PriceSparkline.new()
		chart.custom_minimum_size = Vector2(280, 78)
		chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chart.configure(quote.get("history", []), price_color)
		row.add_child(chart)
		var health := Styles.label("信心 %d\n风险 %d" % [int(quote.get("confidence", 0)), int(quote.get("risk", 0))], 18, Color("d0dde0"))
		health.custom_minimum_size = Vector2(118, 0)
		health.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(health)
		var trader := VBoxContainer.new()
		trader.custom_minimum_size = Vector2(188, 0)
		trader.add_theme_constant_override("separation", 5)
		var active_id := str(GameState.active_player().get("id", ""))
		var ticker := str(quote.get("ticker", ""))
		var holding := ListedMarket.holding_shares(active_id, ticker)
		var holding_label := Styles.label("持有 %d 股" % holding, 15, Color("b7c9cd"))
		holding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		trader.add_child(holding_label)
		var trade_row := HBoxContainer.new()
		trade_row.add_theme_constant_override("separation", 6)
		trader.add_child(trade_row)
		for trade_spec in [["买100", true, Color("67d2ad")], ["卖100", false, Color("e87982")]]:
			var trade_button := Button.new()
			trade_button.text = str(trade_spec[0])
			trade_button.custom_minimum_size = Vector2(88, 38)
			trade_button.disabled = active_id == str(quote.get("player_id", "")) or (not bool(trade_spec[1]) and holding < 100)
			Styles.apply_button(trade_button, false, trade_spec[2], 16)
			trade_button.pressed.connect(_trade_listed_stock.bind(str(quote.get("player_id", "")), bool(trade_spec[1])))
			trade_row.add_child(trade_button)
		row.add_child(trader)
	return panel


func _trade_listed_stock(issuer_id: String, buy: bool) -> void:
	var result := ListedMarket.trade(str(GameState.active_player().get("id", "")), issuer_id, 100, buy)
	message.text = str(result.get("message", "交易未完成"))
	_refresh()


func _status_panel(profile: Dictionary) -> Control:
	var panel := PanelContainer.new(); panel.add_theme_stylebox_override("panel", Styles.panel(Color("071f2be8"), Color("5dabb9"), 18, 18)); var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 12); panel.add_child(box)
	var listed := bool(profile.get("listed", false))
	var preparing := bool(profile.get("preparing", false))
	box.add_child(Styles.label("已上市经营" if listed else "审核进行中" if preparing else "上市准备度", 27, Color("edf3f2")))
	if listed:
		var record: Dictionary = profile.get("record", {})
		var long_term_income := int(record.get("integration_level", 0)) * EndlessOperationsSystem.IPO_INTEGRATION_INCOME_PER_LEVEL + int(record.get("innovation_income", 0))
		box.add_child(_metric_row([["市场信心", "%d" % int(record.get("market_confidence", 0)), Color("68d2b0")], ["累计融资", Styles.money(int(record.get("funding", 0))), Color("e3bf67")], ["长期收益", "+%d万/轮" % long_term_income, Color("a88de2")], ["下次审计", "第 %d 回合" % int(record.get("next_audit_round", 0)), Color("72bfd8")], ["披露风险", "%d%%" % roundi(float(record.get("disclosure_gap", 0.0)) * 100.0), Color("e87982")]]))
		var restricted_until := int(record.get("capital_restriction_until_round", 0))
		if int(profile.get("round", 0)) < restricted_until:
			box.add_child(Styles.label("监管整改中  第 %d 回合恢复资本运作" % restricted_until, 17, Color("e87982")))
	elif preparing:
		var record: Dictionary = profile.get("record", {})
		box.add_child(_metric_row([["审核结果", "第 %d 回合" % int(record.get("approval_round", 0)), Color("72bfd8")], ["预计融资", Styles.money(int(record.get("funding", 0))), Color("e3bf67")], ["发行价", "%.2f 元" % float(record.get("issue_price", 0.0)), Color("a9d9e3")], ["新股稀释", "%d%%" % roundi(float(record.get("dilution_ratio", 0.0)) * 100.0), Color("e87982")], ["路径", str(record.get("route_name", "成长上市" if bool(record.get("aggressive", false)) else "稳健上市")), Color("e87982") if bool(record.get("aggressive", false)) else Color("68d2b0")]]))
	else:
		box.add_child(_metric_row([["营业企业", "%d / %d" % [int(profile.get("operating", 0)), int(profile.get("required_operating", 6))], Color("68d2b0")], ["净资产", "%s / %d万" % [Styles.money(int(profile.get("asset", 0))), int(profile.get("required_asset", 4200))], Color("e3bf67")], ["开放回合", "%d+" % int(profile.get("required_round", 16)), Color("72bfd8")]]))
		box.add_child(Styles.label("持有 %d 块西岸土地  风险不高于 %d  审核 3 回合" % [int(profile.get("required_premium_lands", 2)), int(profile.get("required_max_risk", 32))], 18, Color("c2d1d3")))
	return panel


func _build_listing_plans(profile: Dictionary, player_id: String) -> void:
	content.add_child(Styles.label("发行方案对比", 30, Color("edf3f2")))
	content.add_child(Styles.label("融资额由估值 × 新股比例计算；发行价、稀释、审核与上市后波动均进入真实结算。", 17, Color("a9bec3")))
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 16); content.add_child(row)
	row.add_child(_listing_card(false, profile, player_id))
	row.add_child(_listing_card(true, profile, player_id))


func _build_review_status(profile: Dictionary) -> void:
	var record: Dictionary = profile.get("record", {})
	var panel := PanelContainer.new(); panel.add_theme_stylebox_override("panel", Styles.panel(Color("082631e8"), Color("72bfd8"), 18, 18)); content.add_child(panel)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 12); panel.add_child(box)
	box.add_child(Styles.label("上市审核已受理", 27, Color("edf3f2")))
	box.add_child(Styles.label("交易所将在第 %d 回合给出结果。审核并非必然通过，成长路径对风险和披露质量更敏感。" % int(record.get("approval_round", 0)), 18, Color("b9cbd0")))


func _listing_card(aggressive: bool, profile: Dictionary, player_id: String) -> Control:
	var quote := EndlessOperationsSystem.listing_route_quote(player_id, aggressive)
	var accent := Color("e87982") if aggressive else Color("68d2b0")
	var panel := PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; panel.custom_minimum_size.y = 300; panel.add_theme_stylebox_override("panel", Styles.panel(Color("092631f4"), accent, 20, 20))
	var body := HBoxContainer.new(); body.add_theme_constant_override("separation", 18); panel.add_child(body)
	var rail := ColorRect.new(); rail.custom_minimum_size.x = 8; rail.color = accent; rail.mouse_filter = Control.MOUSE_FILTER_IGNORE; body.add_child(rail)
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 10); body.add_child(box)
	var header := HBoxContainer.new(); box.add_child(header)
	var title := Styles.label(str(quote.get("route_name", "上市方案")), 29, Color("f4ead0")); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title)
	var badge := Styles.label("高弹性·高波动" if aggressive else "低稀释·稳预期", 17, accent); badge.add_theme_stylebox_override("normal", Styles.panel(Color("0b3540df"), accent, 12, 8)); header.add_child(badge)
	box.add_child(Styles.label("抢占成长估值，接受更高审计压力与股价振幅。" if aggressive else "控制股权稀释，以更高审核把握换取稳健定价。", 17, Color("c4d3d5")))
	box.add_child(_metric_row([
		["预计融资", Styles.money(int(quote.get("funding", 0))), Color("e3bf67")],
		["发行价", "%.2f 元" % float(quote.get("issue_price", 0.0)), Color("a9d9e3")],
		["目标估值", Styles.money(int(quote.get("target_market_cap", 0))), accent],
		["新股稀释", "%d%%" % roundi(float(quote.get("dilution_ratio", 0.0)) * 100.0), Color("e87982") if aggressive else Color("e3bf67")],
	]))
	box.add_child(Styles.label("发行 %d 万股｜审核约 %d%%｜申请费 %s｜披露缺口 %d%%" % [roundi(float(quote.get("offered_shares", 0)) / 10000.0), roundi(float(quote.get("approval_chance", 0.0)) * 100.0), Styles.money(int(quote.get("application_cost", 0))), roundi(float(quote.get("disclosure_gap", 0.0)) * 100.0)], 17, Color("cedadc")))
	box.add_child(Styles.label("上市后：利好与利空都会放大，常规涨跌仍受交易所限制。" if aggressive else "上市后：基本面权重更稳定，随机波动较小。", 17, accent.lightened(0.08)))
	var button := Button.new(); button.text = "选择此路径并提交审核"; button.custom_minimum_size = Vector2(0, 54); button.disabled = not bool(profile.get("eligibility", {}).get("ok", false)); button.tooltip_text = str(profile.get("eligibility", {}).get("message", "")); Styles.apply_toy_button(button, true, Styles.TOY_YELLOW, 18); button.pressed.connect(_request_listing.bind(player_id, aggressive)); box.add_child(button)
	return panel


func _request_listing(player_id: String, aggressive: bool) -> void:
	var result := EndlessOperationsSystem.request_ipo(player_id, aggressive)
	message.text = str(result.get("message", "上市申请未完成"))
	_refresh()


func _build_listed_operations(profile: Dictionary, player_id: String) -> void:
	content.add_child(Styles.label("上市后董事会议案", 29, Color("edf3f2")))
	content.add_child(Styles.label("左侧选择议案，右侧先阅读用途、即时影响与后续风险；不会因第一次点击而扣款。", 18, Color("bed0d4")))
	var board := HBoxContainer.new(); board.custom_minimum_size.y = 420; board.add_theme_constant_override("separation", 18); content.add_child(board)
	var agenda := VBoxContainer.new(); agenda.custom_minimum_size.x = 275; agenda.add_theme_constant_override("separation", 7); board.add_child(agenda)
	for spec: Dictionary in _capital_action_specs():
		var action := str(spec.id)
		var button := Button.new(); button.text = "%s  %s" % [str(spec.icon), str(spec.title)]; button.custom_minimum_size = Vector2(0, 50); button.alignment = HORIZONTAL_ALIGNMENT_LEFT; Styles.apply_toy_button(button, action == selected_capital_action, spec.accent, 18); button.pressed.connect(_select_capital_action.bind(action, player_id)); agenda.add_child(button)
	operation_detail_host = VBoxContainer.new(); operation_detail_host.name = "CapitalActionDetail"; operation_detail_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL; operation_detail_host.add_theme_constant_override("separation", 13)
	var detail_panel := PanelContainer.new(); detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; detail_panel.add_theme_stylebox_override("panel", Styles.panel(Color("071f2bf2"), Color("5b8f9a"), 22, 24)); detail_panel.add_child(operation_detail_host); board.add_child(detail_panel)
	_render_capital_action_detail(player_id)


func _capital_action_specs() -> Array[Dictionary]:
	return [
		{"id":"disclose", "icon":"◎", "title":"经营披露", "purpose":"用真实经营数据降低监管与信息不对称风险。", "impact":"现金 -20万｜信心 +7｜风险 -3", "future":"披露缺口下降；2回合冷却", "accent":Color("68d2b0")},
		{"id":"dividend", "icon":"◇", "title":"现金分红", "purpose":"把约8%现金回报给持股者，稳定估值中枢。", "impact":"现金支出随余额变化｜信心 +10｜风险 -4", "future":"真实分配给玩家与AI股东；3回合冷却", "accent":Color("e3bf67")},
		{"id":"issuance", "icon":"⇧", "title":"增发融资", "purpose":"快速补充扩张资金，但会稀释预期并增加审计压力。", "impact":"现金约 +净资产12%｜信心 -12｜风险 +6", "future":"信心需35以上；6回合冷却", "accent":Color("e87982")},
		{"id":"buyback", "icon":"↺", "title":"股份回购", "purpose":"投入现金支撑估值；过热期存在高位接盘概率。", "impact":"现金约 -10%｜信心 +15 或 -8｜风险 -2", "future":"经济周期会改变时点风险；5回合冷却", "accent":Color("72bfd8")},
		{"id":"acquisition", "icon":"◆", "title":"并购整合", "purpose":"用一次性投入换长期协同收益，失败会真实损失。", "impact":"成本约净资产8%｜成功每级 +32万/轮", "future":"成功率受风险、整合等级和西岸尽调影响；7回合冷却", "accent":Color("a88de2")},
		{"id":"guidance", "icon":"⌁", "title":"业绩指引", "purpose":"向市场承诺两回合后的经营目标。", "impact":"现金 -25万｜立即信心 +5", "future":"兑现再增信；落空信心 -20、风险 +10", "accent":Color("6dc8a4")},
		{"id":"innovation", "icon":"✦", "title":"战略研发", "purpose":"投资三回合研发项目，形成可持续新增收益。", "impact":"投入随规模增长｜成功每级 +24万/轮", "future":"成功率受周期、风险和研发等级影响；失败不倒退", "accent":Color("80a9e8")},
	]


func _select_capital_action(action: String, player_id: String) -> void:
	selected_capital_action = action
	_refresh()
	message.text = "已选择议案｜请阅读右侧完整影响，再点击确认执行。"


func _render_capital_action_detail(player_id: String) -> void:
	var spec: Dictionary = _capital_action_specs()[0]
	for candidate: Dictionary in _capital_action_specs():
		if str(candidate.id) == selected_capital_action:
			spec = candidate
			break
	operation_detail_host.add_child(Styles.label("%s  %s" % [str(spec.icon), str(spec.title)], 33, spec.accent))
	var purpose := Styles.label(str(spec.purpose), 20, Color("e7eeed")); purpose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; operation_detail_host.add_child(purpose)
	var impact := Styles.label("本次预计｜%s" % str(spec.impact), 22, Color("f1d681")); impact.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; operation_detail_host.add_child(impact)
	var future := Styles.label("后续检验｜%s" % str(spec.future), 18, Color("9fd3d9")); future.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; operation_detail_host.add_child(future)
	var warning := Styles.label("这项决策会写入经营账本、影响股价脉冲，并接受后续审计。", 18, Color("f09a92")); warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; operation_detail_host.add_child(warning)
	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; operation_detail_host.add_child(spacer)
	var confirm := Button.new(); confirm.name = "ConfirmCapitalAction"; confirm.text = "确认执行  %s" % str(spec.title); confirm.custom_minimum_size = Vector2(0, 58); Styles.apply_toy_button(confirm, true, spec.accent, 19); confirm.pressed.connect(_capital_action.bind(player_id, selected_capital_action)); operation_detail_host.add_child(confirm)


func _capital_action(player_id: String, action: String) -> void:
	var result := EndlessOperationsSystem.capital_market_action(player_id, action)
	message.text = _capital_action_receipt(result)
	message.add_theme_color_override("font_color", Color("70d3aa") if bool(result.get("ok", false)) else Color("ef827d"))
	_refresh()


func _capital_action_receipt(result: Dictionary) -> String:
	if not bool(result.get("ok", false)):
		return "议案未执行｜%s" % str(result.get("message", "条件未满足"))
	var changes: Dictionary = result.get("details", {}).get("changes", {})
	var parts: Array[String] = []
	for spec: Array in [["cash_change", "现金"], ["confidence_change", "信心"], ["risk_change", "风险"], ["income_per_round", "每轮收益"]]:
		if changes.has(str(spec[0])):
			var value := int(changes.get(str(spec[0]), 0))
			parts.append("%s %s%d" % [str(spec[1]), "+" if value > 0 else "", value])
	if changes.has("success_chance"):
		parts.append("成功率 %d%%" % roundi(float(changes.success_chance) * 100.0))
	return "董事会回执｜%s%s" % [str(result.get("message", "议案已执行")), "｜" + "　".join(parts) if not parts.is_empty() else ""]


func _advisor_panel(listed: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 190)
	panel.add_theme_stylebox_override("panel", Styles.panel(Color("071c27e8"), Color("4e8792"), 17, 12))
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 18); panel.add_child(row)
	var portrait := TextureRect.new(); portrait.custom_minimum_size = Vector2(420, 166); portrait.texture = ADVISORS; portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; row.add_child(portrait)
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.alignment = BoxContainer.ALIGNMENT_CENTER; box.add_theme_constant_override("separation", 10); row.add_child(box)
	box.add_child(Styles.label("上市顾问团", 25, Color("f1d681")))
	box.add_child(Styles.label("持续监督披露、现金回报与融资节奏" if listed else "完成准备度后，由顾问团协助选择上市路径", 18, Color("dce8e8")))
	box.add_child(Styles.label("每项操作都会进入经营账本并接受后续审计。", 17, Color("b9c9cc")))
	return panel


func _metric_row(specs: Array) -> Control:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12)
	for spec: Array in specs:
		var card := PanelContainer.new(); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL; card.add_theme_stylebox_override("panel", Styles.panel(Color("0a2b35d9"), Color(spec[2], 0.6), 12, 10)); var stack := VBoxContainer.new(); card.add_child(stack); var k := Styles.label(str(spec[0]), 16, Color("b4c6c9")); k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; stack.add_child(k); var v := Styles.label(str(spec[1]), 24, spec[2]); v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; stack.add_child(v); row.add_child(card)
	return row
