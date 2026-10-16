class_name ModeTile
extends Button

const DurationEstimator = preload("res://scripts/SessionDurationEstimator.gd")
const DISPLAY_FONT: Font = preload("res://Themes/V9141DisplayFont.tres")
const BODY_FONT: Font = preload("res://Themes/V9141BodyMediumFont.tres")
const MODE_ICONS: = {
	"solo": preload("res://assets/images/v131/mode_icons/solo_management.png"), 
	"ai": preload("res://assets/images/v131/mode_icons/human_vs_ai.png"), 
	"multi": preload("res://assets/images/v131/mode_icons/local_boardroom.png"), 
}

var title: = ""
var subtitle: = ""
var mode_color: = Color("62b7bb")
var selected: = false
var mode_id: = "solo"
var rounds: = 16
var seats: = 1


func setup(next_title: String, next_subtitle: String, color: Color, next_mode: = "solo") -> void :
	title = next_title
	subtitle = next_subtitle
	mode_color = color
	mode_id = next_mode
	text = ""
	custom_minimum_size = Vector2(0, 174)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pivot_offset = custom_minimum_size * 0.5
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	queue_redraw()


func set_selected(value: bool) -> void :
	selected = value
	queue_redraw()


func set_session_context(next_rounds: int, next_seats: int) -> void :
	rounds = next_rounds
	seats = 1 if mode_id == "solo" else next_seats
	queue_redraw()


func _draw() -> void :
	var compact: = size.y < 165.0
	var rect: = Rect2(4, 4, size.x - 8, size.y - 8)
	var box: = StyleBoxFlat.new()
	box.bg_color = Color(0.018, 0.07, 0.094, 0.98) if not selected else Color(mode_color, 0.2)
	box.border_color = Color("e4bd5b") if selected else Color(mode_color, 0.76)
	box.set_border_width_all(3 if selected else 2)
	box.set_corner_radius_all(14)
	box.corner_detail = 7
	if selected:
		box.shadow_color = Color(mode_color, 0.36)
		box.shadow_size = 16
	draw_style_box(box, rect)
	draw_rect(Rect2(rect.position + Vector2(0, 0), Vector2(9, rect.size.y)), Color(mode_color, 0.92), true)
	var icon_rect: = Rect2(13, 13 if compact else 16, 70, 70)
	draw_circle(icon_rect.get_center(), 39, Color(mode_color, 0.12))
	var icon: = MODE_ICONS.get(mode_id) as Texture2D
	if icon != null:
		draw_texture_rect(icon, icon_rect, false, Color.WHITE)
	draw_string(DISPLAY_FONT, Vector2(91, 36 if compact else 40), title, HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 111), 22, Color("fff5df"))
	draw_string(BODY_FONT, Vector2(91, 59 if compact else 65), subtitle, HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 111), 13, Color("bfd2d8"))
	var specs: = _mode_specs()
	var divider_y: = 74.0 if compact else 84.0
	draw_rect(Rect2(20, divider_y, size.x - 40, 1), Color(mode_color, 0.45), true)
	draw_string(BODY_FONT, Vector2(24, 96 if compact else 108), str(specs.players), HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 48), 13, Color("e1ecee"))
	draw_string(BODY_FONT, Vector2(24, 116 if compact else 130), str(specs.audience), HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 48), 12, Color("e5c56d") if selected else Color(mode_color).lightened(0.25))
	var duration: Dictionary = DurationEstimator.estimate(mode_id, rounds, seats)
	draw_string(BODY_FONT, Vector2(24, 138 if compact else 154), str(duration.label), HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 48), 13, Color("7ad7df"))
	if selected:
		var badge: = StyleBoxFlat.new()
		badge.bg_color = Color("0b2935")
		badge.border_color = Color("f2d274")
		badge.set_border_width_all(1)
		badge.set_corner_radius_all(9)
		draw_style_box(badge, Rect2(size.x - 80, 16, 58, 25))
		draw_string(BODY_FONT, Vector2(size.x - 72, 34), "已入席", HORIZONTAL_ALIGNMENT_LEFT, 58, 12, Color("f2d274"))


func _mode_specs() -> Dictionary:
	if title == "单人经营":
		return {"players": "1 名董事  自由练习", "audience": "熟悉规则与经营节奏"}
	if title == "人机对战":
		return {"players": "2—8 家财团  AI 对手", "audience": "策略对抗与排名争夺"}
	return {"players": "2—8 名董事  同屏轮流", "audience": "本地聚会与多人竞赛"}
