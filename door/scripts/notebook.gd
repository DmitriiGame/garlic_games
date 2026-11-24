extends TextureRect
## Тёмный бетон под страницами вместо шейдера клетки.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture = load("res://art/ui/concrete.png")
	stretch_mode = TextureRect.STRETCH_TILE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	set_anchors_preset(Control.PRESET_FULL_RECT)
