class_name WestBankInstitutionSystem
extends RefCounted

const Businesses = preload("res://scripts/BusinessSystem.gd")

const PROFILES := {
	"AuroraSpire": {
		"name": "曙光宏观塔", "role": "周期研判与风险对冲", "accent": "67d8e5", "layout": "macro", "icon": "◉", "scene_region": [0, 0, 836, 470], "brief": "捕捉周期拐点，把不确定性转化为经营窗口。",
		"options": [
			{"id": "macro_brief", "name": "订阅宏观晨报", "cost": 30, "cooldown": 3, "effect": "风险 -4，确认固定轮动的下一阶段与预计切换回合"},
			{"id": "policy_hedge", "name": "建立政策对冲", "cost": 60, "cooldown": 4, "effect": "风险 -8，适合高风险阶段"},
		],
	},
	"HarborTwin": {
		"name": "港湾路演双塔", "role": "机构沟通与上市预热", "accent": "8bb8ff", "layout": "roadshow", "icon": "◈", "scene_region": [836, 0, 836, 470], "brief": "用披露质量换取机构信任，但公开承诺也会形成压力。",
		"options": [
			{"id": "institution_roadshow", "name": "机构路演", "cost": 50, "cooldown": 4, "effect": "未上市：审核通过率 +6%；已上市：信心 +9、风险 +2"},
			{"id": "investor_day", "name": "投资者开放日", "cost": 35, "cooldown": 3, "effect": "已上市：信心 +5、披露缺口 -3%；未上市：风险 -3"},
		],
	},
	"TerraceHQ": {
		"name": "星汇财富俱乐部", "role": "周期策略与限时资产挑战", "accent": "b69af1", "layout": "club", "icon": "✦", "scene_region": [0, 470, 836, 471], "brief": "在策略桌上选择防守、进取或人脉，每局都有不同代价。",
		"options": [
			{"id": "wealth_defensive", "name": "稳健资产局", "cost": 30, "cooldown": 3, "effect": "顺应周期配置防守资产：稳定回款并降低风险"},
			{"id": "wealth_growth", "name": "进取主题局", "cost": 50, "cooldown": 3, "effect": "押注当前主题：上行时胜率更高，成功高回报，失败不返投入"},
			{"id": "wealth_salon", "name": "企业家闭门会", "cost": 25, "cooldown": 2, "effect": "获得经营机会；上市企业提升市场信心，未上市企业获得订单"},
		],
	},
	"PearlFinance": {
		"name": "明珠财富大厦", "role": "流动性储备与资产防线", "accent": "e8c56b", "layout": "liquidity", "icon": "⬡", "scene_region": [836, 470, 836, 471], "brief": "现金救急与财务安全不可兼得，选择会进入真实风险账本。",
		"options": [
			{"id": "liquidity_facility", "name": "启用流动性额度", "cost": 0, "cooldown": 6, "effect": "现金 +180 万，风险 +9；以风险换取周转"},
			{"id": "debt_buffer", "name": "建立偿债缓冲", "cost": 90, "cooldown": 5, "effect": "风险 -12，并提高财务安全边际"},
		],
	},
}


static func profile(landmark_id: String) -> Dictionary:
	return (PROFILES.get(landmark_id, {}) as Dictionary).duplicate(true)


static func eligibility(player_id: String) -> Dictionary:
	return Businesses.premium_land_eligibility(player_id)


static func state_for(player_id: String, landmark_id: String) -> Dictionary:
	var all_states: Dictionary = GameState.game_data.get_or_add("west_bank_institutions", {})
	var player_states: Dictionary = all_states.get_or_add(player_id, {})
	var state: Dictionary = player_states.get_or_add(landmark_id, {"last_round": -99, "last_option": ""})
	return state


static func cooldown_left(player_id: String, landmark_id: String, option: Dictionary) -> int:
	var state := state_for(player_id, landmark_id)
	return maxi(0, int(option.get("cooldown", 0)) - (int(GameState.game_data.get("round", 0)) - int(state.get("last_round", -99))))


static func execute(player_id: String, landmark_id: String, option_id: String) -> Dictionary:
	var access := eligibility(player_id)
	if not bool(access.get("ok", false)):
		return {
			"ok": false,
			"message": "尚未解锁西岸地标机构：%s" % str(access.get("message", "资格不足")),
			"eligibility": access,
		}
	var player := GameState.player(player_id)
	var profile_value := profile(landmark_id)
	if player.is_empty() or profile_value.is_empty():
		return {"ok": false, "message": "机构服务暂不可用"}
	var option: Dictionary = {}
	for candidate: Dictionary in profile_value.get("options", []):
		if str(candidate.get("id", "")) == option_id:
			option = candidate
			break
	if option.is_empty():
		return {"ok": false, "message": "未知机构服务"}
	var remaining := cooldown_left(player_id, landmark_id, option)
	if remaining > 0:
		return {"ok": false, "message": "机构团队还需 %d 回合完成上一项目" % remaining}
	var cost := int(option.get("cost", 0))
	if int(player.get("cash", 0)) < cost:
		return {"ok": false, "message": "需要 %d 万现金" % cost}
	if cost > 0:
		GameState.apply_cash(player_id, -cost, str(option.get("name", "西岸机构服务")))
	var changes := {"cash_change": -cost, "risk_change": 0, "confidence_change": 0}
	var message := "服务已经执行"
	var record: Dictionary = GameState.game_data.get("ipo_records", {}).get(player_id, {})
	match option_id:
		"macro_brief":
			player.risk = maxi(0, int(player.get("risk", 0)) - 4); changes.risk_change = -4
			var index := (int(EndlessOperationsSystem.current_cycle().get("index", 0)) + 1) % EndlessOperationsSystem.CYCLE_PHASES.size()
			message = "研判完成：第 %d 回合后预计进入%s期" % [int(EndlessOperationsSystem.current_cycle().get("ends_round", 0)), str(EndlessOperationsSystem.CYCLE_PHASES[index].name)]
		"policy_hedge":
			player.risk = maxi(0, int(player.get("risk", 0)) - 8); changes.risk_change = -8
			message = "政策对冲已建立，本组风险下降 8"
		"institution_roadshow":
			if str(record.get("status", "")) == "listed":
				record.market_confidence = mini(100, int(record.get("market_confidence", 60)) + 9)
				player.risk = mini(100, int(player.get("risk", 0)) + 2); changes.confidence_change = 9; changes.risk_change = 2
				message = "路演获得机构关注，信心 +9；但承诺压力令风险 +2"
			else:
				player.ipo_roadshow_bonus = maxf(float(player.get("ipo_roadshow_bonus", 0.0)), 0.06)
				message = "上市预热完成：下一次审核通过率 +6%"
		"investor_day":
			if str(record.get("status", "")) == "listed":
				record.market_confidence = mini(100, int(record.get("market_confidence", 60)) + 5)
				record.disclosure_gap = maxf(0.0, float(record.get("disclosure_gap", 0.0)) - 0.03); changes.confidence_change = 5
				message = "投资者开放日完成，信心 +5、披露风险下降"
			else:
				player.risk = maxi(0, int(player.get("risk", 0)) - 3); changes.risk_change = -3
				message = "公开沟通提升准备度，风险 -3"
		"wealth_defensive":
			var defensive_return := 72 if str(EndlessOperationsSystem.current_cycle().get("phase", "")) in ["adjustment", "recovery"] else 55
			GameState.apply_cash(player_id, defensive_return, "财富俱乐部稳健资产局")
			player.risk = maxi(0, int(player.get("risk", 0)) - 4)
			changes.cash_change += defensive_return; changes.risk_change = -4
			message = "稳健局完成：净回款 %+d 万、风险 -4（%s期防守配置）" % [int(changes.cash_change), str(EndlessOperationsSystem.current_cycle().get("name", "常态"))]
		"wealth_growth":
			var phase := str(EndlessOperationsSystem.current_cycle().get("phase", "recovery"))
			var success_chance := 0.72 if phase == "boom" else (0.58 if phase == "recovery" else (0.43 if phase == "overheat" else 0.36))
			var won := GameState.rng.randf() < success_chance
			player.risk = mini(100, int(player.get("risk", 0)) + (4 if won else 9)); changes.risk_change = 4 if won else 9
			if won:
				GameState.apply_cash(player_id, 165, "财富俱乐部进取主题局")
				changes.cash_change += 165
				message = "主题判断命中：净收益 %+d 万、风险 +4（命中率 %d%%）" % [int(changes.cash_change), roundi(success_chance * 100.0)]
			else:
				message = "主题判断落空：损失投入 %d 万、风险 +9（本期命中率 %d%%）" % [cost, roundi(success_chance * 100.0)]
		"wealth_salon":
			if str(record.get("status", "")) == "listed":
				record.market_confidence = mini(100, int(record.get("market_confidence", 60)) + 6); changes.confidence_change = 6
				message = "闭门会带来机构关注：市场信心 +6"
			else:
				GameState.apply_cash(player_id, 70, "财富俱乐部合作订单"); changes.cash_change += 70
				message = "闭门会促成联合订单：净回款 %+d 万" % int(changes.cash_change)
		"liquidity_facility":
			GameState.apply_cash(player_id, 180, "明珠财富流动性额度")
			player.risk = mini(100, int(player.get("risk", 0)) + 9); changes.cash_change = 180; changes.risk_change = 9
			message = "流动性额度到账 180 万，同时风险 +9"
		"debt_buffer":
			player.risk = maxi(0, int(player.get("risk", 0)) - 12); changes.risk_change = -12
			message = "偿债缓冲建立，风险 -12"
	var state := state_for(player_id, landmark_id)
	state.last_round = int(GameState.game_data.get("round", 0))
	state.last_option = option_id
	GameState._record(player_id, "west_bank_institution", {"landmark_id": landmark_id, "option_id": option_id, "changes": changes.duplicate(true), "message": message})
	return {"ok": true, "message": message, "changes": changes, "cooldown": int(option.get("cooldown", 0))}
