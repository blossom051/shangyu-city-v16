extends Control

const Economy = preload("res://scripts/EconomyMath.gd")

const UIStyles = preload("res://scripts/UIStyles.gd")
const Stocks = preload("res://scripts/StockSystem.gd")
const ScreenDecorator = preload("res://scripts/V7ScreenDecorator.gd")
const CharacterCard = preload("res://scripts/FinanceCharacterCard.gd")
const StockSuspensions = preload("res://scripts/StockSuspensionSystem.gd")
const StockAssets = preload("res://scripts/StockAssetRegistry.gd")

var selected_id: = ""
var stock_buttons: Dictionary = {}


func _ready() -> void :
	ScreenDecorator.decorate(self, "market")
	_apply_responsive_layout()
	$Layout / Header / Title.text = "证券投资"
	$Layout / Header / Back.text = "返回城市"
	$Layout / Main / TradeDesk / Buy.text = "买入股票"
	$Layout / Main / TradeDesk / Sell.text = "卖出股票"
	$Layout / Header / Back.pressed.connect(_return_to_city)
	$Layout / Main / TradeDesk / Buy.pressed.connect( func() -> void : _trade(true))
	$Layout / Main / TradeDesk / Sell.pressed.connect( func() -> void : _trade(false))
	var clear_position := Button.new()
	clear_position.name = "ClearPosition"
	clear_position.text = "一键清仓"
	clear_position.custom_minimum_size = Vector2(0, 46)
	clear_position.pressed.connect(_liquidate_selected)
	$Layout / Main / TradeDesk.add_child(clear_position)
	$Layout / Main / TradeDesk.move_child(clear_position, $Layout / Main / TradeDesk / Sell.get_index() + 1)
	UIStyles.apply_toy_button(clear_position, false, Color("e1b65b"), 17)
	$Layout / Main / TradeDesk / Shares.value_changed.connect( func(_value: float) -> void : _refresh())
	_style()
	_add_analyst()
	_build_market_context()
	$Layout / Main / Terminal / Chart.point_selected.connect(_on_chart_point_selected)
	for stock: Dictionary in GameState.game_data.stocks.values():
		var b: = Button.new()
		b.custom_minimum_size = Vector2(378, 38 if _is_compact() else 66)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIStyles.apply_toy_button(b, false, Color(str(stock.color)).lightened(0.2), 16)
		b.mouse_entered.connect(AudioManager.hover)
		b.pressed.connect( func() -> void : _select(str(stock.id)))
		b.icon = StockAssets.icon(str(stock.id))
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 46)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		$Layout / Main / Watchlist / Stocks.add_child(b)
		stock_buttons[str(stock.id)] = b
	_select(str(GameState.game_data.stocks.keys()[0]))
	_refresh()


func _add_analyst() -> void :
	var analyst: = CharacterCard.new()
	analyst.setup("market", "值班分析师  沈砚", "趋势   |   持仓   |   成本", true)
	analyst.visible = not _is_compact()
	$Layout / Main / TradeDesk.add_child(analyst)
	$Layout / Main / TradeDesk.move_child(analyst, 1)


func _build_market_context() -> void :
	var news: = PanelContainer.new();news.name = "MarketEventNews";news.add_theme_stylebox_override("panel", UIStyles.panel(Color("0a2733e8"), Color("4c8896"), 16, 1))
	var label: = Label.new();label.name = "Text";label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size", 14);label.add_theme_color_override("font_color", Color("bcd2d7"));news.add_child(label)
	$Layout / Main / Terminal.add_child(news);$Layout / Main / Terminal.move_child(news, $Layout / Main / Terminal / Signal.get_index() + 1)
	var inspector: = Label.new()
	inspector.name = "ChartInspector"
	inspector.text = "点击折线节点查看该交易日闭市价格"
	inspector.custom_minimum_size.y = 54
	inspector.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspector.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inspector.add_theme_font_size_override("font_size", 15)
	inspector.add_theme_color_override("font_color", Color("e9d28d"))
	inspector.add_theme_stylebox_override("normal", UIStyles.panel(Color("0a2b38e8"), Color("5f8390"), 14, 1))
	$Layout / Main / Terminal.add_child(inspector)
	$Layout / Main / Terminal.move_child(inspector, $Layout / Main / Terminal / Chart.get_index() + 1)


func _select(id: String) -> void :
	selected_id = id
	var s: Dictionary = GameState.game_data.stocks[id]
	$Layout / Main / Terminal / Top / Name.text = "%s  /  %s" % [s.name, s.sector]
	var delta: = float(s.history[-1]) - float(s.history[0])
	$Layout / Main / Terminal / Top / Price.text = "%.2f" % s.price
	$Layout / Main / Terminal / Top / Delta.text = "%s %.2f" % ["▲" if delta >= 0 else "▼", absf(delta)]
	$Layout / Main / Terminal / Top / Delta.add_theme_color_override("font_color", Color("72cddd") if delta >= 0 else Color("ff7180"))
	$Layout / Main / Terminal / Chart.set_values(s.history, Color(str(s.color)))
	$Layout / Main / Terminal / Chart.select_point(s.history.size() - 1)
	var status: = StockSuspensions.status(id)
	var hint: = Stocks.stock_hint(str(GameState.active_player().id), id)
	$Layout / Main / Terminal / Signal.text = "%s%s" % [str(status.get("text", "连续竞价")), "" if hint.is_empty() else "  %s" % hint]
	var market_news: = $Layout / Main / Terminal.get_node_or_null("MarketEventNews/Text") as Label
	if market_news != null:
		var related: Array = GameState.game_data.get("news", []).filter( func(item: Dictionary) -> bool: return str(item.get("sector", "")) in [str(s.sector), "all"])
		market_news.text = "市场事件  暂无直接行业新闻，价格由本轮经营与城市事件驱动" if related.is_empty() else "市场事件  %s" % str(related[-1].get("title", related[-1].get("headline", "行业动态")))
	for stock_id: String in stock_buttons:
		var stock_button: = stock_buttons[stock_id] as Button
		UIStyles.apply_toy_button(stock_button, stock_id == selected_id, Color(str(GameState.game_data.stocks[stock_id].color)), 16)
	_refresh()


func _on_chart_point_selected(index: int, value: float, delta: float, rate: float) -> void :
	var inspector: = $Layout / Main / Terminal.get_node_or_null("ChartInspector") as Label
	if inspector == null:
		return
	var direction: = "上涨" if delta > 0.001 else "下跌" if delta < -0.001 else "持平"
	inspector.text = "第 %d 个交易日  闭市价 %.2f  %s %+.2f（%+.2f%%）" % [index + 1, value, direction, delta, rate * 100.0]
	inspector.add_theme_color_override("font_color", Color("79dfad") if delta >= 0.0 else Color("ff8b91"))


func _trade(buy: bool) -> void :
	var result: = Stocks.trade(str(GameState.active_player().id), selected_id, int($Layout / Main / TradeDesk / Shares.value), buy)
	$Layout / Main / TradeDesk / Message.text = result.message
	if bool(result.ok):
		AudioManager.stock_trade(buy)
		_play_trade_feedback(buy)
	_refresh()


func _liquidate_selected() -> void:
	var result := Stocks.liquidate_position(str(GameState.active_player().id), selected_id)
	$Layout / Main / TradeDesk / Message.text = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		AudioManager.stock_trade(false)
		_play_trade_feedback(false)
	_refresh()


func _return_to_city() -> void :
	if TutorialDirector.active:
		TutorialDirector.return_to_city_from_auxiliary("stock_market")
	GameFlow.go("city")


func _play_trade_feedback(buy: bool) -> void :
	$Layout / Main / TradeDesk / Message.modulate = Color("64c98a") if buy else Color("e6b65f")
	$Layout / Main / TradeDesk / Message.scale = Vector2(0.94, 0.94)
	var tween: = create_tween()
	tween.set_parallel(true)
	tween.tween_property($Layout / Main / TradeDesk / Message, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property($Layout / Main / TradeDesk / Message, "modulate", Color.WHITE, 0.55)


func _refresh() -> void :
	var p: = GameState.active_player()
	var clear_button := $Layout / Main / TradeDesk.get_node_or_null("ClearPosition") as Button
	if clear_button != null:
		clear_button.disabled = int(p.get("stocks", {}).get(selected_id, {}).get("shares", 0)) <= 0
	var portfolio: = Stocks.portfolio_summary(str(p.id))
	$Layout / Header / Cash.text = "现金 %s  持仓市值 %s  总浮盈 %s%s" % [UIStyles.money(int(p.cash)), UIStyles.money(int(portfolio.market_value)), "+" if int(portfolio.pnl) >= 0 else "", UIStyles.money(int(portfolio.pnl))]
	var portfolio_rate: = float(portfolio.pnl_rate) * 100.0
	var rate_note: = "现价尚未偏离平均成本" if int(portfolio.get("position_count", 0)) > 0 and absf(portfolio_rate) < 0.05 else "按精确持仓成本实时计算"
	$Layout / Main / Watchlist / Portfolio.text = "[font_size=20][color=#F1CD73]我的证券账户[/color][/font_size]\n[font_size=16][color=#E9F1F2]持有 %d 家[/color]  [color=#8FC8D6]  精确成本 %s[/color][/font_size]\n[font_size=17][color=#F4BC62]浮动收益率 %+.2f%%[/color][/font_size]\n[font_size=13][color=#B9CDD2]%s[/color][/font_size]" % [int(portfolio.position_count), UIStyles.money(int(portfolio.cost_basis)), portfolio_rate, rate_note]
	_refresh_watchlist(str(p.id))
	_refresh_positions(str(p.id))
	var position: = Stocks.position_summary(str(p.id), selected_id)
	var h: Dictionary = p.stocks.get(selected_id, {"shares": 0, "avg": 0.0})
	$Layout / Main / TradeDesk / Holding.text = "当前持仓\n%d 股" % int(position.shares)
	$Layout / Main / TradeDesk / Cost.text = "平均成本\n%.2f  总成本 %s" % [float(position.avg_cost), UIStyles.money(int(position.cost_basis))]
	$Layout / Main / TradeDesk / MarketValue.text = "市值与收益\n%s  %+.1f%%  %s%s" % [UIStyles.money(int(position.market_value)), float(position.pnl_rate) * 100.0, "+" if int(position.pnl) >= 0 else "", UIStyles.money(int(position.pnl))]
	var shares: = int($Layout / Main / TradeDesk / Shares.value)
	var cash_value: = Economy.stock_trade_value(float(GameState.game_data.stocks[selected_id].price), shares)
	var status: = StockSuspensions.status(selected_id)
	var buy_after: = int(p.cash) - cash_value
	var sell_after: = int(p.cash) + cash_value
	$Layout / Main / TradeDesk / SharesLabel.text = "交易股数  %d 股" % shares
	$Layout / Main / TradeDesk / Preview.text = str(status.get("text", "连续竞价")) if not bool(status.get("tradable", true)) else "%d 股  交易金额 %s\n买入后现金 %s  卖出后现金 %s\n当前持仓 %d 股  最多可卖 %d 股" % [shares, UIStyles.money(cash_value), UIStyles.money(buy_after), UIStyles.money(sell_after), int(h.shares), mini(1000, int(h.shares))]
	$Layout / Main / TradeDesk / Buy.disabled = not bool(status.get("tradable", true)) or int(p.cash) < cash_value
	$Layout / Main / TradeDesk / Sell.disabled = not bool(status.get("tradable", true)) or int(h.shares) < shares
	$Layout / Main / TradeDesk / Message.text = str(status.get("text", "该证券当前不可交易")) if not bool(status.get("tradable", true)) else ("现金不足，无法买入当前数量" if int(p.cash) < cash_value else ("持仓不足，无法卖出当前数量" if int(h.shares) < shares else "拖动滑杆选择 100—1000 股；步长 100 股"))


func _refresh_positions(player_id: String) -> void :
	var holder: = $Layout / Main / Watchlist / Positions as VBoxContainer
	for child: Node in holder.get_children(): child.queue_free()
	var count: = 0
	for stock_id: String in GameState.game_data.stocks:
		var position: = Stocks.position_summary(player_id, stock_id)
		if int(position.shares) <= 0:
			continue
		var stock: Dictionary = GameState.game_data.stocks[stock_id]
		var card: = PanelContainer.new();card.add_theme_stylebox_override("panel", UIStyles.panel(Color("0a2733e8"), Color(str(stock.color)), 12, 1)); var row: = HBoxContainer.new();card.add_child(row); var identity: = Label.new();identity.text = "%s\n%d 股  均价 %.2f" % [str(stock.name), int(position.shares), float(position.avg_cost)];identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL;identity.add_theme_font_size_override("font_size", 13);identity.add_theme_color_override("font_color", Color("e5eeee"));row.add_child(identity); var pnl: = Label.new();pnl.text = "%+.1f%%\n%s" % [float(position.pnl_rate) * 100.0, UIStyles.money(int(position.market_value))];pnl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT;pnl.add_theme_font_size_override("font_size", 14);pnl.add_theme_color_override("font_color", Color("76cfe0") if int(position.pnl) >= 0 else Color("ef7782"));row.add_child(pnl);holder.add_child(card);count += 1
	if count == 0:
		var empty: = Label.new();empty.text = "暂无持仓\n买入后将生成持仓卡，显示股数、平均成本、浮盈亏与市值。";empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;empty.add_theme_font_size_override("font_size", 13);empty.add_theme_color_override("font_color", Color("9fb7bd"));holder.add_child(empty)


func _refresh_watchlist(player_id: String) -> void :
	for stock_id: String in stock_buttons:
		var stock: Dictionary = GameState.game_data.stocks[stock_id]
		var position: = Stocks.position_summary(player_id, stock_id)
		var delta: = float(stock.history[-1]) - float(stock.history[0])
		var holding_line: = "未持有  点击查看" if int(position.shares) <= 0 else "已持有 %d股  成本 %.2f  浮盈 %+.1f%%" % [int(position.shares), float(position.avg_cost), float(position.pnl_rate) * 100.0]
		var marker: = "我的持仓" if int(position.shares) > 0 else str(stock.sector)
		var button: = stock_buttons[stock_id] as Button
		var status: = StockSuspensions.status(stock_id)
		var price_line: = "停牌" if not bool(status.get("tradable", true)) else "%s%.1f" % ["+" if delta >= 0 else "−", absf(delta)]
		button.text = "%s  %s   %.2f   %s\n%s" % [marker, str(stock.name), float(stock.price), price_line, holding_line]


func _style() -> void :
	UIStyles.apply_toy_labels($Layout)
	for button in [$Layout / Header / Back, $Layout / Main / TradeDesk / Buy, $Layout / Main / TradeDesk / Sell]:
		UIStyles.apply_toy_button(button, button != $Layout / Header / Back, Color("ffd45e") if button != $Layout / Header / Back else Color("55bce8"), 18)
		button.mouse_entered.connect(AudioManager.hover)
	$Layout / Header / Title.add_theme_color_override("font_color", UIStyles.TOY_INK)
	$Layout / Main / Terminal / Top / Name.add_theme_color_override("font_color", UIStyles.TOY_INK)
	$Layout / Main / Terminal / Top / Price.add_theme_color_override("font_color", UIStyles.TOY_INK)
	$Layout / Main / TradeDesk / Message.add_theme_color_override("font_color", Color("8a5a00"))
	$Layout / Main / TradeDesk / Preview.add_theme_color_override("font_color", UIStyles.TOY_INK)
	$Layout / Main / TradeDesk / Message.text = "选择股数，以 100 股为单位交易"
	UIStyles.apply_slider($Layout / Main / TradeDesk / Shares)
	$Layout / Main / Watchlist / PositionsTitle.add_theme_color_override("font_color", Color("d7b968"))
	$Layout / Main / Watchlist / Portfolio.add_theme_stylebox_override("normal", UIStyles.panel(Color("092632e8"), Color("3e7180"), 14, 1))


func _is_compact() -> bool:
	return get_viewport_rect().size.y < 960.0


func _apply_responsive_layout() -> void :
	$Layout.grow_vertical = Control.GROW_DIRECTION_END
	# A 1080p window still has less than 1000 px for the trading columns after
	# safe margins and the header. Keep every action, including liquidation,
	# inside that visible area instead of allowing the final button to clip.
	if get_viewport_rect().size.y <= 1100.0:
		$Layout / Main / TradeDesk.add_theme_constant_override("separation", 8)
		for label in [$Layout / Main / TradeDesk / Holding, $Layout / Main / TradeDesk / Cost, $Layout / Main / TradeDesk / MarketValue]:
			label.custom_minimum_size.y = 42
			label.add_theme_font_size_override("font_size", 18)
		$Layout / Main / TradeDesk / Shares.custom_minimum_size.y = 42
		$Layout / Main / TradeDesk / Preview.custom_minimum_size.y = 52
		$Layout / Main / TradeDesk / Buy.custom_minimum_size.y = 48
		$Layout / Main / TradeDesk / Sell.custom_minimum_size.y = 48
	if not _is_compact():
		return
	$Layout.add_theme_constant_override("separation", 8)
	$Layout / Header / Title.add_theme_font_size_override("font_size", 27)
	$Layout / Main.add_theme_constant_override("separation", 10)
	$Layout / Main / Watchlist.custom_minimum_size.x = 292
	$Layout / Main / Watchlist.add_theme_constant_override("separation", 5)
	$Layout / Main / Watchlist / Portfolio.custom_minimum_size.y = 74
	$Layout / Main / Watchlist / Stocks.add_theme_constant_override("separation", 3)
	$Layout / Main / Watchlist / Positions.custom_minimum_size.y = 64
	$Layout / Main / Terminal.add_theme_constant_override("separation", 6)
	$Layout / Main / Terminal / Chart.custom_minimum_size.y = 250
	$Layout / Main / Terminal / Signal.custom_minimum_size.y = 38
	$Layout / Main / TradeDesk.custom_minimum_size.x = 310
	$Layout / Main / TradeDesk.add_theme_constant_override("separation", 6)
	$Layout / Main / TradeDesk / DeskTitle.add_theme_font_size_override("font_size", 20)
	for label in [$Layout / Main / TradeDesk / Holding, $Layout / Main / TradeDesk / Cost, $Layout / Main / TradeDesk / MarketValue]:
		label.custom_minimum_size.y = 38
		label.add_theme_font_size_override("font_size", 16)
	$Layout / Main / TradeDesk / Shares.custom_minimum_size.y = 38
	$Layout / Main / TradeDesk / Preview.custom_minimum_size.y = 58
	$Layout / Main / TradeDesk / Preview.add_theme_font_size_override("font_size", 14)
	$Layout / Main / TradeDesk / Buy.custom_minimum_size.y = 46
	$Layout / Main / TradeDesk / Sell.custom_minimum_size.y = 46
