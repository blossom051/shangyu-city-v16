class_name StartupProjectCard
extends Button

const FOUNDER_ATLAS = preload("res://assets/images/v12/startup_founders_atlas.png")
const Styles = preload("res://scripts/UIStyles.gd")

var project: Dictionary = {}
var invested: = false
var action_label: Label


func setup(value: Dictionary) -> void :
	project = value
	text = ""
	custom_minimum_size = Vector2(300, 382)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	tooltip_text = "%s｜%s\n%s" % [str(project.get("founder", "创始人")), str(project.get("founder_role", "创业者")), str(project.get("founder_tagline", ""))]
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_build_project_object()
	pivot_offset = custom_minimum_size * 0.5
	mouse_entered.connect( func() -> void :
		if not _reduced_motion(): create_tween().tween_property(self, "scale", Vector2(1.025, 1.025), 0.13).set_trans(Tween.TRANS_QUAD)
	)
	mouse_exited.connect( func() -> void :
		if not _reduced_motion(): create_tween().tween_property(self, "scale", Vector2.ONE, 0.13)
	)


func set_invested() -> void :
	invested = true
	disabled = true
	if action_label != null:
		action_label.text = "● 已进入尽调管线"
		action_label.add_theme_color_override("font_color", Color("63d6a3"))


func founder_portrait_region() -> Rect2:
	var index: = clampi(int(str(project.get("id", "sp01")).trim_prefix("sp")) - 1, 0, 5)
	var cell: = Vector2(float(FOUNDER_ATLAS.get_width()) / 3.0, float(FOUNDER_ATLAS.get_height()) / 2.0)
	return Rect2(Vector2((index % 3) * cell.x, (index / 3) * cell.y), cell)


func _build_project_object() -> void :
	var accent: = _risk_color(str(project.get("risk", "中")))
	var shell: = PanelContainer.new();shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shell.mouse_filter = Control.MOUSE_FILTER_IGNORE;shell.add_theme_stylebox_override("panel", Styles.panel(Color("071f2bf5"), accent, 20, 2));add_child(shell)
	var stack: = VBoxContainer.new();stack.add_theme_constant_override("separation", 7);shell.add_child(stack)
	var image: = TextureRect.new();image.custom_minimum_size = Vector2(0, 190);image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var atlas: = AtlasTexture.new();atlas.atlas = FOUNDER_ATLAS;atlas.region = founder_portrait_region();image.texture = atlas;stack.add_child(image)
	var identity: = HBoxContainer.new();identity.add_theme_constant_override("separation", 8);stack.add_child(identity)
	var founder: = Styles.label("%s\n%s" % [str(project.get("founder", "创始人")), str(project.get("founder_role", "创业者"))], 17, Color("f0eadb"));founder.size_flags_horizontal = Control.SIZE_EXPAND_FILL;identity.add_child(founder)
	var sector: = Styles.label(str(project.get("sector", "创新")).to_upper(), 13, accent);sector.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT;identity.add_child(sector)
	var name: = Styles.label(str(project.get("name", "城市创新项目")), 22, Color("f4e6bd"));stack.add_child(name)
	var metrics: = HBoxContainer.new();metrics.add_theme_constant_override("separation", 10);stack.add_child(metrics)
	for spec: Array in [["估值", "%d万" % roundi(float(project.get("cost", 0)) * float(project.get("financing_multiplier", 1.0)))], ["成功率", "%d%%" % roundi(float(project.get("base_success", 0.0)) * 100.0)], ["风险", str(project.get("risk", "中"))], ["周期", "%d回合" % int(project.get("delay", 2))]]:
		var item: = VBoxContainer.new();item.size_flags_horizontal = Control.SIZE_EXPAND_FILL; var k: = Styles.label(str(spec[0]), 12, Color("96afb7"));k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;item.add_child(k); var v: = Styles.label(str(spec[1]), 16, accent);v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;item.add_child(v);metrics.add_child(item)
	action_label = Styles.label("查看项目详情  →", 14, Color("f0d27d"));action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;stack.add_child(action_label)


func _risk_color(value: String) -> Color:
	if value.contains("高"): return Color("e67a82")
	if value.contains("低"): return Color("63d6a3")
	return Color("e2bd66")


func _reduced_motion() -> bool:
	var settings: Node = Engine.get_main_loop().root.get_node_or_null("GameSettings")
	return bool(settings.get("reduce_motion")) if settings != null else false
