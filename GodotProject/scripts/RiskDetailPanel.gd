class_name RiskDetailPanel
extends Control

signal closed

const Styles = preload("res://scripts/UIStyles.gd")
const Risks = preload("res://scripts/RiskSystem.gd")
const Bank = preload("res://scripts/BankSystem.gd")

var player_id: = ""
var modal_token: = 0
var status_label: Label
var close_notified: = false


func open_for_player(value: String) -> void :
	player_id = value


func _ready() -> void :
	name = "RiskDetailPanel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 760
	add_to_group("managed_modal_owner")
	modal_token = ModalManager.open_modal("risk_detail", self, self)
	tree_exiting.connect(_on_tree_exiting)
	_build()


func _on_tree_exiting() -> void :
	ModalManager.close_modal(modal_token, "risk_detail_closed")
	if not close_notified:
		close_notified = true
		closed.emit()


func _close_panel() -> void :
	AudioManager.cancel()
	queue_free()


func on_modal_force_close() -> void :
	queue_free()


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_panel()


func _build() -> void :
	var profile: = Risks.profile(player_id)
	var player: = GameState.player(player_id)
	var bank: = Bank.loan_summary(player_id)
	var shade: = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.02, 0.03, 0.84)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var panel: = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 42
	panel.offset_top = 34
	panel.offset_right = -42
	panel.offset_bottom = -34
	panel.add_theme_stylebox_override("panel", Styles.panel(Color("071f2b"), Color(profile.get("tier_color", Color("d6ad54"))), 26, 4))
	add_child(panel)
	var margin: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	panel.add_child(margin)
	var layout: = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	_build_header(layout, profile)
	var columns: = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 18)
	layout.add_child(columns)
	_build_gauge_column(columns, profile)
	_build_source_column(columns, profile)
	_build_action_console(columns, profile, player, bank)
	_build_recent_strip(layout, profile)
	status_label = Styles.label("治理动作会立即结算现金与风险，并写入最近变化。", 15, Color("9fb9c1"))
	status_label.name = "ActionStatus"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(status_label)


func _build_header(parent: VBoxContainer, profile: Dictionary) -> void :
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	var identity: = VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(Styles.label("RISK CONTROL  城市风控中心", 13, Color("77c7d1")))
	identity.add_child(Styles.label("经营安全态势", 31, Color("f4ead8")))
	row.add_child(identity)
	var tier: = Styles.label("风险 %d  %s" % [int(profile.get("score", 0)), str(profile.get("tier", "稳健"))], 24, Color(profile.get("tier_color", Color("64c89b"))));tier.custom_minimum_size.x = 310;tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT;tier.vertical_alignment = VERTICAL_ALIGNMENT_CENTER;row.add_child(tier)
	var close: = Button.new();close.name = "CloseRisk";close.text = "返回城市";close.custom_minimum_size = Vector2(132, 48);Styles.apply_toy_button(close, false, Styles.TOY_BLUE, 17);close.pressed.connect(_close_panel);row.add_child(close)


func _build_gauge_column(parent: HBoxContainer, profile: Dictionary) -> void :
	var surface: = PanelContainer.new();surface.name = "RiskGaugeCommand";surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL;surface.add_theme_stylebox_override("panel", Styles.panel(Color("0b2a36"), Color(profile.get("tier_color", Color("64c89b"))), 24, 2));parent.add_child(surface)
	var box: = VBoxContainer.new();box.alignment = BoxContainer.ALIGNMENT_CENTER;box.add_theme_constant_override("separation", 14);surface.add_child(box)
	box.add_child(Styles.label("风险仪表", 20, Color("efcb72")))
	var score: = int(profile.get("score", 0)); var dial: = ProgressBar.new();dial.name = "RiskGauge";dial.max_value = 100;dial.value = score;dial.show_percentage = false;dial.custom_minimum_size = Vector2(0, 34);dial.add_theme_stylebox_override("background", Styles.panel(Color("102f3b"), Color("294d59"), 17, 1));dial.add_theme_stylebox_override("fill", Styles.panel(Color(profile.get("tier_color", Color("64c89b"))), Color("f2d27b"), 17, 2));box.add_child(dial)
	var score_label: = Styles.label("%d / 100\n%s" % [score, str(profile.get("tier", "稳健"))], 42, Color(profile.get("tier_color", Color("64c89b"))));score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;box.add_child(score_label)
	var round_change: = int(profile.get("round_change", 0)); var movement: = Styles.label("本轮变化  %s%d\n%s" % ["+" if round_change > 0 else "", round_change, str(profile.get("next_tier", "维持当前风险档"))], 16, Color("ef7777") if round_change > 0 else Color("64c89b"));movement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;movement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;box.add_child(movement)


func _build_source_column(parent: HBoxContainer, profile: Dictionary) -> void :
	var surface: = PanelContainer.new()
	surface.name = "RiskSourceMap"
	surface.custom_minimum_size.x = 420
	surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface.add_theme_stylebox_override("panel", Styles.panel(Color("081f2a"), Color("5a8792"), 24, 2))
	parent.add_child(surface)
	var margin: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	surface.add_child(margin)
	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	box.add_child(Styles.label("风险来源", 22, Color("f3ce73")))
	var intro: = Styles.label("每项成本如何影响你的资产、授信与下一次交易", 14, Color("b9ced3"))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)
	for impact: Dictionary in profile.get("impacts", []):
		var card: = PanelContainer.new()
		card.add_theme_stylebox_override("panel", Styles.panel(Color("102f3a"), Color("3f6973"), 14, 1))
		var card_margin: = MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 13)
		card_margin.add_theme_constant_override("margin_right", 13)
		card_margin.add_theme_constant_override("margin_top", 9)
		card_margin.add_theme_constant_override("margin_bottom", 9)
		card.add_child(card_margin)
		var content: = VBoxContainer.new()
		content.add_theme_constant_override("separation", 4)
		card_margin.add_child(content)
		var row: = HBoxContainer.new()
		var label: = Styles.label(str(impact.get("label", "经营风险")), 17, Color("f3f0e7"))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var display: = Styles.label(str(impact.get("display", "0")), 23, Color("f0b95d"))
		display.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(display)
		content.add_child(row)
		var note: = Styles.label(str(impact.get("note", "")), 14, Color("b5c9ce"))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(note)
		box.add_child(card)


func _build_recent_strip(parent: VBoxContainer, profile: Dictionary) -> void :
	var strip: = HBoxContainer.new();strip.name = "RecentRiskChanges";strip.add_theme_constant_override("separation", 8);parent.add_child(strip)
	var title: = Styles.label("最近变化", 16, Color("efcb72"));title.custom_minimum_size.x = 110;title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER;strip.add_child(title)
	var entries: Array = profile.get("recent", [])
	if entries.is_empty():
		var stable: = Styles.label("暂无新增风险  当前经营态势稳定", 15, Color("64c89b"));stable.size_flags_horizontal = Control.SIZE_EXPAND_FILL;strip.add_child(stable);return
	for entry: Dictionary in entries.slice(0, 4):
		var amount: = int(entry.get("amount", 0)); var chip: = Styles.label("%+d  %s" % [amount, str(entry.get("reason", "风险变化"))], 13, Color("ef8078") if amount > 0 else Color("64c89b"));chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL;chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;chip.add_theme_stylebox_override("normal", Styles.toy_card(Color("163640"), false));strip.add_child(chip)


func _build_action_console(parent: HBoxContainer, profile: Dictionary, player: Dictionary, bank: Dictionary) -> void :
	var console: = PanelContainer.new()
	console.name = "RiskActionConsole"
	console.custom_minimum_size.x = 365
	console.add_theme_stylebox_override("panel", Styles.panel(Color("102a35"), Color("d0a94f"), 20, 3))
	parent.add_child(console)
	var box: = VBoxContainer.new();box.add_theme_constant_override("separation", 12);console.add_child(box)
	box.add_child(Styles.label("治理操作台", 21, Color("f0cf76")))
	var debt_status: = "无逾期  授信可用 %s" % Styles.money(int(bank.get("available_credit", 0))) if int(bank.get("overdue_count", 0)) <= 0 else "逾期 %d 笔  本轮应付 %s" % [int(bank.get("overdue_count", 0)), Styles.money(int(bank.get("total_due", 0)))]
	var debt: = Styles.label(debt_status, 16, Color("64c89b") if int(bank.get("overdue_count", 0)) <= 0 else Color("ef756f"));debt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;debt.add_theme_stylebox_override("normal", Styles.toy_card(Color("173b48"), int(bank.get("overdue_count", 0)) > 0));box.add_child(debt)
	for option: Dictionary in Risks.governance_options(player_id):
		_add_governance_action(box, option)
	var cash: = Styles.label("可用现金 %s  风险底线 %d" % [Styles.money(int(player.get("cash", 0))), int(profile.get("delinquency_floor", 0))], 14, Color("9fb6bf"));cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;box.add_child(cash)


func _add_governance_action(parent: VBoxContainer, option: Dictionary) -> void :
	var button: = Button.new()
	button.name = str(option.get("id", "governance")).to_pascal_case()
	button.custom_minimum_size = Vector2(0, 72)
	var redirect: = str(option.get("redirect", "")) == "bank"
	var reason: = str(option.get("disabled_reason", ""))
	button.text = "%s\n%s" % [str(option.get("title", "风险治理")), reason if not reason.is_empty() else "前往银行处理真实账单" if redirect else "支付 %d 万  风险 -%d" % [int(option.get("cost", 0)), int(option.get("risk_reduction", 0))]]
	button.disabled = bool(option.get("disabled", false))
	button.tooltip_text = reason if not reason.is_empty() else str(option.get("description", ""))
	Styles.apply_toy_button(button, redirect, Color("d4ad51") if redirect else Color("397fa2"), 15)
	button.pressed.connect(_perform_governance.bind(str(option.get("id", ""))))
	parent.add_child(button)


func _perform_governance(action_id: String) -> void :
	var result: = Risks.perform_governance(player_id, action_id)
	if str(result.get("redirect", "")) == "bank":
		queue_free()
		GameFlow.open_city_system("res://scenes/BankPanel.tscn", {"source": "risk_control"})
		return
	if not bool(result.get("ok", false)):
		if status_label != null:
			status_label.text = str(result.get("message", "当前无法执行该治理动作"))
			status_label.add_theme_color_override("font_color", Color("ef7777"))
		return
	AudioManager.success()
	for child: Node in get_children():
		child.queue_free()
	call_deferred("_rebuild_after_governance")


func _rebuild_after_governance() -> void :
	await get_tree().process_frame
	if is_inside_tree():
		_build()


func presentation_profile() -> Dictionary:
	return {"gauge": true, "impact_cards": 4, "action_console": true, "disabled_reasons": true}
