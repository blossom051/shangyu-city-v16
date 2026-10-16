class_name CardRewardSystem
extends RefCounted

const DrawPolicy = preload("res://scripts/CardDrawPolicy.gd")


static func create_red_offer(player_id: String, source_card_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {"ok": false, "message": "玩家不存在"}
	var existing: Dictionary = player.get("pending_card_reward", {})
	if not existing.is_empty():
		return existing.duplicate(true)
	var pool: Array = GameConfig.list("cards").filter( func(card: Dictionary) -> bool:
		return str(card.get("rarity", "")) == "red" and str(card.get("id", "")) != source_card_id
	)
	var offer: Array[String] = []
	while not pool.is_empty() and offer.size() < 3:
		var index: = GameState.rng.randi_range(0, pool.size() - 1)
		var card: Dictionary = pool.pop_at(index)
		offer.append(str(card.id))
	if offer.size() < 3:
		return {"ok": false, "message": "红色卡池不足，无法形成三张明牌"}
	var reward: = {
		"ok": true, "kind": "red_three_choose_two", "source_card_id": source_card_id, 
		"offer": offer, "selected": [], "required": 2, 
		"created_round": int(GameState.game_data.get("round", 0)), 
	}
	player.pending_card_reward = reward
	GameState._record(player_id, "red_card_reward_opened", {"offer": offer.duplicate(), "required": 2, "source_card_id": source_card_id})
	return reward.duplicate(true)


static func pending(player_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	return {} if player.is_empty() else player.get("pending_card_reward", {}).duplicate(true)


static func choose(player_id: String, card_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {"ok": false, "message": "玩家不存在"}
	var reward: Dictionary = player.get("pending_card_reward", {})
	var offer: Array = reward.get("offer", [])
	var selected: Array = reward.get("selected", [])
	if reward.is_empty() or card_id not in offer:
		return {"ok": false, "message": "该红卡不在当前明牌候选中"}
	if card_id in selected:
		return {"ok": false, "message": "同一张明牌不能重复选择"}
	if selected.size() >= int(reward.get("required", 2)):
		return {"ok": false, "message": "本次红卡选择已经完成"}
	var acquired: = DrawPolicy.acquire_specific(player_id, card_id, "red_three_choose_two", false)
	if not bool(acquired.get("ok", false)):
		return acquired
	selected.append(card_id)
	reward.selected = selected
	var complete: = selected.size() >= int(reward.get("required", 2))
	if complete:
		player.pending_card_reward = {}
	GameState._record(player_id, "red_card_reward_chosen", {
		"card_id": card_id, "selected_count": selected.size(), "complete": complete, 
		"discarded": bool(acquired.get("discarded", false)), 
	})
	return {"ok": true, "card_id": card_id, "complete": complete, "selected": selected.duplicate(), "discarded": bool(acquired.get("discarded", false))}


static func auto_resolve(player_id: String) -> Dictionary:
	var reward: = pending(player_id)
	if reward.is_empty():
		return {"ok": false, "message": "没有待处理的红卡奖励"}
	var chosen: Array[String] = []
	for card_id: String in reward.get("offer", []):
		var result: = choose(player_id, card_id)
		if bool(result.get("ok", false)):
			chosen.append(card_id)
		if bool(result.get("complete", false)):
			return {"ok": true, "complete": true, "selected": chosen}
	return {"ok": false, "message": "红卡奖励无法自动完成", "selected": chosen}
