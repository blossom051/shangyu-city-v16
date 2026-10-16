class_name ConstructionProgressService
extends RefCounted

const MAX_EVENT_DELAY_ROUNDS := 2


static func initialize_project(business: Dictionary, start_round: int, base_rounds: int) -> void:
	var safe_base := maxi(1, base_rounds)
	business.construction_started_round = maxi(1, start_round)
	business.construction_base_rounds = safe_base
	business.construction_elapsed_rounds = 0
	business.construction_delay_rounds = 0
	business.construction_due_round = int(business.construction_started_round) + safe_base - 1
	business.construction_hard_deadline = int(business.construction_due_round) + MAX_EVENT_DELAY_ROUNDS
	business.construction_event_ids = []
	business.remaining_rounds = safe_base


static func ensure_project(business: Dictionary, current_round: int, fallback_base_rounds: int = 0) -> void:
	if business.has("construction_hard_deadline"):
		return
	var configured_base := fallback_base_rounds
	if configured_base <= 0:
		var business_type := GameConfig.by_id("business_types", str(business.get("type_id", "")))
		configured_base = int(business_type.get("build_rounds", business.get("remaining_rounds", 1)))
	var safe_base := maxi(1, configured_base)
	var legacy_remaining := maxi(0, int(business.get("remaining_rounds", safe_base)))
	var migrated_remaining := mini(legacy_remaining, safe_base + MAX_EVENT_DELAY_ROUNDS)
	var migrated_delay := mini(MAX_EVENT_DELAY_ROUNDS, maxi(0, migrated_remaining - safe_base))
	business.construction_started_round = maxi(1, current_round)
	business.construction_base_rounds = safe_base
	business.construction_elapsed_rounds = 0
	business.construction_delay_rounds = migrated_delay
	business.construction_due_round = int(business.construction_started_round) + maxi(0, migrated_remaining - 1)
	business.construction_hard_deadline = int(business.construction_started_round) + maxi(0, migrated_remaining - 1)
	business.construction_event_ids = []
	business.remaining_rounds = migrated_remaining


static func apply_delta(business: Dictionary, delta: int, event_id: String, current_round: int) -> Dictionary:
	ensure_project(business, current_round)
	if delta == 0 or int(business.get("remaining_rounds", 0)) <= 0:
		return {"applied": 0, "remaining_rounds": int(business.get("remaining_rounds", 0))}
	var event_key := "%s@%d" % [event_id, current_round]
	var applied_events: Array = business.get("construction_event_ids", [])
	if not event_id.is_empty() and applied_events.has(event_key):
		return {"applied": 0, "remaining_rounds": int(business.remaining_rounds), "duplicate": true}
	if not event_id.is_empty():
		applied_events.append(event_key)
		business.construction_event_ids = applied_events
	var applied := delta
	if delta > 0:
		var available_delay := maxi(0, MAX_EVENT_DELAY_ROUNDS - int(business.get("construction_delay_rounds", 0)))
		applied = mini(delta, available_delay)
		business.construction_delay_rounds = int(business.get("construction_delay_rounds", 0)) + applied
	else:
		applied = -mini(-delta, int(business.get("remaining_rounds", 0)))
	business.remaining_rounds = maxi(0, int(business.get("remaining_rounds", 0)) + applied)
	return {"applied": applied, "remaining_rounds": int(business.remaining_rounds)}


static func advance(business: Dictionary, current_round: int, paused: bool = false) -> bool:
	ensure_project(business, current_round)
	if int(business.get("remaining_rounds", 0)) <= 0:
		return true
	if not paused:
		business.remaining_rounds = maxi(0, int(business.remaining_rounds) - 1)
		business.construction_elapsed_rounds = int(business.get("construction_elapsed_rounds", 0)) + 1
	if current_round >= int(business.get("construction_hard_deadline", current_round)):
		business.remaining_rounds = 0
	return int(business.remaining_rounds) <= 0


static func complete_now(business: Dictionary) -> void:
	business.remaining_rounds = 0


static func progress_snapshot(business: Dictionary, current_round: int) -> Dictionary:
	ensure_project(business, current_round)
	var base := maxi(1, int(business.get("construction_base_rounds", 1)))
	var remaining := maxi(0, int(business.get("remaining_rounds", 0)))
	return {
		"base_rounds": base,
		"remaining_rounds": remaining,
		"completed_rounds": maxi(0, base - mini(base, remaining)),
		"delay_rounds": int(business.get("construction_delay_rounds", 0)),
		"hard_deadline": int(business.get("construction_hard_deadline", current_round)),
	}
