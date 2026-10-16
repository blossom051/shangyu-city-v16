class_name EndlessCheatSystem
extends RefCounted

const CHEAT_CODE := "money"
const CASH_REWARD_WAN := 10000


static func is_active(player_id: String) -> bool:
	if not EndlessOperationsSystem.is_enabled():
		return false
	var player := GameState.player(player_id)
	return not player.is_empty() and bool(player.get("endless_cheat", false))


static func activate(player_id: String, raw_code: String) -> Dictionary:
	if not EndlessOperationsSystem.is_enabled():
		return {"ok": false, "message": "作弊码仅在永续经营模式可用"}
	var player := GameState.player(player_id)
	if player.is_empty() or bool(player.get("eliminated", false)):
		return {"ok": false, "message": "当前财团不可启用作弊模式"}
	if raw_code.strip_edges().to_lower() != CHEAT_CODE:
		return {"ok": false, "message": "作弊码无效"}
	if bool(player.get("endless_cheat", false)):
		return {"ok": true, "already_active": true, "message": "无限权限已经启用"}
	player.endless_cheat = true
	player.cash = int(player.get("cash", 0)) + CASH_REWARD_WAN
	player.strategy_points_max = 999999
	player.strategy_points = 999999
	GameState._record(player_id, "endless_cheat_enabled", {"cash_reward": CASH_REWARD_WAN})
	GameState.changed.emit(GameState.snapshot())
	return {
		"ok": true,
		"cash_reward": CASH_REWARD_WAN,
		"message": "已获得 1 亿资金，并解除永续模式经营限制",
	}
