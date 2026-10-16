class_name EconomicCycleDialog
extends CanvasLayer

const Styles = preload("res://scripts/UIStyles.gd")
var modal_token := 0


func _ready() -> void:
	layer = 2200
	var surface := Control.new(); surface.name = "Surface"; surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); surface.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(surface)
	var shade := ColorRect.new(); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.color = Color(0.005, 0.02, 0.035, 0.76); surface.add_child(shade)
	var panel := PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_CENTER); panel.position = Vector2(-420, -290); panel.size = Vector2(840, 580); panel.add_theme_stylebox_override("panel", Styles.panel(Color("071e2af8"), Color("61b9c9"), 22, 28)); surface.add_child(panel)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 15); panel.add_child(box)
	var cycle := EndlessOperationsSystem.current_cycle()
	var current_round := int(GameState.game_data.get("round", 0))
	box.add_child(Styles.label("经济周期  %s期" % str(cycle.get("name", "常态")), 31, Color("f1d681")))
	box.add_child(Styles.label("当前阶段预计持续至第 %d 回合  还剩 %d 回合" % [int(cycle.get("ends_round", current_round)), maxi(0, int(cycle.get("ends_round", current_round)) - current_round + 1)], 19, Color("d0e0e2")))
	box.add_child(Styles.label("规则：复苏 → 上行 → 过热 → 调整固定轮动；每阶段随机持续 4–7 回合", 18, Color("72d1dc")))
	var effects := HBoxContainer.new(); effects.add_theme_constant_override("separation", 12); box.add_child(effects)
	effects.add_child(_metric("建设工期", _signed_round(int(cycle.get("build_delta", 0))), Color("71c8d5")))
	effects.add_child(_metric("创投成功", _signed_percent(float(cycle.get("startup_rate", 0.0))), Color("67d2ad") if float(cycle.get("startup_rate", 0.0)) >= 0 else Color("e87982")))
	effects.add_child(_metric("包装风险", "%d%%" % roundi(float(cycle.get("fraud_rate", 0.0)) * 100.0), Color("e87982")))
	box.add_child(Styles.label("四阶段影响对照", 22, Color("edf3f2")))
	for phase: Dictionary in EndlessOperationsSystem.CYCLE_PHASES:
		var active := str(phase.get("id", "")) == str(cycle.get("phase", ""))
		var line := Styles.label("%s  %s期    建设 %s    创投 %s    包装风险 %d%%" % ["●" if active else "○", str(phase.get("name", "")), _signed_round(int(phase.get("build_delta", 0))), _signed_percent(float(phase.get("startup_rate", 0.0))), roundi(float(phase.get("fraud_rate", 0.0)) * 100.0)], 19, Color("f1d681") if active else Color("b9cdd0")); box.add_child(line)
	var close := Button.new(); close.text = "知道了"; close.custom_minimum_size = Vector2(0, 52); Styles.apply_toy_button(close, true, Styles.TOY_YELLOW, 18); close.pressed.connect(queue_free); box.add_child(close)
	modal_token = ModalManager.open_modal("economic_cycle", self, surface, self)
	tree_exiting.connect(func() -> void: ModalManager.close_modal(modal_token, "economic_cycle_closed"))


func _metric(title: String, value: String, accent: Color) -> Control:
	var panel := PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; panel.add_theme_stylebox_override("panel", Styles.panel(Color("0a2b35db"), accent, 13, 12)); var box := VBoxContainer.new(); panel.add_child(box); var k := Styles.label(title, 14, Color("9db3b7")); k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(k); var v := Styles.label(value, 22, accent); v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(v); return panel


func _signed_round(value: int) -> String:
	return "不变" if value == 0 else "%s%d 回合" % ["+" if value > 0 else "", value]


func _signed_percent(value: float) -> String:
	return "不变" if is_zero_approx(value) else "%s%d%%" % ["+" if value > 0 else "", roundi(value * 100.0)]


func on_modal_force_close() -> void:
	queue_free()
