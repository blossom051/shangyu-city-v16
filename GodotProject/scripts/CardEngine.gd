class_name CardEngine
extends RefCounted

const TimedEffects = preload("res://scripts/TimedEffectSystem.gd")
const DrawPolicy = preload("res://scripts/CardDrawPolicy.gd")
const Risks = preload("res://scripts/RiskSystem.gd")
const Effects = preload("res://scripts/CardEffectResolver.gd")
const Talents = preload("res://scripts/TalentSystem.gd")
const EffectContract = preload("res://scripts/CardEffectContract.gd")
const Rewards = preload("res://scripts/CardRewardSystem.gd")
const BattleRules = preload("res://scripts/CardBattleRules.gd")
const ComboRules = preload("res://scripts/CardComboRules.gd")
const BattlePresenter = preload("res://scripts/CardBattlePresenter.gd")
const Stocks = preload("res://scripts/StockSystem.gd")
const Businesses = preload("res://scripts/BusinessSystem.gd")

const RESPONSE_EFFECTS: Array[String] = [
	"legal_shield", "pr_repair", "stable_operation", "anti_poaching", 
	"counter_trap", "opinion_backlash", "legal_counter", 
]


static func supports_effect(effect: String) -> bool:
	return effect in RESPONSE_EFFECTS or Effects.supports(effect)


static func draw_cards(player_id: String, count: int) -> Dictionary:
	return DrawPolicy.draw_many(player_id, count, "regular", true)


static func create_round_offer(player_id: String, count: = 5) -> Array[String]:
	var player: = GameState.player(player_id)
	var result: Array[String] = []
	if player.is_empty():
		return result
	result = DrawPolicy.create_offer(count)
	GameState.game_data.get_or_add("round_card_offers", {})[player_id] = result
	var west_result: Array[String] = []
	if bool(Businesses.premium_land_eligibility(player_id).get("ok", false)):
		west_result = DrawPolicy.create_west_bank_offer(count)
		GameState.game_data.get_or_add("west_round_card_offers", {})[player_id] = west_result
	GameState._record(player_id, "round_card_offer", {"cards": result.duplicate(), "west_bank_cards": west_result.duplicate(), "draft_count": 2 if not west_result.is_empty() else 1})
	return result


static func round_offer(player_id: String) -> Array:
	var regular: Array = GameState.game_data.get("round_card_offers", {}).get(player_id, [])
	if not regular.is_empty():
		return regular.duplicate()
	return GameState.game_data.get("west_round_card_offers", {}).get(player_id, []).duplicate()


static func round_offer_kind(player_id: String) -> String:
	if not GameState.game_data.get("round_card_offers", {}).get(player_id, []).is_empty():
		return "old_city"
	if not GameState.game_data.get("west_round_card_offers", {}).get(player_id, []).is_empty():
		return "west_bank"
	return ""


static func west_bank_round_offer(player_id: String) -> Array:
	return GameState.game_data.get("west_round_card_offers", {}).get(player_id, []).duplicate()


static func choose_round_card(player_id: String, card_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	var offer: Array = round_offer(player_id)
	if player.is_empty() or offer.is_empty():
		return _fail("本回合没有待选择卡牌")
	if not offer.has(card_id):
		return _fail("只能从本回合五张候选中选择")
	var offer_kind := round_offer_kind(player_id)
	var is_west := offer_kind == "west_bank"
	var acquisition: = DrawPolicy.acquire_specific(player_id, card_id, "west_bank_round_offer" if is_west else "round_offer", not is_west)
	if is_west:
		GameState.game_data.west_round_card_offers.erase(player_id)
	else:
		GameState.game_data.round_card_offers.erase(player_id)
	GameState._record(player_id, "round_card_chosen", {"card_id": card_id, "offer_kind": offer_kind, "hand_count": player.hand.size(), "converted": bool(acquisition.get("converted", false)), "points": int(acquisition.get("points", 0))})
	var message: = "同名牌达到上限，本张已弃置并获得%d积分" % int(acquisition.get("points", 0)) if bool(acquisition.get("discarded", false)) else "已收入手牌：%s" % str(GameConfig.by_id("cards", card_id).get("name", card_id))
	return _ok(message, {"card_id": card_id, "offer_kind": offer_kind, "remaining_offer_kind": round_offer_kind(player_id), "draft_complete": round_offer(player_id).is_empty(), "discarded": bool(acquisition.get("discarded", false)), "converted": bool(acquisition.get("discarded", false)), "points": int(acquisition.get("points", 0)), "needs_discard": player.hand.size() > 5})


static func auto_choose_round_card(player_id: String) -> Dictionary:
	var offer: Array = round_offer(player_id)
	if offer.is_empty():
		return _fail("没有待选择卡牌")
	var result: = choose_round_card(player_id, str(offer[0]))
	var player: = GameState.player(player_id)
	while player.hand.size() > 5:
		_consume_card(player, str(player.hand[-1]))
	return result


static func can_end_turn(player_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return _fail("玩家不存在")
	if not round_offer(player_id).is_empty():
		return _fail("请先完成本回合原城区与西岸策略选牌")
	if not player.get("pending_card_reward", {}).is_empty():
		return _fail("请先完成红色机密档案的三选二奖励")
	if player.hand.size() > 5:
		return _fail("手牌超过 5 张，请先弃置 %d 张" % (player.hand.size() - 5))
	return _ok("可以结束回合", {})


static func legal_targets(player_id: String, card_id: String) -> Array[Dictionary]:
	var card: = GameConfig.by_id("cards", card_id)
	var player: = GameState.player(player_id)
	var targets: Array[Dictionary] = []
	if card.is_empty() or player.is_empty():
		return targets
	match str(card.target):
		"self":
			if _self_effect_is_legal(player, str(card.effect)):
				targets.append({"id": player_id, "label": str(player.name)})
		"own_business":
			if str(card.get("series", "")) == "west_bank":
				_add_west_bank_business_targets(targets, player)
			else:
				_add_business_targets(targets, player, false)
		"own_construction":
			if str(card.get("series", "")) == "west_bank":
				var states: Array = ["constructing"] if str(card.get("program", "")) in ["construction_accelerate", "construction_subsidy"] else ["constructing", "operating", "loss_watch", "mortgaged"]
				_add_west_bank_asset_targets(targets, player, states)
			else:
				_add_business_targets(targets, player, false, ["constructing", "operating", "loss_watch"])
		"enemy":
			for enemy: Dictionary in GameState.game_data.players:
				if str(enemy.id) != player_id and _enemy_effect_is_legal(enemy, str(card.effect)):
					targets.append({"id": str(enemy.id), "label": str(enemy.name)})
		"enemy_business":
			for enemy: Dictionary in GameState.game_data.players:
				if str(enemy.id) != player_id:
					_add_business_targets(targets, enemy, true)
		"enemy_construction":
			for enemy: Dictionary in GameState.game_data.players:
				if str(enemy.id) != player_id:
					_add_business_targets(targets, enemy, true, ["constructing", "operating", "loss_watch"])
		"stock":
			for stock: Dictionary in GameState.game_data.stocks.values():
				var position: Dictionary = Stocks.position_summary(player_id, str(stock.id))
				if str(card.effect) == "hedged_exit" and int(position.get("shares", 0)) <= 0:
					continue
				var history: Array = stock.get("history", [])
				var previous: = float(history[-2]) if history.size() >= 2 else float(stock.get("price", 0.0))
				var change: = 0.0 if previous <= 0.0 else (float(stock.get("price", 0.0)) - previous) / previous
				targets.append({
					"id": str(stock.id), "kind": "stock", "label": str(stock.name), 
					"sector": str(stock.get("sector", "")), "price": float(stock.get("price", 0.0)), "change": change, 
					"shares": int(position.get("shares", 0)), "avg_cost": float(position.get("avg_cost", 0.0)), 
					"market_value": int(position.get("market_value", 0)), "pnl": int(position.get("pnl", 0)), 
					"pnl_rate": float(position.get("pnl_rate", 0.0)), 
					"holding_badge": "我的持仓" if int(position.get("shares", 0)) > 0 else "未持有", 
				})
			targets.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
				var a_owned: = int(a.get("shares", 0)) > 0
				var b_owned: = int(b.get("shares", 0)) > 0
				if a_owned != b_owned:
					return a_owned
				return str(a.get("id", "")) < str(b.get("id", "")))
		"district":
			for district: Dictionary in GameState.game_data.districts.values():
				targets.append({"id": str(district.id), "label": str(district.name)})
		"available_land":
			for land: Dictionary in GameState.game_data.lands.values():
				if str(land.get("state", "")) == "available" and (str(card.get("series", "")) != "west_bank" or bool(land.get("premium_zone", false))):
					targets.append({
						"id": str(land.id), 
						"label": "%s  %s  %d万" % [str(land.id), str(land.district_name), int(land.price)], 
						"kind": "land", 
					})
	if str(card.effect) == "poach_talent":
		targets = targets.filter( func(target: Dictionary) -> bool:
			var business: Dictionary = GameState.game_data.businesses.get(str(target.id), {})
			return business.get("employees", []).any( func(talent_id: String) -> bool: return not talent_id.is_empty()))
	if str(card.get("effect", "")) == "west_program_24":
		targets = targets.filter(func(target: Dictionary) -> bool: return str(target.get("state", "")) == "loss_watch")
	return targets


static func play(player_id: String, card_id: String, target_id: String, response_choice: = "PROMPT") -> Dictionary:
	var player: = GameState.player(player_id)
	var card: = GameConfig.by_id("cards", card_id)
	if player.is_empty() or card.is_empty() or not player.hand.has(card_id):
		return _fail("未拥有该卡牌")
	if not supports_effect(str(card.get("effect", ""))):
		return _fail("该卡牌效果尚未接入统一引擎")
	var is_response: = str(card.type) in ["defense", "counter"]
	BattleRules.ensure_player(player)
	var cheat_active := bool(player.get("endless_cheat", false)) and EndlessOperationsSystem.is_enabled()
	if not cheat_active and not BattleRules.can_pay(player, card):
		return _fail("策略点不足：%s需要%d SP，当前%d SP" % [str(card.name), BattleRules.cost(card), int(player.strategy_points)])
	if not cheat_active and str(card.type) == "attack" and int(player.actions.get("attack_card", 0)) >= 1:
		return _fail("本回合最多主动使用一张进攻卡")
	if not legal_targets(player_id, card_id).any( func(target: Dictionary) -> bool: return str(target.id) == target_id):
		return _fail("当前没有该合法目标")
	if is_response:
		var deployment: = BattleRules.deploy(player, card)
		if bool(deployment.get("ok", false)):
			var contract: = EffectContract.contract_for(card)
			var presentation: = {
				"animation": str(contract.animation), 
				"timing": "secret_deployment", 
				"glow": str(card.rarity), 
				"card_id": card_id, 
				"target_id": player_id, 
				"hold_seconds": 0.65, 
			}
			presentation.merge(BattlePresenter.profile_for(card, deployment), true)
			deployment.presentation = presentation
			deployment.actor_id = player_id
			deployment.target_ids = [player_id]
			deployment.settlement = "%s背面部署至董事会秘策区；消耗%d SP，剩余%d SP；当前槽位%d/2" % [str(card.name), int(deployment.get("cost", 0)), int(deployment.get("remaining_sp", 0)), player.secret_zone.size()]
			deployment.spent_sp = int(deployment.get("cost", 0))
			GameState._record(player_id, "deploy_secret", {"card_id": card_id, "cost": int(deployment.get("cost", 0)), "slots": player.secret_zone.size()})
			_append_ledger(player_id, str(card.name), player_id, deployment)
		return deployment
	if str(card.type) == "attack":
		var reaction: = _reaction_request(player, card, target_id, str(response_choice))
		if bool(reaction.get("requires_reaction_choice", false)):
			return reaction
	var result: = _resolve(player, card, target_id, str(response_choice))
	if not bool(result.ok):
		return result
	var payment: = BattleRules.spend(player, card)
	if not bool(payment.get("ok", false)):
		return payment
	var restored_sp := int(result.get("restore_sp", 0))
	if restored_sp > 0:
		player.strategy_points = mini(int(player.get("strategy_points_max", 3)), int(player.get("strategy_points", 0)) + restored_sp)
		payment.remaining_sp = int(player.strategy_points)
	if not cheat_active:
		_consume_card(player, card_id)
	if bool(result.get("requires_card_choice", false)) and not bool(player.get("human", false)):
		var automatic_reward: = Rewards.auto_resolve(player_id)
		result.requires_card_choice = false
		result.reward_selected = automatic_reward.get("selected", [])
	if not is_response:
		player.actions.card = int(player.actions.get("card", 0)) + 1
		if str(card.type) == "attack":
			player.actions.attack_card = int(player.actions.get("attack_card", 0)) + 1
	var contract: = EffectContract.contract_for(card)
	var presentation: = {
		"animation": str(contract.animation), 
		"timing": str(contract.timing), 
		"glow": str(card.rarity), 
		"card_id": card_id, 
		"target_id": target_id, 
		"hold_seconds": 0.8, 
	}
	presentation.merge(BattlePresenter.profile_for(card, result), true)
	result.presentation = presentation
	result.actor_id = player_id
	result.target_ids = [target_id]
	result.settlement = _settlement_text(card, result)
	result.remaining_card_actions = 999999 if cheat_active else maxi(0, 2 - int(player.actions.get("card", 0)))
	result.spent_sp = int(payment.get("cost", 0))
	result.remaining_sp = int(payment.get("remaining_sp", 0))
	var combo: = ComboRules.resolve(player, card, target_id)
	result.combo = combo
	if bool(combo.get("triggered", false)):
		result.message = "%s；连携《%s》：%s" % [str(result.message), str(combo.name), str(combo.message)]
		result.settlement = "%s；%s" % [str(result.settlement), str(combo.message)]
		result.remaining_sp = int(player.strategy_points)
	if str(card.type) == "attack":
		result.message = "%s 对 %s 使用《%s》：%s" % [str(player.name), _target_label(target_id), str(card.name), str(result.message)]
	GameState._record(player_id, "play_card", {"card_id": card_id, "target_id": target_id, "result": str(result.message), "guarded": bool(result.get("guarded", false)), "countered": bool(result.get("countered", false))})
	_append_ledger(player_id, str(card.name), target_id, result)
	if str(card.type) == "attack":
		_publish_card_notices(player, card, target_id, result)
	return result


static func pending_notices(player_id: String) -> Array:
	var result: Array = []
	for notice: Dictionary in GameState.game_data.get("card_notifications", []):
		if str(notice.get("recipient_id", "")) == player_id and not bool(notice.get("acknowledged", false)):
			result.append(notice.duplicate(true))
	return result


static func acknowledge_notices(player_id: String) -> void :
	for notice: Dictionary in GameState.game_data.get("card_notifications", []):
		if str(notice.get("recipient_id", "")) == player_id:
			notice.acknowledged = true


static func discard(player_id: String, card_id: String) -> bool:
	return bool(discard_for_points(player_id, card_id).get("ok", false))


static func discard_for_points(player_id: String, card_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	var reason: = "超出手牌上限" if not player.is_empty() and player.hand.size() > 5 else "主动弃牌"
	return DrawPolicy.discard_hand_card(player_id, card_id, reason)


static func _resolve(player: Dictionary, card: Dictionary, target_id: String, response_choice: = "PROMPT") -> Dictionary:
	if str(card.type) == "attack":
		var defender: = GameState.player(_target_owner(target_id))
		var shield := _consume_west_attack_shield(defender)
		if not shield.is_empty():
			return _ok("%s的西岸护盾抵挡了《%s》" % [str(defender.get("name", "防守方")), str(card.name)], {"guarded": true, "countered": true, "counter_receipt": "西岸护盾抵挡本次负面卡牌", "shield_source_id": str(shield.get("source_id", ""))})
		var response: = _chosen_response(defender, card, response_choice)
		if not response.is_empty():
			return _resolve_response(player, defender, card, response)
	return _apply_effect(player, card, target_id)


static func _reaction_request(attacker: Dictionary, attack: Dictionary, target_id: String, response_choice: String) -> Dictionary:
	if response_choice != "PROMPT":
		return {}
	var defender: = GameState.player(_target_owner(target_id))
	if defender.is_empty() or not bool(defender.get("human", false)):
		return {}
	var eligible: = BattleRules.eligible_secrets(defender, attack)
	if eligible.is_empty():
		return {}
	var options: Array[Dictionary] = []
	for item: Dictionary in eligible:
		var response_card: Dictionary = item.card
		options.append({"id": str(response_card.id), "name": str(response_card.name), "description": str(response_card.description), "keywords": response_card.get("keywords", [])})
	return {"ok": true, "requires_reaction_choice": true, "message": "等待%s选择是否发动董事会秘策" % str(defender.name), "actor_id": str(attacker.id), "actor_name": str(attacker.name), "defender_id": str(defender.id), "attack_id": str(attack.id), "attack_name": str(attack.name), "target_id": target_id, "options": options}


static func _chosen_response(defender: Dictionary, attack: Dictionary, response_choice: String) -> Dictionary:
	if defender.is_empty() or response_choice.is_empty():
		return {}
	if response_choice == "PROMPT" and not bool(defender.get("human", false)):
		return _automatic_response(defender, attack)
	var eligible: = BattleRules.eligible_secrets(defender, attack)
	for picked: Dictionary in eligible:
		var response_card: Dictionary = picked.card
		if str(response_card.id) != response_choice:
			continue
		BattleRules.consume_secret(defender, str(response_card.id))
		return {"source": "secret", "card": response_card, "effect": str(response_card.effect), "chain": BattleRules.chain_profile(attack, response_card)}
	return {}

static func _automatic_response(defender: Dictionary, attack: Dictionary) -> Dictionary:
	if defender.is_empty():
		return {}
	var eligible: = BattleRules.eligible_secrets(defender, attack)
	if not eligible.is_empty():
		var picked: Dictionary = eligible[0]
		var response_card: Dictionary = picked.card
		BattleRules.consume_secret(defender, str(response_card.id))
		return {"source": "secret", "card": response_card, "effect": str(response_card.effect), "chain": BattleRules.chain_profile(attack, response_card)}
	return {}


static func _resolve_response(attacker: Dictionary, defender: Dictionary, attack: Dictionary, response: Dictionary) -> Dictionary:
	var response_card: Dictionary = response.card
	var countered: = str(response_card.get("type", "")) == "counter" or bool(response.get("counter", false))
	var counter_receipt: = "攻击效果归零"
	match str(response.effect):
		"pr_repair":
			var before: = int(defender.risk)
			Risks.adjust(str(defender.id), - int(response_card.value), str(response_card.name), "舆情防御")
			counter_receipt = "舆论攻击归零；防守方风险%d→%d" % [before, int(defender.risk)]
		"stable_operation":
			var protected: = 0
			for business_id: String in defender.get("business_ids", []):
				var business: Dictionary = GameState.game_data.businesses.get(business_id, {})
				if str(business.get("state", "")) in ["operating", "loss_watch", "mortgaged"]:
					TimedEffects.add_business_effect(business_id, "block_loss_watch", 1.0, 1, str(defender.id), str(response_card.id))
					protected += 1
			counter_receipt = "经营攻击归零；%d家企业本轮免于亏损观察" % protected
		"legal_shield":
			counter_receipt = "攻击效果归零；法务护盾完成一次有效拦截"
		"anti_poaching":
			counter_receipt = "人才挖角归零；核心人才留任"
		"counter_trap":
			Risks.adjust(str(attacker.id), int(response_card.value), str(response_card.name), "策略反制")
			DrawPolicy.draw_one(str(defender.id), "counter_trap")
			counter_receipt = "攻击效果归零；攻击方风险+%d；防守方补充1张策略卡" % int(response_card.value)
		"opinion_backlash":
			Risks.adjust(str(attacker.id), int(response_card.value), str(response_card.name), "策略反制")
			counter_receipt = "舆论攻击归零；攻击方风险+%d" % int(response_card.value)
		"legal_counter":
			var compensation: = mini(int(attacker.cash), int(response_card.value))
			if compensation > 0:
				GameState.apply_cash(str(attacker.id), - compensation, "法务反击赔偿")
				GameState.apply_cash(str(defender.id), compensation, "法务反击获赔")
			counter_receipt = "攻击效果归零；攻击方向防守方赔偿%d万" % compensation
	var message: = "%s自动触发《%s》，抵消《%s》；%s" % [str(defender.name), str(response_card.name), str(attack.name), counter_receipt]
	GameState._record(str(defender.id), "card_response", {"response_id": str(response_card.id), "attack_id": str(attack.id), "attacker_id": str(attacker.id), "countered": countered})
	return _ok(message, {"guarded": true, "countered": countered, "response_card_id": str(response_card.id), "counter_receipt": counter_receipt, "chain": response.get("chain", BattleRules.chain_profile(attack, response_card))})


static func _apply_effect(player: Dictionary, card: Dictionary, target_id: String) -> Dictionary:
	return Effects.resolve(player, card, target_id)


static func _add_business_targets(targets: Array[Dictionary], owner: Dictionary, include_owner: bool, states: = ["constructing", "operating", "loss_watch", "mortgaged", "auction"]) -> void :
	for business_id: String in owner.business_ids:
		var business: Dictionary = GameState.game_data.businesses.get(business_id, {})
		if str(business.get("state", "")) in states:
			var land: Dictionary = GameState.game_data.lands.get(str(business.get("land_id", "")), {})
			targets.append({
				"id": business_id, 
				"kind": "business", 
				"label": "%s  %s" % [str(owner.name), str(business.name)] if include_owner else str(business.name), 
				"business_name": str(business.name), 
				"owner_id": str(owner.id), 
				"owner_name": str(owner.name), 
				"owner_color": str(owner.get("color", "#5aa9d6")), 
				"district_name": str(land.get("district_name", "城市商圈")), 
				"state": str(business.get("state", "operating")), 
			})


static func _add_west_bank_business_targets(targets: Array[Dictionary], owner: Dictionary) -> void:
	for business_id: String in owner.get("business_ids", []):
		var business: Dictionary = GameState.game_data.get("businesses", {}).get(business_id, {})
		var land: Dictionary = GameState.game_data.get("lands", {}).get(str(business.get("land_id", "")), {})
		if not bool(land.get("premium_zone", false)) or str(business.get("state", "")) not in ["operating", "loss_watch", "mortgaged"]:
			continue
		targets.append({"id": business_id, "kind": "business", "label": "%s  ·  西岸" % str(business.get("name", business_id)), "business_name": str(business.get("name", business_id)), "owner_id": str(owner.id), "owner_name": str(owner.name), "owner_color": str(owner.get("color", "#5aa9d6")), "district_name": str(land.get("district_name", "西岸金融核心区")), "state": str(business.get("state", "operating"))})


static func _add_west_bank_asset_targets(targets: Array[Dictionary], owner: Dictionary, states: Array) -> void:
	for business_id: String in owner.get("business_ids", []):
		var business: Dictionary = GameState.game_data.get("businesses", {}).get(business_id, {})
		var land: Dictionary = GameState.game_data.get("lands", {}).get(str(business.get("land_id", "")), {})
		if not bool(land.get("premium_zone", false)) or str(business.get("state", "")) not in states:
			continue
		targets.append({"id": business_id, "kind": "business", "label": "%s  ·  西岸" % str(business.get("name", business_id)), "business_name": str(business.get("name", business_id)), "owner_id": str(owner.id), "owner_name": str(owner.name), "owner_color": str(owner.get("color", "#5aa9d6")), "district_name": str(land.get("district_name", "西岸金融核心区")), "state": str(business.get("state", "operating"))})


static func _self_effect_is_legal(player: Dictionary, effect: String) -> bool:
	match effect:
		"west_program_28":
			return str(GameState.game_data.get("ipo_records", {}).get(str(player.id), {}).get("status", "")) == "listed" and int(player.get("cash", 0)) >= 60
		"portfolio_dividend":
			return player.get("stocks", {}).values().any( func(holding: Dictionary) -> bool: return int(holding.get("shares", 0)) > 0)
		"debt_restructure", "bank_interest_relief":
			return not player.get("loans", []).is_empty()
		"gilded_royal_privilege":
			return int(player.get("actions", {}).get("land", 0)) > 0 or int(player.get("actions", {}).get("build", 0)) > 0
		"gilded_chosen_talent":
			return player.get("talent_ids", []).size() < Talents.roster_limit(str(player.id)) and GameConfig.list("talents").any( func(talent: Dictionary) -> bool: return str(talent.get("quality", "")) == "red")
		"executive_search":
			return player.get("talent_ids", []).size() < Talents.roster_limit(str(player.id))
		"startup_accelerate", "startup_portfolio_boost":
			return player.get("active_projects", []).any( func(project: Dictionary) -> bool:
				return str(project.get("status", "")) == "active" and not bool(project.get("resolved", false)))
	return true


static func _consume_west_attack_shield(player: Dictionary) -> Dictionary:
	if player.is_empty():
		return {}
	for effect: Dictionary in player.get("effects", []).duplicate():
		if str(effect.get("kind", "")) != "west_attack_shield" or int(effect.get("uses", 0)) <= 0:
			continue
		effect.uses = int(effect.get("uses", 0)) - 1
		if int(effect.uses) <= 0:
			player.effects.erase(effect)
		return effect
	return {}


static func _enemy_effect_is_legal(enemy: Dictionary, effect: String) -> bool:
	match effect:
		"price_war":
			return enemy.get("business_ids", []).any( func(business_id: String) -> bool:
				return str(GameState.game_data.businesses.get(business_id, {}).get("state", "")) in ["operating", "loss_watch", "mortgaged"])
		"rent_collection", "account_freeze":
			return GameState.available_cash(str(enemy.id)) > 0
	return not bool(enemy.get("eliminated", false))


static func _target_owner(target_id: String) -> String:
	if not GameState.player(target_id).is_empty():
		return target_id
	return str(GameState.game_data.businesses.get(target_id, {}).get("owner_id", ""))


static func _clear_player_business_effects(player: Dictionary, card_effects: Array[String]) -> void :
	for business_id: String in player.business_ids:
		var business: Dictionary = GameState.game_data.businesses.get(business_id, {})
		for effect: Dictionary in business.get("effects", []).duplicate():
			var source_card: = GameConfig.by_id("cards", str(effect.get("card_id", "")))
			if str(source_card.get("effect", "")) in card_effects:
				business.effects.erase(effect)


static func _consume_card(player: Dictionary, card_id: String) -> void :
	player.hand.erase(card_id)
	player.discard.append(card_id)


static func _append_ledger(player_id: String, card_name: String, target_id: String, result: Dictionary) -> void :
	GameState.game_data.battle_ledger.append({"round": int(GameState.game_data.round), "category": "card", "player_id": player_id, "title": "%s：%s" % [card_name, str(result.message)], "details": {"target_id": target_id, "settlement": str(result.get("settlement", "")), "guarded": bool(result.get("guarded", false)), "countered": bool(result.get("countered", false)), "presentation": result.get("presentation", {})}})


static func _publish_card_notices(actor: Dictionary, card: Dictionary, target_id: String, result: Dictionary) -> void :
	var target_owner_id: = _target_owner(target_id)
	var defended: = bool(result.get("guarded", false))
	var headline: = "攻防反制已结算" if defended else "策略攻击已结算"
	var resolution: = str(result.get("counter_receipt", result.get("settlement", result.get("message", "效果已结算"))))
	var response_card: = GameConfig.by_id("cards", str(result.get("response_card_id", "")))
	var response_line: = "\n%s亮出秘策《%s》，成功抵消。" % [_target_label(target_owner_id), str(response_card.get("name", "反制卡"))] if defended and not response_card.is_empty() else ""
	var body: = "%s 对 %s 使用《%s》。%s\n%s" % [str(actor.get("name", "某财团")), _target_label(target_id), str(card.get("name", "策略卡")), response_line, resolution]
	var feed: Array = GameState.game_data.get_or_add("card_notifications", [])
	for observer: Dictionary in GameState.game_data.get("players", []):
		if bool(observer.get("eliminated", false)):
			continue
		var role: = "旁观战报"
		if str(observer.id) == str(actor.id):
			role = "你的出牌回执"
		elif str(observer.id) == target_owner_id:
			role = "你遭到策略攻击"
		feed.append({"round": int(GameState.game_data.get("round", 0)), "recipient_id": str(observer.id), "actor_id": str(actor.id), "target_owner_id": target_owner_id, "card_id": str(card.id), "title": "%s  %s" % [role, headline], "body": body, "guarded": defended, "countered": bool(result.get("countered", false)), "acknowledged": false})


static func _target_label(target_id: String) -> String:
	var player: = GameState.player(target_id)
	if not player.is_empty():
		return str(player.get("name", target_id))
	var business: Dictionary = GameState.game_data.get("businesses", {}).get(target_id, {})
	if not business.is_empty():
		var owner: = GameState.player(str(business.get("owner_id", "")))
		return "%s的%s" % [str(owner.get("name", "对手")), str(business.get("name", target_id))]
	var district: Dictionary = GameState.game_data.get("districts", {}).get(target_id, {})
	return str(district.get("name", target_id)) if not district.is_empty() else target_id


static func _settlement_text(card: Dictionary, result: Dictionary) -> String:
	if bool(result.get("guarded", false)):
		var response_card: = GameConfig.by_id("cards", str(result.get("response_card_id", "")))
		return "秘策《%s》已触发并抵消进攻；%s" % [str(response_card.get("name", "反制卡")), str(result.get("counter_receipt", "攻击效果归零"))]
	if not str(result.get("receipt", "")).is_empty():
		return str(result.receipt)
	match str(card.get("effect", "")):
		"channel_takeover":
			return "现金已即时转移，最多 %d 万" % int(card.get("value", 0))
		"bargain_buy":
			return "持仓已入账：%d 股，买入价为当前价 %.0f 折" % [int(result.get("shares", card.get("value", 0))), float(result.get("discount", 0.95)) * 10.0]
		"hedged_exit":
			return "持仓已卖出；对冲补偿 +%d 万，风险 -%d" % [int(result.get("hedge_bonus", 0)), int(result.get("risk_reduced", 0))]
		"pr_repair":
			return "风险已立即降低 %d，舆论减益已清除" % int(card.get("value", 0))
		"poach_talent":
			return "人才所有权已立即转移"
		"market_rally", "market_rumor":
			return str(result.get("receipt", "证券价格已立即更新"))
		"construction_accelerate", "construction_delay":
			return "工期已立即改写，地图施工倒计时同步更新"
		"rent_collection", "account_freeze":
			return "现金与风险已立即结算"
		"legal_shield", "stable_operation", "anti_poaching", "counter_trap", "opinion_backlash", "legal_counter":
			return "防守已部署，受袭时会自动触发"
		_:
			var duration: = int(card.get("duration", 0))
			return "状态已写入，持续 %d 回合" % duration if duration > 0 else "效果已立即结算"


static func _ok(message: String, details: = {}) -> Dictionary:
	var result: = {"ok": true, "message": message}
	result.merge(details, true)
	return result


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}
