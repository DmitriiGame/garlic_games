extends RefCounted
## Рваная меловая рамка, собранная из своей текстуры. Крупные панели и мелкие клетки.

const FRAME := "res://art/ui/frame_chalk.png"
const CELL := "res://art/ui/frame_cell.png"


static func panel(pad: int = 10) -> StyleBoxTexture:
	return _box(FRAME, 10, pad, Color.WHITE)


static func button(pad: int = 8) -> StyleBoxTexture:
	return _box(CELL, 10, pad, Color.WHITE)


static func cell(hot: bool, cursed: bool) -> StyleBoxTexture:
	var tint := Color.WHITE
	if hot or cursed:
		tint = Color(1.12, 0.86, 0.82)
	return _box(CELL, 10, 2, tint)


static func _box(path: String, margin: int, pad: int, tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(path)
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = pad
	style.content_margin_top = pad
	style.content_margin_right = pad
	style.content_margin_bottom = pad
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.draw_center = true
	style.modulate_color = tint
	return style
