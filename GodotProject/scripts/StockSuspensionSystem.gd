class_name StockSuspensionSystem
extends RefCounted


static func initialize_match(round_limit: int) -> void :
	var stock_ids: Array[String] = []
	for stock_id: Variant in GameState.game_data.get("stocks", {}).keys():
		stock_ids.append(str(stock_id))
	_shuffle(stock_ids)
	var count: = 1 if round_limit <= 8 else 2
	count = mini(count, stock_ids.size())
	var signal_rounds: Array[int] = []
	if count == 1:
		signal_rounds.append(GameState.rng.randi_range(2, maxi(2, round_limit - 3)))
	else:
		var first_latest: = maxi(2, round_limit / 2 - 2)
		signal_rounds.append(GameState.rng.randi_range(2, first_latest))
		var second_earliest: = maxi(signal_rounds[0] + 3, round_limit / 2 + 1)
		signal_rounds.append(GameState.rng.randi_range(second_earliest, maxi(second_earliest, round_limit - 3)))
	var schedule: Array[Dictionary] = []
	for index in range(count):
		var signal_round: = signal_rounds[index]
		var duration: = GameState.rng.randi_range(2, 3)
		var direction: = -1 if GameState.rng.randf() < 0.5 else 1
		schedule.append({
			"id": "suspension_%02d" % (index + 1), 
			"stock_id": stock_ids[index], 
			"signal_round": signal_round, 
			"halt_round": signal_round + 1, 
			"resume_round": mini(round_limit, signal_round + duration), 
			"direction": direction, 
			"jump": snappedf(GameState.rng.randf_range(0.6, 0.85), 0.01), 
			"resolved": false, 
		})
	GameState.game_data.stock_suspension_schedule = schedule
	GameState.game_data.stock_suspension_history = []
	apply_round_state()


static func ensure_compatible_state() -> void :
	GameState.game_data.get_or_add("stock_suspension_schedule", [])
	GameState.game_data.get_or_add("stock_suspension_history", [])
	for stock: Dictionary in GameState.game_data.get("stocks", {}).values():
		stock.get_or_add("market_status", "normal")
		stock.get_or_add("suspended", false)
		stock.get_or_add("status_text", "连续竞价")
		stock.get_or_add("last_resume_change", 0.0)
		stock.get_or_add("last_resume_round", -1)


static func apply_round_state() -> void :
	ensure_compatible_state()
	var current: = int(GameState.game_data.get("round", 0))
	for stock: Dictionary in GameState.game_data.get("stocks", {}).values():
		stock.market_status = "normal"
		stock.suspended = false
		stock.status_text = "连续竞价"
	for event: Dictionary in GameState.game_data.get("stock_suspension_schedule", []):
		var stock: Dictionary = GameState.game_data.get("stocks", {}).get(str(event.get("stock_id", "")), {})
		if stock.is_empty():
			continue
		if current == int(event.get("signal_round", -1)):
			stock.market_status = "watch"
			stock.status_text = "市场观察  信息披露窗口临近"
		elif current >= int(event.get("halt_round", 999)) and current <= int(event.get("resume_round", -1)):
			var remaining: = int(event.get("resume_round", current)) - current + 1
			stock.market_status = "suspended"
			stock.suspended = true
			stock.status_text = "暂停交易  %s" % ("本轮收盘后恢复定价" if remaining <= 1 else "预计还需 %d 回合" % remaining)
		elif current == int(event.get("resume_round", -2)) + 1 and bool(event.get("resolved", false)):
			stock.market_status = "resumed"
			stock.status_text = "刚刚复牌  跳空 %+.1f%%" % (float(stock.get("last_resume_change", 0.0)) * 100.0)


static func status(stock_id: String) -> Dictionary:
	var stock: Dictionary = GameState.game_data.get("stocks", {}).get(stock_id, {})
	return {
		"stock_id": stock_id, 
		"status": str(stock.get("market_status", "normal")), 
		"suspended": bool(stock.get("suspended", false)), 
		"text": str(stock.get("status_text", "连续竞价")), 
		"tradable": not bool(stock.get("suspended", false)), 
	}


static func signal_story() -> Dictionary:
	var current: = int(GameState.game_data.get("round", 0))
	for event: Dictionary in GameState.game_data.get("stock_suspension_schedule", []):
		if int(event.get("signal_round", -1)) != current:
			continue
		var stock: Dictionary = GameState.game_data.get("stocks", {}).get(str(event.get("stock_id", "")), {})
		if stock.is_empty():
			continue
		var templates: = [
			"%s近期迎来多家机构密集调研，公告披露节奏受到交易端关注", 
			"%s所在板块出现异常资金与信息披露节奏，市场等待进一步材料", 
			"%s临近行业监管与重大事项披露窗口，机构分歧明显扩大", 
		]
		return {
			"id": "market_observation_%d_%s" % [current, str(stock.id)], 
			"section": "market", 
			"title": templates[GameState.rng.randi_range(0, templates.size() - 1)] %str(stock.name), 
			"tags": [str(stock.sector), "市场观察"], 
			"actual_direction": 0, 
			"actual_strength": 0.0, 
			"credibility": "medium", 
			"verified": false, 
			"settlement_text": "公告窗口临近，交易端暂未形成一致判断。", 
		}
	return {}


static func settlement_directive(stock_id: String) -> Dictionary:
	var current: = int(GameState.game_data.get("round", 0))
	for event: Dictionary in GameState.game_data.get("stock_suspension_schedule", []):
		if str(event.get("stock_id", "")) != stock_id:
			continue
		var halt_round: = int(event.get("halt_round", 999))
		var resume_round: = int(event.get("resume_round", -1))
		if current < halt_round or current > resume_round:
			continue
		if current == resume_round and not bool(event.get("resolved", false)):
			return {
				"action": "resume", 
				"change": float(event.get("direction", 1)) * float(event.get("jump", 0.6)), 
				"event": event, 
			}
		return {"action": "hold", "event": event}
	return {"action": "normal"}


static func resolve_resume(stock_id: String, event: Dictionary, applied_change: float) -> void :
	event.resolved = true
	var stock: Dictionary = GameState.game_data.get("stocks", {}).get(stock_id, {})
	stock.last_resume_change = applied_change
	stock.last_resume_round = int(GameState.game_data.get("round", 0))
	stock.market_status = "resumed"
	stock.suspended = false
	stock.status_text = "复牌定价完成  跳空 %+.1f%%" % (applied_change * 100.0)
	var entry: = {
		"round": int(GameState.game_data.get("round", 0)), 
		"stock_id": stock_id, 
		"change": applied_change, 
		"event_id": str(event.get("id", "")), 
	}
	GameState.game_data.get_or_add("stock_suspension_history", []).append(entry)
	GameState._record("system", "stock_resumed", entry)


static func _shuffle(values: Array[String]) -> void :
	for index in range(values.size() - 1, 0, -1):
		var target: = GameState.rng.randi_range(0, index)
		var value: = values[index]
		values[index] = values[target]
		values[target] = value
