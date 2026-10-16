class_name WealthGauge
extends Control

var gauge_kind: = "ring"
var title: = "资产"
var value: = 0.0
var maximum: = 100.0
var accent: = Color("5bb5d6")
var caption: = ""

func setup(kind: String, label_text: String, next_value: float, next_maximum: float, color: Color, note: String) -> void :
	gauge_kind = kind;title = label_text;value = next_value;maximum = maxf(1.0, next_maximum);accent = color;caption = note;queue_redraw()

func _draw() -> void :
	var rect: = Rect2(3, 3, size.x - 6, size.y - 6)
	var panel: = StyleBoxFlat.new();panel.bg_color = Color("0b2633");panel.border_color = Color(accent, 0.72);panel.set_border_width_all(2);panel.set_corner_radius_all(16);draw_style_box(panel, rect)
	var ratio: = clampf(value / maximum, 0.0, 1.0); var center: = Vector2(54, size.y * 0.5)
	match gauge_kind:
		"water":
			draw_circle(center, 25, Color(accent, 0.1));draw_arc(center, 30, 0, TAU, 40, Color(accent, 0.82), 3)
			var water_y: = center.y + 20.0 - 40.0 * ratio
			draw_polyline(PackedVector2Array([Vector2(center.x - 20, water_y), Vector2(center.x - 10, water_y - 3), Vector2(center.x, water_y), Vector2(center.x + 10, water_y + 3), Vector2(center.x + 20, water_y)]), accent, 4, true)
			draw_line(Vector2(center.x - 18, water_y + 8), Vector2(center.x + 18, water_y + 8), Color(accent, 0.55), 3)
			draw_circle(center + Vector2(0, 11), 6, Color(accent, 0.72))
		"scale":
			draw_arc(center, 29, PI, TAU, 32, Color("294756"), 8);draw_arc(center, 29, PI, PI + PI * ratio, 32, accent, 8);draw_line(center, center + Vector2.LEFT.rotated(PI * ratio) * 23, Color("f6e6b2"), 3)
		_:
			draw_arc(center, 29, - PI * 0.5, PI * 1.5, 40, Color("294756"), 8);draw_arc(center, 29, - PI * 0.5, - PI * 0.5 + TAU * ratio, 40, accent, 8)
	draw_string(ThemeDB.fallback_font, Vector2(96, 31), title, HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 108), 14, Color("a8bdc3"));draw_string(ThemeDB.fallback_font, Vector2(96, 62), caption, HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 108), 22, accent)
