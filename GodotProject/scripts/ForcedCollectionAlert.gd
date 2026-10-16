class_name ForcedCollectionAlert
extends Control

const Styles = preload("res://scripts/UIStyles.gd")

signal acknowledged(alert: Dictionary)

var payload: Dictionary = {}
var modal_token: = 0


func open_alert(value: Dictionary) -> void :
	payload = value.duplicate(true)


func _ready() -> void :
	name = "ForcedCollectionAlert"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1400
	add_to_group("managed_modal_owner")
	_build()
	modal_token = ModalManager.open_modal("forced_collection", self, self)
	tree_exiting.connect( func() -> void : ModalManager.close_modal(modal_token, "forced_collection_acknowledged"))
	AudioManager.risk_warning()


func _build() -> void :
	var shade: = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.07, 0.008, 0.015, 0.86)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var panel: = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-360, -270)
	panel.size = Vector2(720, 540)
	panel.add_theme_stylebox_override("panel", _alert_panel())
	shade.add_child(panel)
	var body: = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	panel.add_child(body)
	var header: = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 16)
	body.add_child(header)
	var badge: = Label.new()
	badge.text = "!"
	badge.custom_minimum_size = Vector2(82, 82)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 50)
	badge.add_theme_color_override("font_color", Color("fff2d1"))
	badge.add_theme_stylebox_override("normal", Styles.panel(Color("c83f4d"), Color("ff9b79"), 41, 4))
	header.add_child(badge)
	var titles: = VBoxContainer.new()
	titles.add_child(Styles.label("BANK ENFORCEMENT  银行强制执行", 14, Color("ffb18d")))
	titles.add_child(Styles.label("连续三期逾期  司法拍卖告知", 32, Color("fff0da")))
	header.add_child(titles)
	var asset: = Styles.label(str(payload.get("asset_name", "城市经营资产")), 26, Color("f5d27a"))
	asset.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asset.add_theme_stylebox_override("normal", Styles.toy_card(Color("3c141e"), true))
	asset.custom_minimum_size.y = 72
	body.add_child(asset)
	var facts: = GridContainer.new()
	facts.columns = 3
	facts.add_theme_constant_override("h_separation", 10)
	body.add_child(facts)
	_add_fact(facts, "连续逾期", "%d / 3 期" % int(payload.get("overdue_count", 0)), Color("ff8d78"))
	_add_fact(facts, "待清偿", Styles.money(int(payload.get("outstanding_total", 0))), Color("f2c96c"))
	_add_fact(facts, "当前风险", str(payload.get("risk", 0)), Color("f06b73"))
	var rules: = VBoxContainer.new()
	rules.add_theme_constant_override("separation", 7)
	rules.add_child(_rule("01", "确认后抵押资产进入其他财团的司法竞拍"))
	rules.add_child(_rule("02", "处置完成只核销抵押本金，利息与逾期费仍须偿还"))
	rules.add_child(_rule("03", "剩余息费三回合未清将宣告破产并退出本轮"))
	body.add_child(rules)
	var warning: = Styles.label("新贷款与竞拍资格立即冻结；剩余息费结清前，每回合继续增加风险。", 17, Color("ffd4c2"))
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(warning)
	var confirm: = Button.new()
	confirm.name = "ConfirmEnforcement"
	confirm.text = "确认司法执行  进入下一回合"
	confirm.custom_minimum_size = Vector2(320, 58)
	confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Styles.apply_toy_button(confirm, true, Color("d94d58"), 18)
	confirm.pressed.connect(_confirm)
	body.add_child(confirm)


func _add_fact(parent: GridContainer, title: String, value: String, accent: Color) -> void :
	var card: = VBoxContainer.new()
	card.custom_minimum_size = Vector2(0, 76)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(Styles.label(title, 13, Color("c9aab0")))
	card.add_child(Styles.label(value, 24, accent))
	parent.add_child(card)


func _rule(number: String, text: String) -> Control:
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var badge: = Styles.label(number, 16, Color("f3c86b"))
	badge.custom_minimum_size.x = 36
	row.add_child(badge)
	var copy: = Styles.label(text, 16, Color("e8dadd"))
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	return row


func _confirm() -> void :
	payload.acknowledged = true
	acknowledged.emit(payload.duplicate(true))
	queue_free()


func _alert_panel() -> StyleBoxFlat:
	var style: = Styles.panel(Color("260d16"), Color("e75a62"), 26, 5)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 28
	style.content_margin_bottom = 26
	style.shadow_color = Color(0.4, 0.0, 0.03, 0.72)
	style.shadow_size = 28
	return style
