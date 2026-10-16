class_name SaveSlotService
extends Node

const FORMAT := "v15.5-slot-1"
const AUTO_ID := "auto"
const MANUAL_COUNT := 8
const DEFAULT_STORAGE_ROOT := "user://saves_v155"
const DEFAULT_LEGACY_PATH := "user://v9185_information_visualization_save.json"

var storage_root := DEFAULT_STORAGE_ROOT
var legacy_path := DEFAULT_LEGACY_PATH


func configure_paths_for_tests(root_path: String, legacy_file_path: String) -> void:
	storage_root = root_path
	legacy_path = legacy_file_path


func slot_path(slot_id: String) -> String:
	return "%s/%s.json" % [storage_root, slot_id]


func list_slots() -> Array[Dictionary]:
	_ensure_storage()
	var result: Array[Dictionary] = [slot_summary(AUTO_ID)]
	for index in range(1, MANUAL_COUNT + 1):
		result.append(slot_summary(_manual_id(index)))
	return result


func slot_summary(slot_id: String) -> Dictionary:
	var automatic := slot_id == AUTO_ID
	var index := 0 if automatic else _manual_index(slot_id)
	var base := {
		"id": slot_id,
		"index": index,
		"automatic": automatic,
		"exists": false,
		"corrupt": false,
		"display_name": "自动存档" if automatic else "存档位 %02d" % index,
	}
	if not _valid_slot_id(slot_id):
		base.corrupt = true
		base.message = "无效存档位"
		return base
	var path := slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return base
	var loaded := load_slot(slot_id)
	if not bool(loaded.get("ok", false)):
		base.exists = true
		base.corrupt = true
		base.message = str(loaded.get("message", "存档损坏"))
		return base
	base.merge((loaded.get("metadata", {}) as Dictionary).duplicate(true), true)
	base.exists = true
	return base


func save_auto(snapshot: Dictionary) -> Dictionary:
	return _save_slot(AUTO_ID, "自动存档", snapshot)


func save_manual(index: int, display_name: String, snapshot: Dictionary) -> Dictionary:
	if index < 1 or index > MANUAL_COUNT:
		return _fail("手动存档位必须在 1 到 %d 之间" % MANUAL_COUNT)
	var safe_name := _safe_display_name(display_name, "存档位 %02d" % index)
	return _save_slot(_manual_id(index), safe_name, snapshot)


func load_slot(slot_id: String) -> Dictionary:
	if not _valid_slot_id(slot_id):
		return _fail("无效存档位")
	var path := slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return _fail("该存档位为空")
	var parsed: Variant = _parse_json_file(path)
	if not parsed is Dictionary:
		return _fail("存档损坏：无法解析文件")
	var envelope: Dictionary = parsed
	if str(envelope.get("format", "")) != FORMAT:
		return _fail("存档损坏：格式标识无效")
	if not envelope.get("metadata", {}) is Dictionary or not envelope.get("game_data", {}) is Dictionary:
		return _fail("存档损坏：缺少经营数据")
	var snapshot: Dictionary = (envelope.get("game_data", {}) as Dictionary).duplicate(true)
	if not _snapshot_supported(snapshot):
		return _fail("存档版本不兼容")
	return {
		"ok": true,
		"slot_id": slot_id,
		"metadata": (envelope.get("metadata", {}) as Dictionary).duplicate(true),
		"game_data": snapshot,
	}


func rename_manual(index: int, display_name: String) -> Dictionary:
	if index < 1 or index > MANUAL_COUNT:
		return _fail("无效手动存档位")
	return rename_slot(_manual_id(index), display_name)


func rename_slot(slot_id: String, display_name: String) -> Dictionary:
	if slot_id == AUTO_ID:
		return _fail("自动存档不能改名")
	var loaded := load_slot(slot_id)
	if not bool(loaded.get("ok", false)):
		return loaded
	var metadata: Dictionary = loaded.get("metadata", {})
	metadata.display_name = _safe_display_name(display_name, str(metadata.get("display_name", "手动存档")))
	return _write_envelope(slot_id, {"format": FORMAT, "metadata": metadata, "game_data": loaded.get("game_data", {})})


func delete_manual(index: int) -> Dictionary:
	if index < 1 or index > MANUAL_COUNT:
		return _fail("无效手动存档位")
	return delete_slot(_manual_id(index))


func delete_slot(slot_id: String, allow_auto := false) -> Dictionary:
	if not _valid_slot_id(slot_id):
		return _fail("无效存档位")
	if slot_id == AUTO_ID and not allow_auto:
		return _fail("自动存档不能删除")
	var path := slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return {"ok": true, "slot_id": slot_id, "deleted": false, "message": "存档位已经为空"}
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if error != OK:
		return _fail("无法删除存档（错误 %d）" % error)
	return {"ok": true, "slot_id": slot_id, "deleted": true, "message": "存档已删除"}


func migrate_legacy_once() -> Dictionary:
	if FileAccess.file_exists(slot_path(AUTO_ID)):
		return {"ok": true, "migrated": false, "message": "新自动存档已经存在"}
	if not FileAccess.file_exists(legacy_path):
		return {"ok": true, "migrated": false, "message": "没有需要迁移的旧存档"}
	var parsed: Variant = _parse_json_file(legacy_path)
	if not parsed is Dictionary:
		return _fail("旧存档无法读取：文件损坏")
	var snapshot: Dictionary = parsed
	if not _snapshot_supported(snapshot):
		return _fail("旧存档无法读取：版本不兼容")
	var saved := save_auto(snapshot)
	if not bool(saved.get("ok", false)):
		return saved
	saved.migrated = true
	saved.message = "旧存档已安全导入自动档"
	return saved


func _save_slot(slot_id: String, display_name: String, snapshot: Dictionary) -> Dictionary:
	if not _valid_slot_id(slot_id):
		return _fail("无效存档位")
	if not _snapshot_supported(snapshot):
		return _fail("当前游戏数据无法保存")
	var envelope := {
		"format": FORMAT,
		"metadata": _metadata(slot_id, display_name, snapshot),
		"game_data": snapshot.duplicate(true),
	}
	return _write_envelope(slot_id, envelope)


func _write_envelope(slot_id: String, envelope: Dictionary) -> Dictionary:
	_ensure_storage()
	var target := slot_path(slot_id)
	var temporary := target + ".tmp"
	var backup := target + ".bak"
	for stale_path in [temporary, backup]:
		if FileAccess.file_exists(stale_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(stale_path))
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _fail("无法创建存档临时文件")
	file.store_string(JSON.stringify(envelope))
	file.flush()
	file.close()
	var verified: Variant = _parse_json_file(temporary)
	if not verified is Dictionary or str((verified as Dictionary).get("format", "")) != FORMAT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return _fail("存档写入校验失败")
	var had_target := FileAccess.file_exists(target)
	if had_target:
		var backup_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(target), ProjectSettings.globalize_path(backup))
		if backup_error != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
			return _fail("无法保护原存档（错误 %d）" % backup_error)
	var replace_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target))
	if replace_error != OK:
		if had_target and FileAccess.file_exists(backup):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(backup), ProjectSettings.globalize_path(target))
		return _fail("存档替换失败（错误 %d）" % replace_error)
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
	return {"ok": true, "slot_id": slot_id, "metadata": (envelope.get("metadata", {}) as Dictionary).duplicate(true), "message": "保存成功"}


func _metadata(slot_id: String, display_name: String, snapshot: Dictionary) -> Dictionary:
	var player := _active_player_from_snapshot(snapshot)
	var round_number := int(snapshot.get("round", 0))
	return {
		"slot_id": slot_id,
		"display_name": "自动存档" if slot_id == AUTO_ID else display_name,
		"automatic": slot_id == AUTO_ID,
		"mode": str(snapshot.get("mode", "solo")),
		"endless": bool(snapshot.get("endless", false)),
		"player_name": str(player.get("name", "未命名财团")),
		"round": round_number,
		"game_date": _game_date(round_number),
		"cash": int(player.get("cash", 0)),
		"asset": int(player.get("asset_value", 0)),
		"land_count": (player.get("land_ids", []) as Array).size(),
		"business_count": (player.get("business_ids", []) as Array).size(),
		"saved_unix": int(Time.get_unix_time_from_system()),
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"save_version": str(snapshot.get("version", "")),
		"overview": "west_bank" if bool(snapshot.get("endless", false)) else "original_city",
	}


func _active_player_from_snapshot(snapshot: Dictionary) -> Dictionary:
	var players: Array = snapshot.get("players", [])
	if players.is_empty():
		return {}
	var turn_order: Array = snapshot.get("turn_order", [])
	var active_index := int(snapshot.get("active_order_index", 0))
	var active_id := str(turn_order[clampi(active_index, 0, turn_order.size() - 1)]) if not turn_order.is_empty() else str((players[0] as Dictionary).get("id", ""))
	for value: Variant in players:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == active_id:
			return value as Dictionary
	return players[0] as Dictionary


func _snapshot_supported(snapshot: Dictionary) -> bool:
	return not snapshot.is_empty() and str(snapshot.get("version", "")) in GameState.ACCEPTED_SAVE_VERSIONS


func _game_date(round_number: int) -> String:
	const START_UNIX := 1767225600
	const DAY_SECONDS := 86400
	var date := Time.get_datetime_dict_from_unix_time(START_UNIX + maxi(0, round_number - 1) * 7 * DAY_SECONDS)
	return "%04d.%02d.%02d" % [int(date.year), int(date.month), int(date.day)]


func _ensure_storage() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(storage_root))


func _parse_json_file(path: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data


func _valid_slot_id(slot_id: String) -> bool:
	return slot_id == AUTO_ID or (_manual_index(slot_id) >= 1 and _manual_index(slot_id) <= MANUAL_COUNT)


func _manual_id(index: int) -> String:
	return "slot_%02d" % index


func _manual_index(slot_id: String) -> int:
	if not slot_id.begins_with("slot_"):
		return -1
	return int(slot_id.trim_prefix("slot_"))


func _safe_display_name(value: String, fallback: String) -> String:
	var result := value.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	if result.is_empty():
		result = fallback
	return result.left(20)


func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}
