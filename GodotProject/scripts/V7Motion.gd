class_name V7Motion
extends RefCounted

static func bind_button(button: Button, hover_scale: = 1.07) -> void :
	button.pivot_offset = button.custom_minimum_size * 0.5
	if not button.has_meta("v7_motion_bound"):
		button.set_meta("v7_motion_bound", true)
		button.mouse_entered.connect(_button_hover.bind(button, hover_scale, true))
		button.mouse_exited.connect(_button_hover.bind(button, hover_scale, false))
		button.pressed.connect(_button_press.bind(button))

static func _button_hover(button: Button, hover_scale: float, entered: bool) -> void :
	if is_instance_valid(button):
		var tween: = button.create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2.ONE * (hover_scale if entered else 1.0), 0.14)

static func _button_press(button: Button) -> void :
	if is_instance_valid(button):
		var tween: = button.create_tween()
		tween.tween_property(button, "scale", Vector2.ONE * 0.94, 0.05)
		tween.tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func fade_slide_in(ctrl: Control, offset: = Vector2(0, 26), duration: = 0.24) -> void :
	ctrl.modulate.a = 0.0
	ctrl.position += offset
	var tween: = ctrl.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(ctrl, "modulate:a", 1.0, duration)
	tween.tween_property(ctrl, "position", ctrl.position - offset, duration)

static func pulse(ctrl: Control, strength: = 0.035, speed: = 3.0) -> void :
	ctrl.set_meta("v7_pulse_strength", strength)
	ctrl.set_meta("v7_pulse_speed", speed)
