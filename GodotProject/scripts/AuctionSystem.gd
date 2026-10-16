class_name AuctionSystem
extends RefCounted

const Regions = preload("res://scripts/RegionalEconomySystem.gd")

const CompanyRules = preload("res://scripts/CompanyAbilityEngine.gd")
const CollateralSettlement = preload("res://scripts/CollateralSettlementService.gd")
const AssetStates = preload("res://scripts/AssetStateService.gd")
const CompetitionFeed = preload("res://scripts/CompetitiveEventFeed.gd")


static func initialize_match(round_limit: int) -> void :
	var event_count: = 1 if round_limit <= 10 else 1 + GameState.rng.randi_range(0, 1)
	var schedule: Array[int] = []
	var earliest: = 2
	var latest: = maxi(2, round_limit - 1)
	while schedule.size() < event_count:
		var candidate: = GameState.rng.randi_range(earliest, latest)
		if not schedule.has(candidate):
			schedule.append(candidate)
	schedule.sort()
	GameState.game_data.auction_schedule = schedule
	GameState.game_data.auction_events_triggered = []


static func event_rounds() -> Array:
	return GameState.game_data.get("auction_schedule", []).duplicate()


static func next_event_round(after_round: int = -1) -> int:
	var current: = int(GameState.game_data.get("round", 0)) if after_round < 0 else after_round
	var triggered: Array = GameState.game_data.get("auction_events_triggered", [])
	for value: Variant in event_rounds():
		if int(value) > current and not triggered.has(int(value)):
			return int(value)
	return -1


static func ensure_market_supply() -> Dictionary:
	if not GameState.game_data.get("auctions", []).is_empty():
		return _ok("已有待拍资产")
	var current_round: = int(GameState.game_data.get("round", 0))
	var triggered: Array = GameState.game_data.get_or_add("auction_events_triggered", [])
	var scheduled_round: = -1
	for value: Variant in event_rounds():
		if int(value) <= current_round and not triggered.has(int(value)):
			scheduled_round = int(value)
			break
	if scheduled_round < 0:
		return _fail("本轮无随机土地专场")
	var candidates: Array[Dictionary] = []
	for land: Dictionary in GameState.game_data.get("lands", {}).values():
		if str(land.get("state", "")) == "available":
			candidates.append(land)
	if candidates.is_empty():
		return _fail("没有可供拍卖的城市资产")
	var land: Dictionary = candidates[GameState.rng.randi_range(0, candidates.size() - 1)]
	var discount: = GameState.rng.randf_range(0.55, 0.68)
	AssetStates.transition(land, AssetStates.AUCTION, str(land.get("owner_id", "")))
	GameState.game_data.auctions.append({
		"asset_id": str(land.id), "kind": "city_land", "land_id": str(land.id), "business_id": "", 
		"seller_id": "city", "start_price": maxi(30, roundi(float(land.price) * discount * Regions.auction_price_multiplier(str(land.get("district", ""))))), "bids": {}, 
		"round": 1, "history": ["城市随机释出空地，按低价进入暗标"], "scheduled": true, 
		"scheduled_round": scheduled_round, 
	})
	triggered.append(scheduled_round)
	GameState._record("system", "scheduled_auction_started", {"land_id": str(land.id), "start_price": int(GameState.game_data.auctions[-1].start_price), "scheduled_round": scheduled_round, "discount": discount})
	return _ok("随机低价土地专场已开启")


static func create_for_business(business_id: String) -> void :
	create_for_asset(business_id)


static func create_for_asset(asset_id: String, source: = "collection", excluded_bidder_id: = "") -> void :
	var asset: = _resolve_asset(asset_id)
	if asset.is_empty() or str(asset.owner_id).is_empty():
		return
	var existing: = _find(str(asset.land_id))
	if not existing.is_empty():
		if source == "forced_collection":
			_promote_to_forced_collection(existing, str(asset.owner_id), excluded_bidder_id)
		return
	var land: Dictionary = asset.land
	var business: Dictionary = asset.business
	if str(land.get("state", "")) == "government_locked":
		return
	AssetStates.transition(land, AssetStates.AUCTION, str(land.get("owner_id", "")))
	if not business.is_empty():
		business.state = "auction"
		business.mortgaged = false
	var auction_id: = str(business.get("id", land.id))
	var start_value: = int(land.price) + int(business.get("value", 0))
	GameState.game_data.auctions.append({
		"asset_id": auction_id, 
		"kind": "bundle" if not business.is_empty() else "land", 
		"land_id": str(land.id), 
		"business_id": str(business.get("id", "")), 
		"seller_id": str(asset.owner_id), 
		"start_price": maxi(40, roundi(float(start_value) * 0.6)), 
		"market_price": start_value, 
		"source": source, 
		"excluded_bidder_ids": [excluded_bidder_id] if not excluded_bidder_id.is_empty() else [], 
		"bids": {}, 
		"round": 1, 
		"history": ["资产进入暗标拍卖"]
	})
	GameState._record("system", "auction_started", {
		"asset_id": auction_id, 
		"land_id": str(land.id), 
		"business_id": str(business.get("id", ""))
	})


static func _promote_to_forced_collection(auction: Dictionary, seller_id: String, excluded_bidder_id: String) -> void :
	auction.source = "forced_collection"
	auction.seller_id = seller_id
	var excluded: Array = auction.get_or_add("excluded_bidder_ids", [])
	if not excluded_bidder_id.is_empty() and not excluded.has(excluded_bidder_id):
		excluded.append(excluded_bidder_id)
	auction.bids = {}
	auction.round = 1
	auction.history.append("法院强制执行：现有拍卖升级为抵押资产司法处置")
	GameState._record("system", "auction_promoted_to_forced_collection", {
		"asset_id": str(auction.get("asset_id", "")), 
		"land_id": str(auction.get("land_id", "")), 
		"seller_id": seller_id, 
		"excluded_bidder_id": excluded_bidder_id, 
	})


static func submit_bid(asset_id: String, player_id: String, amount: int) -> Dictionary:
	var tutorial_route: Dictionary = TutorialDirector.route_action("auction_bid", {"player_id": player_id, "asset_id": asset_id, "amount": amount})
	if bool(tutorial_route.get("handled", false)):
		return tutorial_route
	var auction: = _find(asset_id)
	var player: = GameState.player(player_id)
	if auction.is_empty():
		return _fail("拍卖不存在")
	if player.is_empty():
		return _fail("玩家不存在")
	if str(auction.seller_id) == player_id:
		return _fail("原持有人不能参与竞买")
	if _player_is_delinquent(player):
		return _fail("当前存在逾期贷款，授信冻结期间不能参与拍卖")
	if auction.get("excluded_bidder_ids", []).has(player_id):
		return _fail("该财团是本次强制处置对象，不能参与竞买")
	if amount != 0 and amount < int(auction.start_price):
		return _fail("出价低于起拍价")
	if amount > int(player.cash):
		return _fail("现金不足")
	var modifiers: = _bid_effect_profile(auction, player)
	auction.bids[player_id] = amount
	GameState._record(player_id, "auction_bid_locked", {
		"asset_id": str(auction.asset_id), 
		"round": int(auction.round), 
		"amount": amount, 
		"effective_amount": amount + int(modifiers.get("bid_bonus", 0)), 
		"payment_credit": int(modifiers.get("payment_credit", 0)), 
	})
	return _ok("暗标已锁定：你输入%d万，系统竞价比较额%d万" % [amount, amount + int(modifiers.get("bid_bonus", 0))])


static func reveal(asset_id: String) -> Dictionary:
	var auction: = _find(asset_id)
	if auction.is_empty():
		return _fail("拍卖不存在")
	var pending: = pending_bidder_ids(asset_id)
	if not pending.is_empty():
		return {"ok": false, "waiting_for_decisions": true, "pending_player_ids": pending, "message": "仍有竞买席尚未出价或明确放弃"}
	var disclosure: = _bid_disclosure(auction)
	var positive: Array[Dictionary] = []
	for player_id: String in auction.bids:
		var amount: = int(auction.bids[player_id])
		var modifiers: Dictionary = auction.get("bid_effects", {}).get(player_id, {})
		if amount > 0 and amount <= int(GameState.player(player_id).cash):
			positive.append({
				"player_id": player_id, 
				"amount": amount, 
				"effective_amount": amount + int(modifiers.get("bid_bonus", 0)), 
				"payment_credit": int(modifiers.get("payment_credit", 0)), 
			})
	if positive.is_empty():
		if str(auction.get("source", "")) == "forced_collection":
			var returned: = _return_forced_asset_to_market(auction)
			returned["bid_disclosure"] = disclosure
			return returned
		auction.start_price = maxi(20, roundi(float(auction.start_price) * 0.9))
		auction.round = int(auction.round) + 1
		auction.history.append("无人出价，下一轮降价 10%")
		auction.bids = {}
		GameState._record("system", "auction_no_bid", {
			"asset_id": str(auction.asset_id), 
			"round": int(auction.round), 
			"start_price": int(auction.start_price)
		})
		return {"ok": true, "message": "无人出价，下一轮降价 10%", "no_bid": true, "bid_disclosure": disclosure}
	positive.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a.effective_amount) > int(b.effective_amount))
	var top: = int(positive[0].effective_amount)
	var tied: Array = positive.filter( func(bid: Dictionary) -> bool: return int(bid.effective_amount) == top)
	if tied.size() > 1 and int(auction.round) == 1:
		auction.round = 2
		auction.history.append("最高价相同，进入第二轮暗标")
		auction.bids = {}
		GameState._record("system", "auction_second_round", {"asset_id": str(auction.asset_id), "price": top})
		return {"ok": true, "message": "最高价相同，进入第二轮暗标", "tie": true, "bid_disclosure": disclosure}
	var winner: Dictionary = tied[0]
	if tied.size() > 1:
		tied.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
			return int(GameState.player(str(a.player_id)).rank) > int(GameState.player(str(b.player_id)).rank))
		winner = tied[0]
		auction.history.append("再次同价，当前排名靠后者优先")
	var transfer: = _transfer(auction, str(winner.player_id), int(winner.amount), int(winner.get("payment_credit", 0)))
	if not bool(transfer.ok):
		return transfer
	var company_rebate: Dictionary = CompanyRules.apply_auction_win_rebate(str(winner.player_id), int(transfer.paid), str(auction.asset_id))
	return {
		"ok": true, 
		"message": "%s 中标：竞价比较额%d万，实际支付%d万%s" % [GameState.player(str(winner.player_id)).name, int(winner.effective_amount), int(transfer.paid), "  强势成交返利%d万" % int(company_rebate.get("rebate", 0)) if bool(company_rebate.get("triggered", false)) else ""], 
		"winner_id": str(winner.player_id), 
		"effective_amount": int(winner.effective_amount), 
		"cash_bid": int(winner.amount), 
		"paid": int(transfer.paid), 
		"company_rebate": company_rebate, 
		"bid_disclosure": disclosure, 
	}


static func eligible_bidder_ids(asset_id: String) -> Array[String]:
	var auction: = _find(asset_id)
	var result: Array[String] = []
	if auction.is_empty():
		return result
	for player: Dictionary in GameState.game_data.get("players", []):
		if bool(player.get("eliminated", false)) or str(player.get("id", "")) == str(auction.get("seller_id", "")):
			continue
		if auction.get("excluded_bidder_ids", []).has(str(player.get("id", ""))) or _player_is_delinquent(player):
			continue
		result.append(str(player.id))
	return result


static func pending_bidder_ids(asset_id: String) -> Array[String]:
	var auction: = _find(asset_id)
	var result: Array[String] = []
	if auction.is_empty():
		return result
	for player_id: String in eligible_bidder_ids(asset_id):
		if not auction.get("bids", {}).has(player_id):
			result.append(player_id)
	return result


static func _bid_disclosure(auction: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player_id: String in eligible_bidder_ids(str(auction.asset_id)):
		var amount: = int(auction.get("bids", {}).get(player_id, 0))
		var modifiers: Dictionary = auction.get("bid_effects", {}).get(player_id, {})
		result.append({
			"player_id": player_id, 
			"player_name": str(GameState.player(player_id).get("name", player_id)), 
			"cash_bid": amount, 
			"bid_bonus": int(modifiers.get("bid_bonus", 0)), 
			"effective_amount": amount + int(modifiers.get("bid_bonus", 0)), 
			"payment_credit": int(modifiers.get("payment_credit", 0)), 
			"status": "passed" if amount <= 0 else "bid", 
		})
	return result


static func _transfer(auction: Dictionary, winner_id: String, amount: int, payment_credit: = 0) -> Dictionary:
	var payable: = maxi(0, amount - payment_credit)
	if not GameState.apply_cash(winner_id, - payable, "拍卖中标"):
		return _fail("中标方资金不足，成交取消")
	var asset: = _resolve_asset(str(auction.land_id))
	if asset.is_empty():
		return _fail("拍卖资产不存在")
	var land: Dictionary = asset.land
	var business: Dictionary = asset.business
	var old_owner: = GameState.player(str(auction.seller_id))
	if not old_owner.is_empty():
		_apply_collection_proceeds(old_owner, str(land.id), amount)
		old_owner.land_ids.erase(str(land.id))
		if not business.is_empty():
			old_owner.business_ids.erase(str(business.id))
	var winner: = GameState.player(winner_id)
	if not winner.land_ids.has(str(land.id)):
		winner.land_ids.append(str(land.id))
	land.owner_id = winner_id
	land.mortgaged = false
	land.erase("previous_state")
	if business.is_empty():
		AssetStates.transition(land, AssetStates.OWNED, winner_id, "owned_empty")
		land.business_id = ""
	else:
		if not winner.business_ids.has(str(business.id)):
			winner.business_ids.append(str(business.id))
		business.owner_id = winner_id
		business.consecutive_loss = 0
		business.state = "operating"
		business.mortgaged = false
		AssetStates.transition(land, AssetStates.OWNED, winner_id, "operating")
		land.business_id = str(business.id)
	GameState.game_data.auctions.erase(auction)
	GameState._record(winner_id, "auction_won", {
		"land_id": str(land.id), 
		"business_id": str(business.get("id", "")), 
		"amount": amount, 
		"paid": payable, 
		"payment_credit": mini(amount, payment_credit), 
	})
	CompetitionFeed.publish("auction", winner_id, "%s以%d万竞得%s" % [str(winner.get("name", winner_id)), amount, str(land.get("district_name", land.id))], {"land_id": str(land.id), "amount": amount, "seller_id": str(auction.seller_id)})
	return {"ok": true, "message": "拍卖成交", "paid": payable}


static func _return_forced_asset_to_market(auction: Dictionary) -> Dictionary:
	var asset: = _resolve_asset(str(auction.get("land_id", "")))
	if asset.is_empty():
		return _fail("强制处置资产不存在")
	var land: Dictionary = asset.land
	var business: Dictionary = asset.business
	var seller: = GameState.player(str(auction.get("seller_id", "")))
	if not seller.is_empty():
		CollateralSettlement.close_after_disposal(seller, str(land.id), 0, "银行收回抵押资产")
		seller.land_ids.erase(str(land.id))
		if not business.is_empty():
			seller.business_ids.erase(str(business.id))
	if not business.is_empty():
		for talent: Dictionary in GameState.game_data.get("talents", {}).values():
			if str(talent.get("assigned_business_id", "")) == str(business.id):
				talent.assigned_business_id = ""
		GameState.game_data.businesses.erase(str(business.id))
	land.business_id = ""
	AssetStates.transition(land, AssetStates.BANK_OWNED)
	land.price = maxi(int(land.get("price", 0)), ceili(float(int(auction.get("start_price", 0))) * 1.25))
	GameState.game_data.auctions.erase(auction)
	GameState._record("system", "forced_auction_returned_to_market", {
		"land_id": str(land.id), "market_price": int(land.price), 
		"auction_start_price": int(auction.get("start_price", 0)), 
	})
	return {"ok": true, "no_bid": true, "returned_to_market": true, "market_price": int(land.price), "message": "无人承接，资产已收回为空地；后续仅可按市场价 %d 万购买" % int(land.price)}


static func _player_is_delinquent(player: Dictionary) -> bool:
	if player.is_empty():
		return false
	return player.get("loans", []).any( func(loan: Dictionary) -> bool:
		return int(loan.get("overdue", 0)) > 0 or int(loan.get("unpaid_interest", 0)) > 0 or int(loan.get("unpaid_principal", 0)) > 0 or int(loan.get("overdue_fee", 0)) > 0)


static func _bid_effect_profile(auction: Dictionary, player: Dictionary) -> Dictionary:
	var stored: Dictionary = auction.get_or_add("bid_effects", {})
	var player_id: = str(player.id)
	if stored.has(player_id):
		return stored[player_id]
	var profile: = {
		"bid_bonus": _consume_player_effect(player, "auction_bid_bonus"), 
		"payment_credit": _consume_player_effect(player, "auction_payment_credit"), 
	}
	stored[player_id] = profile
	return profile


static func _consume_player_effect(player: Dictionary, kind: String) -> int:
	for effect: Dictionary in player.get("effects", []).duplicate():
		if str(effect.get("kind", "")) != kind:
			continue
		var value: = int(effect.get("value", 0))
		player.effects.erase(effect)
		return value
	return 0


static func _apply_collection_proceeds(owner: Dictionary, land_id: String, amount: int) -> void :
	CollateralSettlement.close_after_disposal(owner, land_id, amount, "抵押资产拍卖")


static func _resolve_asset(asset_id: String) -> Dictionary:
	var land: Dictionary = GameState.game_data.lands.get(asset_id, {})
	var business: Dictionary = GameState.game_data.businesses.get(asset_id, {})
	if not business.is_empty():
		land = GameState.game_data.lands.get(str(business.land_id), {})
	if land.is_empty():
		return {}
	var business_id: = str(land.get("business_id", ""))
	if business.is_empty() and not business_id.is_empty():
		business = GameState.game_data.businesses.get(business_id, {})
	return {
		"land_id": str(land.id), 
		"owner_id": str(land.owner_id), 
		"land": land, 
		"business": business
	}


static func _find(asset_id: String) -> Dictionary:
	for item: Dictionary in GameState.game_data.auctions:
		if asset_id in [str(item.asset_id), str(item.land_id), str(item.get("business_id", ""))]:
			return item
	return {}


static func _ok(message: String) -> Dictionary:
	return {"ok": true, "message": message}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}
