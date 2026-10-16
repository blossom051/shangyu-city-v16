class_name AssetStateService
extends RefCounted

const LandNames = preload("res://scripts/LandNamingService.gd")

const AVAILABLE: = "AVAILABLE"
const OWNED: = "OWNED"
const MORTGAGED: = "MORTGAGED"
const AUCTION: = "AUCTION"
const SOLD: = "SOLD"
const BANK_OWNED: = "BANK_OWNED"


static func state(land: Dictionary) -> String:
	var canonical: = str(land.get("asset_state", ""))
	if not canonical.is_empty():
		return canonical
	var legacy: = str(land.get("state", "available"))
	if legacy == "auction":
		return AUCTION
	if bool(land.get("mortgaged", false)) or legacy == "mortgaged":
		return MORTGAGED
	if legacy in ["sold", "closed", "acquired"]:
		return SOLD
	if str(land.get("owner_id", "")).is_empty():
		return AVAILABLE
	return OWNED


static func transition(land: Dictionary, target: String, owner_id: = "", operating_state: = "") -> Dictionary:
	if land.is_empty():
		return {"ok": false, "message": "资产不存在"}
	var previous: = state(land)
	land.asset_state = target
	match target:
		AVAILABLE:
			LandNames.clear_custom_name(land)
			land.owner_id = ""
			land.mortgaged = false
			land.state = "available"
		BANK_OWNED:
			LandNames.clear_custom_name(land)
			land.owner_id = ""
			land.mortgaged = false
			land.state = "available"
		AUCTION:
			land.mortgaged = false
			land.state = "auction"
		MORTGAGED:
			if not owner_id.is_empty(): land.owner_id = owner_id
			land.mortgaged = true
			land.state = "mortgaged"
		SOLD:
			LandNames.clear_custom_name(land)
			land.owner_id = ""
			land.mortgaged = false
			land.state = "sold"
		OWNED:
			if not owner_id.is_empty() and owner_id != str(land.get("owner_id", "")):
				LandNames.clear_custom_name(land)
				land.owner_id = owner_id
			land.mortgaged = false
			land.state = operating_state if not operating_state.is_empty() else "owned_empty"
	return {"ok": true, "previous": previous, "current": target, "land_id": str(land.get("id", "")), "owner_id": str(land.get("owner_id", ""))}


static func can_purchase(land: Dictionary) -> bool:
	return state(land) in [AVAILABLE, BANK_OWNED] and str(land.get("owner_id", "")).is_empty()


static func income_eligible(land: Dictionary, player_id: String) -> bool:
	return str(land.get("owner_id", "")) == player_id and state(land) in [OWNED, MORTGAGED]


static func valuation_eligible(land: Dictionary, player_id: String) -> bool:
	return income_eligible(land, player_id)


static func validate_all() -> Dictionary:
	var errors: Array[String] = []
	var owners_by_land: Dictionary = {}
	for player: Dictionary in GameState.game_data.get("players", []):
		for land_id: String in player.get("land_ids", []):
			if owners_by_land.has(land_id):
				errors.append("资产%s同时出现在%s与%s名下" % [land_id, str(owners_by_land[land_id]), str(player.get("id", ""))])
			owners_by_land[land_id] = str(player.get("id", ""))
	for land: Dictionary in GameState.game_data.get("lands", {}).values():
		var land_id: = str(land.get("id", ""))
		var owner_id: = str(land.get("owner_id", ""))
		if not owner_id.is_empty() and str(owners_by_land.get(land_id, "")) != owner_id:
			errors.append("资产%s所有权字段与玩家资产列表不一致" % land_id)
		if state(land) in [AVAILABLE, BANK_OWNED, SOLD] and not owner_id.is_empty():
			errors.append("资产%s处于%s但仍有玩家所有者" % [land_id, state(land)])
	return {"ok": errors.is_empty(), "errors": errors, "asset_count": GameState.game_data.get("lands", {}).size()}
