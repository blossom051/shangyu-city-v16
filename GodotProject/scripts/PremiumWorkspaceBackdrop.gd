class_name PremiumWorkspaceBackdrop
extends Control

const BASE: = Color("12313d")
const SURFACE: = Color("173b47")
const LINE: = Color("7f9ca4")
const GOLD: = Color("dfb85f")

const VARIANT_ACCENTS: = {
	"talent": Color("9a83c9"), 
	"bank": Color("dfb85f"), 
	"auction": Color("cf9854"), 
	"startup": Color("5bc69a"), 
	"news": Color("52b39e"), 
	"build": Color("62a9c0"), 
	"cards": Color("c89565"), 
	"market": Color("43a8c7"), 
	"summary": Color("dfb85f"), 
	"final": Color("dfb85f"), 
	"mode": Color("55bce8"), 
	"company": Color("d6ad54"), 
	"generic": Color("43a8c7")
}

const VARIANT_CODES: = {
	"talent": "EXECUTIVE SEARCH / 01", 
	"bank": "PRIVATE CREDIT / 02", 
	"auction": "SEALED BID / 03", 
	"startup": "VENTURE DESK / 04", 
	"news": "CITY INTELLIGENCE / 05", 
	"build": "ASSET DEVELOPMENT / 06", 
	"cards": "STRATEGY ROOM / 07", 
	"market": "SECURITIES DESK / 08", 
	"summary": "CAPITAL REVIEW / 09", 
	"final": "BOARD RESOLUTION / 10", 
	"mode": "CAPITAL TABLE / 11", 
	"company": "HEADQUARTERS DOSSIER / 12", 
	"generic": "CITY CAPITAL NETWORK"
}

var variant: = "generic"
var accent: = Color("43a8c7")


func setup(value: String) -> void :
	variant = value if VARIANT_ACCENTS.has(value) else "generic"
	accent = VARIANT_ACCENTS[variant]
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void :
	draw_rect(Rect2(Vector2.ZERO, size), BASE, true)
	_draw_matte_frame()
	_draw_architectural_grid()
	_draw_identity_rails()
	_draw_variant_signal()


func _draw_matte_frame() -> void :
	var inset: = Rect2(22, 20, size.x - 44, size.y - 40)
	draw_rect(inset, SURFACE, true)
	draw_rect(inset, Color(LINE, 0.17), false, 1)
	draw_rect(Rect2(22, 20, size.x - 44, 4), Color(accent, 0.32), true)
	draw_rect(Rect2(22, size.y - 25, size.x - 44, 3), Color(GOLD, 0.18), true)


func _draw_architectural_grid() -> void :
	var left: = 22.0
	var right: = size.x - 22.0
	var top: = 24.0
	var bottom: = size.y - 25.0
	var columns: = maxi(6, int(size.x / 160.0))
	var rows: = maxi(5, int(size.y / 120.0))
	for index in range(1, columns):
		var x: = lerpf(left, right, float(index) / float(columns))
		draw_line(Vector2(x, top), Vector2(x, bottom), Color(LINE, 0.025), 1)
	for index in range(1, rows):
		var y: = lerpf(top, bottom, float(index) / float(rows))
		draw_line(Vector2(left, y), Vector2(right, y), Color(LINE, 0.022), 1)
	for index in range(9):
		var tick_y: = top + 54.0 + float(index) * 34.0
		if tick_y > bottom - 30.0:
			break
		draw_line(Vector2(right - 26, tick_y), Vector2(right - 12, tick_y), Color(accent, 0.22), 1)


func _draw_identity_rails() -> void :
	var font: = ThemeDB.fallback_font
	var code: = str(VARIANT_CODES[variant])
	draw_string(font, Vector2(48, size.y - 45), code, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(accent, 0.42))
	draw_string(font, Vector2(size.x - 240, 48), "CAPITAL SYSTEM", HORIZONTAL_ALIGNMENT_RIGHT, 190, 11, Color(LINE, 0.34))
	draw_circle(Vector2(size.x - 32, 43), 5, Color(accent, 0.72))
	draw_circle(Vector2(size.x - 32, 43), 2, BASE)


func _draw_variant_signal() -> void :
	match variant:
		"talent": _draw_talent_signal()
		"bank": _draw_bank_signal()
		"auction": _draw_auction_signal()
		"startup": _draw_startup_signal()
		"news": _draw_news_signal()
		"build": _draw_build_signal()
		"cards": _draw_card_signal()
		"market": _draw_market_signal()
		"summary": _draw_summary_signal()
		"final": _draw_final_signal()
		_: _draw_network_signal()


func _draw_talent_signal() -> void :
	var baseline: = size.y * 0.86
	for index in range(5):
		var x: = size.x * (0.34 + float(index) * 0.09)
		draw_line(Vector2(x, baseline - 92), Vector2(x, baseline), Color(accent, 0.09), 1)
		_draw_node(Vector2(x, baseline), accent, index == 2)


func _draw_bank_signal() -> void :
	var start: = Vector2(size.x * 0.22, size.y * 0.82)
	for row in range(3):
		var points: = PackedVector2Array()
		for index in range(8):
			points.append(start + Vector2(float(index) * size.x * 0.075, float(row) * 24.0 - sin(float(index) * 0.9 + row) * 9.0))
		draw_polyline(points, Color(accent, 0.1 + float(row) * 0.035), 2, true)


func _draw_auction_signal() -> void :
	var center: = Vector2(size.x * 0.78, size.y * 0.79)
	for radius in [74.0, 106.0, 140.0]:
		draw_arc(center, radius, - PI * 0.88, - PI * 0.12, 48, Color(accent, 0.11), 2, true)
	for index in range(7):
		var angle: = - PI * 0.84 + float(index) * PI * 0.12
		_draw_node(center + Vector2(cos(angle), sin(angle)) * 140.0, accent, index == 5)


func _draw_startup_signal() -> void :
	var points: = PackedVector2Array()
	for index in range(9):
		var x: = size.x * (0.12 + float(index) * 0.095)
		var y: = size.y * (0.79 - float(index) * 0.035 - sin(float(index) * 1.35) * 0.028)
		points.append(Vector2(x, y))
	draw_polyline(points, Color(accent, 0.16), 3, true)
	for index in range(points.size()):
		_draw_node(points[index], accent, index == points.size() - 1)


func _draw_news_signal() -> void :
	var y: = size.y * 0.83
	draw_line(Vector2(48, y), Vector2(size.x - 48, y), Color(accent, 0.14), 1)
	for index in range(12):
		_draw_node(Vector2(76 + float(index) * (size.x - 152) / 11.0, y), accent, false)


func _draw_build_signal() -> void :
	var baseline: = size.y * 0.86
	var points: = PackedVector2Array([Vector2(size.x * 0.58, baseline)])
	for index in range(7):
		var x: = size.x * (0.61 + float(index) * 0.045)
		var height: = 34.0 + float((index * 37) % 92)
		points.append(Vector2(x, baseline))
		points.append(Vector2(x, baseline - height))
		points.append(Vector2(x + size.x * 0.028, baseline - height))
		points.append(Vector2(x + size.x * 0.028, baseline))
	draw_polyline(points, Color(accent, 0.13), 2, true)


func _draw_card_signal() -> void :
	var origin: = Vector2(size.x * 0.76, size.y * 0.7)
	for index in range(3):
		var rect: = Rect2(origin + Vector2(float(index) * 38.0, - float(index) * 22.0), Vector2(94, 132))
		draw_rect(rect, Color(accent, 0.035), true)
		draw_rect(rect, Color(accent, 0.15), false, 1)


func _draw_market_signal() -> void :
	var points: = PackedVector2Array()
	for index in range(12):
		var x: = size.x * (0.18 + float(index) * 0.06)
		var y: = size.y * (0.84 - sin(float(index) * 0.72) * 0.045 - float(index) * 0.008)
		points.append(Vector2(x, y))
	draw_polyline(points, Color(accent, 0.17), 2, true)
	for index in [0, 4, 8, 11]:
		_draw_node(points[index], accent, index == 11)


func _draw_summary_signal() -> void :
	for index in range(4):
		var y: = size.y * (0.68 + float(index) * 0.055)
		var length: = size.x * (0.2 + float((index * 29) % 18) / 100.0)
		draw_line(Vector2(size.x * 0.58, y), Vector2(size.x * 0.58 + length, y), Color(accent, 0.13), 3)


func _draw_final_signal() -> void :
	var center: = Vector2(size.x * 0.5, size.y * 0.86)
	for radius in [120.0, 190.0, 260.0]:
		draw_arc(center, radius, - PI * 0.82, - PI * 0.18, 64, Color(accent, 0.12), 2, true)


func _draw_network_signal() -> void :
	var y: = size.y * 0.84
	for index in range(10):
		var point: = Vector2(size.x * (0.16 + float(index) * 0.075), y - sin(float(index) * 0.8) * 18.0)
		if index > 0:
			var previous: = Vector2(size.x * (0.16 + float(index - 1) * 0.075), y - sin(float(index - 1) * 0.8) * 18.0)
			draw_line(previous, point, Color(accent, 0.11), 1)
		_draw_node(point, accent, false)


func _draw_node(point: Vector2, color: Color, primary: = false) -> void :
	draw_circle(point, 6 if primary else 3, Color(color, 0.48 if primary else 0.26))
	if primary:
		draw_circle(point, 2, BASE)
