class_name ListedPriceSparkline
extends Control

var values: Array = []
var line_color := Color("67d2ad")


func configure(next_values: Array, next_color: Color) -> void:
	values = next_values.duplicate()
	line_color = next_color
	queue_redraw()


func _draw() -> void:
	if values.size() < 2:
		return
	var low := INF
	var high := -INF
	for value in values:
		low = minf(low, float(value))
		high = maxf(high, float(value))
	var span := maxf(0.01, high - low)
	var points := PackedVector2Array()
	for index in range(values.size()):
		var x := 8.0 + (size.x - 16.0) * float(index) / float(values.size() - 1)
		var y := size.y - 8.0 - (size.y - 16.0) * (float(values[index]) - low) / span
		points.append(Vector2(x, y))
	draw_polyline(points, line_color, 3.0, true)
	draw_circle(points[-1], 4.0, line_color)
