extends Node

const Bank = preload("res://scripts/BankSystem.gd")
const CollateralSettlement = preload("res://scripts/CollateralSettlementService.gd")
const Insolvency = preload("res://scripts/InsolvencySystem.gd")
const Risks = preload("res://scripts/RiskSystem.gd")

var passed := 0
var failed := 0


func _ready() -> void:
	GameState.suppress_disk_save = true
	_test_foreclosure_principal_and_three_round_deadline()
	_test_risk_100_must_be_continuous()
	GameState.suppress_disk_save = false
	print("V154_DEBT_RISK_ENFORCEMENT passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _start_two(seed_value: int) -> Array:
	GameState.start_match("local", 0, [
		{"company_id": "hengyue", "human": true},
		{"company_id": "qiming", "human": true},
	], seed_value)
	GameState.begin_round()
	return GameState.game_data.players


func _test_foreclosure_principal_and_three_round_deadline() -> void:
	var players := _start_two(15471)
	var debtor := players[0] as Dictionary
	var survivor := players[1] as Dictionary
	var debtor_id := str(debtor.id)
	var land := GameState.game_data.lands["L01"] as Dictionary
	land.owner_id = debtor_id
	land.asset_state = "OWNED"
	debtor.land_ids = ["L01"]
	debtor.debt = 453
	debtor.cash = 0
	debtor.loans = [{
		"id": "FORECLOSE-1", "kind": "mortgage", "principal": 168,
		"unpaid_principal": 168, "unpaid_interest": 93, "overdue_fee": 192,
		"asset_id": "L01", "collection_asset_id": "L01", "overdue": 3,
	}]
	GameState.game_data.round = 10
	var closed := CollateralSettlement.close_after_disposal(debtor, "L01", 0, "流拍司法处置")
	var residual := debtor.loans[0] as Dictionary
	_assert("抵押资产成交或流拍处置后贷款本金立即核销", bool(closed.get("ok", false)) and int(closed.get("principal_cleared", 0)) == 168 and int(residual.get("principal", -1)) == 0 and int(debtor.debt) == 285)
	_assert("处置后只保留利息和逾期费并明确三回合期限", str(residual.get("kind", "")) == "judicial_residual" and int(residual.get("unpaid_interest", 0)) == 93 and int(residual.get("overdue_fee", 0)) == 192 and int(residual.get("judicial_residual_due_round", 0)) == 13)
	for round_number in [11, 12]:
		GameState.game_data.round = round_number
		Bank.settle_interest(debtor_id, false)
	_assert("追偿前两回合冻结授信并增加风险但尚不破产", not Bank.has_judicial_bankruptcy_due(debtor_id) and int(debtor.get("credit_frozen_rounds", 0)) > 0 and int(debtor.get("risk", 0)) >= 16)
	GameState.game_data.round = 13
	Bank.settle_interest(debtor_id, false)
	var due := Bank.has_judicial_bankruptcy_due(debtor_id)
	var result := Insolvency.force_delinquency_bankruptcy(debtor_id) if due else {}
	_assert("剩余息费追偿满三回合仍未清会强制破产", due and bool(result.get("bankrupt", false)) and bool(debtor.get("eliminated", false)))
	_assert("多人局失信组退出后其他组仍在有效轮转", GameState.game_data.turn_order == [str(survivor.id)] and not bool(survivor.get("eliminated", false)))


func _test_risk_100_must_be_continuous() -> void:
	var players := _start_two(15472)
	var player := players[0] as Dictionary
	var player_id := str(player.id)
	player.risk = 100
	GameState.game_data.round = 1
	var first := Risks.process_critical_risk_round(player_id)
	GameState.game_data.round = 2
	player.risk = 99
	var reset := Risks.process_critical_risk_round(player_id)
	_assert("风险降到100以下会中断连续极限风险计时", int(first.get("critical_rounds", 0)) == 1 and int(reset.get("critical_rounds", -1)) == 0)
	var status: Dictionary = {}
	for round_number in [3, 4, 5]:
		GameState.game_data.round = round_number
		player.risk = 100
		status = Risks.process_critical_risk_round(player_id)
	var result := Insolvency.force_risk_bankruptcy(player_id) if bool(status.get("bankruptcy_pending", false)) else {}
	_assert("风险100连续三回合不降低才触发破产清算", bool(status.get("bankruptcy_pending", false)) and bool(result.get("bankrupt", false)) and bool(player.get("eliminated", false)))


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s" % label)
