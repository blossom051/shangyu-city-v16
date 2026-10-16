class_name NewsSystem
extends RefCounted

const Startups = preload("res://scripts/StartupInvestmentSystem.gd")
const RandomEvents = preload("res://scripts/RandomEventSystem.gd")
const MatchRandom = preload("res://scripts/RandomSource.gd")
const StockSuspensions = preload("res://scripts/StockSuspensionSystem.gd")
const ConditionalCatalog = preload("res://scripts/ConditionalEventCatalog.gd")


static func generate_round() -> Array:
	var pool: = GameConfig.list("news_events").duplicate(true)
	pool.append_array(ConditionalCatalog.news_events().filter( func(event: Dictionary) -> bool: return ConditionalCatalog.eligible(event)))
	var recent_ids: Array[String] = []
	var history: Array = GameState.game_data.get("news_history", [])
	for record: Dictionary in history.slice(maxi(0, history.size() - 2)):
		for old_news: Dictionary in record.get("items", []):
			recent_ids.append(str(old_news.get("id", "")))
	var fresh: Array = pool.filter(func(event: Dictionary) -> bool: return not recent_ids.has(str(event.get("id", ""))))
	if fresh.size() >= 2:
		pool = fresh
	MatchRandom.shuffle_in_place(pool)
	var selected: Array = pool.slice(0, 2)
	var operating: Array = GameState.game_data.get("businesses", {}).values().filter(func(business: Dictionary) -> bool: return str(business.get("state", "")) in ["operating", "loss_watch", "mortgaged"])
	if not operating.is_empty() and not selected.any(func(event: Dictionary) -> bool: return operating.any(func(business: Dictionary) -> bool: return matches_business(event, business))):
		for candidate: Dictionary in pool:
			if operating.any(func(business: Dictionary) -> bool: return matches_business(candidate, business)):
				selected[1] = candidate
				break
	for item: Dictionary in selected:
		item.section = "market"
		var sector := str(item.get("sector", _sector_for_tag(str(item.get("tags", ["综合"])[0]))))
		item.sector = sector
		if not sector.is_empty() and not item.get("tags", []).has(sector):
			item.tags.append(sector)
		item.actual_direction = int(item.direction)
		item.actual_strength = float(item.strength)
		if str(item.credibility) == "low":
			item.actual_strength *= 0.5
			if GameState.rng.randf() < 0.4:
				item.actual_direction *= -1
		item.verified = true
		var affected := apply_business_news(item)
		item.affected_business_ids = affected
		item.settlement_text = "%s板块证券信号 %+.1f%%；%d 家已建企业经营受影响" % [str(item.get("tags", ["综合"])[0]), float(item.actual_direction) * float(item.actual_strength) * 100.0, affected.size()]
	var market_observation: = StockSuspensions.signal_story()
	if not market_observation.is_empty():
		selected.append(market_observation)
	selected.append_array(_build_city_stories())
	GameState.game_data.news = selected
	GameState.game_data.news_intelligence = build_intelligence()
	GameState.game_data.get_or_add("news_history", []).append({"round": int(GameState.game_data.round), "items": selected.duplicate(true), "intelligence": GameState.game_data.news_intelligence.duplicate(true)})
	return selected


static func matches_business(event: Dictionary, business: Dictionary) -> bool:
	var kind: Dictionary = GameConfig.by_id("business_types", str(business.get("type_id", "")))
	var type_ids: Array = event.get("type_ids", [])
	if not type_ids.is_empty():
		return type_ids.has(str(business.get("type_id", "")))
	var tags: Array = event.get("tags", [])
	var sector := str(event.get("sector", _sector_for_tag(str(tags[0]) if not tags.is_empty() else "")))
	return not sector.is_empty() and sector == str(kind.get("sector", ""))


static func apply_business_news(event: Dictionary) -> Array[String]:
	var affected: Array[String] = []
	var direction := float(event.get("actual_direction", event.get("direction", 0)))
	var strength := float(event.get("actual_strength", event.get("strength", 0.0)))
	var income := float(event.get("business_income", clampf(1.0 + direction * strength * 2.0, 0.65, 1.35)))
	var cost := float(event.get("business_cost", 1.0))
	if direction != float(event.get("direction", direction)):
		if event.has("business_income"):
			income = clampf(2.0 - income, 0.65, 1.35)
		if event.has("business_cost"):
			cost = clampf(2.0 - cost, 0.65, 1.35)
	for business: Dictionary in GameState.game_data.get("businesses", {}).values():
		if str(business.get("state", "")) not in ["operating", "loss_watch", "mortgaged"] or not matches_business(event, business):
			continue
		for effect_kind in ["income_multiplier", "cost_multiplier"]:
			var multiplier := income if effect_kind == "income_multiplier" else cost
			if not is_equal_approx(multiplier, 1.0):
				business.effects.append({"kind": effect_kind, "value": multiplier, "duration": 1, "source_player_id": "system", "event_id": str(event.get("id", ""))})
		affected.append(str(business.get("id", "")))
	return affected


static func _sector_for_tag(tag: String) -> String:
	return {"消费": "consumer", "科技": "technology", "地产": "property", "医疗": "medical", "物流": "logistics", "文娱": "entertainment", "金融": "finance", "新能源": "energy"}.get(tag, "")


static func build_intelligence() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var current: = int(GameState.game_data.get("round", 0))
	var next_project: = Startups.next_event_round(current)
	result.append({"id": "intel_project", "section": "capital", "title": "创投项目窗口：%s" % ("本局已结束" if next_project < 0 else "第%d回合开放" % next_project), "tags": ["创投"], "actual_direction": 0, "actual_strength": 0.0, "credibility": "high", "verified": true, "settlement_text": "项目列表由赛程真实生成，到达该回合即可投资并立即扣款。"})
	var rate_delta: = RandomEvents.loan_rate_modifier()
	result.append({"id": "intel_bank", "section": "finance", "title": "银行当期利率：基准上浮 %+.1f%%" % (rate_delta * 100.0), "tags": ["银行"], "actual_direction": -1 if rate_delta > 0 else 0, "actual_strength": absf(rate_delta), "credibility": "high", "verified": true, "settlement_text": "该利率已计入到期贷款本轮应还利息；新借款从下回合开始。"})
	var auctions: Array = GameState.game_data.get("auctions", [])
	var auction_count: int = auctions.size()
	var next_auction: = _next_auction_round(current)
	result.append({"id": "intel_auction", "section": "city", "title": "拍卖中心：%d 宗资产待竞价%s" % [auction_count, "；下一次随机土地专场第%d回合" % next_auction if auction_count == 0 and next_auction > 0 else ""], "tags": ["拍卖"], "actual_direction": 0, "actual_strength": 0.0, "credibility": "high", "verified": true, "settlement_text": "银行收回、连续亏损与整局随机低价土地专场都会形成真实拍卖资产。"})
	return result


static func _build_city_stories() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var districts: Array = GameState.game_data.get("districts", {}).values()
	districts.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("heat", 0.0)) > float(b.get("heat", 0.0)))
	var hottest: Dictionary = districts[0] if not districts.is_empty() else {}
	result.append({
		"id": "city_heat_%d" % int(GameState.game_data.round), 
		"section": "city", 
		"title": "%s成为本轮城市消费焦点" % str(hottest.get("name", hottest.get("district_name", "核心商圈"))), 
		"tags": ["城市", "商圈"], 
		"actual_direction": 0, 
		"actual_strength": 0.0, 
		"verified": true, 
		"settlement_text": "商圈热度 %.0f，客流与区域控制收益将按真实路线结算。" % float(hottest.get("heat", 100.0)), 
	})
	var operating_count: = 0
	var constructing_count: = 0
	var sector_ids: = {}
	for business: Dictionary in GameState.game_data.get("businesses", {}).values():
		if str(business.get("state", "")) == "operating":
			operating_count += 1
		elif str(business.get("state", "")) == "constructing":
			constructing_count += 1
		var business_type: = GameConfig.by_id("business_types", str(business.get("type_id", "")))
		var sector_id: = str(business_type.get("sector", ""))
		if not sector_id.is_empty():
			sector_ids[sector_id] = true
	result.append({
		"id": "business_watch_%d" % int(GameState.game_data.round), 
		"section": "business", 
		"title": "城市产业供给继续形成", 
		"tags": ["企业", "经营"], 
		"actual_direction": 0, 
		"actual_strength": 0.0, 
		"verified": true, 
		"settlement_text": "全城已有 %d 家企业运营、%d 家处于建设期，覆盖 %d 个产业门类。" % [operating_count, constructing_count, sector_ids.size()], 
	})
	var talent_total: = 0
	var red_total: = 0
	for player: Dictionary in GameState.game_data.get("players", []):
		talent_total += player.get("talent_ids", []).size()
		for talent_id: String in player.get("talent_ids", []):
			if str(GameConfig.by_id("talents", talent_id).get("quality", "")) == "red":
				red_total += 1
	result.append({
		"id": "talent_watch_%d" % int(GameState.game_data.round), 
		"section": "talent", 
		"title": "城市人才流动升温，红色人才仍属稀缺", 
		"tags": ["人才", "招聘"], 
		"actual_direction": 0, 
		"actual_strength": 0.0, 
		"verified": true, 
		"settlement_text": "各财团共签约 %d 位人才，其中红色人才 %d 位；已安排员工的实际收益可在企业档案查看。" % [talent_total, red_total], 
	})
	var available_land: int = GameState.game_data.get("lands", {}).values().filter( func(land: Dictionary) -> bool: return str(land.get("state", "")) == "available").size()
	var next_auction: = _next_auction_round(int(GameState.game_data.round))
	result.append({
		"id": "land_watch_%d" % int(GameState.game_data.round), 
		"section": "property", 
		"title": "城市土地储备仍有 %d 块可交易" % available_land, 
		"tags": ["土地", "拍卖"], 
		"actual_direction": 0, 
		"actual_strength": 0.0, 
		"verified": true, 
		"settlement_text": "随机低价土地专场%s；强制处置资产也可能临时进入拍卖。" % ("将在第%d回合出现" % next_auction if next_auction > 0 else "本局已无后续安排"), 
	})
	return result


static func _next_auction_round(current: int) -> int:
	var triggered: Array = GameState.game_data.get("auction_events_triggered", [])
	for value: Variant in GameState.game_data.get("auction_schedule", []):
		if int(value) > current and not triggered.has(int(value)):
			return int(value)
	return -1
