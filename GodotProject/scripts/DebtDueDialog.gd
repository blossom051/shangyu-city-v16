class_name DebtDueDialog
extends Control

signal open_bank

const Styles = preload("res://scripts/UIStyles.gd")
var notice: Dictionary = {}
var modal_token: = 0


func open_notice(value: Dictionary) -> void :
	notice = value


func _ready() -> void :
	name = "DebtDueDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 430
	add_to_group("managed_modal_owner")
	modal_token = ModalManager.open_modal("bank_due_notice", self, self)
	tree_exiting.connect( func() -> void : ModalManager.close_modal(modal_token, "debt_due_closed"))
	_build()


func _build() -> void :
	var shade: = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.035, 0.05, 0.72)
	add_child(shade)
	var panel: = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-360, -300)
	panel.size = Vector2(720, 600)
	panel.add_theme_stylebox_override("panel", Styles.toy_panel())
	add_child(panel)
	var stack: = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 15)
	panel.add_child(stack)
	var title: = Label.new()
	title.text = "本回合贷款到期提醒"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Styles.TOY_INK)
	stack.add_child(title)
	var totals: = Label.new()
	totals.text = "应还本金  %d 万\n应付利息  %d 万\n逾期费用  %d 万\n本轮合计  %d 万\n当前现金  %d 万\n资金缺口  %d 万" % [int(notice.get("principal_due", 0)), int(notice.get("interest_due", 0)), int(notice.get("overdue_fee_due", 0)), int(notice.get("total_due", 0)), int(notice.get("cash", 0)), int(notice.get("shortfall", 0))]
	totals.add_theme_font_size_override("font_size", 21)
	totals.add_theme_color_override("font_color", Styles.TOY_INK)
	stack.add_child(totals)
	var consequence: = Label.new()
	consequence.text = str(notice.get("consequence", "本期不会自动扣款；未在银行主动缴纳就会进入逾期。"))
	consequence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	consequence.add_theme_font_size_override("font_size", 17)
	consequence.add_theme_color_override("font_color", Color("c34f59") if int(notice.get("shortfall", 0)) > 0 else Color("398a69"))
	stack.add_child(consequence)
	var detail: = Label.new()
	detail.text = str(notice.get("loan_lines", ""))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_font_size_override("font_size", 15)
	detail.add_theme_color_override("font_color", Styles.TOY_MUTED)
	stack.add_child(detail)
	var actions: = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	stack.add_child(actions)
	var later: = Button.new()
	later.text = "稍后筹资"
	later.custom_minimum_size = Vector2(180, 54)
	Styles.apply_toy_button(later, false, Styles.TOY_BLUE, 18)
	later.pressed.connect(queue_free)
	actions.add_child(later)
	var bank: = Button.new()
	bank.text = "前往银行处理"
	bank.custom_minimum_size = Vector2(220, 54)
	Styles.apply_toy_button(bank, true, Styles.TOY_YELLOW, 18)
	bank.pressed.connect( func() -> void : open_bank.emit();queue_free())
	actions.add_child(bank)
