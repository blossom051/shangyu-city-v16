extends Node

const PlayerFactory = preload("res://scripts/PlayerCompany.gd")
const News = preload("res://scripts/NewsSystem.gd")
const Government = preload("res://scripts/GovernmentEventSystem.gd")
const Cards = preload("res://scripts/CardEngine.gd")
const Startups = preload("res://scripts/StartupInvestmentSystem.gd")
const Districts = preload("res://scripts/DistrictSystem.gd")
const RandomEvents = preload("res://scripts/RandomEventSystem.gd")
const Traffic = preload("res://scripts/TrafficSystem.gd")
const Auctions = preload("res://scripts/AuctionSystem.gd")
const StockSuspensions = preload("res://scripts/StockSuspensionSystem.gd")
const Risks = preload("res://scripts/RiskSystem.gd")
const RoundDecisions = preload("res://scripts/RoundDecisionSystem.gd")
const Regions = preload("res://scripts/RegionalEconomySystem.gd")
const Feedback = preload("res://scripts/CityFeedbackSystem.gd")
const Radar = preload("res://scripts/OpportunityRadar.gd")
const Endless = preload("res://scripts/EndlessOperationsSystem.gd")


const CURRENT_SAVE_VERSION: = "15.5-multi-save-west-bank-landmarks"
const SAVE_PATH: = "user://v9185_information_visualization_save.json"
const ACCEPTED_SAVE_VERSIONS: = [
	CURRENT_SAVE_VERSION, 
	"15.5-card-layout-and-art-hotfix",
	"15.4-capital-market-operations-release",
	"15.2-concise-interface-release",
	"14.4-judicial-credit-rare-clarity", 
	"14.0-core-experience-competitive-truth", 
	"13.0-command-table-finance-visuals", 
	"12.0-capital-duel-faction-hall", 
	"10.0-operating-loop-city-feedback", 
	"9.19.4-financial-truth-auction-event-receipts", 
	"9.19.3-in-city-tutorial-procedural-loading", 
	"9.19.2-guided-practice-capital-express", 
	"9.19.1-lifecycle-risk-governance-cards", 
	"9.18.9-event-cinematic-audio-harmony", 
	"9.18.8-random-decision-input-stability", 
	"9.18.7-public-news-guaranteed-decisions", 
	"9.18.5-information-visualization-round-decisions", 
]

signal changed(snapshot: Dictionary)
signal action_recorded(entry: Dictionary)

var game_data: Dictionary = {}
var rng: = RandomNumberGenerator.new()
var suppress_disk_save: = false
var tutorial_lock: = false

func _ready() -> void :
	reset()

func reset() -> void :
	game_data = {
		"version": CURRENT_SAVE_VERSION, 
		"mode": "solo", 
		"ai_difficulty": "standard",
		"round_limit": 12, 
		"endless": false,
		"round": 0, 
		"phase": "menu", 
		"players": [], 
		"lands": {}, 
		"businesses": {}, 
		"talents": {}, 
		"stocks": {}, 
		"news": [], 
		"news_intelligence": [], 
		"city_news_issue": {}, 
		"city_news_public_history": [], 
		"auctions": [], 
		"auction_schedule": [], 
		"auction_events_triggered": [], 
		"auction_notices_seen": {}, 
		"forced_collection_alerts": [], 
		"startup_schedule": [], 
		"startup_offers": {}, 
		"round_card_offers": {}, 
		"west_round_card_offers": {},
		"districts": {}, 
		"regional_economy": {}, 
		"city_visual_state": {}, 
		"city_feedback": [], 
		"competition_feed": [], 
		"economic_transactions": {}, 
		"settled_round_reports": {}, 
		"last_settled_round_id": -1, 
		"opportunity_radar": [], 
		"district_effects": [], 
		"traffic_routes": [], 
		"active_events": [], 
		"event_news": [], 
		"round_decision_offers": {}, 
		"round_decision_schedule": [], 
		"round_decision_event_ids": {}, 
		"round_decision_events_triggered": [], 
		"round_decision_history": [], 
		"market_impacts": [], 
		"stock_suspension_schedule": [], 
		"stock_suspension_history": [], 
		"domain_events": [], 
		"battle_ledger": [], 
		"round_open_snapshots": {}, 
		"last_report": {}, 
		"final_settlement": {}, 
		"turn_order": [], 
		"active_order_index": 0, 
		"log": [], 
		"seed": 6007, 
	}
	rng.seed = int(game_data.seed)

func start_match(mode: String, round_limit: int, selections: Array[Dictionary], match_seed: = 6007, ai_difficulty: String = "standard") -> void :
	reset()
	game_data.seed = int(match_seed)
	rng.seed = int(match_seed)
	game_data.mode = mode
	game_data.ai_difficulty = load("res://scripts/AIDifficultyPolicy.gd").normalize(ai_difficulty)
	game_data.round_limit = round_limit
	Endless.initialize_match(round_limit <= 0)
	for i in selections.size():
		var selected: = selections[i]
		var company: = GameConfig.by_id("investment_companies", str(selected.company_id))
		var player: = PlayerFactory.create("p%d" % (i + 1), i, company, bool(selected.get("human", false)))
		if bool(selected.get("human", false)) and not str(selected.get("custom_name", "")).is_empty(): player.name = str(selected.custom_name)
		game_data.players.append(player)
	for land: Dictionary in GameConfig.list("land_tiles"):
		game_data.lands[str(land.id)] = land.duplicate(true)
		game_data.lands[str(land.id)].merge({"owner_id": "", "state": "available", "asset_state": "AVAILABLE", "business_id": "", "mortgaged": false}, true)
	var stock_index: = 0
	for stock: Dictionary in GameConfig.list("stocks"):
		var copy: = stock.duplicate(true)
		var history: Array[float] = []
		for point in range(12):
			var wave: = sin(float(point) * 0.78 + float(stock_index) * 0.61) * 0.018 + cos(float(point) * 0.31 + float(stock_index)) * 0.009
			history.append(snappedf(maxf(50.0, float(stock.price) * (1.0 + wave)), 0.01))
		copy["history"] = history
		copy["price"] = history[-1]
		copy["fundamental_price"] = float(stock.price)
		game_data.stocks[str(stock.id)] = copy
		stock_index += 1
	Districts.initialize()
	var schedule_horizon := 24 if round_limit <= 0 else round_limit
	Startups.initialize_match(schedule_horizon)
	Auctions.initialize_match(schedule_horizon)
	StockSuspensions.initialize_match(schedule_horizon)
	RoundDecisions.initialize_match(schedule_horizon)
	Regions.initialize()
	Feedback.initialize()
	game_data.phase = "opening_cards"
	_emit_change()

func player(player_id: String) -> Dictionary:
	for value: Dictionary in game_data.players:
		if str(value.id) == player_id:
			return value
	return {}

func active_player() -> Dictionary:
	if game_data.turn_order.is_empty():
		return {}
	var index: = int(game_data.get("active_order_index", -1))
	if index < 0 or index >= game_data.turn_order.size():
		return {}
	return player(str(game_data.turn_order[index]))


func is_human_turn() -> bool:
	var current: = active_player()
	return not current.is_empty() and bool(current.get("human", false))

func set_opening_hand(player_id: String, cards: Array) -> void :
	var target: = player(player_id)
	if target.is_empty() or not target.hand.is_empty() or cards.size() != 3:
		return
	target.hand = cards.duplicate()
	_record(player_id, "opening_cards", {"cards": cards.duplicate()})

func begin_round() -> void :
	game_data.round += 1
	Endless.begin_round()
	if int(game_data.round) > 1:
		Regions.advance_round()
	game_data.round_card_offers = {}
	game_data.west_round_card_offers = {}
	_capture_round_open_snapshots()
	for p: Dictionary in game_data.players:
		p.actions = {"land": 0, "build": 0, "card": 0, "attack_card": 0, "loan": 0}
		load("res://scripts/CardBattleRules.gd").reset_round(p)
		p.round_net = 0
		if int(p.get("talent_reputation_penalty_rounds", 0)) > 0:
			p.talent_reputation_penalty_rounds = int(p.talent_reputation_penalty_rounds) - 1
		var round_number: = int(game_data.round)
		if round_number > 1:
			Cards.create_round_offer(str(p.id), 5)
	StockSuspensions.apply_round_state()
	News.generate_round()
	RandomEvents.generate_round()
	RoundDecisions.generate_round()
	Government.maybe_trigger()
	Districts.recalculate()
	Traffic.generate_round()
	Auctions.ensure_market_supply()
	Radar.refresh()
	game_data.turn_order = _snake_order()
	game_data.active_order_index = 0
	game_data.phase = "player_turn"
	_emit_change()


func _capture_round_open_snapshots() -> void :
	var snapshots: = {}
	var prices: = {}
	for stock_id: String in game_data.get("stocks", {}):
		prices[stock_id] = float(game_data.stocks[stock_id].get("price", 0.0))
	for value: Dictionary in game_data.get("players", []):
		snapshots[str(value.id)] = {
			"round": int(game_data.round), 
			"log_index": game_data.get("log", []).size(), 
			"cash": int(value.get("cash", 0)), 
			"asset": int(value.get("asset_value", 0)), 
			"debt": int(value.get("debt", 0)), 
			"risk": int(value.get("risk", 0)), 
			"rank": int(value.get("rank", 0)), 
			"stock_holdings": value.get("stocks", {}).duplicate(true), 
			"stock_prices": prices.duplicate(true), 
		}
	game_data.round_open_snapshots = snapshots

func advance_turn() -> bool:
	var director: = get_node_or_null("/root/TutorialDirector")
	if director != null:
		var tutorial_route: Dictionary = director.call("route_action", "end_turn")
		if bool(tutorial_route.get("handled", false)):
			return false
	game_data.active_order_index += 1
	if int(game_data.active_order_index) >= game_data.turn_order.size():
		game_data.phase = "settlement"
		_emit_change()
		return false
	_emit_change()
	return true

func apply_cash(player_id: String, amount: int, reason: String) -> bool:
	var target: = player(player_id)
	if target.is_empty() or (amount < 0 and available_cash(player_id) + amount < 0):
		return false
	target.cash = int(target.cash) + amount
	target.round_net = int(target.round_net) + amount
	_record(player_id, "cash", {"amount": amount, "reason": reason})
	return true


func available_cash(player_id: String) -> int:
	var target: = player(player_id)
	if target.is_empty():
		return 0
	var locked: = 0
	for effect: Dictionary in target.get("effects", []):
		if str(effect.get("kind", "")) == "cash_lock":
			locked += int(effect.get("amount", 0))
	return maxi(0, int(target.cash) - locked)


func settle_obligation(player_id: String, amount: int, reason: String, debt_kind: String, risk_increase: = 5) -> Dictionary:
	var target: = player(player_id)
	if target.is_empty() or amount <= 0:
		return {"paid": 0, "debt_added": 0}
	var paid: = mini(available_cash(player_id), amount)
	if paid > 0:
		apply_cash(player_id, - paid, reason)
	var shortfall: = amount - paid
	if shortfall > 0:
		var existing: Dictionary = {}
		for loan: Dictionary in target.loans:
			if str(loan.kind) == debt_kind and str(loan.get("asset_id", "")).is_empty() and int(loan.get("origin_round", -1)) == int(game_data.get("round", 0)):
				existing = loan
				break
		if existing.is_empty():
			var prefix: = "T" if debt_kind == "temporary_finance" else "O"
			target.loans.append({
				"id": "%s%d" % [prefix, target.loans.size() + 1], 
				"kind": debt_kind, 
				"principal": shortfall, 
				"rate": 0.1 if debt_kind == "temporary_finance" else 0.08, 
				"original_principal": shortfall, 
				"term_rounds": 4, 
				"remaining_rounds": 4, 
				"overdue": 0, 
				"unpaid_interest": 0, 
				"unpaid_principal": 0, 
				"overdue_fee": 0, 
				"paid_interest": 0, 
				"maturity_due": false, 
				"origin_round": int(game_data.get("round", 0)), 
				"first_due_round": int(game_data.get("round", 0)) + 1, 
				"asset_id": ""
			})
		else:
			existing.principal = int(existing.principal) + shortfall
		target.debt = int(target.debt) + shortfall
		Risks.adjust(player_id, risk_increase, reason, "资金缺口")
		_record(player_id, "obligation_shortfall", {
			"reason": reason, 
			"kind": debt_kind, 
			"amount": amount, 
			"paid": paid, 
			"debt_added": shortfall
		})
	return {"paid": paid, "debt_added": shortfall}

func snapshot() -> Dictionary:
	return game_data.duplicate(true)


func force_refresh() -> void :


	changed.emit(snapshot())

func save_to_disk() -> void :
	if suppress_disk_save:
		return
	SaveSlots.save_auto(snapshot())

func has_save_file() -> bool:
	SaveSlots.migrate_legacy_once()
	return bool(SaveSlots.load_slot("auto").get("ok", false))

func load_from_disk() -> bool:
	SaveSlots.migrate_legacy_once()
	var loaded := SaveSlots.load_slot("auto")
	if not bool(loaded.get("ok", false)):
		return false
	return bool(restore_snapshot(loaded.get("game_data", {})).get("ok", false))


func restore_snapshot(snapshot_value: Dictionary) -> Dictionary:
	if snapshot_value.is_empty() or str(snapshot_value.get("version", "")) not in ACCEPTED_SAVE_VERSIONS:
		return {"ok": false, "message": "存档版本不兼容"}
	game_data = snapshot_value.duplicate(true)
	game_data.version = CURRENT_SAVE_VERSION
	normalize_compatible_state()
	rng.seed = int(game_data.get("seed", 6007))
	game_data.get_or_add("city_news_issue", {})
	game_data.get_or_add("city_news_public_history", [])
	game_data.get_or_add("round_decision_schedule", [])
	game_data.get_or_add("round_decision_event_ids", {})
	game_data.get_or_add("round_decision_events_triggered", [])
	game_data.get_or_add("round_open_snapshots", {})
	game_data.get_or_add("regional_economy", {})
	game_data.get_or_add("city_visual_state", {})
	game_data.get_or_add("city_feedback", [])
	game_data.get_or_add("competition_feed", [])
	game_data.get_or_add("opportunity_radar", [])
	game_data.get_or_add("forced_collection_alerts", [])
	Regions.ensure_state()
	Feedback.ensure_state()
	if game_data.round_decision_schedule.is_empty():
		RoundDecisions.initialize_match(int(game_data.get("round_limit", 10)))
	for value: Dictionary in game_data.get("players", []):
		value.get_or_add("actions", {})
		value.actions.get_or_add("loan", 0)
		load("res://scripts/CardBattleRules.gd").ensure_player(value)
		if not value.has("pending_card_reward"):
			value.pending_card_reward = {}
		if not value.has("risk_history"):
			value.risk_history = []
		if not value.has("last_loan_settlement"):
			value.last_loan_settlement = {}
	StockSuspensions.ensure_compatible_state()
	StockSuspensions.apply_round_state()
	Risks.ensure_all_players()
	Districts.recalculate()
	_emit_change()
	return {"ok": true, "message": "存档已读取"}


func save_manual_slot(index: int, display_name: String) -> Dictionary:
	if suppress_disk_save:
		return {"ok": false, "message": "当前流程不写入真实存档"}
	return SaveSlots.save_manual(index, display_name, snapshot())


func load_from_slot(slot_id: String) -> Dictionary:
	var loaded := SaveSlots.load_slot(slot_id)
	if not bool(loaded.get("ok", false)):
		return loaded
	var restored := restore_snapshot(loaded.get("game_data", {}))
	if bool(restored.get("ok", false)):
		restored.slot_id = slot_id
	return restored


func normalize_compatible_state() -> void:
	game_data["ai_difficulty"] = load("res://scripts/AIDifficultyPolicy.gd").normalize(str(game_data.get("ai_difficulty", "standard")))
	# Historical saves can contain nulls or legacy scalar ids in arrays that are
	# dictionaries in the current schema.  Normalize once at the state boundary
	# so every gameplay system receives one stable shape.
	var lands: Dictionary = _dictionary_values(game_data.get("lands", {}))
	for config_land: Dictionary in GameConfig.list("land_tiles"):
		var land_id := str(config_land.get("id", ""))
		if land_id.is_empty():
			continue
		if not lands.has(land_id):
			lands[land_id] = config_land.duplicate(true)
			lands[land_id].merge({"owner_id": "", "state": "available", "asset_state": "AVAILABLE", "business_id": "", "mortgaged": false}, true)
		else:
			(lands[land_id] as Dictionary).merge(config_land, true)
	game_data["lands"] = lands
	game_data["players"] = _dictionary_items(game_data.get("players", []))
	for player_value: Variant in game_data.get("players", []):
		if not player_value is Dictionary:
			continue
		var player: Dictionary = player_value
		for key: String in ["active_projects", "loans", "effects", "guards", "risk_history", "round_history"]:
			player[key] = _dictionary_items(player.get(key, []))
		for key: String in ["land_ids", "business_ids", "talent_ids", "hand"]:
			if not player.get(key, []) is Array:
				player[key] = []
		if not player.get("stocks", {}) is Dictionary:
			player["stocks"] = {}
		if not player.get("listed_stocks", {}) is Dictionary:
			player["listed_stocks"] = {}
	for key: String in ["district_effects", "active_events", "event_news", "market_impacts", "battle_ledger", "competition_feed", "opportunity_radar", "forced_collection_alerts", "auctions", "traffic_routes", "log"]:
		game_data[key] = _dictionary_items(game_data.get(key, []))
	game_data["ipo_records"] = _dictionary_values(game_data.get("ipo_records", {}))
	game_data.get_or_add("ipo_audit_history", [])
	game_data.get_or_add("economic_cycle", {})
	game_data.get_or_add("next_endless_startup_round", 2)
	game_data.get_or_add("west_round_card_offers", {})


func _dictionary_items(value: Variant) -> Array:
	var normalized: Array = []
	if not value is Array:
		return normalized
	for item: Variant in value:
		if item is Dictionary:
			normalized.append(item)
	return normalized


func _dictionary_values(value: Variant) -> Dictionary:
	var normalized: Dictionary = {}
	if not value is Dictionary:
		return normalized
	for key: Variant in value:
		var item: Variant = value[key]
		if item is Dictionary:
			normalized[str(key)] = item
	return normalized

func _snake_order() -> Array:
	var order: Array = game_data.players.filter( func(p: Dictionary) -> bool: return not bool(p.get("eliminated", false))).map( func(p: Dictionary) -> String: return str(p.id))
	if int(game_data.round) % 2 == 0:
		order.reverse()
	return order

func _record(player_id: String, kind: String, data: Dictionary) -> void :
	var entry: = {"round": int(game_data.round), "player_id": player_id, "kind": kind, "data": data, "index": game_data.log.size()}
	game_data.log.append(entry)
	Regions.observe_action(player_id, kind, data)
	Feedback.observe_action(player_id, kind, data)
	action_recorded.emit(entry)
	_emit_change()

func _emit_change() -> void :


	if suppress_disk_save or changed.get_connections().is_empty():
		return
	changed.emit(snapshot())
