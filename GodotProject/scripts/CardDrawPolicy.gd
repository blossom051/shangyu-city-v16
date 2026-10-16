class_name CardDrawPolicy
extends RefCounted


const CompanyRules = preload("res://scripts/CompanyAbilityEngine.gd")
const RARITY_WEIGHTS: = {"blue": 0.45, "gold": 0.3, "platinum": 0.15, "red": 0.05, "gilded": 0.05}
const DISCARD_POINTS: = {"blue": 1, "gold": 2, "platinum": 4, "red": 8, "gilded": 12, "west_bank": 3, "west_bank_advanced": 6}
const WEST_BANK_ADVANCED_OFFER_RATE := 0.08
const MAX_SAME_CARD_IN_HAND: = 2
const PLATINUM_PITY: = 8
const RED_PITY: = 18
const NORMAL_REDEEM_COST: = 12
const RED_REDEEM_COST: = 24


static func points_guide() -> Dictionary:
	return {
		"source": "弃置手牌获得积分", 
		"rarity_points": DISCARD_POINTS.duplicate(), 
		"normal_exchange": "12积分：三选一策略卡", 
		"red_exchange": "24积分：三张红色明牌中选择1张", 
	}


static func draw_many(player_id: String, count: int, source: = "regular", allow_company_bonus: = true) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty() or count <= 0:
		return {"ok": false, "message": "玩家不存在或抽取数量无效", "draws": []}
	var results: Array[Dictionary] = []
	for _index in count:
		results.append(draw_one(player_id, source))
		if allow_company_bonus and source == "regular" and CompanyRules.should_award_regular_draw_bonus(player):
			results.append(draw_one(player_id, "company_bonus"))
	return {"ok": true, "draws": results, "count": results.size(), "needs_discard": player.hand.size() > 5}


static func draw_one(player_id: String, source: = "regular") -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {"ok": false, "message": "玩家不存在"}
	var rarity: = _next_rarity(player)
	var pool: Array = GameConfig.list("cards").filter( func(card: Dictionary) -> bool: return str(card.get("rarity", "")) == rarity and str(card.get("series", "")) != "west_bank")
	if pool.is_empty():
		pool = GameConfig.list("cards").filter( func(card: Dictionary) -> bool: return str(card.get("series", "")) != "west_bank")
	var card: Dictionary = pool[GameState.rng.randi_range(0, pool.size() - 1)]
	return acquire_specific(player_id, str(card.id), source, _advances_pity(source))


static func acquire_specific(player_id: String, card_id: String, source: String, advance_pity: = true) -> Dictionary:
	var player: = GameState.player(player_id)
	var card: = GameConfig.by_id("cards", card_id)
	if player.is_empty() or card.is_empty():
		return {"ok": false, "message": "卡牌或玩家不存在"}
	var rarity: = str(card.get("rarity", "blue"))
	if advance_pity:
		_update_pity(player, rarity)
	var copy_count: int = player.hand.count(card_id)
	var forced_discard: bool = copy_count >= MAX_SAME_CARD_IN_HAND
	var points: = 0
	if forced_discard:
		points = _award_discard(player_id, player, card_id, "同名持有上限强制弃牌", false)
	else:
		player.hand.append(card_id)
	var result: = {
		"ok": true, 
		"card_id": card_id, 
		"rarity": rarity, 
		"source": source, 
		"discarded": forced_discard, 
		"discard_reason": "同名持有上限" if forced_discard else "", 
		"converted": forced_discard, 
		"points": points, 
	}
	GameState._record(player_id, "card_acquired", result.duplicate(true))
	return result


static func redemption_choices(player_id: String, red_only: = false) -> Array[String]:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return []
	var existing: Dictionary = player.get("redemption_offer", {})
	if bool(existing.get("red_only", false)) == red_only and int(existing.get("created_round", -1)) == int(GameState.game_data.get("round", 0)):
		var locked_ids: Array = existing.get("card_ids", [])
		if not locked_ids.is_empty():
			var locked: Array[String] = []
			for value: Variant in locked_ids:
				locked.append(str(value))
			return locked
	var rarity_filter: = "red" if red_only else ""
	var available: Array = GameConfig.list("cards").filter( func(card: Dictionary) -> bool:
		var rarity: = str(card.get("rarity", ""))
		if str(card.get("series", "")) == "west_bank":
			return false
		if red_only and rarity != rarity_filter:
			return false
		if not red_only and rarity in ["red", "gilded"]:
			return false
		return player.hand.count(str(card.get("id", ""))) < MAX_SAME_CARD_IN_HAND
	)
	var choices: Array[String] = []
	while not available.is_empty() and choices.size() < 3:
		var index: = GameState.rng.randi_range(0, available.size() - 1)
		var card: Dictionary = available.pop_at(index)
		choices.append(str(card.get("id", "")))
	player.redemption_offer = {
		"red_only": red_only, 
		"card_ids": choices.duplicate(), 
		"created_round": int(GameState.game_data.get("round", 0)), 
	}
	return choices


static func discard_value(card_id: String) -> int:
	var card: = GameConfig.by_id("cards", card_id)
	return int(DISCARD_POINTS.get(str(card.get("rarity", "blue")), 1)) if not card.is_empty() else 0


static func discard_hand_card(player_id: String, card_id: String, reason: = "主动弃牌") -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty() or not player.hand.has(card_id):
		return {"ok": false, "message": "未持有该卡牌"}
	var points: = _award_discard(player_id, player, card_id, reason, true)
	return {
		"ok": true, 
		"card_id": card_id, 
		"rarity": str(GameConfig.by_id("cards", card_id).get("rarity", "blue")), 
		"points": points, 
		"remaining_points": int(player.get("card_points", 0)), 
		"reason": reason, 
		"message": "弃置 %s，获得 %d 卡牌积分" % [str(GameConfig.by_id("cards", card_id).get("name", card_id)), points], 
	}


static func _award_discard(player_id: String, player: Dictionary, card_id: String, reason: String, remove_from_hand: bool) -> int:
	var card: = GameConfig.by_id("cards", card_id)
	var rarity: = str(card.get("rarity", "blue"))
	var points: = int(DISCARD_POINTS.get(rarity, 1))
	if remove_from_hand:
		player.hand.erase(card_id)
	player.discard.append(card_id)
	player.card_points = int(player.get("card_points", 0)) + points
	GameState._record(player_id, "card_discarded_for_points", {
		"card_id": card_id, 
		"card_name": str(card.get("name", card_id)), 
		"rarity": rarity, 
		"reason": reason, 
		"points": points, 
	})
	return points


static func redeem_choice(player_id: String, card_id: String, red_only: = false) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {"ok": false, "message": "玩家不存在"}
	var cost: = RED_REDEEM_COST if red_only else NORMAL_REDEEM_COST
	if int(player.get("card_points", 0)) < cost:
		return {"ok": false, "message": "卡牌积分不足：需要 %d 分" % cost}
	var card: = GameConfig.by_id("cards", card_id)
	if card.is_empty():
		return {"ok": false, "message": "所选卡牌不存在"}
	if red_only and str(card.get("rarity", "")) != "red":
		return {"ok": false, "message": "红卡兑换只能选择红色卡牌"}
	var offer: Dictionary = player.get("redemption_offer", {})
	var offered_ids: Array = offer.get("card_ids", [])
	if bool(offer.get("red_only", false)) != red_only or card_id not in offered_ids:
		return {"ok": false, "message": "兑换候选已过期，请重新打开兑换页"}
	player.card_points = int(player.get("card_points", 0)) - cost
	var result: = acquire_specific(player_id, card_id, "redemption_red_choice" if red_only else "redemption_choice", false)
	if not bool(result.get("ok", false)):
		player.card_points += cost
		return result
	player.redemption_offer = {}
	result["cost"] = cost
	result["remaining_points"] = int(player.card_points)
	result["message"] = "兑换获得 %s" % str(GameConfig.by_id("cards", str(result.card_id)).get("name", result.card_id))
	GameState._record(player_id, "card_redeemed", result.duplicate(true))
	return result


static func redeem(player_id: String, red_only: = false) -> Dictionary:


	var choices: = redemption_choices(player_id, red_only)
	if choices.is_empty():
		return {"ok": false, "message": "当前没有可兑换卡牌"}
	return redeem_choice(player_id, choices[0], red_only)


static func create_offer(count: = 5) -> Array[String]:
	var result: Array[String] = []
	var available: Array = GameConfig.list("cards").filter( func(card: Dictionary) -> bool: return str(card.get("series", "")) != "west_bank")
	while not available.is_empty() and result.size() < count:
		var rarity: = _weighted_rarity()
		var candidates: Array = available.filter( func(card: Dictionary) -> bool: return str(card.get("rarity", "")) == rarity)
		if candidates.is_empty():
			candidates = available
		var chosen: Dictionary = candidates[GameState.rng.randi_range(0, candidates.size() - 1)]
		result.append(str(chosen.id))
		available.erase(chosen)
	return result


static func create_west_bank_offer(count: = 5) -> Array[String]:
	var result: Array[String] = []
	var ordinary: Array = GameConfig.list("cards").filter( func(card: Dictionary) -> bool:
		return str(card.get("series", "")) == "west_bank" and str(card.get("rarity", "")) == "west_bank")
	var advanced: Array = GameConfig.list("cards").filter( func(card: Dictionary) -> bool:
		return str(card.get("series", "")) == "west_bank" and str(card.get("rarity", "")) == "west_bank_advanced")
	if count > 0 and not advanced.is_empty() and GameState.rng.randf() < WEST_BANK_ADVANCED_OFFER_RATE:
		var advanced_index := GameState.rng.randi_range(0, advanced.size() - 1)
		result.append(str(advanced[advanced_index].get("id", "")))
	while not ordinary.is_empty() and result.size() < count:
		var chosen_index := GameState.rng.randi_range(0, ordinary.size() - 1)
		var chosen: Dictionary = ordinary.pop_at(chosen_index)
		result.append(str(chosen.get("id", "")))
	for index in range(result.size() - 1, 0, -1):
		var swap_index := GameState.rng.randi_range(0, index)
		var held := result[index]
		result[index] = result[swap_index]
		result[swap_index] = held
	return result


static func validate_policy() -> Dictionary:
	var errors: Array[String] = []
	var total: = 0.0
	for value: Variant in RARITY_WEIGHTS.values():
		total += float(value)
	if absf(total - 1.0) > 0.001:
		errors.append("card rarity weights must total one")
	for card: Dictionary in GameConfig.list("cards"):
		if str(card.get("series", "")) == "west_bank":
			var west_rarity := str(card.get("rarity", ""))
			var expected_cost := 3 if west_rarity == "west_bank_advanced" else 2
			if west_rarity not in ["west_bank", "west_bank_advanced"] or int(card.get("cost", 0)) != expected_cost:
				errors.append("invalid west bank card profile on %s" % str(card.get("id", "")))
			continue
		if not RARITY_WEIGHTS.has(str(card.get("rarity", ""))):
			errors.append("unknown rarity on card %s" % str(card.get("id", "")))
	if PLATINUM_PITY != 8 or RED_PITY != 18:
		errors.append("pity thresholds do not match the approved rules")
	return {"ok": errors.is_empty(), "errors": errors}


static func _next_rarity(player: Dictionary) -> String:
	if int(player.get("card_draws_since_red", 0)) >= RED_PITY - 1:
		return "red"
	if int(player.get("card_draws_since_platinum", 0)) >= PLATINUM_PITY - 1:
		return "red" if GameState.rng.randf() < RARITY_WEIGHTS.red / (RARITY_WEIGHTS.red + RARITY_WEIGHTS.platinum) else "platinum"
	return _weighted_rarity()


static func _weighted_rarity() -> String:
	var roll: = GameState.rng.randf()
	var cumulative: = 0.0
	for rarity in ["gilded", "red", "platinum", "gold", "blue"]:
		cumulative += float(RARITY_WEIGHTS[rarity])
		if roll < cumulative:
			return rarity
	return "blue"


static func _update_pity(player: Dictionary, rarity: String) -> void :
	if rarity in ["red", "gilded"]:
		player.card_draws_since_red = 0
		player.card_draws_since_platinum = 0
	elif rarity == "platinum":
		player.card_draws_since_red = int(player.get("card_draws_since_red", 0)) + 1
		player.card_draws_since_platinum = 0
	else:
		player.card_draws_since_red = int(player.get("card_draws_since_red", 0)) + 1
		player.card_draws_since_platinum = int(player.get("card_draws_since_platinum", 0)) + 1


static func _advances_pity(source: String) -> bool:
	return source in ["regular", "company_bonus", "round_offer", "event"]
