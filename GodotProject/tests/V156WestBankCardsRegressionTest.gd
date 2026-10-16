extends Node

const Cards = preload("res://scripts/CardEngine.gd")
const Businesses = preload("res://scripts/BusinessSystem.gd")
const BattleRules = preload("res://scripts/CardBattleRules.gd")
const ArtRegistry = preload("res://scripts/CardArtRegistry.gd")
const CardDrawPolicy = preload("res://scripts/CardDrawPolicy.gd")

var passed := 0
var failed := 0


func _ready() -> void:
	GameState.suppress_disk_save = true
	_test_mode_and_unlock_isolation()
	_test_dual_five_choice_draft()
	_test_west_bank_visual_and_balance_contract()
	_test_advanced_offer_probability()
	_test_two_advanced_cards_per_round()
	_test_every_west_bank_effect_executes()
	print("V156_WEST_BANK_CARDS passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _start(endless: bool, seed_value: int) -> Dictionary:
	GameState.start_match("local", 0 if endless else 12, [{"company_id": "hengyue", "human": true}, {"company_id": "qiming", "human": false}], seed_value)
	var player := GameState.game_data.players[0] as Dictionary
	var rival := GameState.game_data.players[1] as Dictionary
	GameState.game_data.turn_order = [str(player.id), str(rival.id)]
	GameState.game_data.active_order_index = 0
	player.cash = 9000
	rival.cash = 9000
	return player


func _qualify(player: Dictionary) -> void:
	GameState.game_data.round = 6
	player.asset_value = 1600
	player.risk = 20
	for index in range(3):
		var land_id: String = ["L09", "L10", "L11"][index]
		var business_id := "WB-CARD-%d" % index
		var land: Dictionary = GameState.game_data.lands[land_id]
		land.owner_id = str(player.id)
		land.asset_state = "OWNED"
		land.state = "operating"
		land.business_id = business_id
		player.land_ids.append(land_id)
		player.business_ids.append(business_id)
		GameState.game_data.businesses[business_id] = {"id": business_id, "owner_id": str(player.id), "land_id": land_id, "type_id": "financial_office", "name": "资格企业%d" % index, "state": "operating", "value": 500, "employees": ["", ""], "effects": []}


func _test_mode_and_unlock_isolation() -> void:
	var standard := _start(false, 15601)
	GameState.game_data.round = 6
	Cards.create_round_offer(str(standard.id), 5)
	_assert("非永续模式不会生成西岸卡牌候选", Cards.west_bank_round_offer(str(standard.id)).is_empty())
	var endless := _start(true, 15602)
	GameState.game_data.round = 5
	Cards.create_round_offer(str(endless.id), 5)
	_assert("未取得西岸购地资格前不会生成西岸卡牌", Cards.west_bank_round_offer(str(endless.id)).is_empty())


func _test_dual_five_choice_draft() -> void:
	var player := _start(true, 15603)
	_qualify(player)
	_assert("满足现有购地条件即解锁西岸卡系", bool(Businesses.premium_land_eligibility(str(player.id)).get("ok", false)))
	var regular := Cards.create_round_offer(str(player.id), 5)
	var west := Cards.west_bank_round_offer(str(player.id))
	_assert("每回合先生成原城区五选一", regular.size() == 5 and Cards.round_offer_kind(str(player.id)) == "old_city")
	_assert("同回合另生成西岸卡五选一", west.size() == 5 and west.all(func(card_id: String) -> bool: return str(GameConfig.by_id("cards", card_id).get("series", "")) == "west_bank"))
	var first := Cards.choose_round_card(str(player.id), regular[0])
	_assert("原城区选择完成后自动进入西岸阶段", bool(first.get("ok", false)) and Cards.round_offer_kind(str(player.id)) == "west_bank")
	var second := Cards.choose_round_card(str(player.id), west[0])
	_assert("两个五选一完成后本回合共获得两张", bool(second.get("ok", false)) and Cards.round_offer(str(player.id)).is_empty() and player.hand.size() == 2)


func _test_west_bank_visual_and_balance_contract() -> void:
	var all_cards: Array = GameConfig.list("cards")
	var west_cards: Array = GameConfig.list("cards").filter(func(card: Dictionary) -> bool: return str(card.get("series", "")) == "west_bank")
	var ordinary: Array = west_cards.filter(func(card: Dictionary) -> bool: return str(card.get("rarity", "")) == "west_bank")
	var advanced: Array = west_cards.filter(func(card: Dictionary) -> bool: return str(card.get("rarity", "")) == "west_bank_advanced")
	var ids: Dictionary = {}
	var names: Dictionary = {}
	var numbers: Dictionary = {}
	var art_keys: Dictionary = {}
	var art_hashes: Dictionary = {}
	var effects: Dictionary = {}
	var valid := all_cards.size() == 100 and west_cards.size() == 42 and ordinary.size() == 39 and advanced.size() == 3
	for card: Dictionary in west_cards:
		ids[str(card.get("id", ""))] = true
		names[str(card.get("name", ""))] = true
		numbers[int(card.get("catalog_no", 0))] = true
		art_keys[str(card.get("art_key", ""))] = true
		var catalog_no := int(card.get("catalog_no", 0))
		var art_path := "res://assets/ui/west_bank/cards/v101_ai/west_bank_ai_%03d.png" % catalog_no
		art_hashes[FileAccess.get_sha256(art_path)] = true
		effects[str(card.get("effect", ""))] = true
		var rarity := str(card.get("rarity", ""))
		valid = valid and rarity in ["west_bank", "west_bank_advanced"] and int(card.get("cost", 0)) == (3 if rarity == "west_bank_advanced" else 2) and Cards.supports_effect(str(card.get("effect", "")))
		var art := ArtRegistry.resolve(card)
		var expected_source := "ai_generated_v101_ue58_fx" if rarity == "west_bank_advanced" else "ai_generated_v101"
		valid = valid and art.get("display_texture") is Texture2D and str(art.get("series", "")) == "west_bank" and str(art.get("source", "")) == expected_source and not bool(art.get("fallback", true))
		valid = valid and str(card.get("art_key", "")) == "west_bank_art_%02d" % catalog_no
	_assert("全库100张且西岸39张普通卡加3张高级卡", valid)
	_assert("西岸编号从1连续到42", numbers.size() == 42 and range(1, 43).all(func(number: int) -> bool: return numbers.has(number)))
	_assert("三张西岸高级卡固定排在NO.001至003", advanced.map(func(card: Dictionary) -> int: return int(card.get("catalog_no", 0))).all(func(number: int) -> bool: return number in [1, 2, 3]))
	_assert("三十九张西岸普通卡顺延为NO.004至042", ordinary.map(func(card: Dictionary) -> int: return int(card.get("catalog_no", 0))).all(func(number: int) -> bool: return number >= 4 and number <= 42))
	_assert("西岸ID、名称、效果和美术键全部唯一", ids.size() == 42 and names.size() == 42 and effects.size() == 42 and art_keys.size() == 42)
	_assert("42张西岸卡使用42张独立AI正面图", art_hashes.size() == 42 and not art_hashes.has("") and range(1, 43).all(func(number: int) -> bool: return ResourceLoader.exists("res://assets/ui/west_bank/cards/v101_ai/west_bank_ai_%03d.png" % number)))
	_assert("三张高级卡接入三套独立UE5.8光效", range(1, 4).all(func(number: int) -> bool: return ResourceLoader.exists("res://assets/ui/west_bank/cards/v101_ue58_fx/west_bank_advanced_fx_%03d.png" % number)) and ResourceLoader.exists("res://assets/ui/west_bank/cards/v101_ue58_fx/ue58_fx_manifest.json"))


func _test_advanced_offer_probability() -> void:
	GameState.rng.seed = 1560808
	var advanced_offers := 0
	var advanced_counts := {"wb40": 0, "wb41": 0, "wb42": 0}
	var valid := true
	var samples := 20000
	for _sample in range(samples):
		var offer := CardDrawPolicy.create_west_bank_offer(5)
		var unique := {}
		var advanced_in_offer := 0
		for card_id: String in offer:
			unique[card_id] = true
			if str(GameConfig.by_id("cards", card_id).get("rarity", "")) == "west_bank_advanced":
				advanced_in_offer += 1
				advanced_counts[card_id] = int(advanced_counts.get(card_id, 0)) + 1
		valid = valid and offer.size() == 5 and unique.size() == 5 and advanced_in_offer <= 1
		if advanced_in_offer == 1:
			advanced_offers += 1
	var rate := float(advanced_offers) / float(samples)
	var spread := int(advanced_counts.values().max()) - int(advanced_counts.values().min())
	_assert("西岸五选一不重复且一次最多1张高级卡", valid)
	_assert("高级卡合计出现率稳定在8%附近", rate >= 0.07 and rate <= 0.09)
	_assert("三张高级卡等概率出现", spread <= maxi(80, roundi(float(advanced_offers) * 0.12)))
	print("WEST_ADVANCED_RATE %.4f counts=%s" % [rate, str(advanced_counts)])


func _test_two_advanced_cards_per_round() -> void:
	var player := _start(true, 15604)
	_qualify(player)
	BattleRules.reset_round(player)
	_assert("解锁西岸后每回合策略点上限提升到6", int(player.strategy_points_max) == 6 and int(player.strategy_points) == 6)
	player.hand = ["wb40", "wb42"]
	var first := Cards.play(str(player.id), "wb40", str(player.id))
	var second := Cards.play(str(player.id), "wb42", str(player.id))
	_assert("6 SP可真实连续执行两张西岸高级卡", bool(first.get("ok", false)) and bool(second.get("ok", false)) and int(player.strategy_points) == 1 and int(player.actions.card) == 2)


func _test_every_west_bank_effect_executes() -> void:
	var card_ids: Array[String] = []
	for number in range(1, 43):
		card_ids.append("wb%02d" % number)
	for index in range(card_ids.size()):
		var player := _start(true, 15700 + index)
		_qualify(player)
		var context := _prepare_card_world(player, index)
		BattleRules.reset_round(player)
		var card_id: String = card_ids[index]
		player.hand = [card_id]
		var targets := Cards.legal_targets(str(player.id), card_id)
		var target_id := str(targets[0].get("id", "")) if not targets.is_empty() else ""
		var result := Cards.play(str(player.id), card_id, target_id)
		_assert("%s 可真实执行并结算效果" % str(GameConfig.by_id("cards", card_id).get("name", card_id)), not context.is_empty() and not target_id.is_empty() and bool(result.get("ok", false)) and not player.hand.has(card_id))


func _prepare_card_world(player: Dictionary, suffix: int) -> Dictionary:
	var operating_id := _add_west_business(player, suffix)
	GameState.game_data.businesses[operating_id].state = "loss_watch"
	var construction_id := "WB-BUILD-%d" % suffix
	var construction_land: Dictionary = GameState.game_data.lands["L30"]
	construction_land.owner_id = str(player.id)
	construction_land.state = "constructing"
	construction_land.business_id = construction_id
	if not player.land_ids.has("L30"):
		player.land_ids.append("L30")
	player.business_ids.append(construction_id)
	GameState.game_data.businesses[construction_id] = {"id": construction_id, "owner_id": str(player.id), "land_id": "L30", "type_id": "investment_bank_hq", "name": "西岸在建项目", "state": "constructing", "value": 700, "remaining_rounds": 2, "employees": ["", ""], "effects": []}
	player.actions.build = 1
	player.debt = 180
	player.loans = [{"id": "WB-LOAN", "kind": "corporate", "principal": 180, "unpaid_principal": 0, "unpaid_interest": 0, "overdue_fee": 0, "asset_id": ""}]
	GameState.game_data.ipo_records[str(player.id)] = {"status": "listed", "market_confidence": 60, "disclosure_gap": 0.12, "issue_price": 24.0, "share_price": 24.0, "price_history": [24.0], "shares_outstanding": 100000, "float_ratio": 0.30}
	return {"operating_id": operating_id, "construction_id": construction_id}


func _add_west_business(player: Dictionary, suffix: int) -> String:
	var land_id := "L29"
	var business_id := "WB-EFFECT-%d" % suffix
	var land: Dictionary = GameState.game_data.lands[land_id]
	land.owner_id = str(player.id)
	land.asset_state = "OWNED"
	land.state = "operating"
	land.business_id = business_id
	if not player.land_ids.has(land_id):
		player.land_ids.append(land_id)
	player.business_ids.append(business_id)
	GameState.game_data.businesses[business_id] = {"id": business_id, "owner_id": str(player.id), "land_id": land_id, "type_id": "investment_bank_hq", "name": "西岸效果验证企业", "state": "operating", "value": 900, "employees": ["", ""], "effects": []}
	return business_id


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s" % label)
