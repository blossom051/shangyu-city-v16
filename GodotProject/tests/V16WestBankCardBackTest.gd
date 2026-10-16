extends SceneTree

const Visual = preload("res://scripts/CardVisualLanguage.gd")

func _initialize() -> void:
	var image: Image = Visual.WEST_BANK_CARD_BACK.get_image()
	if image == null or image.is_empty():
		printerr("V16_WEST_CARD_BACK missing image")
		quit(1)
		return
	var top_coverage := _bright_coverage(image, 0.10, 0.20)
	var bottom_coverage := _bright_coverage(image, 0.80, 0.90)
	print("V16_WEST_CARD_BACK top=%.3f bottom=%.3f" % [top_coverage, bottom_coverage])
	if top_coverage < 0.02 or bottom_coverage < 0.02:
		printerr("V16_WEST_CARD_BACK artwork does not fill card back")
		quit(1)
		return
	quit(0)

func _bright_coverage(image: Image, start_fraction: float, end_fraction: float) -> float:
	var bright := 0
	var samples := 0
	for y in range(int(image.get_height() * start_fraction), int(image.get_height() * end_fraction), 4):
		for x in range(int(image.get_width() * 0.10), int(image.get_width() * 0.90), 4):
			var pixel := image.get_pixel(x, y)
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.18:
				bright += 1
			samples += 1
	return float(bright) / maxf(float(samples), 1.0)
