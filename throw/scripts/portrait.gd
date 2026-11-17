extends Control
## Маленький портрет для бестиария. Рисует ту же фигуру, что и двор.

var shape := "blob"
var color := ThrowTheme.UNCAUGHT
var caught := false


func _ready() -> void:
	custom_minimum_size = Vector2(76, 76)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(next_shape: String, next_color: Color, is_caught: bool) -> void:
	shape = next_shape
	color = next_color
	caught = is_caught
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5 + Vector2(0, 6)
	var tint := color if caught else ThrowTheme.UNCAUGHT
	CritterDraw.paint(self, center, shape, tint, 0.85, caught, 1.0)
