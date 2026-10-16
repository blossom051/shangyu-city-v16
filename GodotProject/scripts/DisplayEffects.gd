extends CanvasLayer

var brightness_value: = 1.0
var contrast_value: = 1.0
var back_buffer: BackBufferCopy
var overlay: ColorRect
var effect_material: ShaderMaterial


func _ready() -> void :
	layer = 1000
	back_buffer = BackBufferCopy.new()
	back_buffer.name = "DisplaySnapshot"
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(back_buffer)
	overlay = ColorRect.new()
	overlay.name = "GlobalDisplayEffect"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_material = ShaderMaterial.new()
	var shader: = Shader.new()
	shader.code = "\nshader_type canvas_item;\nrender_mode unshaded;\nuniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;\nuniform float brightness = 1.0;\nuniform float contrast = 1.0;\nvoid fragment() {\n\tvec4 source = texture(screen_texture, SCREEN_UV);\n\tvec3 adjusted = (source.rgb - vec3(0.5)) * contrast + vec3(0.5);\n\tadjusted *= brightness;\n\tCOLOR = vec4(clamp(adjusted, vec3(0.0), vec3(1.0)), source.a);\n}\n"












	effect_material.shader = shader
	overlay.material = effect_material
	add_child(overlay)
	GameSettings.visual_changed.connect(apply_visual)
	apply_visual(GameSettings.brightness, GameSettings.contrast)


func apply_visual(brightness: float, contrast: float) -> void :
	brightness_value = brightness
	contrast_value = contrast
	if effect_material != null:
		effect_material.set_shader_parameter("brightness", brightness_value)
		effect_material.set_shader_parameter("contrast", contrast_value)
