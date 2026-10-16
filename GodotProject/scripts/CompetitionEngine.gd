class_name CompetitionEngine
extends RefCounted

const Businesses = preload("res://scripts/BusinessSystem.gd")
const Districts = preload("res://scripts/DistrictSystem.gd")
const Settlement = preload("res://scripts/TurnSettlement.gd")


static func execute(command: Dictionary) -> Dictionary:
	var command_type: = str(command.get("type", ""))
	match command_type:
		"buy_land":
			return _buy_land(command)
		_:
			return _failure("未知商业行动：%s" % command_type)


static func settle_round() -> Dictionary:
	return Settlement.settle_round()


static func _buy_land(command: Dictionary) -> Dictionary:
	var player_id: = str(command.get("player_id", ""))
	var land_id: = str(command.get("land_id", ""))
	var before_player: = GameState.player(player_id).duplicate(true)
	var before_land: Dictionary = GameState.game_data.get("lands", {}).get(land_id, {}).duplicate(true)
	var before_districts: Dictionary = GameState.game_data.get("districts", {}).duplicate(true)
	var operation: Dictionary = Businesses.buy_land(player_id, land_id)
	if not bool(operation.get("ok", false)):
		return _failure(str(operation.get("message", "购买失败")))
	var events: Array[Dictionary] = [{
		"type": "land_bought", 
		"player_id": player_id, 
		"land_id": land_id, 
		"amount": int(before_land.get("price", 0)), 
	}]
	var district_id: = str(before_land.get("district", ""))
	var district_after: Dictionary = GameState.game_data.get("districts", {}).get(district_id, {})
	if before_districts.get(district_id, {}) != district_after:
		events.append({"type": "district_control_changed", "district_id": district_id, "leader_id": str(district_after.get("leader_id", "")), "dominant_id": str(district_after.get("dominant_id", "")), "control": district_after.get("control", {}).duplicate(true)})
	_register_events(events)
	var player: = GameState.player(player_id)
	var land: Dictionary = GameState.game_data.lands[land_id]
	var ledger_entry: = {
		"round": int(GameState.game_data.get("round", 0)), 
		"category": "land", 
		"player_id": player_id, 
		"title": "%s 抢下关键地块 %s" % [str(player.get("name", player_id)), land_id], 
		"details": {
			"district_id": str(land.get("district", "")), 
			"district_name": str(land.get("district_name", "")), 
			"price": int(before_land.get("price", 0)), 
		}, 
	}
	GameState.game_data.battle_ledger.append(ledger_entry)
	GameState.save_to_disk()
	GameState._emit_change()
	return {
		"ok": true, 
		"message": "购买成功，商圈控制度已更新", 
		"changes": {
			"cash": {"before": int(before_player.get("cash", 0)), "after": int(player.cash)}, 
			"land": {"id": land_id, "owner_id": player_id, "state": str(land.state)}, 
			"district": GameState.game_data.districts.get(str(land.district), {}).duplicate(true), 
		}, 
		"events": events, 
		"presentation": {
			"type": "land_purchase", 
			"title": "关键地块已购入", 
			"subtitle": "%s  %s" % [land_id, str(land.get("district_name", "城市商圈"))], 
			"focus_land_id": land_id, 
		}, 
	}


static func _register_events(events: Array[Dictionary]) -> void :
	for event: Dictionary in events:
		var stored: = event.duplicate(true)
		stored["round"] = int(GameState.game_data.get("round", 0))
		stored["event_id"] = "R%02d-E%04d" % [int(GameState.game_data.get("round", 0)), GameState.game_data.domain_events.size() + 1]
		GameState.game_data.domain_events.append(stored)


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false, 
		"message": message, 
		"changes": {}, 
		"events": [], 
		"presentation": {"type": "error", "title": message}, 
	}
