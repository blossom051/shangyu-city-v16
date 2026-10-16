class_name MainMenuAtmosphere
extends ColorRect

var atmosphere_material: ShaderMaterial


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	atmosphere_material = ShaderMaterial.new()
	var atmosphere_shader: = Shader.new()
	atmosphere_shader.code = "\nshader_type canvas_item;\n\nuniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;\nuniform float focus_x = 0.19;\nuniform float focus_width = 0.42;\nuniform float portrait = 0.0;\n\nvoid fragment() {\n\tfloat distance_x = abs(UV.x - focus_x);\n\tfloat core = 1.0 - smoothstep(focus_width * 0.34, focus_width, distance_x);\n\tfloat shoulder = 1.0 - smoothstep(focus_width * 0.78, focus_width * 1.58, distance_x);\n\tfloat vertical = smoothstep(0.02, 0.15, UV.y) * (1.0 - smoothstep(0.84, 0.99, UV.y));\n\tfloat veil = max(core * 0.88, shoulder * 0.46) * mix(0.92, vertical, 0.28);\n\tfloat blur = mix(0.0, 2.2, core) + portrait * core * 0.35;\n\tvec3 city = textureLod(screen_texture, SCREEN_UV, blur).rgb;\n\tvec3 smoke = vec3(0.006, 0.035, 0.050);\n\tvec3 result = mix(city, smoke, veil * 0.76);\n\tfloat edge_light = smoothstep(focus_width * 1.18, focus_width * 0.72, distance_x) - smoothstep(focus_width * 0.72, focus_width * 0.30, distance_x);\n\tresult += vec3(0.12, 0.34, 0.40) * edge_light * 0.035;\n\tfloat horizon = exp(-pow((UV.y - 0.22) * 8.0, 2.0));\n\tresult += vec3(0.48, 0.34, 0.13) * horizon * shoulder * 0.018;\n\tCOLOR = vec4(result, 1.0);\n}\n"
























	atmosphere_material.shader = atmosphere_shader
	material = atmosphere_material


func configure_focus(center_x: float, width_ratio: float, is_portrait: bool) -> void :
	if atmosphere_material == null:
		return
	atmosphere_material.set_shader_parameter("focus_x", clampf(center_x, 0.0, 1.0))
	atmosphere_material.set_shader_parameter("focus_width", clampf(width_ratio, 0.3, 0.82))
	atmosphere_material.set_shader_parameter("portrait", 1.0 if is_portrait else 0.0)
