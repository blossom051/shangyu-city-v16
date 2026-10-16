extends Node

const PRODUCT_VERSION: = "V16"
const PRODUCT_NAME: = "商域之城：资本版图"
const PRODUCT_SUBTITLE: = "简明经营与风险真值版"

const REQUIRED_COUNTS: = {
	"investment_companies": 8, 
	"land_tiles": 44,
	"business_types": 18, 
	"talents": 20, 
	"cards": 100,
	"stocks": 8, 
	"traffic_routes": 5, 
}

var tables: Dictionary = {}
var validation_errors: Array[String] = []

func _ready() -> void :
	load_all()

func load_all() -> bool:
	validation_errors.clear()
	for table_name in REQUIRED_COUNTS.keys():
		tables[table_name] = _load_json("res://data/%s.json" % table_name)
	for table_name in ["news_events", "government_events", "random_events", "startup_projects", "balance"]:
		tables[table_name] = _load_json("res://data/%s.json" % table_name)
	_validate()
	return validation_errors.is_empty()

func list(table_name: String) -> Array:
	var value: Variant = tables.get(table_name, [])
	return value if value is Array else []

func dict_value(table_name: String) -> Dictionary:
	var value: Variant = tables.get(table_name, {})
	return value if value is Dictionary else {}

func by_id(table_name: String, item_id: String) -> Dictionary:
	for item: Variant in list(table_name):
		if item is Dictionary and str(item.get("id", "")) == item_id:
			return item
	return {}

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		validation_errors.append("缺少数据文件：%s" % path)
		return []
	var file: = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null:
		validation_errors.append("JSON 无法解析：%s" % path)
		return []
	return parsed

func _validate() -> void :
	for table_name: String in REQUIRED_COUNTS:
		var rows: = list(table_name)
		if rows.size() != int(REQUIRED_COUNTS[table_name]):
			validation_errors.append("%s 数量应为 %d，实际 %d" % [table_name, REQUIRED_COUNTS[table_name], rows.size()])
		var ids: Dictionary = {}
		for row: Variant in rows:
			if not row is Dictionary or str(row.get("id", "")).is_empty():
				validation_errors.append("%s 存在缺少 id 的记录" % table_name)
				continue
			var item_id: = str(row.id)
			if ids.has(item_id):
				validation_errors.append("%s 存在重复 id：%s" % [table_name, item_id])
			ids[item_id] = true
	var quality_total: = 0.0
	for value: Variant in dict_value("balance").get("talent_quality_rates", {}).values():
		quality_total += float(value)
	if absf(quality_total - 1.0) > 0.001:
		validation_errors.append("人才品质概率之和必须为 1")
