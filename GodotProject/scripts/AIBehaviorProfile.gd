class_name AIBehaviorProfile
extends RefCounted

static var GameState:
	get: return Engine.get_main_loop().root.get_node("/root/GameState")

const PROFILES: = {
	"hengyue": {"risk": "conservative", "focus": "operations"}, "qinghe": {"risk": "conservative", "focus": "livelihood"}, 
	"jinding": {"risk": "balanced", "focus": "finance"}, "qiming": {"risk": "balanced", "focus": "technology"}, 
	"yunshan": {"risk": "balanced", "focus": "cards"}, "xingchao": {"risk": "aggressive", "focus": "commercial"}, 
	"wangang": {"risk": "aggressive", "focus": "land"}, "chiyan": {"risk": "aggressive", "focus": "attack"}, 
}


static func for_player(player: Dictionary) -> Dictionary:
	return PROFILES.get(str(player.get("company_id", "")), {"risk": "balanced", "focus": "operations"}).duplicate(true)


static func score_adjustment(player: Dictionary, candidate: Dictionary) -> float:
	var profile: = for_player(player)
	var action: = str(candidate.get("action", ""))
	var breakdown: Dictionary = candidate.get("breakdown", {})
	var adjustment: = 0.0
	match str(profile.risk):
		"conservative":
			adjustment += float(breakdown.get("cash_safety", 0.0)) * 0.25 + float(breakdown.get("debt_pressure", 0.0)) * 0.2
			if action in ["borrow", "attack"]: adjustment -= 12.0
		"aggressive":
			adjustment += float(breakdown.get("expected_return", 0.0)) * 0.16
			if action in ["buy", "build", "attack", "play", "invest"]: adjustment += 8.0
		_:
			adjustment += float(breakdown.get("company_fit", 0.0)) * 0.1
	match str(profile.focus):
		"land":
			if action in ["buy", "bid"]: adjustment += 4.0
		"finance":
			if action in ["buy", "sell", "borrow"]: adjustment += 12.0
		"technology":
			if action in ["build", "draw", "recruit"]: adjustment += 10.0
		"cards", "attack":
			if action in ["play", "choose"]: adjustment += 12.0
		"commercial":
			if action in ["buy", "build"]: adjustment += 9.0
	return adjustment


static func land_reaction(player: Dictionary, land: Dictionary) -> float:
	var human_control: = 0.0
	for other: Dictionary in GameState.game_data.get("players", []):
		if bool(other.get("human", false)):
			human_control = maxf(human_control, float(other.get("district_influence", {}).get(str(land.get("district", "")), 0.0)))
	var risk: = str(for_player(player).risk)
	if human_control >= 0.5: return 22.0 if risk == "aggressive" else 10.0 if risk == "balanced" else -4.0
	if human_control >= 0.25: return 12.0 if risk == "aggressive" else 5.0
	return 0.0


static func validate() -> Dictionary:
	var risks: = {}
	var focuses: = {}
	for company_id: String in PROFILES:
		risks[str(PROFILES[company_id].risk)] = true;focuses[str(PROFILES[company_id].focus)] = true
	return {"ok": PROFILES.size() == 8 and risks.size() == 3 and focuses.size() >= 6, "companies": PROFILES.size(), "risk_preferences": risks.keys(), "focuses": focuses.keys()}
