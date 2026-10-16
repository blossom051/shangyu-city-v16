class_name RoundCashflowAudit
extends RefCounted


const CATEGORY_LABELS: = {
	"operating": "经营现金流", 
	"investment": "投资建设", 
	"stock": "证券交易", 
	"financing": "融资还款", 
	"event": "事件与卡牌", 
	"other": "其他变动", 
}


static func build(player_id: String, opening: Dictionary, closing_cash: int) -> Dictionary:
	var categories: = _empty_categories()
	var lines: Array[Dictionary] = []
	var round_number: = int(opening.get("round", GameState.game_data.get("round", 0)))
	var start_index: = maxi(0, int(opening.get("log_index", 0)))
	var log: Array = GameState.game_data.get("log", [])
	for index in range(start_index, log.size()):
		var entry: Dictionary = log[index]
		if int(entry.get("round", -1)) != round_number or str(entry.get("player_id", "")) != player_id or str(entry.get("kind", "")) != "cash":
			continue
		var data: Dictionary = entry.get("data", {})
		var amount: = int(data.get("amount", 0))
		var reason: = str(data.get("reason", "未说明资金变动"))
		var category: = _category_for(reason)
		var bucket: Dictionary = categories[category]
		bucket.net = int(bucket.net) + amount
		bucket.inflow = int(bucket.inflow) + maxi(0, amount)
		bucket.outflow = int(bucket.outflow) + maxi(0, - amount)
		bucket.lines.append({"reason": reason, "amount": amount, "log_index": int(entry.get("index", index))})
		lines.append({"category": category, "label": str(CATEGORY_LABELS[category]), "reason": reason, "amount": amount})
	var opening_cash: = int(opening.get("cash", closing_cash))
	var classified_total: = 0
	var total_inflow: = 0
	var total_outflow: = 0
	for category: String in categories:
		classified_total += int(categories[category].net)
		total_inflow += int(categories[category].inflow)
		total_outflow += int(categories[category].outflow)
	var actual_change: = closing_cash - opening_cash
	return {
		"round": round_number, 
		"opening_cash": opening_cash, 
		"closing_cash": closing_cash, 
		"actual_change": actual_change, 
		"classified_total": classified_total, 
		"difference": actual_change - classified_total, 
		"balanced": actual_change == classified_total, 
		"total_inflow": total_inflow, 
		"total_outflow": total_outflow, 
		"categories": categories, 
		"lines": lines, 
	}


static func _empty_categories() -> Dictionary:
	var result: = {}
	for category: String in CATEGORY_LABELS:
		result[category] = {"label": str(CATEGORY_LABELS[category]), "net": 0, "inflow": 0, "outflow": 0, "lines": []}
	return result


static func _category_for(reason: String) -> String:
	if _contains_any(reason, ["买入", "卖出", "证券", "股票"]):
		return "stock"
	if _contains_any(reason, ["贷款", "融资", "利息", "偿还", "还款", "抵押", "逾期", "银行"]):
		return "financing"
	if _contains_any(reason, ["购买", "购地", "土地", "建设", "建造", "创投", "项目投资", "拍卖中标"]):
		return "investment"
	if _contains_any(reason, ["事件", "补助", "补贴", "纾困", "征收", "政府", "卡牌", "策略", "奖励"]):
		return "event"
	if _contains_any(reason, ["企业", "经营", "客流", "商圈", "控制收益", "人才", "挖角"]):
		return "operating"
	return "other"


static func _contains_any(value: String, needles: Array[String]) -> bool:
	for needle: String in needles:
		if value.contains(needle):
			return true
	return false
