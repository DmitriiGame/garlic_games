@tool
extends RefCounted
class_name CritterDraw
## Фигуры нечисти. Позже их можно заменить спрайтами, не трогая правила.


static func paint(canvas: CanvasItem, center: Vector2, shape: String, base: Color, draw_scale: float, show_eyes: bool, alpha: float) -> void:
	var color := Color(base.r, base.g, base.b, alpha)
	var ink := Color(ThrowTheme.INK.r, ThrowTheme.INK.g, ThrowTheme.INK.b, alpha)
	var eyes := center + Vector2(0, -6) * draw_scale
	match shape:
		"tall":
			canvas.draw_rect(Rect2(center + Vector2(-12, -18) * draw_scale, Vector2(24, 44) * draw_scale), color, true)
			canvas.draw_circle(center + Vector2(0, -30) * draw_scale, 11 * draw_scale, color)
			eyes = center + Vector2(0, -32) * draw_scale
		"squat":
			_poly(canvas, center, draw_scale, PackedVector2Array([
				Vector2(-26, 10), Vector2(-20, -12), Vector2(20, -12), Vector2(26, 12), Vector2(0, 18),
			]), color)
			canvas.draw_circle(center + Vector2(0, -20) * draw_scale, 11 * draw_scale, color)
			eyes = center + Vector2(0, -22) * draw_scale
		"horned":
			_poly(canvas, center, draw_scale, PackedVector2Array([
				Vector2(-24, 12), Vector2(-16, -10), Vector2(16, -10), Vector2(24, 12), Vector2(0, 18),
			]), color)
			canvas.draw_circle(center + Vector2(0, -18) * draw_scale, 11 * draw_scale, color)
			_poly(canvas, center, draw_scale, PackedVector2Array([
				Vector2(-14, -24), Vector2(-8, -40), Vector2(-2, -22),
			]), color)
			_poly(canvas, center, draw_scale, PackedVector2Array([
				Vector2(14, -24), Vector2(8, -40), Vector2(2, -22),
			]), color)
			eyes = center + Vector2(0, -20) * draw_scale
		"wispy":
			canvas.draw_circle(center + Vector2(-12, 8) * draw_scale, 16 * draw_scale, Color(color.r, color.g, color.b, alpha * 0.45))
			canvas.draw_circle(center + Vector2(12, 6) * draw_scale, 14 * draw_scale, Color(color.r, color.g, color.b, alpha * 0.65))
			canvas.draw_circle(center + Vector2(0, -10) * draw_scale, 12 * draw_scale, color)
			eyes = center + Vector2(0, -12) * draw_scale
		_:
			canvas.draw_circle(center + Vector2(0, 4) * draw_scale, 22 * draw_scale, color)
			eyes = center + Vector2(0, -2) * draw_scale
	if show_eyes:
		canvas.draw_circle(eyes + Vector2(-5, 0) * draw_scale, 2.3 * draw_scale, ink)
		canvas.draw_circle(eyes + Vector2(5, 0) * draw_scale, 2.3 * draw_scale, ink)


static func _poly(canvas: CanvasItem, center: Vector2, draw_scale: float, points: PackedVector2Array, color: Color) -> void:
	var moved := PackedVector2Array()
	for point in points:
		moved.append(center + point * draw_scale)
	if moved.size() >= 3:
		canvas.draw_colored_polygon(moved, color)
