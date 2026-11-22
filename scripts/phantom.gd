extends Node2D
## A hallucination: a flickering fake of the region's monster. Harmless, but you cannot be sure.

var color := Color.WHITE
var life := 1.8
var t := 0.0

func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var a := clampf(1.0 - t / life, 0.0, 1.0) * (0.45 + 0.55 * absf(sin(t * 23.0)))
	var c := Color(color.r, color.g, color.b, a)
	draw_circle(Vector2.ZERO, 13.0, c)
	draw_circle(Vector2(-4, -3), 2.5, Color(1, 0.1, 0.1, a))
	draw_circle(Vector2(4, -3), 2.5, Color(1, 0.1, 0.1, a))
