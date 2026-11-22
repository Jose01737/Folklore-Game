extends Node2D
## A player-built shelter. Hides the player, restores sanity, acts as a save point.
## Monsters that noticed you will scratch it down unless it is warded against them.

const Util = preload("res://scripts/util.gd")

signal collapsed(shelter: Node2D)

var durability := 100.0
var warded_against := ""     # entity id this shelter is permanently safe from
var radius := 34.0
var hit_t := 0.0

func _ready() -> void:
	add_to_group("shelter")
	var l := PointLight2D.new()
	l.texture = Util.make_radial()
	l.texture_scale = 0.9
	l.energy = 0.5
	l.color = Color(1.0, 0.75, 0.4)
	add_child(l)

func contains(p: Vector2) -> bool:
	return global_position.distance_to(p) < radius

func damage(amount: float) -> void:
	durability -= amount
	hit_t = 0.3
	if durability <= 0.0:
		collapsed.emit(self)
		queue_free()

func _process(delta: float) -> void:
	hit_t = maxf(0.0, hit_t - delta)
	queue_redraw()

func _draw() -> void:
	var shake := Vector2(randf_range(-2, 2), randf_range(-2, 2)) if hit_t > 0.0 else Vector2.ZERO
	draw_rect(Rect2(Vector2(-26, -26) + shake, Vector2(52, 52)), Color(0.33, 0.23, 0.14))
	draw_rect(Rect2(Vector2(-26, -26) + shake, Vector2(52, 52)), Color(0.55, 0.4, 0.25), false, 3.0)
	for i in range(-16, 20, 10):
		draw_line(Vector2(-26, i) + shake, Vector2(26, i) + shake, Color(0.2, 0.14, 0.08), 1.5)
	draw_rect(Rect2(Vector2(-7, 14) + shake, Vector2(14, 12)), Color(0.05, 0.03, 0.02))
	if warded_against != "":
		draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 32, Color(0.4, 1.0, 0.6), 2.0)
	var frac := clampf(durability / 100.0, 0.0, 1.0)
	draw_rect(Rect2(-24, -36, 48, 4), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-24, -36, 48.0 * frac, 4), Color(0.9, 0.7, 0.2))
