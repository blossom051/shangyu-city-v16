class_name TalentSystem
extends RefCounted

const Regions = preload("res://scripts/RegionalEconomySystem.gd")

const MatchRandom = preload("res://scripts/RandomSource.gd")

const ROSTER_LIMIT: = 12


static func roster_limit(player_id: = "") -> int:
	var player: = GameState.player(player_id) if not player_id.is_empty() else {}
	return ROSTER_LIMIT + int(player.get("talent_capacity_bonus", 0))


static func capacity_summary(player_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	var used: int = player.get("talent_ids", []).size() if not player.is_empty() else 0
	var limit: = roster_limit(player_id)
	return {"used": used, "limit": limit, "free": maxi(0, limit - used), "over_limit": used > limit}


static func grant_starter(player_id: String) -> String:
	var player: = GameState.player(player_id)
	if player.is_empty() or int(capacity_summary(player_id).free) <= 0:
		return ""
	var candidates: = GameConfig.list("talents").filter( func(t: Dictionary) -> bool: return str(t.quality) == "blue")
	var talent: Dictionary = candidates[GameState.rng.randi_range(0, candidates.size() - 1)]
	if not player.talent_ids.has(str(talent.id)):
		player.talent_ids.append(str(talent.id))
	GameState._record(player_id, "starter_talent", {"talent_id": str(talent.id)})
	return str(talent.id)


static func draw_quote(player_id: String, count: int) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty() or count not in [1, 5]:
		return {"ok": false, "code": "invalid", "message": "人才抽取参数无效", "cash": 0, "cost": 0, "shortfall": 0}
	var cost: = _draw_cost(player, count)
	var cash: = int(player.get("cash", 0))
	var pending: Array = player.get("pending_talents", [])
	if not pending.is_empty():
		return {"ok": false, "code": "pending", "message": "请先处理本次抽到的人才，再继续抽取。", "cash": cash, "cost": cost, "shortfall": maxi(0, cost - cash), "pending_count": pending.size()}
	if cash < cost:
		return {"ok": false, "code": "insufficient_funds", "message": "资金不足", "cash": cash, "cost": cost, "shortfall": cost - cash, "pending_count": 0}
	return {"ok": true, "code": "ready", "message": "可以抽取", "cash": cash, "cost": cost, "shortfall": 0, "pending_count": 0}


static func draw(player_id: String, count: int) -> Dictionary:
	var tutorial_route: Dictionary = TutorialDirector.route_action("talent_draw", {"player_id": player_id, "count": count})
	if bool(tutorial_route.get("handled", false)):
		return tutorial_route
	var player: = GameState.player(player_id)
	var quote: = draw_quote(player_id, count)
	if not bool(quote.get("ok", false)):
		quote["cards"] = []
		return quote
	var cost: = int(quote.cost)
	GameState.apply_cash(player_id, - cost, "人才侦察")
	var results: Array = []
	var drawn_ids: Dictionary = {}
	for i in count:
		var quality: = _roll_quality()
		var pool: = GameConfig.list("talents").filter( func(t: Dictionary) -> bool: return str(t.quality) == quality)
		var available: = pool.filter( func(t: Dictionary) -> bool: return not drawn_ids.has(str(t.id)))
		if available.is_empty():
			available = pool
		var talent: Dictionary = available[GameState.rng.randi_range(0, available.size() - 1)]
		drawn_ids[str(talent.id)] = true
		results.append(talent.duplicate(true))
	var pending: Array = player.get_or_add("pending_talents", [])
	for talent: Dictionary in results:
		pending.append(str(talent.id))
	GameState._record(player_id, "talent_draw", {"count": count, "results": results.map( func(t: Dictionary) -> String: return str(t.id))})
	return {"ok": true, "message": "人才卡已翻开", "cards": results}

static func resolve(player_id: String, talent_id: String, keep: bool) -> Dictionary:
	var tutorial_route: Dictionary = TutorialDirector.route_action("talent_resolve", {"player_id": player_id, "talent_id": talent_id, "keep": keep})
	if bool(tutorial_route.get("handled", false)):
		return tutorial_route
	var player: = GameState.player(player_id)
	var talent: = GameConfig.by_id("talents", talent_id)
	if player.is_empty() or talent.is_empty():
		return {"ok": false, "message": "人才无效"}
	var pending: Array = player.get_or_add("pending_talents", [])
	if not pending.has(talent_id):
		return {"ok": false, "message": "该人才不在待处理抽取队列中"}
	var quality: = str(talent.quality)
	var balance: = GameConfig.dict_value("balance")
	if keep:
		if not player.talent_ids.has(talent_id) and int(capacity_summary(player_id).free) <= 0:
			return {
				"ok": false, 
				"code": "capacity_full", 
				"message": "员工编制已满（%d/%d），候选人已保留；请先在员工管理中辞退一人" % [player.talent_ids.size(), roster_limit(player_id)], 
				"requires_roster_management": true, 
				"used": player.talent_ids.size(), 
				"limit": roster_limit(player_id), 
			}
		pending.erase(talent_id)
		if not player.talent_ids.has(talent_id):
			player.talent_ids.append(talent_id)
		player.red_points = int(player.red_points) + int(balance.red_points_draw.get(quality, 0))
	else:
		pending.erase(talent_id)
		player.red_points = int(player.red_points) + int(balance.red_points_convert.get(quality, 0))
	GameState._record(player_id, "talent_resolve", {"talent_id": talent_id, "keep": keep, "points": int(player.red_points)})
	return {"ok": true, "message": "已保留招募，抽取费用已包含" if keep else "已转换为红卡积分"}


static func resolve_all(player_id: String, keep: bool) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {"ok": false, "message": "玩家无效", "resolved": 0}
	var pending: Array = player.get_or_add("pending_talents", [])
	if pending.is_empty():
		return {"ok": false, "message": "没有待处理人才", "resolved": 0}
	var required_slots: = 0
	if keep:
		var unique_new: Dictionary = {}
		for talent_id: String in pending:
			if not player.talent_ids.has(talent_id):
				unique_new[talent_id] = true
		required_slots = unique_new.size()
		var free_slots: = int(capacity_summary(player_id).free)
		if required_slots > free_slots:
			return {
				"ok": false, 
				"code": "capacity_full", 
				"message": "已有 %d/%d 人，还需 %d 个空位，请先撤岗并裁员" % [player.talent_ids.size(), roster_limit(player_id), required_slots - free_slots], 
				"resolved": 0, 
				"required_slots": required_slots, 
				"requires_roster_management": true, 
			}
	var before_points: = int(player.red_points)
	var pending_copy: = pending.duplicate()
	var resolved: = 0
	for talent_id: String in pending_copy:
		var result: = resolve(player_id, talent_id, keep)
		if bool(result.get("ok", false)):
			resolved += 1
	return {
		"ok": resolved == pending_copy.size(), 
		"message": "已一键招募 %d 人" % resolved if keep else "已一键转化 %d 人，获得 %d 积分" % [resolved, int(player.red_points) - before_points], 
		"resolved": resolved, 
		"points_gained": int(player.red_points) - before_points, 
	}

static func red_choices(player_id: String) -> Array:
	var player: = GameState.player(player_id)
	if player.is_empty() or int(player.red_points) < 100:
		return []
	var reds: = GameConfig.list("talents").filter( func(t: Dictionary) -> bool: return str(t.quality) == "red")
	MatchRandom.shuffle_in_place(reds)
	return reds.slice(0, mini(3, reds.size()))


static func choose_red(player_id: String, talent_id: String, offered_ids: Array) -> bool:
	var player: = GameState.player(player_id)
	if player.is_empty() or int(player.red_points) < 100 or not offered_ids.has(talent_id):
		return false
	if not player.talent_ids.has(talent_id) and int(capacity_summary(player_id).free) <= 0:
		return false
	player.red_points = int(player.red_points) - 100
	if not player.talent_ids.has(talent_id):
		player.talent_ids.append(talent_id)
	GameState._record(player_id, "red_talent_choice", {"talent_id": talent_id})
	return true


static func roster(player_id: String) -> Array[Dictionary]:
	var player: = GameState.player(player_id)
	var result: Array[Dictionary] = []
	if player.is_empty():
		return result
	for talent_id: String in player.get("talent_ids", []):
		var talent: = GameConfig.by_id("talents", talent_id)
		if talent.is_empty():
			continue
		var assignment: = ""
		var assignment_id: = ""
		var assignment_slot: = -1
		for business_id: String in player.get("business_ids", []):
			var business: Dictionary = GameState.game_data.businesses.get(business_id, {})
			if business.get("employees", []).has(talent_id):
				assignment = str(business.get("name", business_id))
				assignment_id = business_id
				assignment_slot = business.get("employees", []).find(talent_id)
				break
		result.append({
			"id": talent_id, 
			"name": str(talent.get("name", talent_id)), 
			"role": str(talent.get("role", "经营")), 
			"quality": str(talent.get("quality", "blue")), 
			"quality_name": quality_name(str(talent.get("quality", "blue"))), 
			"quality_color": quality_color(str(talent.get("quality", "blue"))).to_html(false), 
			"tier_rank": quality_rank(str(talent.get("quality", "blue"))), 
			"effect_text": str(talent.get("effect", "")), 
			"skill_family": _skill_family(str(talent.get("stat", "income"))), 
			"status": "idle" if assignment.is_empty() else "assigned", 
			"status_text": "空闲  可安排" if assignment.is_empty() else "已安排  %s" % assignment, 
			"assignment": assignment, 
			"assignment_id": assignment_id, 
			"assignment_slot": assignment_slot, 
			"dismissal_cost": dismissal_cost(talent_id), 
		})
	return result


static func business_contribution(player_id: String, business: Dictionary, type: Dictionary, income: float, cost: float) -> Dictionary:
	var employees: Array[Dictionary] = []
	var income_bonus: = 0.0
	var cost_saving: = 0.0
	var disabled: = 0
	for effect: Dictionary in business.get("effects", []):
		if str(effect.get("kind", "")) == "disable_employee":
			disabled += int(effect.get("value", 0))
	var slot: = 0
	for talent_id: String in business.get("employees", []):
		if talent_id.is_empty():
			slot += 1
			continue
		var talent: = GameConfig.by_id("talents", talent_id)
		if talent.is_empty():
			slot += 1
			continue
		var quality: = str(talent.get("quality", "blue"))
		var stat: = str(talent.get("stat", "income"))
		var value: = float(talent.get("value", 0.0))
		var land: Dictionary = GameState.game_data.get("lands", {}).get(str(business.get("land_id", "")), {})
		var regional_fit: = Regions.talent_fit_multiplier(talent, str(land.get("district", "")))
		var active: = slot >= disabled
		var employee_income: = 0.0
		var employee_saving: = 0.0
		var contribution_text: = "本轮被干扰，技能暂未生效"
		if active:
			match stat:
				"income":
					employee_income = income * value
					contribution_text = "直接增收 %d 万" % roundi(employee_income)
				"cost":
					employee_saving = cost * value
					contribution_text = "节省成本 %d 万" % roundi(employee_saving)
				"supply":
					employee_income = income * value if type.get("tags", []).has("supply") else income * value * 0.3
					contribution_text = "供应协同增益 %d 万" % roundi(employee_income)
				"build":
					employee_income = income * value * 0.055
					contribution_text = "流程效率增益 %d 万" % roundi(employee_income)
				"risk":
					employee_income = income * value * 0.42
					contribution_text = "风险控制保住 %d 万" % roundi(employee_income)
				"interest":
					employee_income = income * value * 0.3
					contribution_text = "财务结构增益 %d 万，另降低贷款利息" % roundi(employee_income)
				"pr":
					employee_income = income * value * 0.38
					contribution_text = "口碑转化增收 %d 万" % roundi(employee_income)
				"invest":
					employee_income = income * value * 0.32
					contribution_text = "资本运营增益 %d 万，另提升创投成功率" % roundi(employee_income)
				"guard":
					employee_income = income * value * 0.24
					contribution_text = "组织稳定增益 %d 万" % roundi(employee_income)
				"guard_once":
					employee_income = income * 0.18
					contribution_text = "红色守护增益 %d 万，并保留首次必定抵消" % roundi(employee_income)
				"spy":
					employee_income = income * value * 0.34
					contribution_text = "竞争情报增益 %d 万" % roundi(employee_income)
				_:
					employee_income = income * value * 0.2
					contribution_text = "专业能力增益 %d 万" % roundi(employee_income)
			employee_income *= regional_fit
			employee_saving *= regional_fit
		income_bonus += employee_income
		cost_saving += employee_saving
		employees.append({
			"id": talent_id, 
			"name": str(talent.get("name", talent_id)), 
			"role": str(talent.get("role", "经营")), 
			"quality": quality, 
			"quality_name": quality_name(quality), 
			"quality_color": quality_color(quality).to_html(false), 
			"tier_rank": quality_rank(quality), 
			"skill_family": _skill_family(stat), 
			"effect_text": str(talent.get("effect", "")), 
			"regional_fit_multiplier": regional_fit, 
			"active": active, 
			"income_bonus": roundi(employee_income), 
			"cost_saving": roundi(employee_saving), 
			"total_value": roundi(employee_income + employee_saving), 
			"contribution_text": contribution_text, 
		})
		slot += 1
	return {
		"player_id": player_id, 
		"business_id": str(business.get("id", "")), 
		"income_bonus": roundi(income_bonus), 
		"cost_saving": roundi(cost_saving), 
		"total_value": roundi(income_bonus + cost_saving), 
		"employees": employees, 
	}


static func assigned_interest_discount(player_id: String) -> float:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return 0.0
	var discount: = 0.0
	for business_id: String in player.get("business_ids", []):
		var business: Dictionary = GameState.game_data.get("businesses", {}).get(business_id, {})
		if str(business.get("state", "")) not in ["operating", "loss_watch", "mortgaged"]:
			continue
		for talent_id: String in business.get("employees", []):
			var talent: = GameConfig.by_id("talents", talent_id)
			if str(talent.get("stat", "")) == "interest":
				discount += float(talent.get("value", 0.0))
	return clampf(discount, 0.0, 0.3)


static func complaint_quote(player_id: String, business: Dictionary, type: Dictionary, operating_income: float, roll: float = -1.0) -> Dictionary:
	var player := GameState.player(player_id)
	if player.is_empty() or business.is_empty():
		return {"occurred": false, "loss": 0, "raw_loss": 0, "reduction": 0, "chance": 0.0}
	var sector := str(type.get("sector", ""))
	var sensitivity := float({"consumer": 0.11, "entertainment": 0.13, "medical": 0.12, "property": 0.07, "logistics": 0.06}.get(sector, 0.045))
	var chance := clampf(sensitivity + float(player.get("risk", 0)) * 0.0015 + float(business.get("consecutive_loss", 0)) * 0.025, 0.03, 0.32)
	var actual_roll := GameState.rng.randf() if roll < 0.0 else roll
	if actual_roll >= chance:
		return {"occurred": false, "loss": 0, "raw_loss": 0, "reduction": 0, "chance": chance, "sector": sector}
	var reduction_rate := 0.0
	var reducers: Array[String] = []
	for talent_id: String in business.get("employees", []):
		var talent := GameConfig.by_id("talents", talent_id)
		if str(talent.get("stat", "")) == "pr":
			reduction_rate += float(talent.get("value", 0.0))
			reducers.append(str(talent.get("name", talent_id)))
	reduction_rate = clampf(reduction_rate, 0.0, 0.65)
	var raw_loss := maxi(6, roundi(operating_income * (0.10 + sensitivity * 0.45)))
	var loss := maxi(0, roundi(float(raw_loss) * (1.0 - reduction_rate)))
	return {"occurred": true, "loss": loss, "raw_loss": raw_loss, "reduction": raw_loss - loss, "reduction_rate": reduction_rate, "chance": chance, "sector": sector, "reducers": reducers}


static func quality_name(quality: String) -> String:
	return {"blue": "蓝色", "platinum": "铂金", "gold": "金色", "red": "红色"}.get(quality, quality)


static func quality_color(quality: String) -> Color:
	return {
		"blue": Color("3f8fc4"), 
		"platinum": Color("a9bec8"), 
		"gold": Color("d8a93d"), 
		"red": Color("dc4f57"), 
	}.get(quality, Color.WHITE)


static func quality_rank(quality: String) -> int:
	return int({"blue": 1, "platinum": 2, "gold": 3, "red": 4}.get(quality, 1))


static func dismissal_cost(talent_id: String) -> int:
	var quality: = str(GameConfig.by_id("talents", talent_id).get("quality", "blue"))
	return int({"blue": 15, "platinum": 25, "gold": 40, "red": 70}.get(quality, 15))


static func dismiss(player_id: String, talent_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty() or not player.get("talent_ids", []).has(talent_id):
		return {"ok": false, "message": "未拥有该员工"}
	for business_id: String in player.get("business_ids", []):
		var business: Dictionary = GameState.game_data.businesses.get(business_id, {})
		if business.get("employees", []).has(talent_id):
			return {"ok": false, "message": "请先将员工从%s撤回待岗" % str(business.get("name", business_id))}
	var cost: = dismissal_cost(talent_id)
	if int(player.cash) < cost:
		return {"ok": false, "message": "现金不足，开除需支付%d万离职补偿" % cost}
	GameState.apply_cash(player_id, - cost, "员工离职补偿")
	player.talent_ids.erase(talent_id)
	player.talent_reputation_penalty_rounds = maxi(2, int(player.get("talent_reputation_penalty_rounds", 0)))
	player.talent_hiring_surcharge = 10
	GameState._record(player_id, "dismiss_talent", {"talent_id": talent_id, "severance": cost, "recruitment_penalty_rounds": 2})
	return {"ok": true, "message": "已开除员工并支付%d万补偿；未来2回合招聘每人加价10万" % cost, "severance": cost}


static func _roll_quality() -> String:
	var roll: = GameState.rng.randf()
	if roll < 0.03:
		return "red"
	if roll < 0.15:
		return "gold"
	if roll < 0.4:
		return "platinum"
	return "blue"


static func _draw_cost(player: Dictionary, count: int) -> int:
	var balance: = GameConfig.dict_value("balance")
	var draw_cost: Dictionary = balance.get("talent_draw_cost", {"single": 60, "five": 270})
	var cost: = int(draw_cost.get("single", 60)) if count == 1 else int(draw_cost.get("five", 270))
	if int(player.get("talent_reputation_penalty_rounds", 0)) > 0:
		cost += int(player.get("talent_hiring_surcharge", 10)) * count
	if player.get("effects", []).any( func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "talent_discount"):
		cost = roundi(float(cost) * 0.5)
	return cost


static func _skill_family(stat: String) -> String:
	return {
		"income": "增长", 
		"cost": "效率", 
		"supply": "供应链", 
		"build": "流程", 
		"risk": "风控", 
		"interest": "财务", 
		"pr": "口碑", 
		"invest": "资本", 
		"guard": "守护", 
		"guard_once": "红色守护", 
		"spy": "竞争情报", 
	}.get(stat, "经营")
