class_name RandomEventSystem
extends RefCounted

const MarketImpacts = preload("res://scripts/MarketImpactSystem.gd")
const Cards = preload("res://scripts/CardEngine.gd")
const TimedEffects = preload("res://scripts/TimedEffectSystem.gd")
const CompanyRules = preload("res://scripts/CompanyAbilityEngine.gd")
const ConditionalCatalog = preload("res://scripts/ConditionalEventCatalog.gd")


static func generate_round(forced_event_ids: = []) -> Array:
	var selected: Array = []
	if not forced_event_ids.is_empty():
		for event_id: Variant in forced_event_ids:
			var forced: = GameConfig.by_id("random_events", str(event_id))
			if forced.is_empty():
				for candidate: Dictionary in ConditionalCatalog.risk_events():
					if str(candidate.id) == str(event_id): forced = candidate;break
			if not forced.is_empty():
				selected.append(forced.duplicate(true))
	else:
		var pool: = GameConfig.list("random_events").duplicate(true)
		pool = pool.filter(func(event: Dictionary) -> bool: return (EndlessOperationsSystem.is_enabled() or not bool(event.get("endless_only", false))) and int(event.get("min_round", 1)) <= int(GameState.game_data.round))
		pool.append_array(ConditionalCatalog.risk_events().filter( func(event: Dictionary) -> bool: return ConditionalCatalog.eligible(event)))
		var recent_ids: Array[String] = []
		var history: Array = GameState.game_data.get("event_history", [])
		for record: Dictionary in history.slice(maxi(0, history.size() - 2)):
			for old_event: Dictionary in record.get("events", []):
				recent_ids.append(str(old_event.get("id", "")))
		var fresh: Array = pool.filter(func(event: Dictionary) -> bool: return not recent_ids.has(str(event.get("id", ""))))
		if fresh.size() >= 3:
			pool = fresh
		_shuffle_with_match_rng(pool)
		var count: = (3 if GameState.rng.randf() < 0.38 else 2) if EndlessOperationsSystem.is_enabled() else (2 if GameState.rng.randf() < 0.42 else 1)
		selected = pool.slice(0, count)
	GameState.game_data.active_events = []
	GameState.game_data.event_news = []
	for event: Dictionary in selected:
		var active: = event.duplicate(true)
		active.round = int(GameState.game_data.round)
		var impact_receipt: = _apply(active)
		active.impact_receipt = impact_receipt
		GameState.game_data.active_events.append(active)
		GameState.game_data.event_news.append({"id": "event_%s" % str(active.id), "title": str(active.headline), "tags": [str(active.get("district", active.get("sector", "城市")))], "actual_direction": 0, "actual_strength": 0.0, "credibility": "high", "event_name": str(active.name), "is_event": true})
		GameState.game_data.domain_events.append({"event_id": "R%02d-E%03d" % [int(GameState.game_data.round), GameState.game_data.domain_events.size() + 1], "round": int(GameState.game_data.round), "type": "random_event_triggered", "data": active.duplicate(true)})
		GameState.game_data.battle_ledger.append({"round": int(GameState.game_data.round), "category": "event", "player_id": "system", "title": str(active.name), "details": active.duplicate(true)})
	GameState.game_data.get_or_add("event_history", []).append({"round": int(GameState.game_data.round), "events": selected.duplicate(true)})
	return selected


static func is_negative_event(event: Dictionary) -> bool:
	match str(event.get("effect", "")):
		"sector_cost": return float(event.get("value", 1.0)) > 1.0
		"business_impact": return float(event.get("income_multiplier", 1.0)) < 1.0 or float(event.get("cost_multiplier", 1.0)) > 1.0
		"loan_rate": return float(event.get("value", 0.0)) > 0.0
		"construction_delta": return int(event.get("value", 0)) > 0
		"market": return float(event.get("value", 0.0)) < 0.0
		"district_heat_market": return float(event.get("heat", 0.0)) < 0.0 or float(event.get("market", 0.0)) < 0.0
	return false


static func loan_rate_modifier(player_id: = "") -> float:
	var total: = 0.0
	for event: Dictionary in GameState.game_data.get("active_events", []):
		if str(event.effect) == "loan_rate":
			var player: = GameState.player(player_id)
			if not player.is_empty() and CompanyRules.blocks_negative_event(player, str(event.id), int(GameState.game_data.round)):
				continue
			total += float(event.value)
	return total


static func traffic_multiplier(district_ids: Array) -> float:
	var modifier: = 1.0
	for event: Dictionary in GameState.game_data.get("active_events", []):
		if str(event.effect) == "district_heat_market" and district_ids.has(str(event.district)):
			modifier += maxf(0.0, float(event.heat) / 100.0)
	return clampf(modifier, 0.65, 1.45)


static func validate_event_contracts() -> Dictionary:
	var supported: = ["district_heat_market", "sector_cost", "business_impact", "loan_rate", "construction_delta", "red_points", "market", "operating_grant", "draw_card"]
	var errors: Array[String] = []
	var catalog: = GameConfig.list("random_events").duplicate(true);catalog.append_array(ConditionalCatalog.risk_events())
	for event: Dictionary in catalog:
		if str(event.get("effect", "")) not in supported:
			errors.append("%s has no handler" % str(event.get("id", "")))
		if not event.has("duration"):
			errors.append("%s has no duration" % str(event.get("id", "")))
	return {"ok": errors.is_empty(), "errors": errors}


static func _apply(event: Dictionary) -> Dictionary:
	var outcomes: = _outcome_index()
	match str(event.effect):
		"district_heat_market":
			TimedEffects.add_district_effect(str(event.district), "heat_delta", float(event.heat), int(event.duration), str(event.id))
			MarketImpacts.add(str(event.stock), float(event.market), "random_event", "system", {"event_id": str(event.id)})
		"sector_cost":
			for business: Dictionary in GameState.game_data.businesses.values():
				var type: = GameConfig.by_id("business_types", str(business.type_id))
				if str(type.get("sector", "")) == str(event.sector):
					var owner: = GameState.player(str(business.owner_id))
					if not owner.is_empty() and CompanyRules.blocks_negative_event(owner, str(event.id), int(GameState.game_data.round)):
						_mark_outcome(outcomes, str(owner.id), "blocked", str(business.id), "财团能力抵消成本上升")
						continue
					business.effects.append({"kind": "cost_multiplier", "value": float(event.value), "duration": int(event.duration), "source_player_id": "system", "event_id": str(event.id)})
					if not owner.is_empty():
						_mark_outcome(outcomes, str(owner.id), "applied", str(business.id), "固定成本提高%d%%" % roundi((float(event.value) - 1.0) * 100.0))
		"business_impact":
			for business: Dictionary in GameState.game_data.businesses.values():
				if str(business.get("state", "")) not in ["operating", "loss_watch", "mortgaged"]:
					continue
				var kind: Dictionary = GameConfig.by_id("business_types", str(business.get("type_id", "")))
				if not event.get("type_ids", []).is_empty() and not event.get("type_ids", []).has(str(business.type_id)):
					continue
				if str(event.get("sector", "")).length() > 0 and str(kind.get("sector", "")) != str(event.sector):
					continue
				var owner: Dictionary = GameState.player(str(business.owner_id))
				if not owner.is_empty() and is_negative_event(event) and CompanyRules.blocks_negative_event(owner, str(event.id), int(GameState.game_data.round)):
					_mark_outcome(outcomes, str(owner.id), "blocked", str(business.id), "财团能力抵消冲击")
					continue
				for effect_kind in ["income_multiplier", "cost_multiplier"]:
					var multiplier := float(event.get(effect_kind, 1.0))
					if not is_equal_approx(multiplier, 1.0):
						business.effects.append({"kind": effect_kind, "value": multiplier, "duration": int(event.duration), "source_player_id": "system", "event_id": str(event.id)})
				if not owner.is_empty():
					_mark_outcome(outcomes, str(owner.id), "applied", str(business.id), "%s收入×%.2f、成本×%.2f" % [str(business.name), float(event.get("income_multiplier", 1.0)), float(event.get("cost_multiplier", 1.0))])
		"loan_rate":
			for player: Dictionary in GameState.game_data.players:
				if CompanyRules.blocks_negative_event(player, str(event.id), int(GameState.game_data.round)):
					_mark_outcome(outcomes, str(player.id), "blocked", "", "财团能力抵消融资加息")
				else:
					_mark_outcome(outcomes, str(player.id), "applied", "", "新增融资利率 +%.1f%%" % (float(event.value) * 100.0))
		"construction_delta":
			for business: Dictionary in GameState.game_data.businesses.values():
				if str(business.state) == "constructing":
					ConstructionProgressService.apply_delta(business, int(event.value), str(event.id), int(GameState.game_data.round))
		"red_points":
			for player: Dictionary in GameState.game_data.players:
				player.red_points = int(player.red_points) + int(event.value)
		"market":
			MarketImpacts.add(str(event.stock), float(event.value), "random_event", "system", {"event_id": str(event.id)})
		"operating_grant":
			for player: Dictionary in GameState.game_data.players:
				if not player.business_ids.is_empty():
					GameState.apply_cash(str(player.id), int(event.value), "城市经营纾困金")
		"draw_card":


			if int(GameState.game_data.get("round", 0)) >= 3:
				for player: Dictionary in GameState.game_data.players:
					Cards.draw_cards(str(player.id), int(event.value))
		_:
			push_error("未知随机事件效果，已安全跳过：%s" % str(event.get("effect", "")))
	return {
		"event_id": str(event.get("id", "")), 
		"negative": is_negative_event(event), 
		"duration": int(event.get("duration", 0)), 
		"player_outcomes": outcomes.values(), 
	}


static func _outcome_index() -> Dictionary:
	var result: = {}
	for player: Dictionary in GameState.game_data.get("players", []):
		result[str(player.id)] = {"player_id": str(player.id), "player_name": str(player.name), "status": "unaffected", "asset_ids": [], "details": []}
	return result


static func _mark_outcome(outcomes: Dictionary, player_id: String, status: String, asset_id: String, detail: String) -> void :
	if not outcomes.has(player_id):
		return
	var outcome: Dictionary = outcomes[player_id]
	if str(outcome.status) != "blocked" or status == "blocked":
		outcome.status = status
	if not asset_id.is_empty() and not outcome.asset_ids.has(asset_id):
		outcome.asset_ids.append(asset_id)
	if not detail.is_empty() and not outcome.details.has(detail):
		outcome.details.append(detail)


static func _shuffle_with_match_rng(values: Array) -> void :
	for index in range(values.size() - 1, 0, -1):
		var other: = GameState.rng.randi_range(0, index)
		var value: Variant = values[index]
		values[index] = values[other]
		values[other] = value
