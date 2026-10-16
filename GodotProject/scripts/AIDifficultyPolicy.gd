class_name AIDifficultyPolicy
extends RefCounted

const CASUAL := "casual"
const STANDARD := "standard"
const HARD := "hard"

static func normalize(value: String) -> String:
	return value if value in [CASUAL, STANDARD, HARD] else STANDARD

static func current() -> String:
	return normalize(str(GameState.game_data.get("ai_difficulty", STANDARD)))

static func label(value: String) -> String:
	return {CASUAL: "休闲", STANDARD: "标准", HARD: "困难"}.get(normalize(value), "标准")

static func should_pass(player_id: String, stage: String) -> bool:
	if current() != CASUAL or stage not in ["land", "build", "card", "stock", "listed_stock", "startup", "ipo"]:
		return false
	var key := "%s|%s|%d|%d" % [player_id, stage, int(GameState.game_data.get("round", 0)), int(GameState.game_data.get("seed", 0))]
	return int(abs(hash(key)) % 100) < 22

static func score(candidate: Dictionary, player_id: String) -> float:
	var base := float(candidate.get("score", 0.0))
	if current() != HARD:
		return base
	var parts: Dictionary = candidate.get("breakdown", {})
	var cash := float(GameState.available_cash(player_id))
	var debt := float(GameState.player(player_id).get("debt", 0))
	var safety_weight := 0.28 if cash < 300.0 or debt > cash else 0.10
	return base + float(parts.get("expected_return", 0.0)) * 0.27 + float(parts.get("target_threat", 0.0)) * 0.22 + float(parts.get("cash_safety", 0.0)) * safety_weight + float(parts.get("opportunity_cost", 0.0)) * 0.15

static func pick_index(candidate_count: int, player_id: String, stage_key: String) -> int:
	if current() != CASUAL or candidate_count < 2:
		return 0
	var key := "%s|%s|%d|%d" % [player_id, stage_key, int(GameState.game_data.get("round", 0)), int(GameState.game_data.get("seed", 0))]
	return 1 if int(abs(hash(key)) % 100) < 45 else 0
