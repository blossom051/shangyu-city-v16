class_name MapHeatScale
extends RefCounted

const LOW: = Color("2e6fb4")
const COOL: = Color("35b9c5")
const WARM: = Color("e2b84b")
const HIGH: = Color("d94d45")


static func build_land_payloads(lands: Dictionary, districts: Dictionary) -> Dictionary:
	var raw_scores: = {}
	var minimum: = INF
	var maximum: = - INF
	var prices: Array[float] = []
	for land: Dictionary in lands.values():
		prices.append(float(land.get("price", 0.0)))
	var min_price: float = prices.min() if not prices.is_empty() else 0.0
	var max_price: float = prices.max() if not prices.is_empty() else 1.0
	for land_id: String in lands:
		var land: Dictionary = lands[land_id]
		var district: Dictionary = districts.get(str(land.get("district", "")), {})
		var heat_ratio: = inverse_lerp(40.0, 160.0, clampf(float(district.get("heat", 100.0)), 40.0, 160.0))
		var traffic: = traffic_score(land.get("environment", []))
		var location_value: = inverse_lerp(min_price, max_price, float(land.get("price", min_price))) if max_price > min_price else 0.5
		var raw: = heat_ratio * 0.5 + traffic * 0.32 + location_value * 0.18
		raw_scores[land_id] = {"raw": raw, "heat": float(district.get("heat", 100.0)), "traffic": traffic}
		minimum = minf(minimum, raw)
		maximum = maxf(maximum, raw)
	var payloads: = {}
	for land_id: String in raw_scores:
		var item: Dictionary = raw_scores[land_id]
		var ratio: = inverse_lerp(minimum, maximum, float(item.raw)) if maximum - minimum > 0.0001 else 0.5
		payloads[land_id] = {
			"heat": item.heat, 
			"traffic": item.traffic, 
			"value": item.raw, 
			"ratio": clampf(ratio, 0.0, 1.0), 
			"band": band_for_ratio(ratio), 
		}
	return payloads


static func traffic_score(tags_value: Variant) -> float:
	var tags: Array = tags_value if tags_value is Array else []
	if tags.has("transport"):
		return 1.0
	if tags.has("logistics"):
		return 0.78
	if tags.has("commercial") or tags.has("finance"):
		return 0.6
	if tags.has("medical") or tags.has("education"):
		return 0.42
	return 0.2


static func color_for_ratio(value: float) -> Color:
	var ratio: = clampf(value, 0.0, 1.0)
	if ratio <= 0.36:
		return LOW.lerp(COOL, ratio / 0.36)
	if ratio <= 0.68:
		return COOL.lerp(WARM, (ratio - 0.36) / 0.32)
	return WARM.lerp(HIGH, (ratio - 0.68) / 0.32)


static func band_for_ratio(value: float) -> String:
	var ratio: = clampf(value, 0.0, 1.0)
	if ratio < 0.34:
		return "偏低"
	if ratio < 0.67:
		return "适中"
	return "偏高"
