class_name StartupResultDialog
extends Control

const Styles = preload("res://scripts/UIStyles.gd")

var notice: Dictionary = {}
var modal_token: = 0


func open_result(value: Dictionary) -> void :
	notice = value.duplicate(true)


func _ready() -> void :
	name = "StartupResultDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 435
	add_to_group("managed_modal_owner")
	modal_token = ModalManager.open_modal("startup_result", self, self)
	tree_exiting.connect( func() -> void : ModalManager.close_modal(modal_token, "startup_result_closed"))
	_build()


func _build() -> void :
	var success: = str(notice.get("outcome", "failure")) == "success"
	var accent: = Color("72dfb0") if success else Color("ef7782")
	var shade: = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.025, 0.045, 0.8)
	add_child(shade)
	var panel: = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-390, -260)
	panel.size = Vector2(780, 520)
	panel.add_theme_stylebox_override("panel", Styles.panel(Color("071d2af7"), accent, 22, 3))
	add_child(panel)
	var margin: = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 34)
	panel.add_child(margin)
	var stack: = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	margin.add_child(stack)
	stack.add_child(_label("VENTURE EXIT  /  创投到期揭晓", 15, accent))
	stack.add_child(_label(str(notice.get("project_name", "创业项目")), 34, Color("f4f6f4")))
	stack.add_child(_label("投资成功" if success else "尽调失败", 27, accent))
	var accounting: = "投入 %d万    融资到账 %d万    估值增加 %d万\n本项目损益 %s%d万    风险 %s%d" % [
		int(notice.get("cost", 0)), int(notice.get("cash_return", 0)), int(notice.get("valuation_gain", 0)), 
		"+" if int(notice.get("profit_loss", 0)) >= 0 else "", int(notice.get("profit_loss", 0)), 
		"+" if int(notice.get("risk_change", 0)) > 0 else "", int(notice.get("risk_change", 0)), 
	]
	var accounting_label: = _label(accounting, 20, Color("d8e5e6"))
	accounting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	accounting_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(accounting_label)
	var note: = "项目完成融资退出，回款与估值已计入本轮结算。" if success else "项目本金已损失，风险上升；本次经验会提高后续项目判断空间。"
	stack.add_child(_label(note, 17, Color("a9c2c8")))
	var button: = Button.new()
	button.text = "确认投决结果"
	button.custom_minimum_size = Vector2(260, 58)
	Styles.apply_toy_button(button, true, accent, 18)
	button.pressed.connect(queue_free)
	stack.add_child(button)


func _label(value: String, size: int, color: Color) -> Label:
	var label: = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
