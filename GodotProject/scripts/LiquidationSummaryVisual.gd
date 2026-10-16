class_name LiquidationSummaryVisual
extends Control

var summary: Dictionary = {}


func configure(next_summary: Dictionary) -> void:
	summary = next_summary.duplicate(true)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var chart := Rect2(36, 82, size.x - 72, size.y - 158)
	draw_string(font, Vector2(34, 35), "资产航程", HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 68), 25, Color("f3d47c"))
	draw_string(font, Vector2(34, 61), "每个节点代表一次真实回合结算", HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 68), 14, Color("91adb4"))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("081f2b")
	panel.border_color = Color("315d68")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(18)
	draw_style_box(panel, chart)
	var series: Array = summary.get("asset_series", [])
	if series.is_empty():
		series = [{"round": int(summary.get("rounds", 0)), "value": int(summary.get("asset", 0))}]
	var max_value := maxi(1, int(summary.get("peak_asset", 1)))
	var min_value := max_value
	for point: Dictionary in series:
		min_value = mini(min_value, int(point.get("value", 0)))
	var floor_value := maxi(0, min_value - maxi(100, roundi(float(max_value - min_value) * 0.18)))
	var span := maxi(1, max_value - floor_value)
	for line in range(5):
		var ratio := float(line) / 4.0
		var y := chart.position.y + 22 + (chart.size.y - 48) * ratio
		draw_line(Vector2(chart.position.x + 24, y), Vector2(chart.end.x - 24, y), Color(0.22, 0.48, 0.55, 0.18), 1.0)
		var label_value := roundi(lerpf(float(max_value), float(floor_value), ratio))
		draw_string(font, Vector2(chart.position.x + 28, y - 5), "%d万" % label_value, HORIZONTAL_ALIGNMENT_LEFT, 92, 12, Color("6f9098"))
	var points := PackedVector2Array()
	for index in range(series.size()):
		var value := int((series[index] as Dictionary).get("value", 0))
		var x_ratio := float(index) / float(maxi(1, series.size() - 1))
		var y_ratio := 1.0 - float(value - floor_value) / float(span)
		points.append(Vector2(chart.position.x + 112 + x_ratio * (chart.size.x - 148), chart.position.y + 24 + y_ratio * (chart.size.y - 54)))
	if points.size() == 1:
		points.append(points[0] + Vector2(1, 0))
	var area := points.duplicate()
	area.append(Vector2(points[-1].x, chart.end.y - 20))
	area.append(Vector2(points[0].x, chart.end.y - 20))
	draw_colored_polygon(area, Color(0.19, 0.72, 0.73, 0.16))
	draw_polyline(points, Color("69d2c9"), 4.0, true)
	for index in range(points.size()):
		draw_circle(points[index], 5.5, Color("f1c867"))
		if index == 0 or index == points.size() - 1:
			var point_data: Dictionary = series[mini(index, series.size() - 1)]
			draw_string(font, points[index] + Vector2(-34, -12), "第%d轮" % int(point_data.get("round", 0)), HORIZONTAL_ALIGNMENT_CENTER, 68, 12, Color("bad0d4"))
	var start_value := int((series[0] as Dictionary).get("value", 0))
	var finish_value := int((series[-1] as Dictionary).get("value", 0))
	var change := finish_value - start_value
	var footer := "期末 %d万   全程变化 %s%d万   峰值 %d万" % [finish_value, "+" if change >= 0 else "", change, max_value]
	draw_string(font, Vector2(34, size.y - 34), footer, HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 68), 17, Color("dce8e8"))
