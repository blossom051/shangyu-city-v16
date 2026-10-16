class_name AIDecisionEngine
extends RefCounted

const ParcelGeometry = preload("res://scripts/LandParcelGeometry.gd")


const Cards = preload("res://scripts/CardEngine.gd")
const CompanyRules = preload("res://scripts/CompanyAbilityEngine.gd")
const Economy = preload("res://scripts/EconomyMath.gd")
const Bank = preload("res://scripts/BankSystem.gd")
const Startups = preload("res://scripts/StartupInvestmentSystem.gd")
const Regions = preload("res://scripts/RegionalEconomySystem.gd")
const Behavior = preload("res://scripts/AIBehaviorProfile.gd")
const Difficulty = preload("res://scripts/AIDifficultyPolicy.gd")
const BattleRules = preload("res://scripts/CardBattleRules.gd")
const ComboRules = preload("res://scripts/CardComboRules.gd")


static func choose_stage(player_id: String, stage: String) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return _abstain("玩家不存在")
	match stage:
		"round_card": return _choose_round_card(player)
		"land": return _choose_land(player)
		"build": return _choose_business(player)
		"talent": return _choose_talent(player)
		"discard": return _choose_discard(player)
		"card": return _choose_card(player)
		"stock": return _choose_stock(player)
		"loan": return _choose_loan(player)
		"startup": return _choose_startup(player)
		"recovery": return _choose_recovery(player)
	return _abstain("未知行动阶段")


static func auction_bid(player_id: String, auction: Dictionary) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return _abstain("玩家不存在")
	var land: Dictionary = GameState.game_data.lands.get(str(auction.get("asset_id", "")), {})
	if land.is_empty():
		var business: Dictionary = GameState.game_data.businesses.get(str(auction.get("asset_id", "")), {})
		land = GameState.game_data.lands.get(str(business.get("land_id", "")), {})
	if land.is_empty():
		return _abstain("拍品缺少可估值资产")
	var available: = GameState.available_cash(player_id)
	var start_price: = int(auction.get("start_price", 0))
	var breakdown: = _blank_breakdown()
	var book: = float(land.get("price", start_price))
	breakdown.expected_return = maxf(-40.0, (book - float(start_price)) * 0.35)
	breakdown.cash_safety = float(available - start_price - 150) * 0.06
	breakdown.district_control = _district_control_value(player, land)
	breakdown.company_fit = _land_company_fit(player, land)
	breakdown.debt_pressure = - float(player.debt) * 0.04
	breakdown.remaining_rounds = float(_rounds_left()) * 1.5
	var market_roll: = int(abs(hash("auction-market|%s|%d" % [str(land.id), int(GameState.game_data.seed)])) % 100)
	breakdown.opportunity_cost = -180.0 if market_roll < 35 else -8.0 + float(market_roll % 19)
	var score: = _sum_breakdown(breakdown) + _stable_jitter(player_id, str(land.id))
	var maximum: = roundi(book * (0.82 + minf(0.16, float(breakdown.company_fit + breakdown.district_control) / 300.0)))
	if score < 8.0 or available - start_price < 150 or start_price > maximum:
		return _abstain("拍品协同或现金安全不足")
	var increment: int = 5 + int(abs(hash("auction|%s|%s|%d" % [player_id, str(land.id), int(GameState.game_data.seed)])) % 46)
	var amount: int = mini(maximum, start_price + increment + maxi(0, int(auction.get("round", 1)) - 1) * 12)
	return _candidate("bid", score, breakdown, {"amount": amount, "asset_id": str(auction.get("asset_id", "")), "maximum": maximum})


static func _choose_round_card(player: Dictionary) -> Dictionary:
	var offer: Array = Cards.round_offer(str(player.id))
	var candidates: Array[Dictionary] = []
	for card_id: String in offer:
		var card: = GameConfig.by_id("cards", card_id)
		var rarity_value: float = float({"blue": 10.0, "gold": 24.0, "platinum": 40.0, "red": 68.0, "gilded": 82.0, "west_bank": 34.0, "west_bank_advanced": 58.0}.get(str(card.get("rarity", "blue")), 10.0))
		var breakdown: = _blank_breakdown()
		breakdown.expected_return = rarity_value
		breakdown.opportunity_cost = -6.0 * float(player.hand.count(card_id))
		candidates.append(_candidate("choose", rarity_value + float(breakdown.opportunity_cost), breakdown, {"card_id": card_id}))
	return _best(candidates, "没有回合卡候选", player)


static func _choose_land(player: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var available_cash: = GameState.available_cash(str(player.id))
	for land: Dictionary in GameState.game_data.lands.values():
		if str(land.state) != "available" or int(land.price) > available_cash - 160:
			continue
		var breakdown: = _blank_breakdown()
		breakdown.expected_return = 150.0 - float(land.price) * 0.28
		breakdown.cash_safety = minf(35.0, float(available_cash - int(land.price)) * 0.08)
		breakdown.district_control = _district_control_value(player, land)
		breakdown.district_control += Regions.ai_opportunity(land, player)
		breakdown.target_threat = Behavior.land_reaction(player, land)
		breakdown.company_fit = _land_company_fit(player, land)
		breakdown.remaining_rounds = float(_rounds_left()) * 2.0
		var score: = _sum_breakdown(breakdown)
		candidates.append(_candidate("buy", score, breakdown, {"land_id": str(land.id)}))
	return _best(candidates, "现金安全垫不足或没有合适地块", player)


static func _choose_business(player: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for land_id: String in player.land_ids:
		var land: Dictionary = GameState.game_data.lands.get(land_id, {})
		if str(land.get("state", "")) != "owned_empty":
			continue
		for business: Dictionary in GameConfig.list("business_types"):
			var build_cost: = roundi(float(business.cost) * CompanyRules.build_cost_multiplier(str(player.company_id)))
			if build_cost > GameState.available_cash(str(player.id)) - 120:
				continue
			var breakdown: = _blank_breakdown()
			var income: = float(business.income) * CompanyRules.income_multiplier(str(player.company_id), business, int(GameState.game_data.round))
			var fixed: = float(business.fixed_cost) * CompanyRules.fixed_cost_multiplier(str(player.company_id))
			breakdown.expected_return = (income - fixed) * maxf(1.0, float(_rounds_left() - int(business.get("build_rounds", 1)))) / maxf(1.0, float(build_cost)) * 100.0
			breakdown.cash_safety = float(GameState.available_cash(str(player.id)) - build_cost) * 0.05
			breakdown.company_fit = 24.0 if CompanyRules.income_multiplier(str(player.company_id), business, int(GameState.game_data.round)) > 1.0 else 0.0
			breakdown.company_fit += (1.0 - CompanyRules.fixed_cost_multiplier(str(player.company_id))) * float(business.fixed_cost) * 8.0
			breakdown.company_fit += (1.0 - CompanyRules.risk_loss_multiplier(str(player.company_id))) * float(business.get("risk", 0)) * 5.0
			if CompanyRules.numeric_ability(str(player.company_id), "event_guard_every", 0.0) > 0.0:
				breakdown.company_fit += minf(10.0, float(business.get("risk", 0)) * 0.25)
			breakdown.district_control = 16.0 if business.get("fit", []).has(str(land.district)) else -8.0 if business.get("avoid", []).has(str(land.district)) else 0.0
			breakdown.remaining_rounds = float(_rounds_left() - int(business.get("build_rounds", 1))) * 2.0
			candidates.append(_candidate("build", _sum_breakdown(breakdown), breakdown, {"land_id": land_id, "business_type_id": str(business.id)}))
	return _best(candidates, "没有满足回收期和现金安全的建设方案", player)


static func _choose_talent(player: Dictionary) -> Dictionary:
	if not player.get("pending_talents", []).is_empty():
		var best_id: = ""
		var best_score: = - INF
		for talent_id: String in player.pending_talents:
			var talent: = GameConfig.by_id("talents", talent_id)
			var score: = _talent_score(player, talent)
			if score > best_score:
				best_score = score
				best_id = talent_id
		return _candidate("recruit" if player.talent_ids.size() < 12 and best_score >= 20.0 else "convert", best_score, _blank_breakdown(), {"talent_id": best_id})
	if player.talent_ids.size() >= 12 or GameState.available_cash(str(player.id)) < 420:
		return _abstain("人才容量或现金安全不足")
	var breakdown: = _blank_breakdown()
	breakdown.expected_return = 24.0 + float(player.business_ids.size()) * 5.0
	breakdown.cash_safety = float(GameState.available_cash(str(player.id)) - 60) * 0.03
	return _candidate("draw", _sum_breakdown(breakdown), breakdown, {"count": 1})


static func _choose_discard(player: Dictionary) -> Dictionary:
	if player.hand.size() <= 5:
		return _abstain("手牌未超限")
	var worst_id: = str(player.hand[-1])
	var worst_value: = INF
	for card_id: String in player.hand:
		var card: = GameConfig.by_id("cards", card_id)
		var value: = float({"blue": 1, "gold": 2, "platinum": 3, "red": 5, "gilded": 7, "west_bank": 3, "west_bank_advanced": 5}.get(str(card.get("rarity", "blue")), 1))
		if value < worst_value:
			worst_value = value
			worst_id = card_id
	return _candidate("discard", 1.0, _blank_breakdown(), {"card_id": worst_id})


static func _choose_card(player: Dictionary) -> Dictionary:
	if int(player.get("strategy_points", 0)) <= 0:
		return _abstain("本回合策略点已用完")
	var candidates: Array[Dictionary] = []
	for card_id: String in player.hand:
		var card: = GameConfig.by_id("cards", card_id)
		if int(card.get("cost", 1)) > int(player.get("strategy_points", 0)):
			continue
		if str(card.get("type", "")) in ["defense", "counter"] and player.get("secret_zone", []).size() >= BattleRules.MAX_SECRET_SLOTS:
			continue
		for target: Dictionary in Cards.legal_targets(str(player.id), card_id):
			var breakdown: = _blank_breakdown()
			breakdown.expected_return = _card_effect_value(card)
			breakdown.target_threat = _target_threat(str(target.id), str(player.id)) if str(card.type) == "attack" else 0.0
			var company: = GameConfig.by_id("investment_companies", str(player.get("company_id", "")))
			var signature_tags: Array = company.get("signature_tags", [])
			breakdown.company_fit = 14.0 if signature_tags.has(str(card.get("group", ""))) or signature_tags.has(str(card.get("category", ""))) else 3.0
			if str(card.get("type", "")) in ["defense", "counter"]:
				breakdown.company_fit += 16.0 if str(player.get("company_id", "")) in ["hengyue", "yunshan"] else 5.0
			if str(card.get("type", "")) == "attack" and str(player.get("company_id", "")) == "chiyan":
				breakdown.target_threat += 18.0
			if str(card.get("type", "")) == "attack":
				var target_owner: = str(target.id)
				if GameState.game_data.get("businesses", {}).has(target_owner): target_owner = str(GameState.game_data.businesses[target_owner].owner_id)
				breakdown.opportunity_cost -= float(GameState.player(target_owner).get("secret_zone", []).size()) * 7.0
			var combo: = ComboRules.preview(player, card)
			if bool(combo.get("triggered", false)): breakdown.company_fit += 22.0
			breakdown.opportunity_cost = -10.0 if _rounds_left() > 3 and str(card.rarity) == "red" else 0.0
			breakdown.remaining_rounds = 18.0 if int(card.get("duration", 0)) > 0 and _rounds_left() > 1 else 0.0
			var score: = _sum_breakdown(breakdown)
			candidates.append(_candidate("play", score, breakdown, {"card_id": card_id, "target_id": str(target.id)}))
	return _best(candidates, "没有正收益的合法卡牌目标", player, 12.0)


static func _choose_stock(player: Dictionary) -> Dictionary:
	var available_cash: = GameState.available_cash(str(player.id))
	if available_cash < 180 and not player.stocks.is_empty():
		var best_sale: Dictionary = {}
		for stock_id: String in player.stocks:
			var holding: Dictionary = player.stocks[stock_id]
			if int(holding.get("shares", 0)) < 100:
				continue
			var value: = Economy.stock_position_value(float(GameState.game_data.stocks[stock_id].price), int(holding.shares))
			if best_sale.is_empty() or value > float(best_sale.get("value", 0.0)):
				best_sale = {"stock_id": stock_id, "shares": mini(500, int(holding.shares)), "value": value}
		if not best_sale.is_empty():
			var breakdown: = _blank_breakdown()
			breakdown.cash_safety = 45.0
			breakdown.debt_pressure = 20.0 if int(player.debt) > 0 else 0.0
			return _candidate("sell", _sum_breakdown(breakdown), breakdown, {"stock_id": str(best_sale.stock_id), "shares": int(best_sale.shares)})
	if available_cash < 420 or _rounds_left() <= 1:
		return _abstain("现金安全垫或剩余回合不足")
	var candidates: Array[Dictionary] = []
	for stock: Dictionary in GameState.game_data.stocks.values():
		var history: Array = stock.get("history", [])
		var trend: = 0.0 if history.size() < 2 else (float(history[-1]) - float(history[0])) / maxf(1.0, float(history[0]))
		var breakdown: = _blank_breakdown()
		breakdown.expected_return = trend * 260.0 + 12.0
		breakdown.cash_safety = float(available_cash - Economy.stock_trade_value(float(stock.price), 100)) * 0.02
		breakdown.opportunity_cost = -12.0 if player.stocks.has(str(stock.id)) else 4.0
		breakdown.remaining_rounds = float(_rounds_left()) * 1.5
		candidates.append(_candidate("buy", _sum_breakdown(breakdown), breakdown, {"stock_id": str(stock.id), "shares": 100}))
	return _best(candidates, "没有值得承担波动的证券", player, 16.0)


static func _choose_loan(player: Dictionary) -> Dictionary:
	var available_cash: = GameState.available_cash(str(player.id))
	if available_cash >= 200:
		return _abstain("当前现金充足")
	var has_funded_opportunity: = false
	for land_id: String in player.land_ids:
		if str(GameState.game_data.lands.get(land_id, {}).get("state", "")) == "owned_empty":
			has_funded_opportunity = true
			break
	if not has_funded_opportunity:
		return _abstain("没有可产生回报的融资用途")
	var summary: = Bank.loan_summary(str(player.id))
	var credit: = int(summary.get("available_credit", 0))
	if credit < 100:
		return _abstain("授信不足")
	var amount: = 200 if credit >= 200 and available_cash < 80 else 100
	var breakdown: = _blank_breakdown()
	breakdown.expected_return = 34.0
	breakdown.cash_safety = 28.0
	breakdown.debt_pressure = - float(player.debt) * 0.05
	breakdown.remaining_rounds = float(_rounds_left()) * 1.5
	return _candidate("borrow", _sum_breakdown(breakdown), breakdown, {"amount": amount})


static func _choose_startup(player: Dictionary) -> Dictionary:
	if not Startups.is_event_round() or player.active_projects.size() >= 2:
		return _abstain("当前没有可投窗口或项目位已满")
	var candidates: Array[Dictionary] = []
	for project: Dictionary in Startups.projects_for_round():
		if int(project.cost) > GameState.available_cash(str(player.id)) - 180:
			continue
		var breakdown: = _blank_breakdown()
		var expected_value: = float(project.cost) * float(project.base_success) * float(project.financing_multiplier) - float(project.cost)
		breakdown.expected_return = expected_value * 0.45
		breakdown.cash_safety = float(GameState.available_cash(str(player.id)) - int(project.cost)) * 0.03
		breakdown.company_fit = 18.0 if CompanyRules.array_ability(str(player.company_id), "income_tags").has(str(project.sector)) else 0.0
		breakdown.remaining_rounds = float(_rounds_left() - int(project.delay)) * 2.0
		candidates.append(_candidate("invest", _sum_breakdown(breakdown), breakdown, {"project_id": str(project.id)}))
	return _best(candidates, "项目回报不足以覆盖风险和资金占用", player, 12.0)


static func _choose_recovery(player: Dictionary) -> Dictionary:
	for business_id: String in player.business_ids:
		var business: Dictionary = GameState.game_data.businesses.get(business_id, {})
		if str(business.get("state", "")) == "loss_watch" and GameState.available_cash(str(player.id)) >= 100:
			var breakdown: = _blank_breakdown()
			breakdown.expected_return = 40.0
			breakdown.cash_safety = 10.0
			return _candidate("recover", 50.0, breakdown, {"business_id": business_id})
	return _abstain("没有需要且有能力整改的企业")


static func _best(candidates: Array[Dictionary], reason: String, player: Dictionary, minimum_score: = 0.0) -> Dictionary:
	if candidates.is_empty():
		return _abstain(reason)
	for candidate: Dictionary in candidates:
		candidate.score = Difficulty.score(candidate, str(player.id)) + Behavior.score_adjustment(player, candidate) + (0.0 if Difficulty.current() == Difficulty.HARD else _stable_jitter(str(player.id), str(candidate)))
	candidates.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
	var selected: Dictionary = candidates[Difficulty.pick_index(candidates.size(), str(player.id), str(candidates[0].get("action", "")))]
	return selected if float(selected.score) >= minimum_score else _abstain(reason)


static func _candidate(action: String, score: float, breakdown: Dictionary, details: = {}) -> Dictionary:
	var result: = {"abstain": false, "action": action, "score": score, "breakdown": breakdown}
	result.merge(details, true)
	return result


static func _abstain(reason: String) -> Dictionary:
	return {"abstain": true, "action": "abstain", "score": 0.0, "reason": reason, "breakdown": _blank_breakdown()}


static func _blank_breakdown() -> Dictionary:
	return {"expected_return": 0.0, "cash_safety": 0.0, "debt_pressure": 0.0, "district_control": 0.0, "company_fit": 0.0, "target_threat": 0.0, "opportunity_cost": 0.0, "remaining_rounds": 0.0}


static func _sum_breakdown(breakdown: Dictionary) -> float:
	var total: = 0.0
	for value: Variant in breakdown.values():
		total += float(value)
	return total


static func _rounds_left() -> int:
	return EndlessOperationsSystem.planning_rounds_left()


static func _target_threat(target_id: String, actor_id: String) -> float:
	var owner_id: = target_id
	if GameState.game_data.businesses.has(target_id):
		owner_id = str(GameState.game_data.businesses[target_id].owner_id)
	var target: = GameState.player(owner_id)
	var actor: = GameState.player(actor_id)
	if target.is_empty() or actor.is_empty():
		return 0.0
	return clampf((float(target.asset_value) - float(actor.asset_value)) * 0.06 + float(target.rank <= actor.rank) * 16.0, 0.0, 90.0)


static func _card_effect_value(card: Dictionary) -> float:
	var base: float = float({"attack": 24.0, "operation": 28.0, "finance": 22.0, "district": 24.0, "defense": 14.0, "counter": 16.0}.get(str(card.type), 12.0))
	return float(base) + minf(30.0, absf(float(card.get("value", 0.0))) * (0.2 if absf(float(card.get("value", 0.0))) > 5.0 else 12.0))


static func _district_control_value(player: Dictionary, land: Dictionary) -> float:
	var control: = float(player.get("district_influence", {}).get(str(land.district), 0.0))
	return 35.0 if control >= 0.25 else 18.0 if control > 0.0 else 4.0


static func _land_company_fit(player: Dictionary, land: Dictionary) -> float:
	var fit_score: = 0.0
	var adjacency_multiplier: = CompanyRules.numeric_ability(str(player.company_id), "adjacency_income_multiplier", 1.0)
	if adjacency_multiplier > 1.0:
		for owned_id: String in player.get("land_ids", []):
			var owned: Dictionary = GameState.game_data.lands.get(owned_id, {})
			if not owned.is_empty() and ParcelGeometry.are_adjacent(land, owned):
				fit_score = maxf(fit_score, (adjacency_multiplier - 1.0) * 250.0)
				break
	for business: Dictionary in GameConfig.list("business_types"):
		if not business.get("fit", []).has(str(land.get("district", ""))):
			continue
		var income_multiplier: = CompanyRules.income_multiplier(str(player.company_id), business, int(GameState.game_data.get("round", 1)))
		fit_score = maxf(fit_score, maxf(0.0, income_multiplier - 1.0) * 180.0)
	var fixed_cost_multiplier: = CompanyRules.fixed_cost_multiplier(str(player.company_id))
	fit_score = maxf(fit_score, maxf(0.0, 1.0 - fixed_cost_multiplier) * 100.0)
	if CompanyRules.numeric_ability(str(player.company_id), "event_guard_every", 0.0) > 0.0:
		fit_score = maxf(fit_score, 8.0)
	return clampf(fit_score, 0.0, 32.0)


static func _talent_score(player: Dictionary, talent: Dictionary) -> float:
	var quality: float = float({"blue": 10.0, "platinum": 24.0, "gold": 38.0, "red": 58.0}.get(str(talent.get("quality", "blue")), 8.0))
	var role_bonus: = float(player.business_ids.size()) * 4.0
	return float(quality) + role_bonus


static func _stable_jitter(player_id: String, candidate_key: String) -> float:
	var seed: = int(GameState.game_data.get("seed", 0))
	return float(abs(hash("%s|%s|%d" % [player_id, candidate_key, seed])) % 401) / 100.0 - 2.0
