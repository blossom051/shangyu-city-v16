class_name BusinessRecommendationEngine
extends RefCounted


const FIT_INCOME_MULTIPLIER: = 1.12
const PRIMARY_FIT_INCOME_MULTIPLIER: = 1.2
const AVOID_INCOME_MULTIPLIER: = 0.82
const ENVIRONMENT_MATCH_BONUS: = 0.06
const MAX_RECOMMENDATIONS: = 2

const TAG_NAMES: = {
	"education": "教育客群", "medical": "医疗配套", "finance": "金融办公", "commercial": "商业客流", 
	"residential": "社区人口", "entertainment": "文娱消费", "waterfront": "滨水客流", "technology": "科技资源", 
	"newtown": "新区发展", "oldtown": "老城消费", "transport": "交通可达", "government": "政务资源", 
}


static func rank_for_land(land: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var premium_land := bool(land.get("premium_zone", false))
	for business: Dictionary in GameConfig.list("business_types"):
		# 西岸和原城区使用两套独立企业池。展示层必须先过滤，不能把
		# 最终会被 BusinessSystem 拒绝的方案继续作为“可选项”呈现。
		if bool(business.get("premium_only", false)) != premium_land:
			continue
		results.append(evaluate(business, land))
	results.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(float(a.score), float(b.score)):
			return int(a.adjusted_net) > int(b.adjusted_net)
		return float(a.score) > float(b.score))
	var top_score: = float(results[0].score) if not results.is_empty() else 0.0
	for index in range(results.size()):
		var item: Dictionary = results[index]
		item.recommended = index < MAX_RECOMMENDATIONS and int(item.conflict_count) == 0 and float(item.score) >= top_score - 14.0
		item.rank = index + 1
		item.badge = "街区首选" if index == 0 and bool(item.recommended) else "街区推荐" if bool(item.recommended) else "普通方案"
	return results


static func evaluate(business: Dictionary, land: Dictionary) -> Dictionary:
	var district_id: = str(land.get("district", ""))
	var tags: Array = land.get("environment", []).duplicate()
	if not tags.has(district_id):
		tags.append(district_id)
	var matched: Array[String] = []
	var conflicts: Array[String] = []
	for tag: Variant in business.get("fit", []):
		if tags.has(str(tag)):
			matched.append(str(tag))
	for tag: Variant in business.get("avoid", []):
		if tags.has(str(tag)):
			conflicts.append(str(tag))
	var district_match: bool = business.get("fit", []).has(district_id)
	var primary_match: bool = not business.get("fit", []).is_empty() and str(business.get("fit", [""])[0]) == district_id
	var multiplier: = PRIMARY_FIT_INCOME_MULTIPLIER if primary_match else FIT_INCOME_MULTIPLIER if district_match else 1.0
	var environment_matches: = matched.size() - (1 if district_match else 0)
	multiplier *= 1.0 + minf(0.18, float(maxi(0, environment_matches)) * ENVIRONMENT_MATCH_BONUS)
	if not conflicts.is_empty():
		multiplier *= pow(AVOID_INCOME_MULTIPLIER, conflicts.size())
	var revenue: = roundi(float(business.get("income", 0)) * multiplier)
	var adjusted_net: = revenue - int(business.get("fixed_cost", 0))
	var score: = float(adjusted_net) * 1.35
	score -= float(business.get("cost", 0)) / float(maxi(2, int(business.get("build_rounds", 1)) + 2)) * 0.18
	score -= float(business.get("risk", 0)) * 0.45
	score += 26.0 if district_match else 0.0
	score += 50.0 if primary_match else 0.0
	score += float(environment_matches) * 9.0
	score -= float(conflicts.size()) * 72.0
	var reason_parts: Array[String] = []
	if district_match:
		reason_parts.append("契合%s" % str(land.get("district_name", "当前街区")))
	for tag: String in matched:
		if tag != district_id:
			reason_parts.append("利用%s" % _tag_name(tag))
	for tag: String in conflicts:
		reason_parts.append("避开失败：与%s冲突" % _tag_name(tag))
	if reason_parts.is_empty():
		reason_parts.append("无直接区位加成，按基础收益测算")
	return {
		"business": business, 
		"score": snappedf(score, 0.1), 
		"adjusted_income": revenue, 
		"adjusted_net": adjusted_net, 
		"income_multiplier": multiplier, 
		"matched_tags": matched, 
		"conflicts": conflicts, 
		"conflict_count": conflicts.size(), 
		"district_match": district_match, 
		"primary_match": primary_match, 
		"reason": "；".join(reason_parts), 
		"recommended": false, 
	}


static func result_for(business: Dictionary, land: Dictionary) -> Dictionary:
	for item: Dictionary in rank_for_land(land):
		if str(item.business.get("id", "")) == str(business.get("id", "")):
			return item
	return evaluate(business, land)


static func _tag_name(tag: String) -> String:
	return str(TAG_NAMES.get(tag, tag))
