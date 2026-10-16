class_name BusinessSystem
extends RefCounted

const CompanyRules = preload("res://scripts/CompanyAbilityEngine.gd")
const BusinessFactory = preload("res://scripts/BusinessInstance.gd")
const Districts = preload("res://scripts/DistrictSystem.gd")
const Risks = preload("res://scripts/RiskSystem.gd")
const Regions = preload("res://scripts/RegionalEconomySystem.gd")
const WorldBounds = preload("res://scripts/CityWorldBounds.gd")
const AssetStates = preload("res://scripts/AssetStateService.gd")
const Transactions = preload("res://scripts/EconomyTransactionService.gd")
const CompetitionFeed = preload("res://scripts/CompetitiveEventFeed.gd")
const LandNames = preload("res://scripts/LandNamingService.gd")
const Cheats = preload("res://scripts/EndlessCheatSystem.gd")


static func land_purchase_quote(player_id: String, land_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	var land: Dictionary = GameState.game_data.get("lands", {}).get(land_id, {})
	if player.is_empty() or land.is_empty():
		return {}
	var base_price: = int(land.get("price", 0))
	var list_price: = roundi(float(base_price) * Regions.land_price_multiplier(str(land.get("district", ""))))
	var discounted: = list_price
	if str(land.get("district", "")) == "commercial" and player.get("effects", []).any( func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "commercial_land_discount"):
		discounted = roundi(float(discounted) * 0.85)
	var land_discount: = _effect_value(player, "land_discount", 1.0)
	discounted = roundi(float(discounted) * land_discount)
	var west_land_discount := _effect_value(player, "west_land_discount", 1.0) if bool(land.get("premium_zone", false)) else 1.0
	discounted = roundi(float(discounted) * west_land_discount)
	var surcharge_rate: = Risks.land_purchase_surcharge_rate(int(player.get("risk", 0)))
	var surcharge: = ceili(float(discounted) * surcharge_rate)
	return {
		"list_price": list_price, "base_after_discounts": discounted, 
		"risk_surcharge_rate": surcharge_rate, "risk_surcharge": surcharge, 
		"total": discounted + surcharge, "risk_tier": Risks.tier_name(int(player.get("risk", 0))), 
	}


static func business_build_quote(player_id: String, type_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	var business_type: = GameConfig.by_id("business_types", type_id)
	if player.is_empty() or business_type.is_empty():
		return {}
	var build_discount: = _effect_value(player, "build_discount", 1.0)
	var base: = roundi(float(business_type.get("cost", 0)) * CompanyRules.build_cost_multiplier(str(player.get("company_id", ""))) * build_discount)
	var surcharge_rate: = Risks.build_surcharge_rate(int(player.get("risk", 0)))
	var surcharge: = ceili(float(base) * surcharge_rate)
	return {
		"base_after_discounts": base, "risk_surcharge_rate": surcharge_rate, 
		"risk_surcharge": surcharge, "total": base + surcharge, 
		"risk_tier": Risks.tier_name(int(player.get("risk", 0))), 
	}


static func buy_land(player_id: String, land_id: String) -> Dictionary:
	var tutorial_route: Dictionary = TutorialDirector.route_action("buy_land", {"player_id": player_id, "land_id": land_id})
	if bool(tutorial_route.get("handled", false)):
		return tutorial_route
	var player: = GameState.player(player_id)
	var land: Dictionary = GameState.game_data.lands.get(land_id, {})
	if player.is_empty() or land.is_empty():
		return _fail("无效地块")
	var cheat_active := Cheats.is_active(player_id)
	if not cheat_active and remaining_land_actions(player) <= 0:
		return _fail("本回合购地次数已用完")
	if not cheat_active and _has_action_block(player):
		return _fail("《全面封锁》生效：本回合不能买地")
	if not AssetStates.can_purchase(land):
		return _fail("地块不可购买")
	if bool(land.get("premium_zone", false)):
		var premium_check := premium_land_eligibility(player_id)
		if not bool(premium_check.get("ok", false)):
			return _fail(str(premium_check.get("message", "尚未取得西岸新区购地资格")))
	var anchor: Array = land.get("anchor", [INF, INF])
	if not WorldBounds.is_valid_build_position(Vector3(float(anchor[0]), 0.0, float(anchor[1])), land_id):
		return _fail("地块不在城市合法建设区域")
	var quote: = land_purchase_quote(player_id, land_id)
	var price: = int(quote.get("total", int(land.price)))
	var land_discount: = _effect_value(player, "land_discount", 1.0)
	var west_land_discount := _effect_value(player, "west_land_discount", 1.0) if bool(land.get("premium_zone", false)) else 1.0
	if int(player.cash) < price:
		return _fail("现金不足")
	var cash_before: = int(player.cash)
	if not GameState.apply_cash(player_id, - price, "购买土地 %s" % land_id):
		return _fail("扣款失败")
	AssetStates.transition(land, AssetStates.OWNED, player_id, "owned_empty")
	land.acquired_round = int(GameState.game_data.get("round", 0))
	LandNames.clear_custom_name(land)
	if not player.land_ids.has(land_id):
		player.land_ids.append(land_id)
	player.actions.land = int(player.actions.land) + 1
	if land_discount < 1.0:
		_consume_effect(player, "land_discount")
	if west_land_discount < 1.0:
		_consume_effect(player, "west_land_discount")
	var rivals: Array[String] = []
	for other_land: Dictionary in GameState.game_data.lands.values():
		var other_owner: = str(other_land.get("owner_id", ""))
		if str(other_land.get("district", "")) == str(land.district) and not other_owner.is_empty() and other_owner != player_id and not rivals.has(other_owner):
			rivals.append(other_owner)
	Districts.recalculate()
	GameState._record(player_id, "buy_land", {
		"land_id": land_id, "price": price, "list_price": int(quote.get("list_price", int(land.price))), 
		"risk_surcharge": int(quote.get("risk_surcharge", 0)), "risk_surcharge_rate": float(quote.get("risk_surcharge_rate", 0.0)), 
	})
	Transactions.record("buy_land:%d:%s:%s" % [int(GameState.game_data.round), player_id, land_id], player_id, "buy_land", {"cash": cash_before, "owner_id": ""}, {"cash": - price}, {"cash": int(player.cash), "owner_id": player_id}, [land_id])
	CompetitionFeed.publish("land_purchase", player_id, "%s购入%s" % [str(player.name), str(land.get("district_name", land_id))], {"land_id": land_id, "price": price})
	if not rivals.is_empty():
		var rival_names: Array[String] = []
		for rival_id: String in rivals:
			rival_names.append(str(GameState.player(rival_id).name))
		GameState.game_data.battle_ledger.append({"round": int(GameState.game_data.round), "category": "land_conflict", "player_id": player_id, "title": "%s抢入%s，与%s形成商圈争夺" % [str(player.name), str(land.district_name), "、".join(rival_names)], "details": {"land_id": land_id, "district_id": str(land.district), "rivals": rivals}})
		return _ok("购入成功，已进入%s商圈争夺" % str(land.district_name), {"land_id": land_id, "rivals": rivals, "quote": quote})
	return _ok("购买成功", {"land_id": land_id, "quote": quote})


static func land_action_limit(player: Dictionary) -> int:
	return -1 if EndlessOperationsSystem.is_enabled() else 1


static func remaining_land_actions(player: Dictionary) -> int:
	var limit := land_action_limit(player)
	return 999999 if limit < 0 else maxi(0, limit - int(player.get("actions", {}).get("land", 0)))


static func premium_land_eligibility(player_id: String) -> Dictionary:
	var player := GameState.player(player_id)
	var progress := premium_land_progress(player_id)
	if not EndlessOperationsSystem.is_enabled():
		return {"ok": false, "message": "西岸金融核心区仅在永续经营模式开放", "progress": progress}
	if player.is_empty() or bool(player.get("eliminated", false)):
		return {"ok": false, "message": "当前财团不可进入西岸新区", "progress": progress}
	if Cheats.is_active(player_id):
		return {"ok": true, "message": "无限权限已解锁西岸新区", "cheat": true, "progress": progress}
	var checks := {
		"round": bool((progress.get("round", {}) as Dictionary).get("met", false)),
		"asset": bool((progress.get("asset", {}) as Dictionary).get("met", false)),
		"operating": bool((progress.get("operating", {}) as Dictionary).get("met", false)),
		"risk": bool((progress.get("risk", {}) as Dictionary).get("met", false)),
	}
	if not bool(checks.round):
		return {"ok": false, "message": "第 6 回合开放西岸新区", "checks": checks, "progress": progress}
	if not bool(checks.asset):
		return {"ok": false, "message": "进入西岸新区需净资产达到 1200 万", "checks": checks, "progress": progress}
	if not bool(checks.operating):
		return {"ok": false, "message": "进入西岸新区需至少 3 家营业企业", "checks": checks, "progress": progress}
	if not bool(checks.risk):
		return {"ok": false, "message": "风险需降至 55 以下才能进入西岸新区", "checks": checks, "progress": progress}
	return {"ok": true, "message": "已取得西岸新区投资资格", "checks": checks, "progress": progress}


static func premium_land_progress(player_id: String) -> Dictionary:
	var player := GameState.player(player_id)
	var round_number := int(GameState.game_data.get("round", 0))
	var asset := int(player.get("asset_value", 0)) if not player.is_empty() else 0
	var risk := int(player.get("risk", 100)) if not player.is_empty() else 100
	var operating := 0
	if not player.is_empty():
		for business_id: String in player.get("business_ids", []):
			var business: Dictionary = GameState.game_data.get("businesses", {}).get(business_id, {})
			if str(business.get("state", "")) in ["operating", "loss_watch", "mortgaged"]:
				operating += 1
	return {
		"round": {"label": "经营回合", "current": round_number, "target": 6, "met": round_number >= 6, "direction": "at_least"},
		"asset": {"label": "净资产", "current": asset, "target": 1200, "unit": "万", "met": asset >= 1200, "direction": "at_least"},
		"operating": {"label": "营业企业", "current": operating, "target": 3, "unit": "家", "met": operating >= 3, "direction": "at_least"},
		"risk": {"label": "经营风险", "current": risk, "target": 55, "met": risk <= 55, "direction": "at_most"},
	}


static func build_business(player_id: String, land_id: String, type_id: String) -> Dictionary:
	var tutorial_route: Dictionary = TutorialDirector.route_action("build_business", {"player_id": player_id, "land_id": land_id, "type_id": type_id})
	if bool(tutorial_route.get("handled", false)):
		return tutorial_route
	var player: = GameState.player(player_id)
	var land: Dictionary = GameState.game_data.lands.get(land_id, {})
	var business_type: = GameConfig.by_id("business_types", type_id)
	if player.is_empty() or land.is_empty() or business_type.is_empty():
		return _fail("建设目标无效")
	var cheat_active := Cheats.is_active(player_id)
	if not cheat_active and not EndlessOperationsSystem.is_enabled() and int(player.get("actions", {}).get("build", 0)) >= 1:
		return _fail("本回合建设次数已用完")
	if not cheat_active and _has_action_block(player):
		return _fail("《全面封锁》生效：本回合不能建设")
	if str(land.owner_id) != player_id or str(land.state) != "owned_empty":
		return _fail("只能在自己的空地建设")
	var premium_land := bool(land.get("premium_zone", false))
	var premium_business := bool(business_type.get("premium_only", false))
	if premium_land and not premium_business:
		return _fail("西岸新区仅允许建设高级总部业态")
	if premium_business and not premium_land:
		return _fail("该高级业态只能落户西岸金融核心区")
	var anchor: Array = land.get("anchor", [INF, INF])
	if not WorldBounds.is_valid_build_position(Vector3(float(anchor[0]), 0.0, float(anchor[1])), land_id):
		return _fail("施工位置不满足城市合法区域要求")
	var build_discount: = _effect_value(player, "build_discount", 1.0)
	var quote: = business_build_quote(player_id, type_id)
	var cost: = int(quote.get("total", int(business_type.cost)))
	if int(player.cash) < cost:
		return _fail("建设资金不足")
	if not GameState.apply_cash(player_id, - cost, "建设%s" % business_type.name):
		return _fail("扣款失败")
	var instance_id: = "B%03d" % (GameState.game_data.businesses.size() + 1)
	var business: = BusinessFactory.create(instance_id, player_id, land_id, business_type)
	var cycle_delta := EndlessOperationsSystem.construction_round_delta()
	if cycle_delta != 0:
		ConstructionProgressService.apply_delta(business, cycle_delta, "economic_cycle_start", int(GameState.game_data.round))
	GameState.game_data.businesses[instance_id] = business
	land.business_id = instance_id
	land.state = "constructing"
	if not player.business_ids.has(instance_id):
		player.business_ids.append(instance_id)
	player.actions.build = int(player.actions.build) + 1
	if build_discount < 1.0:
		_consume_effect(player, "build_discount")
	Districts.recalculate()
	GameState._record(player_id, "build_business", {
		"business_id": instance_id, "land_id": land_id, "type_id": type_id, "cost": cost, 
		"risk_surcharge": int(quote.get("risk_surcharge", 0)), "risk_surcharge_rate": float(quote.get("risk_surcharge_rate", 0.0)), 
	})
	return _ok("开始建设", {"business_id": instance_id, "quote": quote})


static func assign_talent(player_id: String, business_id: String, talent_id: String, slot: int) -> Dictionary:
	return replace_talent(player_id, business_id, talent_id, slot)


static func replace_talent(player_id: String, business_id: String, talent_id: String, slot: int) -> Dictionary:
	var tutorial_route: Dictionary = TutorialDirector.route_action("talent_resolve", {"player_id": player_id, "business_id": business_id, "talent_id": talent_id, "slot": slot})
	if bool(tutorial_route.get("handled", false)):
		return tutorial_route
	var player: = GameState.player(player_id)
	var business: Dictionary = GameState.game_data.businesses.get(business_id, {})
	if player.is_empty() or business.is_empty():
		return _fail("企业不存在")
	if str(business.owner_id) != player_id:
		return _fail("不能安排到对手企业")
	var business_state := str(business.get("state", ""))
	var talent := GameConfig.by_id("talents", talent_id)
	if business_state == "constructing" and str(talent.get("stat", "")) != "build":
		return _fail("施工期只能安排建设人才")
	if business_state not in ["operating", "constructing"]:
		return _fail("企业当前不可安排员工")
	if slot < 0 or slot > 1:
		return _fail("员工位不可用")
	if not player.talent_ids.has(talent_id):
		return _fail("未拥有该人才")
	for other_id: String in player.business_ids:
		var other: Dictionary = GameState.game_data.businesses.get(other_id, {})
		if other_id != business_id and other.get("employees", []).has(talent_id):
			return _fail("人才已入驻其他企业")
	var current_slot: int = business.get("employees", []).find(talent_id)
	if current_slot >= 0 and current_slot != slot:
		business.employees[current_slot] = ""
	var replaced_id: String = str(business.employees[slot])
	business.employees[slot] = talent_id
	var accelerated := false
	if business_state == "constructing":
		var accelerators: Array = business.get("construction_talent_accelerators", [])
		if not accelerators.has(talent_id):
			ConstructionProgressService.apply_delta(business, -maxi(1, int(talent.get("value", 1))), "talent_%s" % talent_id, int(GameState.game_data.round))
			accelerators.append(talent_id)
			business.construction_talent_accelerators = accelerators
			accelerated = true
	GameState._record(player_id, "assign_talent", {"business_id": business_id, "talent_id": talent_id, "slot": slot, "replaced_id": replaced_id})
	var message := "%s已安排到%s  员工位%d" % [str(GameConfig.by_id("talents", talent_id).get("name", talent_id)), str(business.get("name", business_id)), slot + 1]
	if business_state == "constructing":
		message += "；已立即缩短工期" if accelerated else "；该人才此前已加速，本项目不重复生效"
	return _ok(message, {"replaced_id": replaced_id, "construction_accelerated": accelerated, "remaining_rounds": int(business.get("remaining_rounds", 0))})


static func unassign_talent(player_id: String, business_id: String, slot: int) -> Dictionary:
	var business: Dictionary = GameState.game_data.businesses.get(business_id, {})
	if business.is_empty() or str(business.get("owner_id", "")) != player_id:
		return _fail("企业不存在或不属于你")
	if slot < 0 or slot >= business.get("employees", []).size():
		return _fail("员工位无效")
	var talent_id: = str(business.employees[slot])
	if talent_id.is_empty():
		return _fail("该员工位当前为空")
	business.employees[slot] = ""
	GameState._record(player_id, "unassign_talent", {"business_id": business_id, "talent_id": talent_id, "slot": slot})
	return _ok("员工已撤回待岗", {"talent_id": talent_id})


static func estimate_assets(player_id: String) -> int:
	var player: = GameState.player(player_id)
	var total: = 0
	for land_id: String in player.land_ids:
		var land: Dictionary = GameState.game_data.lands.get(land_id, {})
		if land.is_empty() or not AssetStates.valuation_eligible(land, player_id):
			continue
		total += int(land.price)
	for business_id: String in player.business_ids:
		var business: Dictionary = GameState.game_data.businesses.get(business_id, {})
		if business.is_empty() or str(business.get("owner_id", "")) != player_id:
			continue
		if str(business.get("state", "")) in ["closed", "acquired"]:
			continue
		total += int(business.value)
	return total


static func demolition_quote(player_id: String, land_id: String) -> Dictionary:
	var player := GameState.player(player_id)
	var land: Dictionary = GameState.game_data.get("lands", {}).get(land_id, {})
	var business: Dictionary = GameState.game_data.get("businesses", {}).get(str(land.get("business_id", "")), {})
	if not EndlessOperationsSystem.is_enabled():
		return _fail("拆除重建仅在永续经营模式开放")
	if player.is_empty() or land.is_empty() or business.is_empty() or str(land.get("owner_id", "")) != player_id:
		return _fail("资产不属于当前财团")
	if bool(land.get("mortgaged", false)) or bool(business.get("mortgaged", false)):
		return _fail("抵押资产不能主动拆除")
	if str(business.get("state", "")) not in ["operating", "loss_watch"]:
		return _fail("企业当前不可拆除")
	var operated := int(GameState.game_data.round) - int(business.get("operating_since_round", GameState.game_data.round))
	if operated < 3:
		return _fail("企业需经营满 3 回合后才能拆除")
	return _ok("可拆除，1 回合后恢复为空地", {"rounds": 1, "operated_rounds": operated, "business_name": str(business.get("name", "现有企业")), "business_value_lost": int(business.get("value", 0)), "land_id": land_id})


static func start_demolition(player_id: String, land_id: String) -> Dictionary:
	var quote := demolition_quote(player_id, land_id)
	if not bool(quote.get("ok", false)):
		return quote
	var land: Dictionary = GameState.game_data.lands[land_id]
	var business: Dictionary = GameState.game_data.businesses[str(land.business_id)]
	business.state = "demolishing"
	business.demolition_remaining_rounds = 1
	land.state = "demolishing"
	GameState._record(player_id, "demolition_started", {"land_id": land_id, "business_id": str(business.id)})
	return _ok("拆除已开始，下回合恢复为空地", {"land_id": land_id})


static func bank_sale_quote(player_id: String, land_id: String) -> Dictionary:
	var player := GameState.player(player_id)
	var land: Dictionary = GameState.game_data.get("lands", {}).get(land_id, {})
	if not EndlessOperationsSystem.is_enabled():
		return _fail("银行快速变现仅在永续经营模式开放")
	if player.is_empty() or land.is_empty() or str(land.get("owner_id", "")) != player_id:
		return _fail("资产不属于当前财团")
	if int(GameState.game_data.round) - int(land.get("acquired_round", GameState.game_data.round)) < 2:
		return _fail("土地持有满 2 回合后才能快速变现")
	if str(land.get("state", "")) in ["auction", "government_locked", "demolishing"]:
		return _fail("资产当前不可出售")
	var business: Dictionary = GameState.game_data.get("businesses", {}).get(str(land.get("business_id", "")), {})
	var gross_value := int(land.get("price", 0)) + int(business.get("value", 0))
	var proceeds := roundi(float(gross_value) * 0.6)
	return _ok("银行回收价 %d 万" % proceeds, {"proceeds": proceeds, "gross_value": gross_value, "discount_rate": 0.6, "land_id": land_id, "business_name": str(business.get("name", "空地"))})


static func sell_land_to_bank(player_id: String, land_id: String) -> Dictionary:
	var quote := bank_sale_quote(player_id, land_id)
	if not bool(quote.get("ok", false)):
		return quote
	var player := GameState.player(player_id)
	var land: Dictionary = GameState.game_data.lands[land_id]
	var business_id := str(land.get("business_id", ""))
	var business: Dictionary = GameState.game_data.businesses.get(business_id, {})
	var proceeds := int(quote.get("data", {}).get("proceeds", 0))
	var collateral_result := {}
	if bool(land.get("mortgaged", false)) or bool(business.get("mortgaged", false)):
		collateral_result = load("res://scripts/CollateralSettlementService.gd").close_after_disposal(player, land_id, proceeds, "银行快速变现")
	else:
		GameState.apply_cash(player_id, proceeds, "土地银行快速变现")
	player.land_ids.erase(land_id)
	if not business_id.is_empty():
		player.business_ids.erase(business_id)
		business.state = "closed"
		business.owner_id = ""
	AssetStates.transition(land, AssetStates.BANK_OWNED)
	land.business_id = ""
	GameState._record(player_id, "bank_land_sale", {"land_id": land_id, "proceeds": proceeds, "collateral": collateral_result})
	return _ok("银行已回收资产，到账 %d 万" % int(collateral_result.get("surplus_returned", proceeds)), {"proceeds": proceeds, "collateral": collateral_result})


static func _effect_value(player: Dictionary, kind: String, fallback: float) -> float:
	for effect: Dictionary in player.get("effects", []):
		if str(effect.get("kind", "")) == kind:
			return float(effect.get("value", fallback))
	return fallback


static func _has_action_block(player: Dictionary) -> bool:
	return player.get("effects", []).any( func(effect: Dictionary) -> bool:
		return str(effect.get("kind", "")) == "gilded_action_block" and int(effect.get("duration", 0)) > 0)


static func _consume_effect(player: Dictionary, kind: String) -> void :
	for effect: Dictionary in player.get("effects", []).duplicate():
		if str(effect.get("kind", "")) == kind:
			player.effects.erase(effect)
			return


static func _ok(message: String, data: Dictionary) -> Dictionary:
	return {"ok": true, "message": message, "data": data}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message, "data": {}}
