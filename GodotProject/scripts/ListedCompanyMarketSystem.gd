class_name ListedCompanyMarketSystem
extends RefCounted

const Economy = preload("res://scripts/EconomyMath.gd")
const MAX_REGULAR_CHANGE := 0.12
const MAX_EVENT_CHANGE := 0.18


static func initialize_listing(player_id: String, record: Dictionary) -> void:
	var player := GameState.player(player_id)
	if player.is_empty() or record.has("ticker"):
		return
	var player_index := 0
	for index in range(GameState.game_data.get("players", []).size()):
		if str(GameState.game_data.players[index].get("id", "")) == player_id:
			player_index = index
			break
	var asset := maxi(1, int(player.get("asset_value", 0)))
	var issue_price := float(record.get("issue_price", snappedf(clampf(float(asset) / 82.0, 18.0, 88.0), 0.01)))
	var target_market_cap := int(record.get("target_market_cap", roundi(float(asset) * (1.32 if bool(record.get("aggressive", false)) else 1.18))))
	var shares := int(record.get("shares_outstanding", maxi(100000, roundi(float(target_market_cap) * 10000.0 / issue_price / 10000.0) * 10000)))
	record.ticker = "XA%02d" % (player_index + 1)
	record.issue_price = issue_price
	record.share_price = issue_price
	record.price_history = [issue_price]
	record.shares_outstanding = shares
	record.float_ratio = float(record.get("float_ratio", 0.36 if bool(record.get("aggressive", false)) else 0.26))
	record.market_inventory = roundi(float(shares) * float(record.float_ratio) / 100.0) * 100
	record.last_price_change = 0.0
	record.turnover = 0
	record.market_status = "正常交易"
	record.last_priced_round = int(GameState.game_data.get("round", 0))
	record.last_priced_asset = asset


static func queue_impulse(player_id: String, amount: float, reason: String) -> void:
	var record: Dictionary = GameState.game_data.get("ipo_records", {}).get(player_id, {})
	if str(record.get("status", "")) != "listed":
		return
	record.market_impulse = clampf(float(record.get("market_impulse", 0.0)) + amount, -0.22, 0.22)
	var reasons: Array = record.get("market_impulse_reasons", [])
	if not reason.is_empty():
		reasons.append(reason)
	record.market_impulse_reasons = reasons.slice(maxi(0, reasons.size() - 4))


static func price_all(round_number: int) -> Array[Dictionary]:
	var repriced: Array[Dictionary] = []
	for player_id: String in GameState.game_data.get("ipo_records", {}).keys():
		var record: Dictionary = GameState.game_data.ipo_records[player_id]
		if str(record.get("status", "")) != "listed":
			continue
		initialize_listing(player_id, record)
		if int(record.get("last_priced_round", -1)) >= round_number:
			continue
		var player := GameState.player(player_id)
		var old_price := float(record.get("share_price", record.get("issue_price", 20.0)))
		if player.is_empty() or bool(player.get("eliminated", false)):
			record.share_price = snappedf(maxf(0.5, old_price * 0.2), 0.01)
			record.last_price_change = -0.8
			record.market_status = "退市整理"
			record.last_priced_round = round_number
			_append_history(record, float(record.share_price))
			repriced.append(_quote(player_id, player, record, old_price))
			continue
		var asset := maxi(1, int(player.get("asset_value", 0)))
		var previous_asset := maxi(1, int(record.get("last_priced_asset", asset)))
		var profit_signal := clampf(float(player.get("last_round_income", 0)) / float(asset) * 0.9, -0.065, 0.065)
		var asset_signal := clampf(float(asset - previous_asset) / float(previous_asset) * 0.18, -0.045, 0.045)
		var risk_signal := clampf((35.0 - float(player.get("risk", 0))) * 0.0013, -0.075, 0.04)
		var confidence_signal := clampf((float(record.get("market_confidence", 60)) - 60.0) * 0.0011, -0.055, 0.044)
		var disclosure_signal := -clampf(float(record.get("disclosure_gap", 0.0)) * 0.11, 0.0, 0.07)
		var cycle_signal: float = float({"recovery": 0.008, "boom": 0.022, "overheat": -0.012, "adjustment": -0.022}.get(str(GameState.game_data.get("economic_cycle", {}).get("phase", "recovery")), 0.0))
		var impulse := float(record.get("market_impulse", 0.0))
		var volatility_factor := clampf(float(record.get("volatility_factor", 1.0)), 0.65, 1.45)
		var noise := GameState.rng.randf_range(-0.022, 0.022) * volatility_factor
		var event_move := absf(impulse) >= 0.08
		var limit := MAX_EVENT_CHANGE if event_move else MAX_REGULAR_CHANGE
		var fundamental_move := profit_signal + asset_signal + risk_signal + confidence_signal + disclosure_signal + float(cycle_signal)
		var change := clampf(fundamental_move * volatility_factor + impulse + noise, -limit, limit)
		var issue_price := maxf(1.0, float(record.get("issue_price", old_price)))
		var new_price := snappedf(clampf(old_price * (1.0 + change), issue_price * 0.30, issue_price * 5.0), 0.01)
		record.share_price = new_price
		record.last_price_change = clampf(snappedf((new_price - old_price) / maxf(0.01, old_price), 0.0001), -limit, limit)
		record.turnover = roundi(float(record.get("shares_outstanding", 100000)) * float(record.get("float_ratio", 0.25)) * clampf(0.035 + absf(change) * 0.65 + GameState.rng.randf_range(0.0, 0.035), 0.02, 0.22))
		record.market_status = "异动" if absf(change) >= 0.10 else "活跃" if absf(change) >= 0.055 else "正常交易"
		record.last_priced_round = round_number
		record.last_priced_asset = asset
		record.market_impulse = 0.0
		record.market_impulse_reasons = []
		_append_history(record, new_price)
		repriced.append(_quote(player_id, player, record, old_price))
	if not repriced.is_empty():
		GameState.game_data.battle_ledger.append({"round": round_number, "category": "listed_market", "player_id": "system", "title": "西岸板完成本轮经营定价", "details": {"quotes": repriced.duplicate(true)}})
	return repriced


static func snapshot() -> Array[Dictionary]:
	var quotes: Array[Dictionary] = []
	for player_id: String in GameState.game_data.get("ipo_records", {}).keys():
		var record: Dictionary = GameState.game_data.ipo_records[player_id]
		if str(record.get("status", "")) != "listed":
			continue
		var player := GameState.player(player_id)
		initialize_listing(player_id, record)
		quotes.append(_quote(player_id, player, record, float(record.get("share_price", 0.0))))
	quotes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("market_cap", 0.0)) > float(b.get("market_cap", 0.0)))
	return quotes


static func trade(investor_id: String, issuer_id: String, shares: int, buy: bool) -> Dictionary:
	if not bool(GameState.game_data.get("endless", false)):
		return {"ok": false, "message": "财团挂牌交易仅在永续经营模式开放"}
	if shares < 100 or shares % 100 != 0:
		return {"ok": false, "message": "挂牌股票须按 100 股整数交易"}
	if investor_id == issuer_id:
		return {"ok": false, "message": "本财团股份请通过分红、增发或回购管理"}
	var investor := GameState.player(investor_id)
	var record: Dictionary = GameState.game_data.get("ipo_records", {}).get(issuer_id, {})
	if investor.is_empty() or bool(investor.get("eliminated", false)) or str(record.get("status", "")) != "listed":
		return {"ok": false, "message": "交易对象当前不可交易"}
	initialize_listing(issuer_id, record)
	var ticker := str(record.get("ticker", ""))
	var price := float(record.get("share_price", 0.0))
	var cash_value := Economy.stock_trade_value(price, shares)
	var holdings: Dictionary = investor.get_or_add("listed_stocks", {})
	var holding: Dictionary = holdings.get(ticker, {"issuer_id": issuer_id, "shares": 0, "avg": 0.0})
	if buy:
		if int(record.get("market_inventory", 0)) < shares:
			return {"ok": false, "message": "当前可交易流通盘不足"}
		if int(investor.get("cash", 0)) < cash_value:
			return {"ok": false, "message": "现金不足"}
		var old_cost := float(holding.get("avg", 0.0)) * float(holding.get("shares", 0))
		GameState.apply_cash(investor_id, -cash_value, "买入西岸板 %s" % ticker)
		holding.shares = int(holding.get("shares", 0)) + shares
		holding.avg = (old_cost + price * float(shares)) / float(holding.shares)
		record.market_inventory = int(record.get("market_inventory", 0)) - shares
	else:
		if int(holding.get("shares", 0)) < shares:
			return {"ok": false, "message": "持股不足"}
		GameState.apply_cash(investor_id, cash_value, "卖出西岸板 %s" % ticker)
		holding.shares = int(holding.get("shares", 0)) - shares
		record.market_inventory = int(record.get("market_inventory", 0)) + shares
	holdings[ticker] = holding
	var float_shares := maxi(100, roundi(float(record.get("shares_outstanding", 100000)) * float(record.get("float_ratio", 0.25))))
	var order_impact := clampf(float(shares) / float(float_shares) * 0.45, 0.001, 0.04)
	queue_impulse(issuer_id, order_impact if buy else -order_impact, "%s盘交易" % ("买" if buy else "卖"))
	record.turnover = int(record.get("turnover", 0)) + shares
	GameState._record(investor_id, "listed_stock_trade", {"issuer_id": issuer_id, "ticker": ticker, "shares": shares, "buy": buy, "price": price, "cash": cash_value})
	return {"ok": true, "message": "%s %s %d 股" % ["买入" if buy else "卖出", ticker, shares], "cash": cash_value, "ticker": ticker, "shares": shares}


static func market_value(investor_id: String) -> int:
	var investor := GameState.player(investor_id)
	if investor.is_empty():
		return 0
	var total := 0.0
	for holding_value: Variant in investor.get("listed_stocks", {}).values():
		var holding := holding_value as Dictionary
		var record: Dictionary = GameState.game_data.get("ipo_records", {}).get(str(holding.get("issuer_id", "")), {})
		total += Economy.stock_position_value(float(record.get("share_price", 0.0)), int(holding.get("shares", 0)))
	return roundi(total)


static func holding_shares(investor_id: String, ticker: String) -> int:
	var investor := GameState.player(investor_id)
	return int(investor.get("listed_stocks", {}).get(ticker, {}).get("shares", 0)) if not investor.is_empty() else 0


static func distribute_dividend(issuer_id: String, total_dividend: int) -> Dictionary:
	var record: Dictionary = GameState.game_data.get("ipo_records", {}).get(issuer_id, {})
	var public_shares := maxi(1, roundi(float(record.get("shares_outstanding", 1)) * float(record.get("float_ratio", 0.25))))
	var paid := 0
	var recipients := 0
	var ticker := str(record.get("ticker", ""))
	for investor: Dictionary in GameState.game_data.get("players", []):
		if str(investor.get("id", "")) == issuer_id or bool(investor.get("eliminated", false)):
			continue
		var shares := holding_shares(str(investor.get("id", "")), ticker)
		if shares <= 0:
			continue
		var payout := roundi(float(total_dividend) * float(shares) / float(public_shares))
		if payout > 0:
			GameState.apply_cash(str(investor.id), payout, "%s 现金分红" % ticker)
			paid += payout
			recipients += 1
	return {"paid": paid, "recipients": recipients}


static func _append_history(record: Dictionary, price: float) -> void:
	var history: Array = record.get("price_history", []).duplicate()
	history.append(snappedf(price, 0.01))
	record.price_history = history.slice(maxi(0, history.size() - 24))


static func _quote(player_id: String, player: Dictionary, record: Dictionary, previous_price: float) -> Dictionary:
	var price := float(record.get("share_price", 0.0))
	var shares := int(record.get("shares_outstanding", 0))
	return {
		"player_id": player_id,
		"company_name": str(player.get("name", player_id)),
		"ticker": str(record.get("ticker", "XA--")),
		"price": snappedf(price, 0.01),
		"change": float(record.get("last_price_change", 0.0)),
		"history": record.get("price_history", []).duplicate(),
		"market_cap": roundi(price * float(shares) / 10000.0),
		"turnover": int(record.get("turnover", 0)),
		"status": str(record.get("market_status", "正常交易")),
		"risk": int(player.get("risk", 0)),
		"confidence": int(record.get("market_confidence", 0)),
		"previous_price": previous_price,
	}
