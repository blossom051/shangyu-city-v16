class_name CityFeedbackSystem
extends RefCounted

static var GameState:
	get: return Engine.get_main_loop().root.get_node("/root/GameState")

const MAJOR_ACTIONS: = ["buy_land", "auction_won", "build_business", "play_card", "direct_loan", "startup_invest", "bankruptcy"]


static func initialize() -> void :
	GameState.game_data.city_visual_state = {}
	GameState.game_data.competition_feed = []
	GameState.game_data.city_feedback = []
	for land: Dictionary in GameState.game_data.get("lands", {}).values():
		GameState.game_data.city_visual_state[str(land.id)] = _visual_for_land(land)


static func ensure_state() -> void :
	if not GameState.game_data.has("city_visual_state"):
		initialize()
	GameState.game_data.get_or_add("competition_feed", [])
	GameState.game_data.get_or_add("city_feedback", [])


static func observe_action(player_id: String, kind: String, data: Dictionary) -> void :
	ensure_state()
	if not kind in ["buy_land", "auction_won", "build_business", "assign_talent", "play_card", "direct_loan", "loan_repaid", "stock_trade", "startup_invest", "round_settlement", "risk_changed", "bankruptcy"]:
		return
	var entry: = _entry(player_id, kind, data)
	GameState.game_data.city_feedback.append(entry)
	if GameState.game_data.city_feedback.size() > 80:
		GameState.game_data.city_feedback.pop_front()
	var actor: Dictionary = GameState.player(player_id)
	if not actor.is_empty() and not bool(actor.get("human", false)):
		GameState.game_data.competition_feed.append(entry)
		if GameState.game_data.competition_feed.size() > 40:
			GameState.game_data.competition_feed.pop_front()
	var land_id: = str(data.get("land_id", ""))
	if land_id.is_empty() and not str(data.get("business_id", "")).is_empty():
		land_id = str(GameState.game_data.get("businesses", {}).get(str(data.business_id), {}).get("land_id", ""))
	if not land_id.is_empty() and GameState.game_data.lands.has(land_id):
		var visual: = _visual_for_land(GameState.game_data.lands[land_id])
		visual.pulse = kind
		visual.pulse_round = int(GameState.game_data.get("round", 0))
		GameState.game_data.city_visual_state[land_id] = visual


static func finalize_round(report: Dictionary) -> void :
	ensure_state()
	for land: Dictionary in GameState.game_data.get("lands", {}).values():
		GameState.game_data.city_visual_state[str(land.id)] = _visual_for_land(land)
	for player_id: String in report.get("players", {}):
		var item: Dictionary = report.players[player_id]
		if int(item.get("rank_change", 0)) != 0:
			var kind: = "rank_up" if int(item.rank_change) > 0 else "rank_down"
			GameState.game_data.city_feedback.append(_entry(player_id, kind, item))


static func visual_for_land(land_id: String) -> Dictionary:
	ensure_state()
	return GameState.game_data.city_visual_state.get(land_id, {}).duplicate(true)


static func feed(limit: = 8, competition_only: = true) -> Array:
	ensure_state()
	var source: Array = GameState.game_data.competition_feed if competition_only else GameState.game_data.city_feedback
	var result: = source.slice(maxi(0, source.size() - limit))
	result.reverse()
	return result


static func _entry(player_id: String, kind: String, data: Dictionary) -> Dictionary:
	var player: Dictionary = GameState.player(player_id)
	var name: = str(player.get("name", "城市市场"))
	var land_id: = str(data.get("land_id", ""))
	var land: Dictionary = GameState.game_data.get("lands", {}).get(land_id, {})
	var title: = "城市状态发生变化"
	match kind:
		"buy_land", "auction_won": title = "%s取得%s %s" % [name, str(land.get("district_name", "城市地块")), land_id]
		"build_business": title = "%s在%s启动企业建设" % [name, str(land.get("district_name", "城市"))]
		"assign_talent": title = "%s完成关键人才配置" % name
		"play_card": title = "%s发动策略卡：%s" % [name, str(data.get("result", "竞争行动"))]
		"direct_loan": title = "%s新增贷款 %d 万" % [name, int(data.get("amount", 0))]
		"loan_repaid": title = "%s偿还贷款 %d 万" % [name, int(data.get("paid", data.get("amount", 0)))]
		"stock_trade": title = "%s%s%s板块" % [name, "买入" if bool(data.get("buy", false)) else "卖出", str(data.get("stock_id", "证券"))]
		"startup_invest": title = "%s投资创业项目" % name
		"rank_up": title = "%s资本排名上升" % name
		"rank_down": title = "%s资本排名下降" % name
		"risk_changed": title = "%s风险状态变化" % name
		"bankruptcy": title = "%s进入破产处置" % name
	return {"round": int(GameState.game_data.get("round", 0)), "player_id": player_id, "kind": kind, "title": title, "major": kind in MAJOR_ACTIONS, "land_id": land_id, "district_id": str(land.get("district", data.get("district_id", ""))), "details": data.duplicate(true)}


static func _visual_for_land(land: Dictionary) -> Dictionary:
	var owner_id: = str(land.get("owner_id", ""))
	var owner: Dictionary = GameState.player(owner_id)
	var business: Dictionary = GameState.game_data.get("businesses", {}).get(str(land.get("business_id", "")), {})
	var total_rounds: = maxi(1, int(business.get("build_rounds", business.get("remaining_rounds", 1))))
	var progress: = 0.0
	if str(land.get("state", "")) == "constructing":
		progress = 1.0 - float(business.get("remaining_rounds", total_rounds)) / float(total_rounds)
	elif str(land.get("state", "")) in ["operating", "loss_watch", "mortgaged"]:
		progress = 1.0
	return {"owner_id": owner_id, "owner_color": str(owner.get("color", "#6A7B88")), "owner_name": str(owner.get("name", "待售")), "state": str(land.get("state", "available")), "construction_progress": clampf(progress, 0.0, 1.0), "business_id": str(land.get("business_id", "")), "business_level": int(business.get("level", 1)), "risk_warning": str(land.get("state", "")) == "loss_watch"}
