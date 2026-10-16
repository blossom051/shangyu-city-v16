class_name MusicAlbumEmblem
extends Control

var emblem_kind: = "radio"
var accent: = Color("e7c468")


func setup(kind: String, color: Color) -> void :
	emblem_kind = kind
	accent = color
	name = "AlbumEmblem"
	custom_minimum_size = Vector2(58, 58)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void :
	var c: = size * 0.5
	draw_circle(c, 24, Color(accent, 0.18))
	draw_circle(c, 21, accent, false, 3)
	match emblem_kind:
		"swim", "bay", "radio":
			draw_arc(c + Vector2(-3, 4), 16, 3.35, 6.1, 32, accent.lightened(0.28), 4, true)
			draw_arc(c + Vector2(9, 4), 10, 3.3, 6.15, 28, accent.lightened(0.42), 3, true)
		"dynamite":
			for index in range(8):
				var angle: = TAU * float(index) / 8.0
				draw_line(c + Vector2(cos(angle), sin(angle)) * 7.0, c + Vector2(cos(angle), sin(angle)) * 20.0, accent.lightened(0.35), 3)
			draw_circle(c, 7, accent.lightened(0.55))
		_:
			draw_line(c + Vector2(-11, 14), c + Vector2(-11, -13), accent.lightened(0.4), 4)
			draw_line(c + Vector2(7, 10), c + Vector2(7, -18), accent.lightened(0.4), 4)
			draw_circle(c + Vector2(-16, 14), 6, accent.lightened(0.55))
			draw_circle(c + Vector2(2, 10), 6, accent.lightened(0.55))
