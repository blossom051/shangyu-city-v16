class_name CardTaxonomy
extends RefCounted


const FAMILIES: = ["utility", "competition", "counter_guard"]
const EFFECT_TIERS: = ["basic", "advanced", "ace"]


static func family(card: Dictionary) -> String:
	var type: = str(card.get("type", "operation"))
	if type in ["defense", "counter"]:
		return "counter_guard"
	if type == "attack":
		return "competition"
	return "utility"


static func family_name(card: Dictionary) -> String:
	return {
		"utility": "经营功能", 
		"competition": "竞争效果", 
		"counter_guard": "反制保护", 
	}.get(family(card), "经营功能")


static func effect_tier(card: Dictionary) -> String:
	var power: = int(card.get("power", 0))
	if power >= 140:
		return "ace"
	if power >= 65:
		return "advanced"
	return "basic"


static func effect_tier_name(card: Dictionary) -> String:
	if str(card.get("series", "")) == "west_bank":
		return "西岸高级" if str(card.get("rarity", "")) == "west_bank_advanced" else "西岸普通"
	return {"basic": "基础级", "advanced": "进阶级", "ace": "王牌级"}.get(effect_tier(card), "基础级")


static func audit(cards: Array) -> Dictionary:
	var family_counts: = {}
	var tier_counts: = {}
	var errors: Array[String] = []
	for key: String in FAMILIES:
		family_counts[key] = 0
	for key: String in EFFECT_TIERS:
		tier_counts[key] = 0
	for card: Dictionary in cards:
		var family_id: = family(card)
		var tier_id: = effect_tier(card)
		family_counts[family_id] = int(family_counts.get(family_id, 0)) + 1
		tier_counts[tier_id] = int(tier_counts.get(tier_id, 0)) + 1
		if str(card.get("effect", "")).is_empty():
			errors.append("%s 缺少可执行效果" % str(card.get("id", "")))
	for key: String in FAMILIES:
		if int(family_counts.get(key, 0)) <= 0:
			errors.append("卡池缺少战术家族：%s" % key)
	for key: String in EFFECT_TIERS:
		if int(tier_counts.get(key, 0)) <= 0:
			errors.append("卡池缺少效果等级：%s" % key)
	return {"ok": errors.is_empty(), "errors": errors, "families": family_counts, "tiers": tier_counts}
