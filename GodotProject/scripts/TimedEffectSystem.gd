class_name TimedEffectSystem
extends RefCounted

const Risks = preload("res://scripts/RiskSystem.gd")


static func add_player_effect(
	player_id: String, 
	kind: String, 
	value: Variant, 
	duration_rounds: int, 
	source_id: = "", 
	extra: = {}
) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {"ok": false, "message": "玩家不存在"}
	var effect: = {
		"kind": kind, 
		"value": value, 
		"duration": maxi(1, duration_rounds), 
		"source_id": source_id, 
		"started_round": int(GameState.game_data.get("round", 0)), 
	}
	effect.merge(extra, true)
	player.get_or_add("effects", []).append(effect)
	return {"ok": true, "effect": effect}


static func add_business_effect(
	business_id: String, 
	kind: String, 
	value: Variant, 
	duration_rounds: int, 
	source_player_id: = "", 
	card_id: = ""
) -> Dictionary:
	var business: Dictionary = GameState.game_data.get("businesses", {}).get(business_id, {})
	if business.is_empty():
		return {"ok": false, "message": "企业不存在"}
	var effect: = {
		"kind": kind, 
		"value": value, 
		"duration": maxi(1, duration_rounds), 
		"source_player_id": source_player_id, 
		"card_id": card_id, 
		"started_round": int(GameState.game_data.get("round", 0)), 
	}
	business.get_or_add("effects", []).append(effect)
	return {"ok": true, "effect": effect}


static func lock_cash(player_id: String, requested: int, duration_rounds: = 1, source_id: = "") -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty() or requested <= 0:
		return {"ok": false, "message": "没有可冻结资金", "amount": 0}
	var amount: = mini(requested, available_cash(player))
	if amount <= 0:
		return {"ok": false, "message": "目标没有可冻结资金", "amount": 0}
	var effect: = {
		"kind": "cash_lock", 
		"amount": amount, 
		"source_id": source_id, 
		"started_round": int(GameState.game_data.get("round", 0)), 
		"unlock_after_round": int(GameState.game_data.get("round", 0)) + maxi(1, duration_rounds), 
	}
	player.effects.append(effect)
	GameState._record(player_id, "cash_locked", effect.duplicate(true))
	return {"ok": true, "message": "已冻结%d万可用现金" % amount, "amount": amount, "effect": effect}


static func available_cash(player: Dictionary) -> int:
	var locked: = 0
	for effect: Dictionary in player.get("effects", []):
		if str(effect.get("kind", "")) == "cash_lock":
			locked += int(effect.get("amount", 0))
	return maxi(0, int(player.get("cash", 0)) - locked)


static func finish_round(completed_round: int) -> void :
	for player: Dictionary in GameState.game_data.get("players", []):
		for effect: Dictionary in player.get("effects", []).duplicate():
			match str(effect.get("kind", "")):
				"cash_lock":
					if int(effect.get("unlock_after_round", completed_round)) <= completed_round:
						player.effects.erase(effect)
						GameState._record(str(player.id), "cash_unlocked", {"amount": int(effect.get("amount", 0)), "source_id": str(effect.get("source_id", ""))})
				"temporary_risk":
					if int(effect.get("expires_after_round", completed_round)) <= completed_round:
						Risks.adjust(str(player.id), - int(effect.get("amount", 0)), "临时风险到期", "时效效果")
						player.effects.erase(effect)
	for effect: Dictionary in GameState.game_data.get("district_effects", []).duplicate():
		if int(effect.get("expires_after_round", completed_round)) <= completed_round:
			GameState.game_data.district_effects.erase(effect)


static func add_district_effect(district_id: String, kind: String, value: float, duration_rounds: int, source_id: = "", extra: = {}) -> Dictionary:
	if not GameState.game_data.get("districts", {}).has(district_id):
		return {"ok": false, "message": "商圈不存在"}
	var effect: = {
		"district_id": district_id, 
		"kind": kind, 
		"value": value, 
		"source_id": source_id, 
		"started_round": int(GameState.game_data.get("round", 0)), 
		"expires_after_round": int(GameState.game_data.get("round", 0)) + maxi(1, duration_rounds) - 1, 
	}
	effect.merge(extra, true)
	GameState.game_data.get_or_add("district_effects", []).append(effect)
	return {"ok": true, "effect": effect}


static func add_temporary_risk(player_id: String, amount: int, duration_rounds: int, source_id: = "") -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty() or amount <= 0:
		return {"ok": false}
	Risks.adjust(player_id, amount, "临时风险", "时效效果")
	var effect: = {"kind": "temporary_risk", "amount": amount, "source_id": source_id, "expires_after_round": int(GameState.game_data.get("round", 0)) + maxi(1, duration_rounds) - 1}
	player.effects.append(effect)
	return {"ok": true, "effect": effect}
