class_name CityNewsModel
extends RefCounted


const PRIVATE_TERMS: = ["现金", "负债", "贷款", "逾期", "征信", "风险分", "净资产", "排名"]


static func build_issue() -> Dictionary:
	var current_round: = int(GameState.game_data.get("round", 0))
	var district_pulse: = _district_pulse()
	var city: = _city_counts()
	var mobility: = _mobility_pulse()
	var issue: = {
		"round": current_round, 
		"edition": "第 %02d 期" % current_round, 
		"date_line": "城市经营纪元  第 %d 回合" % current_round, 
		"public_metrics": [
			{"label": "城市平均热度", "value": "%.0f" % float(district_pulse.get("average", 100.0)), "trend": str(district_pulse.get("average_trend", "持平"))}, 
			{"label": "在营企业", "value": "%d 家" % int(city.operating), "trend": "建设中 %d 家" % int(city.constructing)}, 
			{"label": "活跃客流", "value": "%d 条" % int(mobility.routes), "trend": "平均强度 %.2f" % float(mobility.average_strength)}, 
			{"label": "待售土地", "value": "%d 块" % int(city.available_land), "trend": "在拍 %d 宗" % int(city.auctions)}, 
		], 
		"pulse": district_pulse.get("districts", []), 
		"stories": _stories(district_pulse, city, mobility), 
		"schedule": _public_schedule(), 
		"watch_list": _watch_list(district_pulse, city, mobility), 
	}
	GameState.game_data["city_news_issue"] = issue.duplicate(true)
	var archive: Array = GameState.game_data.get_or_add("city_news_public_history", [])
	var replaced: = false
	for index in archive.size():
		if int((archive[index] as Dictionary).get("round", -1)) == current_round:
			archive[index] = issue.duplicate(true)
			replaced = true
			break
	if not replaced:
		archive.append(issue.duplicate(true))
	return issue


static func privacy_audit(issue: Dictionary) -> Dictionary:
	var text: = JSON.stringify(issue)
	var matches: Array[String] = []
	for term: String in PRIVATE_TERMS:
		if text.contains(term):
			matches.append(term)
	for player: Dictionary in GameState.game_data.get("players", []):
		var player_name: = str(player.get("name", "")).strip_edges()
		if not player_name.is_empty() and text.contains(player_name):
			matches.append("玩家名:%s" % player_name)
	return {"ok": matches.is_empty(), "matches": matches}


static func _stories(district_pulse: Dictionary, city: Dictionary, mobility: Dictionary) -> Array[Dictionary]:
	var stories: Array[Dictionary] = []
	var hottest: Dictionary = district_pulse.get("hottest", {})
	var coolest: Dictionary = district_pulse.get("coolest", {})
	stories.append({
		"section": "头版", "tone": "hot", "headline": "%s成为本轮城市消费焦点" % str(hottest.get("name", "核心商圈")), 
		"summary": "商圈热度达到 %.0f，较上期%s。城市客流正向活跃街区重新聚集。" % [float(hottest.get("heat", 100.0)), _signed_points(float(hottest.get("delta", 0.0)))], 
		"signal": "热度越高，沿线企业获得的公共客流机会越多。", "watch": "同时留意 %s 的低位变化。" % str(coolest.get("name", "外围街区")), 
	})
	stories.append({
		"section": "城市交通", "tone": "cool", "headline": "%d 条客流路线重绘城市动线" % int(mobility.routes), 
		"summary": "%s 当前最活跃，路线强度 %.2f；全城平均强度 %.2f。" % [str(mobility.top_name), float(mobility.top_strength), float(mobility.average_strength)], 
		"signal": "路线强度来自两端商圈热度和本轮公共事件。", "watch": "关注路线两端的经营与建设变化。", 
	})
	stories.append({
		"section": "产业观察", "tone": "business", "headline": "城市已有 %d 家企业投入经营" % int(city.operating), 
		"summary": "另有 %d 家处于建设期，%d 个产业门类已经进入城市版图。" % [int(city.constructing), int(city.sectors)], 
		"signal": "新企业完工后会改变商圈供给和下一轮客流分配。", "watch": "建设密集街区可能成为下一期热点。", 
	})
	stories.append({
		"section": "土地市场", "tone": "property", "headline": "%d 块城市土地仍等待开发" % int(city.available_land), 
		"summary": "拍卖中心现有 %d 宗公开资产，下一次城市专场%s。" % [int(city.auctions), _auction_schedule_text()], 
		"signal": "低价专场由真实赛程随机生成，空地和处置资产都可能入场。", "watch": "报纸只公布公共排期，不披露任何财团底价。", 
	})
	stories.append(_talent_story())
	stories.append(_event_story())
	var decision_story: = _decision_recap_story()
	if not decision_story.is_empty():
		stories.append(decision_story)
	var market_story: = _market_story()
	if not market_story.is_empty():
		stories.append(market_story)
	return stories


static func _district_pulse() -> Dictionary:
	var current: Array[Dictionary] = []
	var previous: = _previous_district_values()
	var total: = 0.0
	var previous_total: = 0.0
	for district: Dictionary in GameState.game_data.get("districts", {}).values():
		var district_id: = str(district.get("id", district.get("district_id", "")))
		var heat: = float(district.get("heat", 100.0))
		var old_heat: = float(previous.get(district_id, heat))
		current.append({"id": district_id, "name": str(district.get("name", district.get("district_name", "城市街区"))), "heat": heat, "delta": heat - old_heat})
		total += heat
		previous_total += old_heat
	current.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return float(a.heat) > float(b.heat))
	var count: = maxi(1, current.size())
	var average: = total / float(count)
	var previous_average: = previous_total / float(count)
	return {
		"districts": current, 
		"hottest": current[0] if not current.is_empty() else {}, 
		"coolest": current[-1] if not current.is_empty() else {}, 
		"average": average, 
		"average_trend": _trend_label(average - previous_average), 
	}


static func _previous_district_values() -> Dictionary:
	var history: Array = GameState.game_data.get("city_news_public_history", [])
	var current_round: = int(GameState.game_data.get("round", 0))
	var previous_issue: Dictionary = {}
	for index in range(history.size() - 1, -1, -1):
		var candidate: Dictionary = history[index]
		if int(candidate.get("round", -1)) < current_round:
			previous_issue = candidate
			break
	if previous_issue.is_empty():
		return {}
	var values: = {}
	for item: Dictionary in previous_issue.get("pulse", []):
		values[str(item.get("id", ""))] = float(item.get("heat", 100.0))
	return values


static func _city_counts() -> Dictionary:
	var available: = 0
	for land: Dictionary in GameState.game_data.get("lands", {}).values():
		if str(land.get("state", "")) == "available":
			available += 1
	var operating: = 0
	var constructing: = 0
	var sectors: = {}
	for business: Dictionary in GameState.game_data.get("businesses", {}).values():
		var state: = str(business.get("state", ""))
		if state == "operating":
			operating += 1
		elif state == "constructing":
			constructing += 1
		var business_type: = GameConfig.by_id("business_types", str(business.get("type_id", "")))
		var sector: = str(business_type.get("sector", ""))
		if not sector.is_empty():
			sectors[sector] = true
	return {"available_land": available, "operating": operating, "constructing": constructing, "sectors": sectors.size(), "auctions": GameState.game_data.get("auctions", []).size()}


static func _mobility_pulse() -> Dictionary:
	var routes: Array = GameState.game_data.get("traffic_routes", [])
	var top_name: = "城市环线"
	var top_strength: = 0.0
	var total: = 0.0
	for route: Dictionary in routes:
		var strength: = float(route.get("strength", 1.0))
		total += strength
		if strength > top_strength:
			top_strength = strength
			top_name = str(route.get("name", "城市环线"))
	return {"routes": routes.size(), "top_name": top_name, "top_strength": top_strength, "average_strength": total / float(routes.size()) if not routes.is_empty() else 0.0}


static func _talent_story() -> Dictionary:
	var total: = 0
	var assigned: = 0
	var rare: = 0
	for player: Dictionary in GameState.game_data.get("players", []):
		total += player.get("talent_ids", []).size()
		for talent_id: String in player.get("talent_ids", []):
			var talent: = GameConfig.by_id("talents", talent_id)
			if str(talent.get("quality", "")) in ["gold", "red"]:
				rare += 1
	for business: Dictionary in GameState.game_data.get("businesses", {}).values():
		assigned += business.get("employee_ids", business.get("talent_ids", [])).size()
	return {
		"section": "人才流动", "tone": "talent", "headline": "城市人才库录得 %d 份有效签约" % total, 
		"summary": "其中金色与红色稀有人才共 %d 位，已安排到企业的岗位共 %d 个。" % [rare, assigned], 
		"signal": "只有实际上岗的人才才会进入企业经营贡献。", "watch": "人才结构变化会影响城市产业效率。", 
	}


static func _event_story() -> Dictionary:
	var active: Array = GameState.game_data.get("active_events", [])
	if active.is_empty():
		return {"section": "公共事件", "tone": "neutral", "headline": "城市运行维持常态窗口", "summary": "本轮暂无额外城市环境冲击，各系统按基础规则运行。", "signal": "商圈、客流和产业仍会随真实经营行为变化。", "watch": "留意下一轮公共日程。"}
	var event: Dictionary = active[0]
	return {"section": "公共事件", "tone": "event", "headline": str(event.get("headline", event.get("name", "城市公共事件生效"))), "summary": str(event.get("description", event.get("brief", "事件已进入本轮城市运行。"))), "signal": "该事件已经写入商圈、产业或市场的真实计算。", "watch": "影响持续 %d 回合。" % int(event.get("duration", 1))}


static func _decision_recap_story() -> Dictionary:
	var history: Array = GameState.game_data.get("round_decision_history", [])
	if history.is_empty():
		return {}
	var latest_round: = int((history[-1] as Dictionary).get("round", -1))
	var grouped: = {}
	var title: = "城市经营抉择出现分化"
	for entry: Dictionary in history:
		if int(entry.get("round", -2)) != latest_round:
			continue
		var result: Dictionary = entry.get("result", {})
		title = str(result.get("event_title", title))
		var choice_title: = str(result.get("choice_title", "其他方案"))
		grouped[choice_title] = int(grouped.get(choice_title, 0)) + 1
	var fragments: Array[String] = []
	for choice_title: String in grouped:
		fragments.append("%s %d 组" % [choice_title, int(grouped[choice_title])])
	return {"section": "经营抉择", "tone": "decision", "headline": "%s完成城市回应" % title, "summary": "各方案选择：%s。" % "；".join(fragments), "signal": "每组选择已分别生效，报纸仅公布公共数量。", "watch": "后续影响将在经营与城市指标中逐步显现。"}


static func _market_story() -> Dictionary:
	var stories: Array = GameState.game_data.get("news", [])
	for item: Dictionary in stories:
		var tags: Array = item.get("tags", [])
		if str(item.get("id", "")).begins_with("market_observation") or tags.has("市场观察") or bool(item.get("suspension_signal", false)):
			return {"section": "市场观察", "tone": "market", "headline": str(item.get("title", "市场出现异常交易线索")), "summary": "公开信息显示相关板块可能进入短暂停牌观察。", "signal": "线索只提示方向，不直接公布复牌结果。", "watch": "停牌结束后可能出现明显波动。"}
	return {}


static func _public_schedule() -> Array[Dictionary]:
	var current: = int(GameState.game_data.get("round", 0))
	var result: Array[Dictionary] = []
	var auction_round: = _next_round(GameState.game_data.get("auction_schedule", []), current)
	var decision_round: = _next_round(GameState.game_data.get("round_decision_schedule", []), current)
	result.append({"label": "城市拍卖", "value": "本局暂无后续专场" if auction_round < 0 else "第 %d 回合" % auction_round})
	result.append({"label": "经营抉择", "value": "本局事件已结束" if decision_round < 0 else "第 %d 回合" % decision_round})
	result.append({"label": "创投窗口", "value": _next_startup_text(current)})
	return result


static func _watch_list(district_pulse: Dictionary, city: Dictionary, mobility: Dictionary) -> Array[String]:
	var third: = "%d 块待售土地、%d 家建设中企业" % [int(city.available_land), int(city.constructing)]
	var decision_recap: = _decision_recap_story()
	if not decision_recap.is_empty():
		third = "经营抉择：%s" % str(decision_recap.get("headline", "各组完成回应"))
	elif not GameState.game_data.get("active_events", []).is_empty():
		var event: Dictionary = GameState.game_data.get("active_events", [])[0]
		third = "公共事件：%s" % str(event.get("headline", event.get("name", "城市环境变化")))
	return [
		"%s热度 %.0f，居全城首位" % [str((district_pulse.get("hottest", {}) as Dictionary).get("name", "核心商圈")), float((district_pulse.get("hottest", {}) as Dictionary).get("heat", 100.0))], 
		"%s以 %.2f 成为最强客流线" % [str(mobility.top_name), float(mobility.top_strength)], 
		third, 
	]


static func _next_round(values: Array, current: int) -> int:
	for value: Variant in values:
		if int(value) >= current:
			return int(value)
	return -1


static func _auction_schedule_text() -> String:
	var value: = _next_round(GameState.game_data.get("auction_schedule", []), int(GameState.game_data.get("round", 0)))
	return "本局暂无后续安排" if value < 0 else "排在第 %d 回合" % value


static func _next_startup_text(current: int) -> String:
	var value: = _next_round(GameState.game_data.get("startup_schedule", []), current)
	return "本局窗口已结束" if value < 0 else "第 %d 回合" % value


static func _trend_label(delta: float) -> String:
	if delta > 0.5:
		return "上行 %.1f" % delta
	if delta < -0.5:
		return "回落 %.1f" % absf(delta)
	return "基本持平"


static func _signed_points(delta: float) -> String:
	if absf(delta) < 0.05:
		return "基本持平"
	return "上升 %.1f 点" % delta if delta > 0.0 else "回落 %.1f 点" % absf(delta)
