class_name RoundDecisionSystem
extends RefCounted

const Risks = preload("res://scripts/RiskSystem.gd")
const Cards = preload("res://scripts/CardEngine.gd")
const ConditionalCatalog = preload("res://scripts/ConditionalEventCatalog.gd")

const EVENTS: = [
	{
		"id": "night_market_inspection", "section": "城市经营", "title": "夜间经济联合检查", "brief": "热门商圈客流攀升，但安全与延时经营成本同时上升。", 
		"choices": [
			{"title": "升级安全系统", "tag": "稳健治理", "preview": "现金 -40万  风险 -8", "cash": -40, "risk": -8, "detail": "以一次性投入换取更稳定的经营环境。"}, 
			{"title": "延长营业时段", "tag": "抢占客流", "preview": "现金 +35万  风险 +7", "cash": 35, "risk": 7, "detail": "立刻获取夜间收入，但舆情和运营压力上升。"}, 
			{"title": "联合街区共治", "tag": "中期收益", "preview": "现金 -15万  风险 -2  两轮收入 +6%", "cash": -15, "risk": -2, "effect": {"kind": "all_income_multiplier", "value": 1.06, "duration": 2}, "detail": "小额投入换取两轮经营协同。"}, 
		]
	}, 
	{
		"id": "supply_chain_choice", "section": "供应链", "title": "核心供应商临时调价", "brief": "企业可锁价、切换渠道，或接受短期波动。", 
		"choices": [
			{"title": "提前锁定采购", "tag": "成本确定", "preview": "现金 -30万  风险 -5", "cash": -30, "risk": -5, "detail": "用现金换取供应稳定。"}, 
			{"title": "启用替代渠道", "tag": "灵活采购", "preview": "现金 -10万  风险 +2  两轮收入 +4%", "cash": -10, "risk": 2, "effect": {"kind": "all_income_multiplier", "value": 1.04, "duration": 2}, "detail": "保留增长空间，但执行风险略有上升。"}, 
			{"title": "维持现有合同", "tag": "承受波动", "preview": "现金 +20万  风险 +6", "cash": 20, "risk": 6, "detail": "保住当期现金，承担后续不确定性。"}, 
		]
	}, 
	{
		"id": "brand_public_opinion", "section": "品牌舆情", "title": "品牌话题突然登上热榜", "brief": "关注度带来流量，也放大了经营瑕疵。", 
		"choices": [
			{"title": "公开透明回应", "tag": "声誉修复", "preview": "现金 -20万  风险 -7", "cash": -20, "risk": -7, "detail": "主动沟通，降低持续舆情风险。"}, 
			{"title": "顺势投放营销", "tag": "流量变现", "preview": "现金 +45万  风险 +8", "cash": 45, "risk": 8, "detail": "将热度快速转为收入。"}, 
			{"title": "邀请专家背书", "tag": "稳中求进", "preview": "现金 -10万  风险 -3  获得 1 张牌", "cash": -10, "risk": -3, "draw": 1, "detail": "用专业意见稳定局势并获得策略资源。"}, 
		]
	}, 
	{
		"id": "talent_retention", "section": "人才经营", "title": "核心团队收到外部邀约", "brief": "本轮需要在留才、激励和成本之间作出选择。", 
		"choices": [
			{"title": "启动长期激励", "tag": "稳定团队", "preview": "现金 -35万  风险 -6  两轮收入 +5%", "cash": -35, "risk": -6, "effect": {"kind": "all_income_multiplier", "value": 1.05, "duration": 2}, "detail": "提高组织稳定性与执行效率。"}, 
			{"title": "发放即时奖金", "tag": "快速留才", "preview": "现金 -20万  风险 -3", "cash": -20, "risk": -3, "detail": "快速解决问题，不形成长期负担。"}, 
			{"title": "优化团队结构", "tag": "控制成本", "preview": "现金 +25万  风险 +5", "cash": 25, "risk": 5, "detail": "降低当期成本，但团队压力上升。"}, 
		]
	}, 
	{
		"id": "green_upgrade", "section": "城市政策", "title": "绿色经营升级窗口开放", "brief": "城市提供有限补贴，企业需决定升级力度。", 
		"choices": [
			{"title": "全面绿色改造", "tag": "长期价值", "preview": "现金 -45万  风险 -9  两轮收入 +7%", "cash": -45, "risk": -9, "effect": {"kind": "all_income_multiplier", "value": 1.07, "duration": 2}, "detail": "投入最大，风险与经营效率改善最明显。"}, 
			{"title": "申请基础补贴", "tag": "平衡方案", "preview": "现金 +15万  风险 -2", "cash": 15, "risk": -2, "detail": "获得补贴并完成基础升级。"}, 
			{"title": "暂缓改造", "tag": "保留现金", "preview": "现金 +30万  风险 +6", "cash": 30, "risk": 6, "detail": "本轮资金更充裕，但政策风险上升。"}, 
		]
	}, 
]


static func initialize_match(round_limit: int) -> void :
	if round_limit <= 0 or bool(GameState.game_data.get("endless", false)):
		GameState.game_data["round_decision_schedule"] = []
		GameState.game_data["round_decision_event_ids"] = {}
		GameState.game_data["round_decision_events_triggered"] = []
		_extend_endless_schedule(int(GameState.game_data.get("round", 1)))
		return
	var event_count: = 2 if round_limit <= 10 else 3 if round_limit <= 16 else 4
	var schedule: Array[int] = []
	var earliest: = 2
	var latest: = maxi(earliest, round_limit - 1)
	for index in event_count:
		var center: = roundi(float(index + 1) * float(round_limit) / float(event_count + 1))
		var candidate: = clampi(center + GameState.rng.randi_range(-1, 1), earliest, latest)
		while schedule.has(candidate) and candidate < latest:
			candidate += 1
		while schedule.has(candidate) and candidate > earliest:
			candidate -= 1
		if not schedule.has(candidate):
			schedule.append(candidate)
	schedule.sort()
	var event_pool: Array = EVENTS.duplicate(true)
	event_pool.append_array(ConditionalCatalog.decision_events().filter( func(event: Dictionary) -> bool: return ConditionalCatalog.eligible(event)))
	_shuffle(event_pool)
	var event_ids: = {}
	for index in schedule.size():
		event_ids[str(schedule[index])] = str((event_pool[index % event_pool.size()] as Dictionary).id)
	GameState.game_data["round_decision_schedule"] = schedule
	GameState.game_data["round_decision_event_ids"] = event_ids
	GameState.game_data["round_decision_events_triggered"] = []


static func event_rounds() -> Array:
	_ensure_schedule()
	return GameState.game_data.get("round_decision_schedule", []).duplicate()


static func next_event_round(after_round: = -1) -> int:
	_ensure_schedule()
	var current: = int(GameState.game_data.get("round", 0)) if after_round < 0 else int(after_round)
	var triggered: Array = GameState.game_data.get("round_decision_events_triggered", [])
	for value: Variant in GameState.game_data.get("round_decision_schedule", []):
		if int(value) > current and not triggered.has(int(value)):
			return int(value)
	return -1


static func generate_round(forced_event_ids: = []) -> Array:
	GameState.game_data["round_decision_offers"] = {}
	GameState.game_data.get_or_add("round_decision_history", [])
	var round_number: = int(GameState.game_data.get("round", 0))
	_ensure_schedule()
	var event: Dictionary = {}
	if not forced_event_ids.is_empty():
		event = _event_by_id(str(forced_event_ids[0]))
	else:
		var schedule: Array = GameState.game_data.get("round_decision_schedule", [])
		var triggered: Array = GameState.game_data.get_or_add("round_decision_events_triggered", [])
		if not schedule.has(round_number) or triggered.has(round_number):
			return []
		var event_id: = str(GameState.game_data.get("round_decision_event_ids", {}).get(str(round_number), ""))
		event = _event_by_id(event_id)
		if event.is_empty():
			event = EVENTS[GameState.rng.randi_range(0, EVENTS.size() - 1)].duplicate(true)
		triggered.append(round_number)
	if event.is_empty():
		return []
	var created: Array = []
	for player: Dictionary in GameState.game_data.get("players", []):
		if bool(player.get("eliminated", false)):
			continue
		var offer: = event.duplicate(true)
		offer["event_id"] = str(event.id)
		offer["round"] = round_number
		offer["player_id"] = str(player.id)
		GameState.game_data.round_decision_offers[str(player.id)] = offer
		created.append(offer.duplicate(true))
		if not bool(player.get("human", false)):
			resolve(str(player.id), _ai_choice_index(offer, player))
	return created


static func pending(player_id: String) -> Dictionary:
	return GameState.game_data.get("round_decision_offers", {}).get(player_id, {}).duplicate(true)


static func resolve(player_id: String, choice_index: int) -> Dictionary:
	var offers: Dictionary = GameState.game_data.get("round_decision_offers", {})
	var offer: Dictionary = offers.get(player_id, {})
	if offer.is_empty():
		return {"ok": false, "message": "本回合没有待处理的经营抉择"}
	var choices: Array = offer.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return {"ok": false, "message": "经营抉择选项无效"}
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {"ok": false, "message": "玩家不存在"}
	var choice: Dictionary = choices[choice_index]
	var cash_delta: = int(choice.get("cash", 0))
	if cash_delta < 0 and GameState.available_cash(player_id) < abs(cash_delta):
		return {"ok": false, "message": "可用现金不足，无法执行该方案"}
	var cash_before: = int(player.cash)
	var risk_before: = int(player.risk)
	if cash_delta != 0:
		GameState.apply_cash(player_id, cash_delta, "经营抉择：%s" % str(choice.title))
	var risk_delta: = int(choice.get("risk", 0))
	if risk_delta != 0:
		Risks.adjust(player_id, risk_delta, str(choice.title), "随机经营事件")
	if choice.has("effect"):
		var effect: Dictionary = choice.effect.duplicate(true)
		effect["source"] = str(offer.event_id)
		player.get_or_add("effects", []).append(effect)
	if int(choice.get("draw", 0)) > 0:
		Cards.draw_cards(player_id, int(choice.draw))
	offers.erase(player_id)
	var result: = {
		"ok": true, "event_id": str(offer.event_id), "event_title": str(offer.title), "choice_index": choice_index, 
		"choice_title": str(choice.title), "cash_before": cash_before, "cash_after": int(player.cash), 
		"cash_delta": int(player.cash) - cash_before, "risk_before": risk_before, "risk_after": int(player.risk), 
		"risk_delta": int(player.risk) - risk_before, "message": "已执行：%s" % str(choice.title), 
	}
	GameState.game_data.round_decision_history.append({"round": int(GameState.game_data.round), "player_id": player_id, "result": result.duplicate(true)})
	GameState.game_data.battle_ledger.append({"round": int(GameState.game_data.round), "category": "event", "player_id": player_id, "title": "%s  %s" % [str(offer.title), str(choice.title)], "details": result.duplicate(true)})
	GameState._record(player_id, "round_decision", result.duplicate(true))
	return result


static func _event_by_id(event_id: String) -> Dictionary:
	for event: Dictionary in EVENTS:
		if str(event.id) == event_id:
			return event.duplicate(true)
	for event: Dictionary in ConditionalCatalog.decision_events():
		if str(event.get("id", "")) == event_id and ConditionalCatalog.eligible(event):
			return event.duplicate(true)
	return {}


static func _ai_choice_index(offer: Dictionary, player: Dictionary) -> int:
	var best_index: = 0
	var best_score: = - INF
	var choices: Array = offer.get("choices", [])
	for index in choices.size():
		var choice: Dictionary = choices[index]
		if int(choice.get("cash", 0)) < 0 and int(player.get("cash", 0)) < abs(int(choice.cash)):
			continue
		var score: = float(choice.get("cash", 0)) - float(choice.get("risk", 0)) * 5.0
		if choice.has("effect"):
			score += 24.0
		if score > best_score:
			best_score = score
			best_index = index
	return best_index


static func _ensure_schedule() -> void :
	if GameState.game_data.get("round_decision_schedule", []).is_empty():
		initialize_match(int(GameState.game_data.get("round_limit", 10)))
	if bool(GameState.game_data.get("endless", false)):
		_extend_endless_schedule(int(GameState.game_data.get("round", 1)))


static func _extend_endless_schedule(from_round: int) -> void:
	var schedule: Array = GameState.game_data.get_or_add("round_decision_schedule", [])
	var event_ids: Dictionary = GameState.game_data.get_or_add("round_decision_event_ids", {})
	var last_round := from_round
	if not schedule.is_empty():
		last_round = int(schedule.max())
	var horizon := from_round + 24
	var event_pool: Array = EVENTS.duplicate(true)
	event_pool.append_array(ConditionalCatalog.decision_events().filter(func(event: Dictionary) -> bool: return ConditionalCatalog.eligible(event)))
	if event_pool.is_empty():
		return
	var previous_id := str(event_ids.get(str(last_round), ""))
	while last_round < horizon:
		last_round += GameState.rng.randi_range(2, 4)
		var candidates := event_pool.filter(func(event: Dictionary) -> bool: return str(event.get("id", "")) != previous_id)
		if candidates.is_empty(): candidates = event_pool
		var selected: Dictionary = candidates[GameState.rng.randi_range(0, candidates.size() - 1)]
		schedule.append(last_round)
		previous_id = str(selected.get("id", ""))
		event_ids[str(last_round)] = previous_id
	schedule.sort()


static func _shuffle(values: Array) -> void :
	for index in range(values.size() - 1, 0, -1):
		var other: = GameState.rng.randi_range(0, index)
		var item: Variant = values[index]
		values[index] = values[other]
		values[other] = item
