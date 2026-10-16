class_name InsolvencySystem
extends RefCounted

const Auctions = preload("res://scripts/AuctionSystem.gd")
const Bank = preload("res://scripts/BankSystem.gd")


static func audit(player_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty() or bool(player.get("eliminated", false)):
		return {"bankrupt": bool(player.get("eliminated", false))}
	var has_cash: = int(player.cash) > 0
	var has_credit: = int(player.debt) < Bank.refinance_limit(player_id)
	var has_disposable_assets: = not Bank.mortgageable_assets(player_id).is_empty()
	var insolvent: = int(player.debt) > 0 and int(player.asset_value) <= 0 and not has_cash and not has_credit and not has_disposable_assets
	if not insolvent:
		return {"bankrupt": false}
	return _eliminate(player, "经营资不抵债", "insolvency", "经营负债已经超过可持续承受范围。及时控制杠杆、保留现金缓冲，才能避免资不抵债。")


static func force_delinquency_bankruptcy(player_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {"bankrupt": false, "message": "玩家不存在"}
	if bool(player.get("eliminated", false)):
		return {"bankrupt": true, "player_id": player_id, "reused": true}
	return _eliminate(player, "司法剩余息费连续三回合未清", "judicial_default", "连续失信会让经营主体失去融资与继续经营的资格。按期履约、主动沟通并及时清偿，是资本经营的基本责任。")


static func force_risk_bankruptcy(player_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {"bankrupt": false, "message": "玩家不存在"}
	if bool(player.get("eliminated", false)):
		return {"bankrupt": true, "player_id": player_id, "reused": true}
	return _eliminate(player, "风险值连续三回合处于100", "critical_risk", "风险长期处于极限意味着经营体系已经失去韧性。应主动治理风险、降低杠杆并保留现金缓冲，不能依赖侥幸继续经营。")


static func voluntary_liquidate(player_id: String) -> Dictionary:
	if not EndlessOperationsSystem.is_enabled():
		return {"bankrupt": false, "ok": false, "message": "主动清算仅在永续经营模式开放"}
	var player := GameState.player(player_id)
	if player.is_empty() or bool(player.get("eliminated", false)):
		return {"bankrupt": false, "ok": false, "message": "当前财团不可申请清算"}
	var summary := _career_summary(player)
	var result := _eliminate(player, "主动申请破产清算", "voluntary_liquidation", "本局经营已由玩家主动结束。")
	# 主动清算是玩家明确选择“结束本局”，永续人机局不能在玩家退出后
	# 继续让 AI 空跑。保留各财团数据用于总结，但终止整场回合队列。
	GameState.game_data.endless_session_ended = true
	GameState.game_data.endless_end_reason = "voluntary_liquidation"
	GameState.game_data.turn_order = []
	GameState.game_data.active_order_index = 0
	result["ok"] = true
	result["summary"] = summary
	result["session_ended"] = true
	GameState.game_data.get_or_add("voluntary_liquidation_summaries", {})[player_id] = summary.duplicate(true)
	return result


static func _career_summary(player: Dictionary) -> Dictionary:
	var peak_asset := int(player.get("asset_value", 0))
	var peak_rank := int(player.get("rank", 1))
	var total_net := 0
	var best_round := 0
	var best_round_net := -2147483648
	var asset_series: Array[Dictionary] = []
	var net_series: Array[Dictionary] = []
	for history_value: Variant in player.get("round_history", []):
		var history := history_value as Dictionary
		var round_summary := history.get("summary", {}) as Dictionary
		peak_asset = maxi(peak_asset, int(round_summary.get("asset_after", round_summary.get("asset", 0))))
		peak_rank = mini(peak_rank, int(round_summary.get("rank_after", peak_rank)))
		var net := int(round_summary.get("net", 0))
		asset_series.append({"round": int(history.get("round", 0)), "value": int(round_summary.get("asset_after", round_summary.get("asset", 0)))})
		net_series.append({"round": int(history.get("round", 0)), "value": net})
		total_net += net
		if net > best_round_net:
			best_round_net = net
			best_round = int(history.get("round", 0))
	var player_id := str(player.get("id", ""))
	var listed := str(GameState.game_data.get("ipo_records", {}).get(player_id, {}).get("status", "")) == "listed"
	var milestones: Array[String] = []
	if not player.get("land_ids", []).is_empty(): milestones.append("建立城市土地版图")
	if not player.get("business_ids", []).is_empty(): milestones.append("形成企业经营组合")
	if listed: milestones.append("登陆西岸板资本市场")
	if int(player.get("debt", 0)) == 0: milestones.append("保持无负债经营")
	if milestones.is_empty(): milestones.append("完成首次经营探索")
	if asset_series.is_empty() or int(asset_series[-1].get("round", -1)) != int(GameState.game_data.get("round", 0)):
		asset_series.append({"round": int(GameState.game_data.get("round", 0)), "value": int(player.get("asset_value", 0))})
	var grade := "S" if int(player.get("asset_value", 0)) >= 8000 and int(player.get("risk", 0)) <= 35 else "A" if int(player.get("asset_value", 0)) >= 4500 else "B" if int(player.get("asset_value", 0)) >= 1800 else "C"
	var verdict := "资本版图已形成，经营韧性优秀" if grade == "S" else "规模与风险保持良好平衡" if grade == "A" else "已建立经营基础，仍有扩张空间" if grade == "B" else "现金与风险管理仍需强化"
	var rankings: Array[Dictionary] = []
	for competitor: Dictionary in GameState.game_data.get("players", []):
		rankings.append({"player_id": str(competitor.get("id", "")), "name": str(competitor.get("name", "财团")), "asset": int(competitor.get("asset_value", 0)), "human": bool(competitor.get("human", false))})
	rankings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.asset) > int(b.asset))
	return {
		"player_id": player_id,
		"company_name": str(player.get("name", "本组财团")),
		"rounds": int(GameState.game_data.get("round", 0)),
		"cash": int(player.get("cash", 0)),
		"asset": int(player.get("asset_value", 0)),
		"peak_asset": peak_asset,
		"debt": int(player.get("debt", 0)),
		"risk": int(player.get("risk", 0)),
		"lands": player.get("land_ids", []).size(),
		"businesses": player.get("business_ids", []).size(),
		"talents": player.get("talent_ids", []).size(),
		"peak_rank": peak_rank,
		"total_net": total_net,
		"best_round": best_round,
		"best_round_net": 0 if best_round_net == -2147483648 else best_round_net,
		"listed": listed,
		"milestones": milestones,
		"asset_series": asset_series,
		"net_series": net_series,
		"grade": grade,
		"verdict": verdict,
		"rankings": rankings,
	}


static func _eliminate(player: Dictionary, reason: String, category: String, solo_message: String) -> Dictionary:
	var player_id: = str(player.get("id", ""))
	var removed_index: int = GameState.game_data.get("turn_order", []).find(player_id)
	var active_index := int(GameState.game_data.get("active_order_index", 0))
	player.eliminated = true
	player.status = "bankrupt"
	for land_id: String in player.land_ids.duplicate():
		Auctions.create_for_asset(land_id)
	var stock_pool: Dictionary = GameState.game_data.get_or_add("bankruptcy_stock_pool", {})
	for stock_id: String in player.stocks:
		var holding: Dictionary = player.stocks[stock_id]
		stock_pool[stock_id] = int(stock_pool.get(stock_id, 0)) + int(holding.get("shares", 0))
	player.stocks.clear()
	var listed_pool: Dictionary = GameState.game_data.get_or_add("bankruptcy_listed_stock_pool", {})
	for ticker: String in player.get("listed_stocks", {}):
		var listed_holding: Dictionary = player.listed_stocks[ticker]
		listed_pool[ticker] = int(listed_pool.get(ticker, 0)) + int(listed_holding.get("shares", 0))
	player.get_or_add("listed_stocks", {}).clear()
	var own_listing: Dictionary = GameState.game_data.get("ipo_records", {}).get(player_id, {})
	if str(own_listing.get("status", "")) == "listed":
		own_listing["status"] = "delisted"
		own_listing["market_status"] = "退市整理"
		own_listing["last_change"] = -0.80
		own_listing["share_price"] = maxf(0.5, float(own_listing.get("share_price", 1.0)) * 0.2)
		var history: Array = own_listing.get_or_add("price_history", [])
		history.append(float(own_listing.share_price))
		GameState.game_data.ipo_records[player_id] = own_listing
	GameState.game_data.turn_order.erase(player_id)
	if GameState.game_data.turn_order.is_empty():
		GameState.game_data.active_order_index = 0
	else:
		if removed_index >= 0 and removed_index < active_index:
			active_index -= 1
		elif removed_index == active_index and active_index >= GameState.game_data.turn_order.size():
			active_index = 0
		GameState.game_data.active_order_index = clampi(active_index, 0, GameState.game_data.turn_order.size() - 1)
	var details: = {"lands_to_auction": player.land_ids.duplicate(), "debt": int(player.debt), "reason": reason, "category": category}
	GameState._record(player_id, "bankruptcy", details)
	GameState.game_data.battle_ledger.append({"round": int(GameState.game_data.round), "category": "bankruptcy", "player_id": player_id, "title": "%s因%s退出竞争" % [str(player.name), reason], "details": details.duplicate(true)})
	var notices: Array = GameState.game_data.get_or_add("bankruptcy_notices", [])
	if not notices.any( func(item: Dictionary) -> bool: return str(item.get("player_id", "")) == player_id and int(item.get("round", -1)) == int(GameState.game_data.round)):
		notices.append({
			"player_id": player_id, "player_name": str(player.get("name", "本组")), 
			"reason": reason, "debt": int(player.get("debt", 0)), "category": category, 
			"message": solo_message, "round": int(GameState.game_data.round), 
			"solo": str(GameState.game_data.get("mode", "")) == "solo", "acknowledged": false, 
		})
	if str(GameState.game_data.get("mode", "")) == "solo":
		GameState.game_data.solo_bankruptcy_defeat = {
			"player_id": player_id, "player_name": str(player.get("name", "本组")), 
			"reason": reason, "debt": int(player.get("debt", 0)), "category": category, 
			"message": solo_message, 
		}
	return {"bankrupt": true, "player_id": player_id, "reason": reason, "category": category}
