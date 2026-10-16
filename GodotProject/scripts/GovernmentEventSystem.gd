class_name GovernmentEventSystem
extends RefCounted

const Bank = preload("res://scripts/BankSystem.gd")
const TimedEffects = preload("res://scripts/TimedEffectSystem.gd")
const CompanyRules = preload("res://scripts/CompanyAbilityEngine.gd")
const ParcelGeometry = preload("res://scripts/LandParcelGeometry.gd")
const ConditionalCatalog = preload("res://scripts/ConditionalEventCatalog.gd")


static func maybe_trigger() -> Dictionary:
	var round_index: = int(GameState.game_data.round)
	var limit: = int(GameState.game_data.round_limit)
	if EndlessOperationsSystem.is_enabled():
		if round_index < 4 or (round_index - 4) % 6 != 0:
			return {}
		limit = round_index + 6
	var trigger_rounds: = [maxi(3, limit / 3), maxi(6, limit * 2 / 3)]
	if not EndlessOperationsSystem.is_enabled() and round_index not in trigger_rounds:
		return {}
	var events: = GameConfig.list("government_events").duplicate(true)
	events.append_array(ConditionalCatalog.policy_events().filter( func(event: Dictionary) -> bool: return ConditionalCatalog.eligible(event)))
	var event: Dictionary = events[GameState.rng.randi_range(0, events.size() - 1)].duplicate(true)
	GameState.game_data.get_or_add("government_history", []).append({"round": round_index, "event": event})
	var result: = apply_event(event)
	GameState.game_data.battle_ledger.append({"round": round_index, "category": "event", "player_id": "system", "title": str(event.get("name", "城市政策事件")), "details": event.merged({"impact_receipt": result}, true)})
	return event


static func apply_event(event: Dictionary, context: = {}) -> Dictionary:
	var outcomes: = _outcome_index()
	var result: = {"ok": true, "event_id": str(event.get("id", "")), "negative": is_negative_event(event), "duration": int(event.get("duration", 0)), "affected_land_ids": [], "player_outcomes": outcomes.values()}
	match str(event.effect):
		"land_value":
			result.merge(_apply_transport_plan(event, context), true)
		"suspend_tag":
			for business: Dictionary in GameState.game_data.businesses.values():
				if str(business.get("state", "")) in ["closed", "acquired", "auction"]:
					continue
				var business_type: = GameConfig.by_id("business_types", str(business.type_id))
				if business_type.get("tags", []).has(str(event.tag)):
					var owner: = GameState.player(str(business.owner_id))
					if not owner.is_empty() and CompanyRules.blocks_negative_event(owner, str(event.id), int(GameState.game_data.round)):
						_mark_outcome(outcomes, str(owner.id), "blocked", str(business.id), "财团能力抵消停业")
						continue
					business.effects.append({"kind": "suspended", "value": 1, "duration": int(event.duration)})
					if not owner.is_empty():
						_mark_outcome(outcomes, str(owner.id), "applied", str(business.id), "企业暂停经营%d回合" % int(event.duration))
		"risk_tag":
			var affected_players: Dictionary = {}
			for business: Dictionary in GameState.game_data.businesses.values():
				if str(business.get("state", "")) in ["closed", "acquired", "auction"]:
					continue
				var business_type: = GameConfig.by_id("business_types", str(business.type_id))
				if business_type.get("tags", []).has(str(event.tag)):
					var owner: = GameState.player(str(business.owner_id))
					if not owner.is_empty() and not affected_players.has(str(owner.id)):
						if CompanyRules.blocks_negative_event(owner, str(event.id), int(GameState.game_data.round)):
							affected_players[str(owner.id)] = true
							_mark_outcome(outcomes, str(owner.id), "blocked", str(business.id), "财团能力抵消风险上升")
							continue
						TimedEffects.add_temporary_risk(str(owner.id), int(event.value), int(event.duration), str(event.id))
						affected_players[str(owner.id)] = true
						_mark_outcome(outcomes, str(owner.id), "applied", str(business.id), "风险 +%d" % int(event.value))
		"acquisition":
			var acquisition: = _acquire_random_land(event)
			result.merge(acquisition, true)
			var owner_id: = str(acquisition.get("owner_id", ""))
			if not owner_id.is_empty():
				_mark_outcome(outcomes, owner_id, "blocked" if bool(acquisition.get("blocked", false)) else "applied", str(acquisition.get("land_id", "")), "征收已被抵消" if bool(acquisition.get("blocked", false)) else "地块被征收并完成补偿")
		_:
			return {"ok": false, "message": "未知政府事件效果", "event_id": str(event.get("id", ""))}
	result.player_outcomes = outcomes.values()
	return result


static func is_negative_event(event: Dictionary) -> bool:
	match str(event.get("effect", "")):
		"suspend_tag", "risk_tag", "acquisition": return true
		"land_value": return float(event.get("value", 0.0)) < 0.0
	return false


static func validate_event_contracts() -> Dictionary:
	var supported: = ["land_value", "suspend_tag", "risk_tag", "acquisition"]
	var errors: Array[String] = []
	var catalog: = GameConfig.list("government_events").duplicate(true);catalog.append_array(ConditionalCatalog.policy_events())
	for event: Dictionary in catalog:
		if str(event.get("effect", "")) not in supported:
			errors.append("%s has no handler" % str(event.get("id", "")))
		if not event.has("duration"):
			errors.append("%s has no duration" % str(event.get("id", "")))
	return {"ok": errors.is_empty(), "errors": errors}


static func _apply_transport_plan(event: Dictionary, context: Dictionary) -> Dictionary:
	var lands: Array = GameState.game_data.lands.values()
	if lands.is_empty():
		return {"ok": false, "message": "没有可规划地块", "affected_land_ids": []}
	var site_id: = str(context.get("site_land_id", ""))
	var site: Dictionary = GameState.game_data.lands.get(site_id, {})
	if site.is_empty():
		site = lands[GameState.rng.randi_range(0, lands.size() - 1)]
		site_id = str(site.id)
	var affected_land_ids: Array[String] = []
	var affected_districts: Dictionary = {}
	var site_anchor: = ParcelGeometry.anchor_of(site)
	for land: Dictionary in lands:
		var land_anchor: = ParcelGeometry.anchor_of(land)
		if land_anchor.distance_to(site_anchor) <= 8.1:
			affected_land_ids.append(str(land.id))
			affected_districts[str(land.district)] = true
	var heat_delta: = float(event.get("value", 0.0)) * 100.0
	for district_id: String in affected_districts:
		TimedEffects.add_district_effect(district_id, "heat_delta", heat_delta, int(event.duration), str(event.id))
	return {"ok": true, "event_id": str(event.id), "site_land_id": site_id, "affected_land_ids": affected_land_ids, "affected_district_ids": affected_districts.keys()}


static func _acquire_random_land(event: Dictionary) -> Dictionary:
	var owned: Array = GameState.game_data.lands.values().filter( func(land: Dictionary) -> bool:
		return (
			not str(land.owner_id).is_empty()
			and str(land.state) not in ["government_locked", "auction", "bank_disposal", "locked"]
			and not bool(land.get("transaction_locked", false))
		))
	if owned.is_empty():
		return {"ok": true, "skipped": true, "message": "没有可征收资产"}
	var land: Dictionary = owned[GameState.rng.randi_range(0, owned.size() - 1)]
	var old_owner_id: = str(land.owner_id)
	var protected_owner: = GameState.player(old_owner_id)
	var event_id: = str(event.get("id", "government_acquisition"))
	if not protected_owner.is_empty() and CompanyRules.blocks_negative_event(protected_owner, event_id, int(GameState.game_data.round)):
		GameState._record(old_owner_id, "company_event_guard", {"event_id": event_id, "land_id": str(land.id)})
		return {"ok": true, "blocked": true, "owner_id": old_owner_id, "land_id": str(land.id)}
	var land_compensation: = roundi(float(land.price) * GameState.rng.randf_range(float(event.min), float(event.max)))
	var business_id: = str(land.get("business_id", ""))
	var business_compensation: = 0
	if not business_id.is_empty() and GameState.game_data.businesses.has(business_id):
		var business: Dictionary = GameState.game_data.businesses[business_id]
		business_compensation = roundi(float(business.get("value", 0)) * 0.55)
	var gross_compensation: = land_compensation + business_compensation
	var mortgage_payoff: = Bank.settle_acquired_asset(old_owner_id, str(land.id), gross_compensation)
	var paid_to_owner: = maxi(0, gross_compensation - mortgage_payoff)
	if paid_to_owner > 0:
		GameState.apply_cash(old_owner_id, paid_to_owner, "政府征收补偿")
	if not business_id.is_empty() and GameState.game_data.businesses.has(business_id):
		_close_acquired_business(GameState.game_data.businesses[business_id], old_owner_id)
	var owner: = GameState.player(old_owner_id)
	if not owner.is_empty():
		owner.land_ids.erase(str(land.id))
	land.owner_id = ""
	land.state = "government_locked"
	land.business_id = ""
	land.mortgaged = false
	land.erase("previous_state")
	GameState._record("system", "government_acquisition", {
		"land_id": str(land.id), 
		"old_owner_id": old_owner_id, 
		"business_id": business_id, 
		"gross_compensation": gross_compensation, 
		"mortgage_payoff": mortgage_payoff, 
		"paid_to_owner": paid_to_owner
	})
	return {"ok": true, "blocked": false, "owner_id": old_owner_id, "land_id": str(land.id), "business_id": business_id, "gross_compensation": gross_compensation, "mortgage_payoff": mortgage_payoff, "paid_to_owner": paid_to_owner}


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


static func _close_acquired_business(business: Dictionary, old_owner_id: String) -> void :
	var owner: = GameState.player(old_owner_id)
	if not owner.is_empty():
		owner.business_ids.erase(str(business.id))
	business.owner_id = ""
	business.state = "acquired"
	business.mortgaged = false
	business.last_net = 0
	business.effects = []
