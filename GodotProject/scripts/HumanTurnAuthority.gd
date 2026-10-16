class_name HumanTurnAuthority
extends RefCounted


static func check(game_data: Dictionary, ai_sequence_running: = false) -> Dictionary:
	var verdict: = {
		"allowed": false, 
		"player_id": "", 
		"reason": "当前不是可操作的玩家回合", 
	}
	if ai_sequence_running:
		verdict.reason = "AI 财团正在执行行动"
		return verdict
	if str(game_data.get("phase", "")) != "player_turn":
		verdict.reason = "当前正在结算，不能执行经营操作"
		return verdict
	var order: Array = game_data.get("turn_order", [])
	var index: = int(game_data.get("active_order_index", -1))
	if index < 0 or index >= order.size():
		verdict.reason = "当前席位无效，正在恢复回合流程"
		return verdict
	var player_id: = str(order[index])
	verdict.player_id = player_id
	for player: Dictionary in game_data.get("players", []):
		if str(player.get("id", "")) != player_id:
			continue
		if not bool(player.get("human", false)):
			verdict.reason = "%s由 AI 自动经营" % str(player.get("name", "该财团"))
			return verdict
		if bool(player.get("eliminated", false)):
			verdict.reason = "该玩家已退出本局"
			return verdict
		verdict.allowed = true
		verdict.reason = ""
		return verdict
	verdict.reason = "找不到当前回合席位"
	return verdict


static func can_open_turn_modal(game_data: Dictionary, ai_sequence_running: = false) -> bool:
	return bool(check(game_data, ai_sequence_running).get("allowed", false))
