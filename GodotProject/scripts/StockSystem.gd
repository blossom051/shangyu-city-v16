class_name StockSystem
extends RefCounted

const Economy = preload("res://scripts/EconomyMath.gd")
const CompanyRules = preload("res://scripts/CompanyAbilityEngine.gd")

const MarketImpacts = preload("res://scripts/MarketImpactSystem.gd")
const Regions = preload("res://scripts/RegionalEconomySystem.gd")
const StockSuspensions = preload("res://scripts/StockSuspensionSystem.gd")

static func generate_round() -> void :
	var news: Array = GameState.game_data.get("news", [])
	var repriced: Array[Dictionary] = []
	for stock: Dictionary in GameState.game_data.stocks.values():
		var old_price: = float(stock.price)
		var directive: = StockSuspensions.settlement_directive(str(stock.id))
		if str(directive.get("action", "normal")) == "hold":
			stock.last_change = 0.0
			stock.risk_label = "停牌"
			repriced.append({"stock_id": str(stock.id), "before": old_price, "after": old_price, "change": 0.0, "status": "suspended"})
			continue
		if str(directive.get("action", "normal")) == "resume":
			var resume_change: = float(directive.get("change", 0.6))
			var resumed_price: = snappedf(maxf(1.0, old_price * (1.0 + resume_change)), 0.01)
			var resume_history: Array = stock.get("history", []).duplicate()
			if resume_history.is_empty():
				resume_history.append(old_price)
			resume_history.append(resumed_price)
			stock.history = resume_history.slice(maxi(0, resume_history.size() - 7))
			stock.price = resumed_price
			stock.last_change = snappedf(resume_change, 0.0001)
			stock.risk_label = "复牌异动"
			StockSuspensions.resolve_resume(str(stock.id), directive.get("event", {}), float(stock.last_change))
			repriced.append({"stock_id": str(stock.id), "before": old_price, "after": resumed_price, "change": stock.last_change, "status": "resumed"})
			continue
		var news_bias: = 0.0
		for item: Dictionary in news:
			if item.get("tags", []).has(str(stock.sector)):
				news_bias += float(item.get("actual_direction", item.get("direction", 0))) * float(item.get("actual_strength", item.get("strength", 0.0)))
		var regional_bias: = Regions.stock_expectation(str(stock.id))
		var system_bias: = MarketImpacts.total_for(str(stock.id)) + regional_bias
		var combined: = news_bias * 0.45 + system_bias
		if EndlessOperationsSystem.is_enabled():
			var fundamental := maxf(1.0, float(stock.get("fundamental_price", old_price)))
			var growth_anchor := fundamental * (1.0 + minf(1.2, float(GameState.game_data.get("round", 0)) * 0.008))
			combined += clampf((growth_anchor - old_price) / maxf(1.0, old_price) * 0.18, -0.06, 0.06)
		var major: = absf(combined) >= 0.1
		var limit: = 0.18 if major else 0.12
		var change: = clampf(combined + GameState.rng.randf_range(-0.025, 0.025), - limit, limit)
		var new_price: = snappedf(maxf(50.0, old_price * (1.0 + change)), 0.01)
		if EndlessOperationsSystem.is_enabled():
			var price_anchor := maxf(50.0, float(stock.get("fundamental_price", old_price)))
			var upper_band := price_anchor * (2.5 + minf(1.5, float(GameState.game_data.get("round", 0)) * 0.02))
			new_price = clampf(new_price, maxf(50.0, price_anchor * 0.45), upper_band)
		var history: Array = stock.get("history", []).duplicate()
		if history.is_empty():
			history.append(old_price)
		for day in range(1, 7):
			var progress: = float(day) / 6.0
			var point: = lerpf(old_price, new_price, progress)
			if day < 6:
				point *= 1.0 + GameState.rng.randf_range(-0.008, 0.008)
			history.append(snappedf(maxf(50.0, point), 0.01))
		stock.history = history.slice(maxi(0, history.size() - 7))
		stock.price = new_price
		stock.last_change = snappedf(change, 0.0001)
		stock.risk_label = "异常波动" if absf(change) >= 0.15 else "高波动" if absf(change) >= 0.08 else "正常"
		repriced.append({"stock_id": str(stock.id), "before": old_price, "after": new_price, "change": stock.last_change, "news_bias": news_bias, "system_bias": system_bias, "regional_bias": regional_bias})
	var consumed: = MarketImpacts.consume_all()
	GameState.game_data.battle_ledger.append({
		"round": int(GameState.game_data.get("round", 0)), 
		"category": "stock", 
		"player_id": "system", 
		"title": "经营与市场消息完成定价", 
		"details": {"stocks": repriced, "consumed_impacts": consumed}, 
	})


static func trade(player_id: String, stock_id: String, shares: int, buy: bool) -> Dictionary:
	var tutorial_route: Dictionary = TutorialDirector.route_action("stock_trade", {"player_id": player_id, "stock_id": stock_id, "shares": shares, "buy": buy})
	if bool(tutorial_route.get("handled", false)):
		return tutorial_route
	var player: = GameState.player(player_id)
	var stock: Dictionary = GameState.game_data.stocks.get(stock_id, {})
	if player.is_empty() or stock.is_empty() or shares < 100 or shares % 100 != 0:
		return _fail("交易股数必须是 100 的正整数倍")
	var market_status: = StockSuspensions.status(stock_id)
	if not bool(market_status.get("tradable", true)):
		return _fail("该证券当前停牌，暂停买入与卖出")
	var cash_value: = Economy.stock_trade_value(float(stock.price), shares)
	var holding: Dictionary = player.stocks.get(stock_id, {"shares": 0, "avg": 0.0})
	var settled_cash: = cash_value
	var realized_profit: = 0
	if buy:
		if GameState.available_cash(player_id) < cash_value:
			return _fail("现金不足")
		if not GameState.apply_cash(player_id, - cash_value, "买入%s" % stock.name):
			return _fail("可用现金不足")
		var old_cost: = float(holding.avg) * float(holding.shares)
		holding.shares = int(holding.shares) + shares
		holding.avg = (old_cost + float(stock.price) * shares) / float(holding.shares)
	else:
		if int(holding.shares) < shares:
			return _fail("持仓不足")
		var cost_basis: = Economy.stock_trade_value(float(holding.avg), shares)
		var positive_profit: = maxi(0, cash_value - cost_basis)
		var profit_multiplier: = CompanyRules.stock_profit_multiplier(str(player.company_id))
		settled_cash = cost_basis + roundi(float(positive_profit) * profit_multiplier) if positive_profit > 0 else cash_value
		realized_profit = settled_cash - cost_basis
		holding.shares = int(holding.shares) - shares
		GameState.apply_cash(player_id, settled_cash, "卖出%s" % stock.name)
	player.stocks[stock_id] = holding
	GameState._record(player_id, "stock_trade", {"stock_id": stock_id, "shares": shares, "buy": buy, "cash": settled_cash, "gross_cash": cash_value, "realized_profit": realized_profit})
	return _ok("成交 %d 股" % shares, {"cash": settled_cash, "gross_cash": cash_value})


static func liquidate_position(player_id: String, stock_id: String) -> Dictionary:
	var player := GameState.player(player_id)
	var stock: Dictionary = GameState.game_data.stocks.get(stock_id, {})
	if player.is_empty() or stock.is_empty():
		return _fail("证券账户无效")
	var market_status := StockSuspensions.status(stock_id)
	if not bool(market_status.get("tradable", true)):
		return _fail("该证券当前停牌，无法清仓")
	var holding: Dictionary = player.stocks.get(stock_id, {"shares": 0, "avg": 0.0})
	var shares := int(holding.get("shares", 0))
	if shares <= 0:
		return _fail("当前证券没有持仓")
	var gross_cash := Economy.stock_trade_value(float(stock.price), shares)
	var cost_basis := Economy.stock_trade_value(float(holding.get("avg", 0.0)), shares)
	var positive_profit := maxi(0, gross_cash - cost_basis)
	var settled_cash := cost_basis + roundi(float(positive_profit) * CompanyRules.stock_profit_multiplier(str(player.company_id))) if positive_profit > 0 else gross_cash
	holding.shares = 0
	player.stocks[stock_id] = holding
	GameState.apply_cash(player_id, settled_cash, "清仓%s" % stock.name)
	GameState._record(player_id, "stock_trade", {"stock_id": stock_id, "shares": shares, "buy": false, "cash": settled_cash, "gross_cash": gross_cash, "realized_profit": settled_cash - cost_basis, "liquidated": true})
	return _ok("已清仓 %d 股" % shares, {"cash": settled_cash, "gross_cash": gross_cash, "shares": shares})


static func market_value(player_id: String) -> int:
	var player: = GameState.player(player_id)
	var total: = 0.0
	for stock_id: String in player.stocks:
		var holding: Dictionary = player.stocks[stock_id]
		var market: = Economy.stock_position_value(float(GameState.game_data.stocks[stock_id].price), int(holding.shares))
		var basis: = Economy.stock_position_value(float(holding.get("avg", 0.0)), int(holding.shares))
		if market > basis:
			market = basis + (market - basis) * CompanyRules.stock_profit_multiplier(str(player.company_id))
		total += market
	return roundi(total)


static func snapshot_market_value(player_id: String, snapshot: Dictionary) -> int:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return 0
	var holdings: Dictionary = snapshot.get("stock_holdings", {})
	var prices: Dictionary = snapshot.get("stock_prices", {})
	var total: = 0.0
	for stock_id: String in holdings:
		var holding: Dictionary = holdings[stock_id]
		var price: = float(prices.get(stock_id, GameState.game_data.stocks.get(stock_id, {}).get("price", 0.0)))
		var market: = Economy.stock_position_value(price, int(holding.get("shares", 0)))
		var basis: = Economy.stock_position_value(float(holding.get("avg", 0.0)), int(holding.get("shares", 0)))
		if market > basis:
			market = basis + (market - basis) * CompanyRules.stock_profit_multiplier(str(player.company_id))
		total += market
	return roundi(total)


static func position_summary(player_id: String, stock_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	var stock: Dictionary = GameState.game_data.stocks.get(stock_id, {})
	if player.is_empty() or stock.is_empty():
		return {}
	var holding: Dictionary = player.stocks.get(stock_id, {"shares": 0, "avg": 0.0})
	var shares: = int(holding.get("shares", 0))
	var avg: = float(holding.get("avg", 0.0))
	var price: = float(stock.get("price", 0.0))
	var history: Array = stock.get("history", [])
	var previous: = price
	if history.size() >= 2:
		previous = float(history[-2])
	var market: = Economy.stock_position_value(price, shares)
	var cost: = Economy.stock_position_value(avg, shares)
	var pnl: = market - cost
	var pnl_rate: = 0.0 if cost <= 0.0 else pnl / cost
	var day_delta: = 0.0 if previous <= 0.0 else (price - previous) / previous
	return {
		"stock_id": stock_id, 
		"name": str(stock.get("name", stock_id)), 
		"sector": str(stock.get("sector", "")), 
		"shares": shares, 
		"avg_cost": snappedf(avg, 0.01), 
		"current_price": snappedf(price, 0.01), 
		"today_delta": snappedf(day_delta, 0.0001), 
		"market_value": roundi(market), 
		"cost_basis": roundi(cost), 
		"pnl": roundi(pnl), 
		"market_value_exact": market, 
		"cost_basis_exact": cost, 
		"pnl_exact": pnl, 
		"pnl_rate": snappedf(pnl_rate, 0.0001)
		, "market_status": str(stock.get("market_status", "normal"))
		, "status_text": str(stock.get("status_text", "连续竞价"))
	}


static func portfolio_summary(player_id: String) -> Dictionary:
	var positions: Array[Dictionary] = []
	var market_value_total: = 0
	var cost_basis_total: = 0
	var market_value_exact_total: = 0.0
	var cost_basis_exact_total: = 0.0
	for stock_id: String in GameState.game_data.stocks:
		var position: = position_summary(player_id, stock_id)
		if int(position.get("shares", 0)) <= 0:
			continue
		positions.append(position)
		market_value_total += int(position.market_value)
		cost_basis_total += int(position.cost_basis)
		market_value_exact_total += float(position.get("market_value_exact", position.market_value))
		cost_basis_exact_total += float(position.get("cost_basis_exact", position.cost_basis))
	var pnl: = market_value_total - cost_basis_total
	var pnl_exact: = market_value_exact_total - cost_basis_exact_total
	return {
		"positions": positions, 
		"position_count": positions.size(), 
		"market_value": market_value_total, 
		"cost_basis": cost_basis_total, 
		"pnl": pnl, 
		"market_value_exact": market_value_exact_total, 
		"cost_basis_exact": cost_basis_exact_total, 
		"pnl_exact": pnl_exact, 
		"pnl_rate": 0.0 if cost_basis_exact_total <= 0.0 else pnl_exact / cost_basis_exact_total, 
	}


static func round_activity(player_id: String, round_number: = -1) -> Dictionary:
	var resolved_round: = int(GameState.game_data.get("round", 0)) if round_number < 0 else round_number
	var buy_cash: = 0
	var sell_cash: = 0
	var sell_gross_cash: = 0
	var realized_pnl: = 0
	var trades: Array[Dictionary] = []
	for entry: Dictionary in GameState.game_data.get("log", []):
		if int(entry.get("round", -1)) != resolved_round or str(entry.get("player_id", "")) != player_id or str(entry.get("kind", "")) != "stock_trade":
			continue
		var data: Dictionary = entry.get("data", {})
		var is_buy: = bool(data.get("buy", false))
		if is_buy:
			buy_cash += int(data.get("cash", 0))
		else:
			sell_cash += int(data.get("cash", 0))
			sell_gross_cash += int(data.get("gross_cash", data.get("cash", 0)))
			realized_pnl += int(data.get("realized_profit", 0))
		trades.append(data.duplicate(true))
	var ending: = portfolio_summary(player_id)
	return {
		"round": resolved_round, 
		"buy_cash": buy_cash, 
		"sell_cash": sell_cash, 
		"sell_gross_cash": sell_gross_cash, 
		"realized_pnl": realized_pnl, 
		"ending_unrealized_pnl": roundi(float(ending.get("pnl_exact", ending.get("pnl", 0)))), 
		"ending_unrealized_rate": float(ending.get("pnl_rate", 0.0)), 
		"trades": trades, 
	}

static func stock_hint(player_id: String, stock_id: String) -> String:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return ""
	if not player.effects.any( func(e: Dictionary) -> bool: return str(e.kind) == "stock_hint" and str(e.target_id) == stock_id):
		return ""
	var stock: Dictionary = GameState.game_data.stocks.get(stock_id, {})
	if stock.is_empty():
		return ""
	var history: Array = stock.get("history", [])
	if history.size() < 2:
		return "提示：走势未明"
	return "提示：短线偏强" if float(history[-1]) >= float(history[0]) else "提示：短线偏弱"


static func _ok(message: String, details: = {}) -> Dictionary:
	var result: = {"ok": true, "message": message}
	result.merge(details, true)
	return result


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}
