extends Node

const Insolvency = preload("res://scripts/InsolvencySystem.gd")
const DialogScene = preload("res://scripts/VoluntaryLiquidationDialog.gd")

var passed := 0
var failed := 0


func _ready() -> void:
	GameState.suppress_disk_save = true
	_test_standard_mode_rejects()
	await _test_ai_match_ends_and_ui_summary()
	_test_solo_marks_return_flow()
	ModalManager.clear_all("voluntary_liquidation_test_cleanup")
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.suppress_disk_save = false
	print("V154_VOLUNTARY_LIQUIDATION passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _test_standard_mode_rejects() -> void:
	GameState.start_match("solo", 12, [{"company_id": "hengyue", "human": true}], 15481)
	var player := GameState.game_data.players[0] as Dictionary
	var result := Insolvency.voluntary_liquidate(str(player.id))
	_assert("有限回合模式不开放主动破产入口", not bool(result.get("ok", false)) and not bool(player.get("eliminated", false)))


func _test_ai_match_ends_and_ui_summary() -> void:
	GameState.start_match("local", 0, [
		{"company_id": "hengyue", "human": true},
		{"company_id": "qiming", "human": false},
	], 15482)
	GameState.begin_round()
	var first := GameState.active_player()
	var second := GameState.game_data.players[1] as Dictionary
	first.asset_value = 4800
	first.cash = 900
	first.land_ids = ["L01"]
	first.business_ids = ["B01"]
	first.talent_ids = ["T01"]
	GameState.game_data.ipo_records[str(first.id)] = {"status": "listed", "ticker": "XA01", "share_price": 36.0, "price_history": [36.0]}
	var dialog := DialogScene.new()
	dialog.open_for_player(str(first.id))
	add_child(dialog)
	await get_tree().process_frame
	_assert("主动清算先显示二次确认而非直接退出", _has_button(dialog, "确认清算") and not bool(first.get("eliminated", false)))
	dialog.call("_confirm_liquidation")
	await get_tree().process_frame
	_assert("确认后显示图形化经营总结", _has_button(dialog, "确认总结") and not dialog.find_children("*", "LiquidationSummaryVisual", true, false).is_empty())
	_assert("人机永续局主动清算后整局结束且 AI 不再续跑", bool(first.get("eliminated", false)) and GameState.game_data.turn_order.is_empty() and bool(GameState.game_data.get("endless_session_ended", false)) and not bool(second.get("eliminated", false)))
	_assert("破产上市主体退出西岸板并进入退市整理", str(GameState.game_data.ipo_records[str(first.id)].get("status", "")) == "delisted" and float(GameState.game_data.ipo_records[str(first.id)].get("share_price", 99.0)) < 36.0)
	dialog.queue_free()
	await get_tree().process_frame


func _test_solo_marks_return_flow() -> void:
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15483)
	var player := GameState.game_data.players[0] as Dictionary
	var result := Insolvency.voluntary_liquidate(str(player.id))
	var summary := result.get("summary", {}) as Dictionary
	_assert("单人永续主动清算生成完整生涯总结", bool(result.get("ok", false)) and bool(player.get("eliminated", false)) and GameState.game_data.turn_order.is_empty() and summary.has("peak_asset") and summary.has("milestones"))


func _has_button(root: Node, wanted: String) -> bool:
	for node: Node in root.find_children("*", "Button", true, false):
		if str((node as Button).text) == wanted:
			return true
	return false


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s" % label)
