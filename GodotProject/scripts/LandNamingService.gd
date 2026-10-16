class_name LandNamingService
extends RefCounted

const MAX_CHINESE_LENGTH: = 5
const MAX_ENGLISH_LENGTH: = 6


static func display_name(land: Dictionary) -> String:
	var custom: = str(land.get("custom_name", "")).strip_edges()
	return custom if not custom.is_empty() else str(land.get("id", land.get("land_id", "地块")))


static func validate_name(value: String) -> Dictionary:
	var candidate: = value.strip_edges()
	if candidate.is_empty():
		return _fail("请输入地名")
	if candidate.contains("\n") or candidate.contains("\r") or candidate.contains("\t") or candidate.contains(" "):
		return _fail("地名不能包含空格")
	var english: = RegEx.new()
	english.compile("^[A-Za-z]+$")
	if english.search(candidate) != null:
		if candidate.length() > MAX_ENGLISH_LENGTH:
			return _fail("英文地名最多6个字母")
		return {"ok": true, "name": candidate}
	if not _is_basic_chinese(candidate):
		return _fail("地名只支持中文或英文字母")
	if candidate.length() > MAX_CHINESE_LENGTH:
		return _fail("中文地名最多5个字")
	return {"ok": true, "name": candidate}


static func _is_basic_chinese(value: String) -> bool:
	if value.is_empty():
		return false
	for index in value.length():
		var codepoint: = value.unicode_at(index)
		if codepoint < 19968 or codepoint > 40959:
			return false
	return true


static func rename(player_id: String, land_id: String, value: String) -> Dictionary:
	var player: = GameState.player(player_id)
	var land: Dictionary = GameState.game_data.get("lands", {}).get(land_id, {})
	if player.is_empty() or land.is_empty():
		return _fail("地块不存在")
	if str(land.get("owner_id", "")) != player_id:
		return _fail("只能编辑自己的地块")
	var validation: = validate_name(value)
	if not bool(validation.get("ok", false)):
		return validation
	var previous: = display_name(land)
	land["custom_name"] = str(validation.get("name", ""))
	GameState._record(player_id, "rename_land", {
		"land_id": land_id, 
		"previous_name": previous, 
		"custom_name": str(land.custom_name), 
	})
	return {"ok": true, "message": "地名已更新", "land_id": land_id, "name": str(land.custom_name)}


static func clear_custom_name(land: Dictionary) -> void :
	if not land.is_empty():
		land["custom_name"] = ""


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}
