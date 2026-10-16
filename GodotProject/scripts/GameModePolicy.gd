class_name GameModePolicy

const SOLO: = "solo"
const VERSUS_AI: = "ai"
const LOCAL_MULTI: = "multi"


static func normalize_mode(value: String) -> String:
	if value in [SOLO, VERSUS_AI, LOCAL_MULTI]:
		return value
	return SOLO


static func normalized_player_count(mode: String, requested: int) -> int:
	match normalize_mode(mode):
		SOLO:
			return 1
		VERSUS_AI, LOCAL_MULTI:
			return clampi(requested, 2, 8)
	return 1


static func is_human_seat(mode: String, seat_index: int) -> bool:
	match normalize_mode(mode):
		SOLO, VERSUS_AI:
			return seat_index == 0
		LOCAL_MULTI:
			return true
	return false


static func build_roster(
	mode: String, 
	human_pick: Dictionary, 
	requested_count: int, 
	companies: Array
) -> Array[Dictionary]:
	var normalized: = normalize_mode(mode)
	var count: = normalized_player_count(normalized, requested_count)
	var roster: Array[Dictionary] = [{
		"company_id": str(human_pick.get("company_id", "")), 
		"human": true, 
		"custom_name": str(human_pick.get("custom_name", "")), 
	}]
	if normalized != VERSUS_AI:
		return roster
	var used: Array[String] = [str(human_pick.get("company_id", ""))]
	for company: Variant in companies:
		if roster.size() >= count:
			break
		if not company is Dictionary:
			continue
		var company_id: = str((company as Dictionary).get("id", ""))
		if company_id.is_empty() or used.has(company_id):
			continue
		used.append(company_id)
		roster.append({"company_id": company_id, "human": false})
	return roster


static func label(mode: String) -> String:
	return {
		SOLO: "单人经营", 
		VERSUS_AI: "人机对战", 
		LOCAL_MULTI: "本地多人", 
	}.get(normalize_mode(mode), "单人经营")
