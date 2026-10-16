extends CanvasLayer


var last_notice: Dictionary = {}
var shade: ColorRect
var card: PanelContainer
var title_label: Label
var body_label: Label
var close_button: Button
var modal_token: = 0


func _ready() -> void :
	layer = 1100
	_build()
	visible = false
	set_process_unhandled_input(true)


func show_notice(title: String, body: String, button_text: = "我知道了") -> void :
	_build()
	last_notice = {"title": title, "body": body}
	title_label.text = title
	body_label.text = body
	close_button.text = button_text
	visible = true
	if not ModalManager.is_blocked():
		modal_token = ModalManager.open_modal("feedback_notice", self, shade, self)
	close_button.grab_focus.call_deferred()


func close() -> void :
	visible = false
	ModalManager.close_modal(modal_token, "feedback_acknowledged")
	modal_token = 0


func on_modal_force_close() -> void :
	visible = false
	modal_token = 0


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void :
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build() -> void :
	if shade != null:
		return
	shade = ColorRect.new()
	shade.name = "CenteredNoticeShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.004, 0.015, 0.025, 0.74)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	card = PanelContainer.new()
	card.name = "CenteredNoticeCard"
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-250, -155)
	card.size = Vector2(500, 310)
	var style: = StyleBoxFlat.new()
	style.bg_color = Color("0b2633")
	style.border_color = Color("d6ad54")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 26
	style.content_margin_bottom = 24
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 18
	card.add_theme_stylebox_override("panel", style)
	shade.add_child(card)
	var stack: = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 18)
	card.add_child(stack)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color("f2d27d"))
	stack.add_child(title_label)
	body_label = Label.new()
	body_label.custom_minimum_size = Vector2(0, 112)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.add_theme_font_size_override("font_size", 18)
	body_label.add_theme_color_override("font_color", Color("edf4f5"))
	stack.add_child(body_label)
	close_button = Button.new()
	close_button.name = "Acknowledge"
	close_button.custom_minimum_size = Vector2(190, 52)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	stack.add_child(close_button)
