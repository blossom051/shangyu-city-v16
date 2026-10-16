class_name TutorialFlowState
extends RefCounted


const STEPS: Array[Dictionary] = [
	{"id": "capital_goal", "target_key": "turn_panel", "advance": "automatic", "success_action": "capital_goal", "action_label": "理解本局目标", "title": "启航 1  你要赢下什么", "objective": "在限定回合结束时，让最终净值成为全场第一", "body": "最终净值由现金、经营资产与投资资产构成，再扣除负债和风险惩罚。"}, 
	{"id": "dashboard_drill", "target_key": "operations", "advance": "automatic", "success_action": "dashboard_reviewed", "action_label": "查看经营驾驶舱", "title": "启航 2  看懂四个核心指标", "objective": "点击高亮的“经营驾驶舱”，查看后再返回城市", "body": "现金决定现在能做什么；净资产决定排名；负债和风险决定你会损失什么。"}, 
	{"id": "select_land", "target_key": "map_area", "advance": "automatic", "success_action": "select_land", "action_label": "找到第一块地", "title": "启航 3  读懂商圈与地块", "objective": "点击地图上金色光圈标出的待售地块", "body": "商圈热度影响客流，地价决定资金占用，区域控制会带来额外收益。"}, 
	{"id": "land_decision", "target_key": "buy", "advance": "automatic", "success_action": "buy_land", "action_label": "完成购买判断", "title": "启航 4  做一次购买判断", "objective": "核对价格、商圈、客流和风险后模拟购入", "body": "本次写入教学沙盘，不扣正式现金；正式对局购地次数不限，但每笔交易都会占用现金。"}, 
	{"id": "build_cashflow", "target_key": "build", "advance": "automatic", "success_action": "build_business", "action_label": "建成第一条现金流", "title": "启航 5  把土地变成现金流", "objective": "打开建设方案并选择街区首选企业", "body": "净收益＝营业收入＋客流与控制收益－固定成本；不要只看营业收入。"}, 
	{"id": "assign_talent", "target_key": "talent", "advance": "automatic", "success_action": "assign_talent", "action_label": "招募并安排人才", "title": "启航 6  建立你的经营团队", "objective": "招募一名候选人，再从员工管理安排到教学企业", "body": "人才只有安排到已建成企业才会生效；可在员工管理中调岗、撤回或辞退。"}, 
	{"id": "play_strategy", "target_key": "cards", "advance": "automatic", "success_action": "play_strategy", "action_label": "使用策略卡", "title": "启航 7  在正确时点出牌", "objective": "打开策略手牌，打出教学收益卡并观察预测变化", "body": "每轮获得3点策略点 SP；可以连续使用低费牌，也可以把防御或反制牌部署到两格秘策区。主动攻击牌每轮最多1张。"}, 
	{"id": "stock_market", "target_key": "stocks", "advance": "automatic", "success_action": "stock_trade", "action_label": "完成证券交易", "title": "启航 8  配置证券资产", "objective": "进入证券终端，拖动选择100股并完成一次教学买入", "body": "证券价格会受城市事件和企业经营影响；列表会明确标记你的持仓、成本与浮盈亏。"}, 
	{"id": "finance_risk", "target_key": "bank", "advance": "automatic", "success_action": "finance_risk", "action_label": "理解融资、还款与风险", "title": "启航 9  管理现金与信用", "objective": "进入城市银行，查看现金流预览并模拟确认一次融资", "body": "借款前同时核对总利息、每期应付和剩余赛程；贷款账户可支付本期或提前结清，逾期会冻结授信并推高风险。"}, 
	{"id": "startup_review", "target_key": "startup", "advance": "automatic", "success_action": "startup_invest", "action_label": "完成创投尽调", "title": "启航 10  判断创业投资", "objective": "进入创投中心，对比成本、成功率和回报后完成一次教学投资", "body": "创投会占用当期现金，经过尽调期后才揭晓；失败会损失本金并增加风险。"}, 
	{"id": "auction_practice", "target_key": "auction", "advance": "automatic", "success_action": "auction_bid", "action_label": "完成一次暗标", "title": "启航 11  参加资产拍卖", "objective": "进入拍卖中心，输入不低于起拍价的教学暗标并锁定", "body": "暗标提交前看不到对手价格；现金、竞价技能和逾期资格会共同决定能否成交。"}, 
	{"id": "first_round_plan", "target_key": "news", "advance": "automatic", "success_action": "first_round_plan", "action_label": "读取城市机会", "title": "启航 12  用情报校准计划", "objective": "打开新闻日报读取本轮机会，随后返回城市", "body": "先读公共变化，再决定土地、企业和投资配置；经营动作应围绕同一轮计划。"}, 
	{"id": "settle_practice", "target_key": "end_turn", "advance": "automatic", "success_action": "settle_practice", "action_label": "完成模拟结算", "title": "启航 13  完成一轮经营", "objective": "点击模拟结算，核对现金、净值、风险和排名变化", "body": "结算前保留到期支出；结算后复盘收入、成本、债务、投资和排名，再制定下一轮计划。"}, 
]

var index: = -1
var running: = false


func start() -> Dictionary:
	index = 0
	running = true
	return current()


func current() -> Dictionary:
	if not running or index < 0 or index >= STEPS.size():
		return {}
	return STEPS[index].duplicate(true)


func current_id() -> String:
	return str(current().get("id", ""))


func submit_action(action_id: String) -> Dictionary:
	var step: = current()
	if step.is_empty() or str(step.get("advance", "manual")) != "automatic":
		return {"accepted": false, "advanced": false, "completed": false, "step": step}
	if str(step.get("success_action", "")) != action_id:
		return {"accepted": false, "advanced": false, "completed": false, "step": step}
	return _advance()


func stop() -> void :
	running = false
	index = -1


func profile() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for step in STEPS:
		var copy: = step.duplicate(true)
		copy["requires_action"] = str(copy.get("advance", "manual")) == "automatic"
		copy["required_label"] = str(copy.get("objective", ""))
		result.append(copy)
	return result


func _advance() -> Dictionary:
	index += 1
	if index >= STEPS.size():
		running = false
		return {"accepted": true, "advanced": true, "completed": true, "step": {}}
	return {"accepted": true, "advanced": true, "completed": false, "step": current()}
