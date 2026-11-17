extends Control
## Лист тетради: кремовая бумага, синие линейки, красная поля.

const PAPER := Color("f7f3ea")
const LINE := Color(0.16, 0.31, 0.62, 0.14)
const MARGIN := Color(0.76, 0.28, 0.28, 0.55)


func _ready() -> void:
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	var y := 28.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), LINE, 1.0, false)
		y += 34.0
	draw_line(Vector2(46, 0), Vector2(46, size.y), MARGIN, 2.0, false)
