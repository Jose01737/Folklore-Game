extends Node2D
## Notes, items, save points (shrines) and the level exit.

const Util = preload("res://scripts/util.gd")

var kind := "item"       # note | item | save | exit
var payload := ""        # entity id (note) or item id (item)
var index := 0           # clue index for notes
var key := ""            # unique id so collected things stay collected
var label_text := ""

func _ready() -> void:
	add_to_group("interactable")
	if kind == "save" or kind == "exit":
		var l := PointLight2D.new()
		l.texture = Util.make_radial()
		l.texture_scale = 1.6
		l.energy = 0.9
		l.color = Color(1.0, 0.7, 0.3) if kind == "save" else Color(0.4, 1.0, 0.6)
		add_child(l)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + 0.15 * sin(Time.get_ticks_msec() / 250.0)
	match kind:
		"note":
			draw_rect(Rect2(-7, -9, 14, 18), Color(0.95, 0.9, 0.7))
		"scrap":
			draw_rect(Rect2(-9, -3, 18, 6), Color(0.6, 0.42, 0.22))
			draw_rect(Rect2(-3, -9, 6, 18), Color(0.5, 0.35, 0.18))
		"item":
			draw_circle(Vector2.ZERO, 7.0, Color(0.4, 0.7, 1.0))
		"save":
			draw_circle(Vector2.ZERO, 9.0 * pulse, Color(1.0, 0.65, 0.2))
			draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 20, Color(1, 0.8, 0.4), 1.5)
		"exit":
			draw_rect(Rect2(-14, -14, 28, 28), Color(0.3, 1.0, 0.5, 0.8))
