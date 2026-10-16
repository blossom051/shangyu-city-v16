extends Node

func snapshot() -> Dictionary:
	var p: = GameState.active_player(); if p.is_empty(): return {"steps": [], "recommended": ""}
	var steps: Array[Dictionary] = [
		{"id": "intel", "label": "查看情报", "done": _did("view_news") or int(GameState.game_data.round) > 1}, 
		{"id": "land_build", "label": "买地 / 建设", "done": int(p.actions.land) > 0 or int(p.actions.build) > 0}, 
		{"id": "support", "label": "人才 / 卡牌 / 证券 / 银行", "done": int(p.actions.card) > 0 or _did_any(["hire_talent", "stock_trade", "loan", "mortgage"])}, 
		{"id": "finish", "label": "确认结束回合", "done": false}
	]
	var recommended: = "news" if not steps[0].done else "land" if p.land_ids.is_empty() else "build" if int(p.actions.build) == 0 else "cards" if int(p.get("strategy_points", 0)) > 0 and not p.hand.is_empty() else "end_turn"
	return {"player": p.name, "round": int(GameState.game_data.round), "steps": steps, "recommended": recommended, "actions": {"land": -1, "build": -1, "card": maxi(0, int(p.get("strategy_points", 0)))}}
func unavailable_reason(action: String) -> String:
	var p: = GameState.active_player(); if p.is_empty(): return "当前没有可操作玩家"
	match action:
		"land":
			if int(p.cash) < 200: return "现金不足，先前往银行融资"
		"build":
			if p.land_ids.is_empty(): return "需要先购买一块土地"
		"cards":
			if p.hand.is_empty(): return "当前没有可用卡牌"
	return ""


func card_play_unavailable_reason() -> String:
	var p: = GameState.active_player()
	if p.is_empty(): return "当前没有可操作玩家"
	if int(p.get("strategy_points", 0)) <= 0: return "本回合策略点已用完；仍可查看、弃牌与兑换"
	return ""
func turn_summary() -> Dictionary:
	var p: = GameState.active_player(); var result: = {"buy_land": 0, "build_business": 0, "card": 0, "stock": 0, "loan": 0}
	if p.is_empty(): return result
	for entry: Dictionary in GameState.game_data.log:
		if int(entry.round) != int(GameState.game_data.round) or str(entry.player_id) != str(p.id): continue
		match str(entry.kind):
			"buy_land": result.buy_land += 1
			"build_business": result.build_business += 1
			"play_card": result.card += 1
			"stock_trade": result.stock += 1
			"loan", "mortgage": result.loan += 1
	return result
func ai_brief(player_id: String) -> Array[String]:
	var lines: Array[String] = []
	for entry: Dictionary in GameState.game_data.log:
		if int(entry.round) == int(GameState.game_data.round) and str(entry.player_id) == player_id: lines.append(_kind_label(str(entry.kind)))
	return lines.slice(maxi(0, lines.size() - 3))
func _did(kind: String) -> bool: return _did_any([kind])
func _did_any(kinds: Array) -> bool:
	var p: = GameState.active_player(); if p.is_empty(): return false
	return GameState.game_data.log.any( func(e: Dictionary) -> bool: return int(e.round) == int(GameState.game_data.round) and str(e.player_id) == str(p.id) and kinds.has(str(e.kind)))
func _kind_label(kind: String) -> String: return {"buy_land": "购入城市地块", "build_business": "启动企业建设", "play_card": "发动策略卡牌", "loan": "获得银行融资", "mortgage": "办理资产抵押", "stock_trade": "完成证券交易"}.get(kind, "调整经营策略")
