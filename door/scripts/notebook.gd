extends ColorRect
## Лист «Ночного бункера»: серо-зелёная клетка, фактура и виньетка фонарика.

const Palette := preload("res://scripts/door_theme.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/paper.gdshader")
	mat.set_shader_parameter("paper_light", Palette.PAPER)
	mat.set_shader_parameter("paper_shade", Palette.PAPER_SHADE)
	mat.set_shader_parameter("ink", Palette.INK)
	material = mat
