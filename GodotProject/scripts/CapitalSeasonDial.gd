class_name CapitalSeasonDial
extends VBoxContainer

signal season_changed(rounds: int)

const Styles = preload("res://scripts/UIStyles.gd")
const DurationEstimator = preload("res://scripts/SessionDurationEstimator.gd")
const VALUES: = [10, 16, 24, 0]
const PROFILES: = {
	10: {"name": "闪电赛", "note": "快速决策  轻量体验", "accent": Color("55c7df")}, 
	16: {"name": "标准赛", "note": "完整经营  推荐赛制", "accent": Color("e5bd5b")}, 
	24: {"name": "完整战", "note": "长期布局  深度对局", "accent": Color("9b78df")}, 
	0: {"name": "永续经营", "note": "持续发展  主动收官", "accent": Color("75dcc5")},
}

var option_buttons: Array[Button] = []
var selected_rounds: = 16
var session_mode: = "solo"
var session_seats: = 1


func _ready() -> void :
	name = "CapitalSeasonDial"
	var compact: = get_viewport_rect().size.x < 1500.0
	add_theme_constant_override("separation", 6 if compact else 10)
	var header: = HBoxContainer.new()
	header.add_child(_label("选择资本赛季", 18, Color("f0cf73")))
	var hint: = _label("四种赛程均可直接点击", 13, Color("a8c2ca"))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(hint)
	add_child(header)
	var row: = HBoxContainer.new()
	row.name = "SeasonOptions"
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	for rounds: int in VALUES:
		var profile: Dictionary = PROFILES[rounds]
		var button: = Button.new()
		button.name = "Season%d" % rounds
		button.text = _button_text(rounds)
		button.custom_minimum_size = Vector2(0, 78 if compact else 94)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("rounds", rounds)
		button.pressed.connect(_select.bind(rounds))
		button.mouse_entered.connect(_audio_hover)
		row.add_child(button)
		option_buttons.append(button)
	_refresh_styles()


func set_rounds(rounds: int) -> void :
	selected_rounds = VALUES[clampi(VALUES.find(rounds), 0, VALUES.size() - 1)] if rounds in VALUES else 16
	if is_node_ready():
		_refresh_styles()


func set_session_context(mode: String, seats: int) -> void :
	session_mode = mode
	session_seats = seats
	if is_node_ready():
		_refresh_styles()


func _select(rounds: int) -> void :
	if selected_rounds == rounds:
		return
	selected_rounds = rounds
	_refresh_styles()
	season_changed.emit(rounds)


func _refresh_styles() -> void :
	for button: Button in option_buttons:
		var rounds: = int(button.get_meta("rounds", 16))
		var selected: = rounds == selected_rounds
		var accent: Color = PROFILES[rounds].accent
		button.text = _button_text(rounds)
		Styles.apply_toy_button(button, selected, accent, 16)
		button.add_theme_color_override("font_color", Color("fff1bf") if selected else Color("d5e5e8"))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_constant_override("outline_size", 5 if selected else 3)
		button.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.04, 0.92))


func _button_text(rounds: int) -> String:
	var profile: Dictionary = PROFILES[rounds]
	if rounds == 0:
		return "∞ 回合\n%s\n%s" % [profile.name, profile.note]
	var duration: Dictionary = DurationEstimator.estimate(session_mode, rounds, session_seats)
	return "%d 回合\n%s  %s\n%s" % [rounds, profile.name, duration.label, profile.note]


func _label(text: String, size: int, color: Color) -> Label:
	var label: = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _audio_hover() -> void :
	if not is_inside_tree():
		return
	var audio: = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("hover")
