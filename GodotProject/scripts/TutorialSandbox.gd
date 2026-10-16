class_name TutorialSandbox
extends RefCounted


var active: = false
var player_id: = ""
var demo_land_id: = ""
var selected_land_id: = ""
var purchased_land_ids: Array[String] = []
var demo_businesses: Dictionary = {}
var demo_talent_recruited: = false
var demo_talent_id: = ""
var demo_talent_assigned: = false
var demo_strategy_played: = false
var demo_stock_traded: = false
var demo_financing_reviewed: = false
var demo_startup_invested: = false
var demo_auction_bid: = false
var demo_settled: = false
var practice_cash: = 800

const PRACTICE_INCOME: = 68
const PRACTICE_COST: = 26
const PRACTICE_TALENT: = 14
const PRACTICE_CARD: = 18

var _game_snapshot: Dictionary = {}
var _game_fingerprint: = ""
var _rng_state: = 0
var _save_path: = ""
var _save_existed: = false
var _save_bytes: = PackedByteArray()
var _previous_suppress_disk_save: = false
var _previous_tutorial_lock: = false


func begin(value: String) -> Dictionary:
	if active:
		finish("restart")
	var candidate_land_id: = _first_available_land()
	if candidate_land_id.is_empty():
		return _fail("当前没有可用教学土地")
	player_id = value
	selected_land_id = ""
	purchased_land_ids.clear()
	demo_businesses.clear()
	_reset_practice()
	_game_snapshot = GameState.game_data.duplicate(true)
	_game_fingerprint = JSON.stringify(_game_snapshot)
	_rng_state = int(GameState.rng.state)
	_previous_suppress_disk_save = bool(GameState.suppress_disk_save)
	_save_path = str(GameState.SAVE_PATH)
	_save_existed = FileAccess.file_exists(_save_path)
	_save_bytes = FileAccess.get_file_as_bytes(_save_path) if _save_existed else PackedByteArray()
	_previous_tutorial_lock = bool(GameState.tutorial_lock)
	active = true
	GameState.suppress_disk_save = true
	GameState.tutorial_lock = true
	demo_land_id = candidate_land_id
	selected_land_id = demo_land_id
	return {"ok": true, "player_id": player_id, "demo_land_id": demo_land_id}


func select_land(land_id: String) -> Dictionary:
	if not active:
		return _fail("教学沙盒尚未开始")
	var land: Dictionary = GameState.game_data.get("lands", {}).get(land_id, {})
	if not _is_available_land(land):
		return _fail("请选择带有‘待售’标记的教学地块。")
	demo_land_id = land_id
	selected_land_id = land_id
	return {"ok": true, "simulated": true, "land_id": land_id, "district_name": str(land.get("district_name", "城市街区"))}


func simulate_purchase(land_id: String) -> Dictionary:
	var selected: = select_land(land_id)
	if not bool(selected.get("ok", false)):
		return selected
	if not purchased_land_ids.has(land_id):
		purchased_land_ids.append(land_id)
	return {
		"ok": true, 
		"simulated": true, 
		"land_id": land_id, 
		"message": "教学资产：已模拟购入 %s，不影响正式对局。" % land_id, 
	}


func simulate_build(type_id: String, land_id: = "") -> Dictionary:
	var target_land: = land_id if not land_id.is_empty() else selected_land_id
	if not active or not purchased_land_ids.has(target_land):
		return _fail("请先完成教学买地")
	var business: Dictionary = GameConfig.by_id("business_types", type_id)
	if business.is_empty():
		business = _fallback_business()
	if business.is_empty():
		return _fail("没有可展示的教学企业")
	demo_businesses[target_land] = {
		"type_id": str(business.get("id", type_id)), 
		"name": str(business.get("name", "教学企业")), 
		"remaining_rounds": maxi(1, int(business.get("build_rounds", 1))), 
		"state": "constructing", 
	}
	return {
		"ok": true, 
		"simulated": true, 
		"land_id": target_land, 
		"type_id": str(business.get("id", type_id)), 
		"message": "教学演示：%s已模拟开工，真实对局未扣款。" % str(business.get("name", "企业")), 
	}


func owns_land(land_id: String) -> bool:
	return active and purchased_land_ids.has(land_id)


func recruit_demo_talent(talent_id: String) -> Dictionary:
	if not active:
		return _fail("教学沙盒尚未开始")
	demo_talent_recruited = true
	demo_talent_id = talent_id
	return {"ok": true, "talent_id": talent_id, "message": "教学人才已招募，请进入员工管理并安排到教学企业。"}


func assign_demo_talent() -> Dictionary:
	if not active:
		return _fail("教学沙盒尚未开始")
	if not demo_talent_recruited:
		return _fail("请先招募教学人才")
	demo_talent_assigned = true
	return {
		"ok": true, 
		"base_net": PRACTICE_INCOME - PRACTICE_COST, 
		"talent_bonus": PRACTICE_TALENT, 
		"projected_net": _projected_net(), 
	}


func play_demo_strategy() -> Dictionary:
	if not active:
		return _fail("教学沙盒尚未开始")
	var before_net: = _projected_net()
	demo_strategy_played = true
	return {
		"ok": true, 
		"before_net": before_net, 
		"card_bonus": PRACTICE_CARD, 
		"projected_net": _projected_net(), 
	}


func simulate_stock_trade(stock_id: String, shares: int, buy: bool) -> Dictionary:
	if not active or stock_id.is_empty():
		return _fail("请先选择一只证券")
	if not buy or shares != 100:
		return _fail("教学任务需要把滑杆设为100股并点击买入")
	demo_stock_traded = true
	return {"ok": true, "simulated": true, "stock_id": stock_id, "shares": shares, "buy": true, "message": "教学买入100股已成交；持仓、成本和盈亏已演示，正式账户未变化。"}


func simulate_financing(amount: int) -> Dictionary:
	if not active or amount <= 0:
		return _fail("请先选择融资额度")
	demo_financing_reviewed = true
	return {"ok": true, "simulated": true, "amount": amount, "message": "教学融资%d万；已演示到账、分期应付和提前结清，正式账本未变化。" % amount}


func simulate_startup(project_id: String) -> Dictionary:
	if not active or project_id.is_empty():
		return _fail("请选择一个创业项目")
	demo_startup_invested = true
	return {"ok": true, "simulated": true, "project_id": project_id, "invested": 120, "cash_after": practice_cash, "success_rate": 0.68, "remaining_rounds": 1, "expected_financing": 240, "message": "教学创投决策已记录；正式现金和项目库未变化。"}


func simulate_auction(asset_id: String, amount: int) -> Dictionary:
	if not active or asset_id.is_empty() or amount < 100:
		return _fail("教学暗标不得低于100万")
	demo_auction_bid = true
	return {"ok": true, "simulated": true, "asset_id": asset_id, "amount": amount, "message": "教学暗标已锁定：%d万；正式现金与资产未变化。" % amount}


func simulate_settlement() -> Dictionary:
	if not active:
		return _fail("教学沙盒尚未开始")
	if not demo_talent_assigned or not demo_strategy_played:
		return _fail("请先安排人才并使用教学卡")
	var net: = _projected_net()
	if not demo_settled:
		practice_cash += net
		demo_settled = true
	return {
		"ok": true, 
		"income": PRACTICE_INCOME, 
		"cost": PRACTICE_COST, 
		"talent": PRACTICE_TALENT, 
		"card": PRACTICE_CARD, 
		"net_cashflow": net, 
		"cash_after": practice_cash, 
	}


func practice_profile() -> Dictionary:
	return {
		"talent_recruited": demo_talent_recruited, 
		"talent_assigned": demo_talent_assigned, 
		"strategy_played": demo_strategy_played, 
		"stock_traded": demo_stock_traded, 
		"financing_reviewed": demo_financing_reviewed, 
		"startup_invested": demo_startup_invested, 
		"auction_bid": demo_auction_bid, 
		"settled": demo_settled, 
		"income": PRACTICE_INCOME, 
		"cost": PRACTICE_COST, 
		"talent": PRACTICE_TALENT if demo_talent_assigned else 0, 
		"card": PRACTICE_CARD if demo_strategy_played else 0, 
		"projected_net": _projected_net(), 
		"cash": practice_cash, 
	}


func land_visual(land_id: String) -> Dictionary:
	if not active:
		return {}
	if demo_businesses.has(land_id):
		return {"kind": "construction", "land_id": land_id, "business": demo_businesses[land_id].duplicate(true)}
	if purchased_land_ids.has(land_id):
		return {"kind": "owned", "land_id": land_id, "label": "教学资产", "message": "模拟购入，不影响正式对局"}
	if land_id == demo_land_id:
		return {"kind": "available", "land_id": land_id, "label": "教学地块"}
	return {}


func fingerprint_unchanged() -> bool:
	return JSON.stringify(GameState.game_data) == _game_fingerprint and int(GameState.rng.state) == _rng_state and _save_unchanged()


func finish(reason: = "complete") -> Dictionary:
	if not active:
		return {"ok": true, "unchanged": true, "rolled_back": false, "differences": []}
	var differences: = _diff_categories()
	var unchanged: = differences.is_empty()
	if not unchanged:
		GameState.game_data = _game_snapshot.duplicate(true)
		GameState.rng.state = _rng_state
		_restore_save()
	active = false
	demo_land_id = ""
	selected_land_id = ""
	purchased_land_ids.clear()
	demo_businesses.clear()
	_reset_practice()
	GameState.suppress_disk_save = _previous_suppress_disk_save
	GameState.tutorial_lock = _previous_tutorial_lock
	if not unchanged:
		push_warning("[TutorialSandbox] %s 时发现正式状态变化，已恢复：%s" % [reason, "、".join(differences)])
		GameState.force_refresh()
	return {"ok": true, "unchanged": unchanged, "rolled_back": not unchanged, "differences": differences}


func _first_available_land() -> String:
	var ids: Array = GameState.game_data.get("lands", {}).keys()
	ids.sort()
	for land_id: Variant in ids:
		if _is_available_land(GameState.game_data.lands[str(land_id)]):
			return str(land_id)
	return ""


func _is_available_land(land: Dictionary) -> bool:
	return (
		not land.is_empty()
		and str(land.get("state", "")) == "available"
		and str(land.get("owner_id", "")).is_empty()
		and not bool(land.get("mortgaged", false))
		and bool(land.get("visible", true))
		and int(land.get("price", 0)) > 0
	)


func _fallback_business() -> Dictionary:
	var businesses: = GameConfig.list("business_types")
	return {} if businesses.is_empty() else (businesses[0] as Dictionary)


func _save_unchanged() -> bool:
	var exists_now: = FileAccess.file_exists(_save_path)
	if exists_now != _save_existed:
		return false
	return not exists_now or FileAccess.get_file_as_bytes(_save_path) == _save_bytes


func _restore_save() -> void :
	if _save_existed:
		var file: = FileAccess.open(_save_path, FileAccess.WRITE)
		if file:
			file.store_buffer(_save_bytes)
	elif FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))


func _diff_categories() -> Array[String]:
	var result: Array[String] = []
	if JSON.stringify(GameState.game_data) != _game_fingerprint:
		for key in ["players", "lands", "businesses", "log", "battle_ledger", "phase", "round"]:
			if JSON.stringify(GameState.game_data.get(key)) != JSON.stringify(_game_snapshot.get(key)):
				result.append(key)
		if result.is_empty():
			result.append("game_data")
	if int(GameState.rng.state) != _rng_state:
		result.append("rng")
	if not _save_unchanged():
		result.append("save_file")
	return result


func _fail(message: String) -> Dictionary:
	return {"ok": false, "simulated": true, "message": message}


func _projected_net() -> int:
	return PRACTICE_INCOME - PRACTICE_COST + (PRACTICE_TALENT if demo_talent_assigned else 0) + (PRACTICE_CARD if demo_strategy_played else 0)


func _reset_practice() -> void :
	demo_talent_recruited = false
	demo_talent_id = ""
	demo_talent_assigned = false
	demo_strategy_played = false
	demo_stock_traded = false
	demo_financing_reviewed = false
	demo_startup_invested = false
	demo_auction_bid = false
	demo_settled = false
	practice_cash = 800
