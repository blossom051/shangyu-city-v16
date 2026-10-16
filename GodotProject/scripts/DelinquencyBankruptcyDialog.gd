class_name DelinquencyBankruptcyDialog
extends Control

const Styles = preload("res://scripts/UIStyles.gd")

signal confirmed

var payload: Dictionary = {}
var modal_token: = 0


func open(value: Dictionary) -> void :
	payload = value.duplicate(true)


func _ready() -> void :
	name = "DelinquencyBankruptcyDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1800
	add_to_group("managed_modal_owner")
	_build()
	modal_token = ModalManager.open_modal("delinquency_bankruptcy", self, self)
	tree_exiting.connect( func() -> void : ModalManager.close_modal(modal_token, "bankruptcy_confirmed"))
	AudioManager.risk_warning()


func _build() -> void :
	var risk_failure: = str(payload.get("category", "")) == "critical_risk"
	var shade: = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.045, 0.004, 0.012, 0.93)
	add_child(shade)
	var panel: = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-350, -235)
	panel.size = Vector2(700, 470)
	panel.add_theme_stylebox_override("panel", _panel_style())
	shade.add_child(panel)
	var body: = VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 18)
	panel.add_child(body)
	var kicker: = Styles.label("RISK LIQUIDATION  极限风险清算" if risk_failure else "JUDICIAL DEFAULT  司法失信裁定", 14, Color("ff9b8b"))
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(kicker)
	var title: = Styles.label("本轮经营资格终止", 38, Color("fff0df"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(title)
	var rule: = ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = Color("d54b59")
	body.add_child(rule)
	var reason: = Styles.label(str(payload.get("reason", "经营资格终止")), 23, Color("f2c06e"))
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(reason)
	var message: = Styles.label(str(payload.get("message", "按期履约与及时清偿，是资本经营的基本责任。")), 18, Color("e9d9d3"))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.custom_minimum_size = Vector2(560, 104)
	body.add_child(message)
	var confirm: = Button.new()
	confirm.text = "确认提醒  返回首页" if bool(payload.get("solo", false)) else "确认提醒  继续本局"
	confirm.custom_minimum_size = Vector2(320, 58)
	confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Styles.apply_toy_button(confirm, true, Color("cf4854"), 19)
	confirm.pressed.connect( func() -> void :
		confirmed.emit()
		queue_free())
	body.add_child(confirm)


func _panel_style() -> StyleBoxFlat:
	var style: = Styles.panel(Color("220b14"), Color("e25b65"), 28, 4)
	style.content_margin_left = 44
	style.content_margin_right = 44
	style.content_margin_top = 34
	style.content_margin_bottom = 32
	style.shadow_color = Color(0.45, 0.0, 0.03, 0.78)
	style.shadow_size = 30
	return style
