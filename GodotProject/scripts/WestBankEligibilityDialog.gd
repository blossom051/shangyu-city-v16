class_name WestBankEligibilityDialog
extends CanvasLayer

signal closed

const Styles = preload("res://scripts/UIStyles.gd")
const Institutions = preload("res://scripts/WestBankInstitutionSystem.gd")
const LOCK_BACKGROUND_PATH := "res://assets/ui/west_bank/west_bank_lock_ue58.png"

const KEYS := ["round", "asset", "operating", "risk"]
const NAMES := {
	"AuroraSpire": "曙光宏观塔",
	"HarborTwin": "港湾路演双塔",
	"TerraceHQ": "星汇财富俱乐部",
	"PearlFinance": "明珠财富大厦",
}

var landmark_id := ""
var player_id := ""
var access: Dictionary = {}


func open(value: String, active_player_id: String, eligibility_value: Dictionary = {}) -> void:
	landmark_id = value
	player_id = active_player_id
	access = eligibility_value.duplicate(true)


func _ready() -> void:
	layer = 2120
	name = "WestBankEligibilityDialog"
	_build()


func _build() -> void:
	if access.is_empty():
		access = Institutions.eligibility(player_id)
	var shade := ColorRect.new()
	shade.name = "EligibilityShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.002, 0.012, 0.022, 0.91)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 28.0
	center.offset_right = -28.0
	center.offset_top = 28.0
	center.offset_bottom = -28.0
	shade.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "EligibilityConsole"
	panel.custom_minimum_size = Vector2(1040, 690)
	panel.add_theme_stylebox_override("panel", Styles.panel(Color("061923fa"), Color("d9b657"), 32, 18))
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	panel.add_child(root)
	root.add_child(_build_hero())

	var body_margin := MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 42)
	body_margin.add_theme_constant_override("margin_right", 42)
	body_margin.add_theme_constant_override("margin_top", 24)
	body_margin.add_theme_constant_override("margin_bottom", 28)
	root.add_child(body_margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body_margin.add_child(body)

	var progress: Dictionary = access.get("progress", {})
	var met_count := 0
	for key: String in KEYS:
		if bool((progress.get(key, {}) as Dictionary).get("met", false)):
			met_count += 1
	var headline := Styles.label("解锁进度  %d / 4" % met_count, 25, Color("f6d77d"))
	body.add_child(headline)
	var bar := ProgressBar.new()
	bar.name = "EligibilityProgress"
	bar.custom_minimum_size.y = 20
	bar.max_value = 4.0
	bar.value = float(met_count)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", Styles.panel(Color("0b303b"), Color("244b55"), 10, 0))
	bar.add_theme_stylebox_override("fill", Styles.panel(Color("61cfa6"), Color("9de8c5"), 10, 0))
	body.add_child(bar)

	var rail := HBoxContainer.new()
	rail.name = "EligibilityConditionRail"
	rail.add_theme_constant_override("separation", 12)
	body.add_child(rail)
	for index in KEYS.size():
		var key: String = KEYS[index]
		var item: Dictionary = progress.get(key, {})
		rail.add_child(_condition_column(key, item))
		if index < KEYS.size() - 1:
			var divider := VSeparator.new()
			divider.modulate = Color("3e6971")
			rail.add_child(divider)

	var reason := Styles.label(str(access.get("message", "完成条件后即可进入西岸机构")), 22, Color("e9c76d"))
	reason.name = "EligibilityReason"
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.custom_minimum_size.y = 58
	body.add_child(reason)

	var close := Button.new()
	close.name = "EligibilityClose"
	close.text = "返回城市"
	close.custom_minimum_size = Vector2(0, 62)
	Styles.apply_toy_button(close, true, Color("d9b657"), 22)
	close.pressed.connect(_close)
	body.add_child(close)


func _build_hero() -> Control:
	var hero := TextureRect.new()
	hero.name = "EligibilityHero"
	hero.custom_minimum_size.y = 240
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(LOCK_BACKGROUND_PATH):
		hero.texture = load(LOCK_BACKGROUND_PATH) as Texture2D
	else:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color("0b4a5c"), Color("082836"), Color("2b2417")])
		gradient.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 1024
		texture.height = 240
		hero.texture = texture
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.005, 0.025, 0.04, 0.42)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(veil)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 24)
	hero.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	box.add_child(Styles.label("◇  西岸金融核心区", 23, Color("75dce6")))
	box.add_child(Styles.label("尚未取得地标机构通行资格", 39, Color("fff0bd")))
	box.add_child(Styles.label("%s保持开放展示；完成购地资格后即可进入专属玩法。" % str(NAMES.get(landmark_id, "当前地标")), 20, Color("dbe9e9")))
	return hero


func _condition_column(key: String, item: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.name = "EligibilityCondition_%s" % key
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 7)
	var met := bool(item.get("met", false))
	var color := Color("68d1a6") if met else Color("eea55f")
	var status := Styles.label("✓ 已达成" if met else "◇ 进行中", 18, color)
	box.add_child(status)
	box.add_child(Styles.label(str(item.get("label", key)), 21, Color("edf3f2")))
	var current := int(item.get("current", 0))
	var target := int(item.get("target", 0))
	var unit := str(item.get("unit", ""))
	var direction := str(item.get("direction", "at_least"))
	var value_text := "%d%s / ≤%d%s" % [current, unit, target, unit] if direction == "at_most" else "%d%s / %d%s" % [current, unit, target, unit]
	box.add_child(Styles.label(value_text, 27, color))
	return box


func _close() -> void:
	closed.emit()
	queue_free()
