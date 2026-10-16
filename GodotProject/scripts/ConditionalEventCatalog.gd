class_name ConditionalEventCatalog
extends RefCounted

static var GameState:
	get: return Engine.get_main_loop().root.get_node("/root/GameState")
static var GameConfig:
	get: return Engine.get_main_loop().root.get_node("/root/GameConfig")

const DECISION_NAMES: = ["债务评级沟通", "融资期限重组", "技术突破窗口", "专利许可谈判", "研发失败复盘", "核心人才争夺", "商圈监管问询", "反垄断承诺", "存量土地提效", "流动性冲击", "市场异动核查", "内幕消息辨伪", "声誉修复会议", "联盟联合施压", "供应链韧性改造"]
const NEWS_NAMES: = ["商业区客流连续回升", "科技企业研发投入扩张", "金融区资金净流入", "住宅服务需求趋稳", "滨水物流效率提升", "高负债企业融资承压", "消费类股票获资金关注", "科技类股票出现分化", "城市地价温和上行", "拍卖市场竞价升温", "人才市场运营岗位紧俏", "监管关注高占有率商圈", "创投项目退出窗口临近"]
const STARTUP_SPECS: = [
	["sp07", "智慧街区调度", "姜澜", "城市运营产品经理", "consumer", 170, 0.58, 1.9], 
	["sp08", "柔性机器人仓", "沈拓", "工业自动化工程师", "logistics", 260, 0.43, 2.4], 
	["sp09", "企业碳账本", "许禾", "绿色金融研究员", "finance", 210, 0.5, 2.1], 
	["sp10", "诊间智能助手", "唐玥", "医疗信息化创业者", "medical", 230, 0.48, 2.2], 
	["sp11", "文化空间云票务", "闻舟", "现场娱乐运营人", "entertainment", 190, 0.54, 2.0], 
]


static func decision_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(DECISION_NAMES.size()):
		var trigger: = _trigger_for_index(index)
		result.append({"id": "v10_decision_%02d" % (index + 1), "section": "条件经营", "title": DECISION_NAMES[index], "brief": "该事件由当前经营结构触发，选择会改变现金、风险或后续经营效率。", "trigger": trigger, "choices": [{"title": "稳健处置", "tag": "降低波动", "preview": "现金 -25万  风险 -5", "cash": -25, "risk": -5, "detail": "以当期投入换取稳定。"}, {"title": "主动进攻", "tag": "争取增长", "preview": "现金 +30万  风险 +6", "cash": 30, "risk": 6, "detail": "放大当前机会并承担波动。"}, {"title": "结构优化", "tag": "两轮协同", "preview": "现金 -10万  两轮收入 +4%", "cash": -10, "risk": 0, "effect": {"kind": "all_income_multiplier", "value": 1.04, "duration": 2}, "detail": "将资源投入到跨系统协同。"}]})
	return result


static func news_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(NEWS_NAMES.size()):
		var positive: = index not in [5, 7, 11]
		result.append({"id": "v10_news_%02d" % (index + 1), "title": NEWS_NAMES[index], "tags": [["消费", "科技", "金融", "地产", "物流"][index % 5]], "direction": 1 if positive else -1, "strength": 0.035 + float(index % 4) * 0.008, "credibility": "high" if index % 3 == 0 else "medium", "trigger": _trigger_for_index(index)})
	return result


static func risk_events() -> Array[Dictionary]:
	return [
		{"id": "v10_risk_01", "name": "银行风险复核", "headline": "高负债资本进入授信复核", "effect": "loan_rate", "value": 0.025, "duration": 2, "trigger": {"debt_ratio_min": 0.45}}, 
		{"id": "v10_risk_02", "name": "融资压力扩散", "headline": "短期融资成本抬升", "effect": "loan_rate", "value": 0.018, "duration": 1, "trigger": {"debt_ratio_min": 0.35}}, 
		{"id": "v10_risk_03", "name": "专利纠纷", "headline": "科技企业专利边界出现争议", "effect": "sector_cost", "sector": "technology", "value": 1.12, "duration": 2, "trigger": {"sector_business_min": {"technology": 2}}}, 
		{"id": "v10_risk_04", "name": "研发节点延迟", "headline": "研发设施交付时间延后", "effect": "construction_delta", "value": 1, "duration": 1, "trigger": {"sector_business_min": {"technology": 1}}}, 
		{"id": "v10_risk_05", "name": "商业监管关注", "headline": "高占有率商圈接受合规检查", "effect": "district_heat_market", "district": "commercial", "heat": -6.0, "stock": "consumer", "market": -0.025, "duration": 2, "trigger": {"district_control_min": 0.5}}, 
		{"id": "v10_risk_06", "name": "流动性冲击", "headline": "大额证券持仓放大市场波动", "effect": "market", "stock": "finance", "value": -0.035, "duration": 1, "trigger": {"stock_positions_min": 2}}, 
		{"id": "v10_risk_07", "name": "联盟针对", "headline": "频繁攻击引发竞争者联合回应", "effect": "red_points", "value": -1, "duration": 1, "trigger": {"attacks_min": 2}}, 
		{"id": "v10_risk_08", "name": "声誉修复成本", "headline": "激烈竞争带来城市舆情压力", "effect": "operating_grant", "value": 12, "duration": 1, "trigger": {"attacks_min": 1}}, 
	]


static func policy_events() -> Array[Dictionary]:
	return [
		{"id": "v10_policy_01", "name": "科技人才补贴", "description": "科技与教育片区获得短期地价支持", "effect": "land_value", "value": 0.08, "duration": 2, "trigger": {"sector_business_min": {"technology": 2}}}, 
		{"id": "v10_policy_02", "name": "商业集中度审查", "description": "高占有率商圈经营风险提高", "effect": "risk_tag", "tag": "commerce", "value": 8, "duration": 1, "trigger": {"district_control_min": 0.5}}, 
		{"id": "v10_policy_03", "name": "金融去杠杆窗口", "description": "金融企业进入风险复核", "effect": "risk_tag", "tag": "finance", "value": 10, "duration": 1, "trigger": {"debt_ratio_min": 0.4}}, 
		{"id": "v10_policy_04", "name": "夜间经营安全规范", "description": "文娱企业短期整改", "effect": "suspend_tag", "tag": "entertainment", "duration": 1, "trigger": {"sector_business_min": {"entertainment": 2}}}, 
		{"id": "v10_policy_05", "name": "城市更新征询", "description": "成熟地块可能进入协商征收", "effect": "acquisition", "min": 1.25, "max": 1.55, "duration": 0, "trigger": {"round_min": 6}}, 
	]


static func startup_projects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spec: Array in STARTUP_SPECS:
		result.append({"id": spec[0], "name": spec[1], "founder": spec[2], "founder_role": spec[3], "founder_tagline": "以城市真实需求验证增长", "summary": "从区域状态中寻找可持续经营机会", "cost": spec[5], "risk": "中高" if float(spec[6]) < 0.5 else "中", "delay": 2 if int(spec[5]) >= 220 else 1, "sector": spec[4], "base_success": spec[6], "financing_multiplier": spec[7], "trigger": _trigger_for_index(result.size())})
	return result


static func eligible(event: Dictionary) -> bool:
	var trigger: Dictionary = event.get("trigger", {})
	if trigger.is_empty(): return true
	if int(GameState.game_data.get("round", 0)) < int(trigger.get("round_min", 0)): return false
	var max_debt_ratio: = 0.0
	var max_stock_positions: = 0
	var max_attacks: = 0
	for player: Dictionary in GameState.game_data.get("players", []):
		max_debt_ratio = maxf(max_debt_ratio, float(player.get("debt", 0)) / maxf(1.0, float(player.get("asset_value", player.get("cash", 1)))))
		max_stock_positions = maxi(max_stock_positions, player.get("stocks", {}).size())
		max_attacks = maxi(max_attacks, int(player.get("actions", {}).get("attack_card", 0)))
	if max_debt_ratio < float(trigger.get("debt_ratio_min", 0.0)): return false
	if max_stock_positions < int(trigger.get("stock_positions_min", 0)): return false
	if max_attacks < int(trigger.get("attacks_min", 0)): return false
	for sector: String in trigger.get("sector_business_min", {}):
		var count: = 0
		for business: Dictionary in GameState.game_data.get("businesses", {}).values():
			if str(GameConfig.by_id("business_types", str(business.get("type_id", ""))).get("sector", "")) == sector: count += 1
		if count < int(trigger.sector_business_min[sector]): return false
	if float(trigger.get("district_control_min", 0.0)) > 0.0:
		var found: = false
		for district: Dictionary in GameState.game_data.get("districts", {}).values():
			for control: Variant in district.get("control", {}).values():
				found = found or float(control) >= float(trigger.district_control_min)
		if not found: return false
	return true


static func catalog_counts() -> Dictionary:
	return {"decision": 5 + decision_events().size(), "news": 9 + news_events().size(), "risk": 10 + risk_events().size(), "policy": 4 + policy_events().size(), "startup": 6 + startup_projects().size()}


static func _trigger_for_index(index: int) -> Dictionary:
	match index % 5:
		0: return {"debt_ratio_min": 0.25}
		1: return {"sector_business_min": {"technology": 1}}
		2: return {"district_control_min": 0.25}
		3: return {"stock_positions_min": 1}
	return {"round_min": 2}
