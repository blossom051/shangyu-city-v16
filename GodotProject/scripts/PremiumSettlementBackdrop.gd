class_name PremiumSettlementBackdrop
extends TextureRect

const INK: = Color("eaf3f4")
const MUTED: = Color("9eb4bc")
const GOLD: = Color("d6ad54")

var players: Array = []
var reports: Dictionary = {}
var phase: = 0.0


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_results(value: Array, report_data: Dictionary) -> void :
	players = value.duplicate(true)
	players.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("rank", 99)) < int(b.get("rank", 99)))
	reports = report_data.get("players", {})
	queue_redraw()


func _process(delta: float) -> void :
	phase += delta
	queue_redraw()


func _draw() -> void :
	var w: = size.x
	var h: = size.y
	if w < 40.0 or h < 40.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.045, 0.065, 0.34), true)
	draw_rect(Rect2(0, h * 0.53, w, h * 0.47), Color(0.018, 0.075, 0.1, 0.92), true)
	draw_line(Vector2(0, h * 0.53), Vector2(w, h * 0.53), Color(GOLD, 0.72), 2.0)
	_draw_label(Vector2(30, 34), "CITY CAPITAL PULSE", 15, Color(GOLD, 0.9))
	_draw_label(Vector2(30, 64), "城市资本热力图", 28, INK)
	_draw_label(Vector2(30, 94), "本季资产变化与综合排名", 15, MUTED)
	_draw_skyline_signal(w, h)
	if players.is_empty():
		_draw_label(Vector2(30, h * 0.65), "等待本季结算数据", 22, MUTED)
		return
	var row_height: = minf(80.0, h * 0.38 / maxf(1.0, float(players.size())))
	var max_change: = 1.0
	for player: Dictionary in players:
		var report: Dictionary = reports.get(str(player.get("id", "")), {})
		max_change = maxf(max_change, absf(float(report.get("asset_change", 0))))
	for index in range(players.size()):
		_draw_player_row(players[index], index, Vector2(30, h * 0.585 + index * row_height), Vector2(w - 60, row_height - 10), max_change)


func _draw_skyline_signal(w: float, h: float) -> void :
	var points: = PackedVector2Array()
	for index in range(15):
		var t: = float(index) / 14.0
		var y: = h * (0.365 + sin(t * 8.0 + phase * 0.35) * 0.027) - t * h * 0.055
		points.append(Vector2(30 + t * (w - 60), y))
	if points.size() > 1:
		draw_polyline(points, Color(0.34, 0.76, 0.7, 0.7), 3.0, true)
	for point in points:
		draw_circle(point, 4.0, Color("d9f0e9"))


func _draw_player_row(player: Dictionary, index: int, position: Vector2, dimensions: Vector2, max_change: float) -> void :
	var accent: = Color(str(player.get("color", "#3195bd")))
	var report: Dictionary = reports.get(str(player.get("id", "")), {})
	var asset_change: = int(report.get("asset_change", 0))
	var fill: = Color(0.035, 0.13, 0.17, 0.86) if index > 0 else Color(0.065, 0.17, 0.19, 0.94)
	var box: = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = Color(accent, 0.75)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	draw_style_box(box, Rect2(position, dimensions))
	var rank_text: = "%02d" % (index + 1)
	_draw_label(position + Vector2(16, 29), rank_text, 25, GOLD if index == 0 else MUTED)
	_draw_label(position + Vector2(68, 27), str(player.get("name", "城市财团")), 21, INK)
	var bar_left: = position.x + dimensions.x * 0.39
	var bar_width: = dimensions.x * 0.37
	var bar_y: = position.y + dimensions.y * 0.5
	draw_rect(Rect2(bar_left, bar_y - 5, bar_width, 10), Color(0.2, 0.31, 0.34, 0.65), true)
	var ratio: = clampf(absf(float(asset_change)) / max_change, 0.04, 1.0)
	var gain_color: = Color("54bd8b") if asset_change >= 0 else Color("d76569")
	draw_rect(Rect2(bar_left, bar_y - 5, bar_width * ratio, 10), gain_color, true)
	var sign: = "+" if asset_change >= 0 else ""
	_draw_label(position + Vector2(dimensions.x - 160, 28), "%s%d 万" % [sign, asset_change], 20, gain_color)


func _draw_label(position: Vector2, text: String, font_size: int, color: Color) -> void :
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
