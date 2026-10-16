class_name PremiumCityBackdrop
extends TextureRect

var accent: = Color("2f94bd")
var backdrop_material: ShaderMaterial


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop_material = ShaderMaterial.new()
	var shader: = Shader.new()
	shader.code = "\nshader_type canvas_item;\nuniform vec3 accent = vec3(0.18, 0.58, 0.74);\nvoid fragment() {\n\tvec2 uv = (UV - vec2(0.5)) / 0.99 + vec2(0.5);\n\tvec4 base = texture(TEXTURE, uv);\n\tfloat edge = smoothstep(0.82, 0.18, distance(UV, vec2(0.52, 0.48)));\n\tbase.rgb = mix(base.rgb, base.rgb * vec3(0.95, 0.97, 0.98) + accent * 0.018, 0.08);\n\tbase.rgb *= mix(0.92, 1.0, edge);\n\tCOLOR = base * COLOR;\n}\n"











	backdrop_material.shader = shader
	material = backdrop_material
	show_company({})


func show_company(company: Dictionary) -> void :
	accent = Color(str(company.get("color", "#2f94bd"))) if not company.is_empty() else Color("2f94bd")
	if backdrop_material != null:
		backdrop_material.set_shader_parameter("accent", Vector3(accent.r, accent.g, accent.b))
