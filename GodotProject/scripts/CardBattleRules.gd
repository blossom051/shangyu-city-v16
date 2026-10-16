class_name CardBattleRules
extends RefCounted

const Businesses = preload("res://scripts/BusinessSystem.gd")

const ROUND_SP: = 3
const MAX_SP: = 3
const WEST_BANK_ROUND_SP: = 6
const MAX_SECRET_SLOTS: = 2
const MAX_CHAIN_DEPTH: = 3


static func ensure_player(player: Dictionary) -> void :
	player.get_or_add("strategy_points_max", MAX_SP)
	player.get_or_add("strategy_points", int(player.strategy_points_max))
	player.get_or_add("secret_zone", [])
	player.get_or_add("continuous_zone", [])
	if not bool(player.get("endless_cheat", false)) and _west_bank_unlocked(player) and int(player.get("strategy_points_max", MAX_SP)) < WEST_BANK_ROUND_SP:
		var increase := WEST_BANK_ROUND_SP - int(player.get("strategy_points_max", MAX_SP))
		player.strategy_points_max = WEST_BANK_ROUND_SP
		player.strategy_points = mini(WEST_BANK_ROUND_SP, int(player.get("strategy_points", 0)) + increase)
	load("res://scripts/CardComboRules.gd").ensure_player(player)


static func reset_round(player: Dictionary) -> void :
	ensure_player(player)
	if bool(player.get("endless_cheat", false)):
		player.strategy_points_max = 999999
		player.strategy_points = 999999
		load("res://scripts/CardComboRules.gd").reset_round(player)
		return
	var unlocked := _west_bank_unlocked(player)
	player.strategy_points_max = WEST_BANK_ROUND_SP if unlocked else MAX_SP
	player.strategy_points = WEST_BANK_ROUND_SP if unlocked else ROUND_SP
	load("res://scripts/CardComboRules.gd").reset_round(player)


static func _west_bank_unlocked(player: Dictionary) -> bool:
	var player_id := str(player.get("id", ""))
	return not player_id.is_empty() and bool(Businesses.premium_land_eligibility(player_id).get("ok", false))


static func cost(card: Dictionary) -> int:
	return clampi(int(card.get("cost", 1)), 0, MAX_SP)


static func can_pay(player: Dictionary, card: Dictionary) -> bool:
	ensure_player(player)
	if bool(player.get("endless_cheat", false)):
		return true
	return int(player.strategy_points) >= cost(card)


static func spend(player: Dictionary, card: Dictionary) -> Dictionary:
	ensure_player(player)
	var required: = cost(card)
	if bool(player.get("endless_cheat", false)):
		return {"ok": true, "cost": 0, "remaining_sp": int(player.strategy_points)}
	if int(player.strategy_points) < required:
		return {"ok": false, "message": "策略点不足：需要%d SP，当前%d SP" % [required, int(player.strategy_points)]}
	player.strategy_points = maxi(0, int(player.strategy_points) - required)
	return {"ok": true, "cost": required, "remaining_sp": int(player.strategy_points)}


static func can_deploy(player: Dictionary, card: Dictionary) -> Dictionary:
	ensure_player(player)
	if not str(card.get("type", "")) in ["defense", "counter"]:
		return {"ok": false, "message": "只有防御或反制牌可部署为秘策"}
	if not bool(player.get("endless_cheat", false)) and player.secret_zone.size() >= MAX_SECRET_SLOTS:
		return {"ok": false, "message": "董事会秘策区已满（2/2）"}
	if not can_pay(player, card):
		return {"ok": false, "message": "策略点不足，无法部署秘策"}
	return {"ok": true}


static func deploy(player: Dictionary, card: Dictionary) -> Dictionary:
	var allowed: = can_deploy(player, card)
	if not bool(allowed.get("ok", false)):
		return allowed
	var payment: = spend(player, card)
	if not bool(player.get("endless_cheat", false)):
		player.hand.erase(str(card.id))
	var state: Node = Engine.get_main_loop().root.get_node("GameState")
	player.secret_zone.append({"card_id": str(card.id), "deployed_round": int(state.game_data.get("round", 0)), "hidden": true})
	var capacity := "∞" if bool(player.get("endless_cheat", false)) else "2"
	return {"ok": true, "message": "秘策已背面部署（%d/%s）" % [player.secret_zone.size(), capacity], "deployed": true, "cost": int(payment.cost), "remaining_sp": int(payment.remaining_sp)}


static func eligible_secrets(defender: Dictionary, attack: Dictionary) -> Array[Dictionary]:
	ensure_player(defender)
	var result: Array[Dictionary] = []
	var category: = str(attack.get("category", "operation"))
	for slot: Dictionary in defender.secret_zone:
		var config: Node = Engine.get_main_loop().root.get_node("GameConfig")
		var response: Dictionary = config.by_id("cards", str(slot.get("card_id", "")))
		if not response.is_empty() and response.get("guards", []).has(category):
			result.append({"card": response, "slot": slot})
	return result


static func consume_secret(defender: Dictionary, card_id: String) -> bool:
	ensure_player(defender)
	for slot: Dictionary in defender.secret_zone.duplicate():
		if str(slot.get("card_id", "")) != card_id:
			continue
		defender.secret_zone.erase(slot)
		defender.discard.append(card_id)
		return true
	return false


static func chain_profile(attack: Dictionary, response: = {}, followup: = {}, overflow_response: = {}) -> Dictionary:
	var chain: Array[Dictionary] = [{"chain": 1, "card_id": str(attack.get("id", "")), "side": "attacker"}]
	if response is Dictionary and not response.is_empty():
		chain.append({"chain": 2, "card_id": str(response.get("id", "")), "side": "defender"})
	if followup is Dictionary and not followup.is_empty() and chain.size() < MAX_CHAIN_DEPTH:
		chain.append({"chain": 3, "card_id": str(followup.get("id", "")), "side": "attacker"})
	if overflow_response is Dictionary and not overflow_response.is_empty():
		return {"ok": false, "depth": 4, "max_depth": MAX_CHAIN_DEPTH, "message": "反应链已达3层上限", "resolution_order": [1, 2, 3], "chain": chain}
	return {"ok": true, "depth": chain.size(), "max_depth": MAX_CHAIN_DEPTH, "resolution_order": chain.duplicate().map( func(item: Dictionary) -> int: return int(item.chain)), "chain": chain}
