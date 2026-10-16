class_name BusinessInstance
extends RefCounted

static func create(instance_id: String, owner_id: String, land_id: String, business_type: Dictionary) -> Dictionary:
	var business := {
		"id": instance_id, 
		"owner_id": owner_id, 
		"land_id": land_id, 
		"type_id": str(business_type.id), 
		"name": str(business_type.name), 
		"state": "constructing", 
		"remaining_rounds": int(business_type.build_rounds), 
		"employees": ["", ""], 
		"effects": [], 
		"consecutive_loss": 0, 
		"mortgaged": false, 
		"last_net": 0, 
		"last_ledger": {}, 
		"value": int(business_type.cost),
	}
	ConstructionProgressService.initialize_project(business, int(GameState.game_data.get("round", 1)), int(business_type.build_rounds))
	return business
