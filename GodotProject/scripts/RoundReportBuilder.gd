class_name RoundReportBuilder
extends RefCounted


static func build(report: Dictionary) -> Dictionary:
	var rows: Array[Dictionary] = []
	var all_players: Array = GameState.game_data.get("players", [])
	for player_index in range(all_players.size()):
		var player: Dictionary = all_players[player_index]
		var player_id: = str(player.get("id", ""))
		var entry: Dictionary = report.get("players", {}).get(player_id, {})
		var row: = {
			"player_id": player_id, 
			"group_number": player_index + 1, 
			"player_name": str(player.get("name", player_id)), 
			"round_change": int(entry.get("asset_change", entry.get("net", 0))), 
			"cash_change": int(entry.get("cash_change", 0)), 
			"net_worth": int(entry.get("asset_after", player.get("asset_value", 0))), 
			"rank": int(entry.get("rank_after", player.get("rank", 0))), 
			"rank_change": int(entry.get("rank_change", 0)), 
			"risk": int(entry.get("risk_after", player.get("risk", 0))), 
			"risk_change": int(entry.get("risk_change", 0)), 
			"key_event": _key_event(entry), 
			"business_income": int(entry.get("business_income", 0)), 
			"stock_pnl": int(entry.get("stock_pnl", 0)), 
			"interest": int(entry.get("interest", 0)), 
		}
		rows.append(row)
	rows.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a.rank) < int(b.rank))
	return {
		"round": int(report.get("round", GameState.game_data.get("round", 0))), 
		"players": rows, 
		"biggest_winner": _extreme(rows, "round_change", true), 
		"biggest_loss": _extreme(rows, "round_change", false), 
		"risk_alert": _extreme(rows, "risk", true), 
		"biggest_transaction": _biggest_transaction(), 
		"competition_event": _latest_competition_event(), 
		"next_round_starter": next_round_starter(), 
	}


static func next_round_starter() -> Dictionary:
	var eligible: Array[Dictionary] = []
	var players: Array = GameState.game_data.get("players", [])
	for index in range(players.size()):
		var player: Dictionary = players[index]
		if bool(player.get("eliminated", false)):
			continue
		eligible.append({
			"player_id": str(player.get("id", "")), 
			"player_name": str(player.get("name", "财团")), 
			"group_number": index + 1, 
		})
	var next_round: = int(GameState.game_data.get("round", 0)) + 1
	if next_round % 2 == 0:
		eligible.reverse()
	if eligible.is_empty():
		return {}
	var result: Dictionary = eligible[0].duplicate(true)
	result["round"] = next_round
	return result


static func _key_event(entry: Dictionary) -> String:
	var loan: Dictionary = entry.get("loan_settlement", {})
	if loan.get("events", []).any( func(item: Dictionary) -> bool: return int(item.get("overdue_after", 0)) > 0):
		return "贷款逾期，授信承压"
	var startups: Array = entry.get("startups", [])
	if not startups.is_empty():
		return str(startups[0].get("message", startups[0].get("title", "创投项目完成验证")))
	var lines: Array = entry.get("lines", [])
	if not lines.is_empty():
		var best: Dictionary = lines[0]
		for line: Dictionary in lines:
			if abs(int(line.get("value", 0))) > abs(int(best.get("value", 0))):
				best = line
		return "%s %+d万" % [str(best.get("label", "企业经营")), int(best.get("value", 0))]
	if int(entry.get("stock_pnl", 0)) != 0:
		return "证券浮动 %+d万" % int(entry.get("stock_pnl", 0))
	return "稳健经营，暂无重大事项"


static func _extreme(rows: Array[Dictionary], key: String, highest: bool) -> Dictionary:
	if rows.is_empty():
		return {}
	var result: Dictionary = rows[0]
	for row: Dictionary in rows:
		if (highest and int(row.get(key, 0)) > int(result.get(key, 0))) or ( not highest and int(row.get(key, 0)) < int(result.get(key, 0))):
			result = row
	return result.duplicate(true)


static func _biggest_transaction() -> Dictionary:
	var current_round: = int(GameState.game_data.get("round", 0))
	var result: Dictionary = {}
	for event: Dictionary in GameState.game_data.get("log", []):
		if int(event.get("round", current_round)) != current_round:
			continue
		var amount: = 0
		for key in ["amount", "paid", "price", "proceeds", "total"]:
			amount = maxi(amount, abs(int(event.get(key, 0))))
		if amount > int(result.get("amount", 0)):
			result = {"amount": amount, "player_id": str(event.get("player_id", "")), "event": str(event.get("event", event.get("type", "资本交易")))}
	return result


static func _latest_competition_event() -> Dictionary:
	var current_round: = int(GameState.game_data.get("round", 0))
	var events: Array = GameState.game_data.get("battle_ledger", [])
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if int(event.get("round", -1)) == current_round and str(event.get("category", "")) != "settlement":
			return event.duplicate(true)
	return {}
