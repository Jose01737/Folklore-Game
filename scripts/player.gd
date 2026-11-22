extends CharacterBody2D

const Util = preload("res://scripts/util.gd")

var speed := 150.0
var sanity_max := 100.0
var sanity_drain_mult := 1.0
var noise_mult := 1.0
var color := Color.WHITE
var aim := Vector2.RIGHT
var sneaking := false
var light_on := true
var flicker := false
var light: PointLight2D
var in_shelter: Node2D = null

func setup(c: Dictionary) -> void:
	speed = float(c.speed)
	sanity_max = float(c.sanity_max)
	sanity_drain_mult = float(c.sanity_drain_mult)
	noise_mult = float(c.noise_mult)
	color = Color(c.color)

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	add_to_group("player")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	add_child(shape)
	light = PointLight2D.new()
	light.texture = Util.make_radial()
	light.texture_scale = 2.6
	light.energy = 1.1
	light.color = Color(1.0, 0.93, 0.75)
	add_child(light)
	var cam := Camera2D.new()
	cam.zoom = Vector2(1.3, 1.3)
	cam.position_smoothing_enabled = true
	add_child(cam)
	cam.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("flashlight"):
		light_on = not light_on

func view_radius() -> float:
	return 330.0 if light_on else 90.0

func noise_radius() -> float:
	var base := 100.0
	if velocity.length() > 5.0:
		base = 90.0 if sneaking else 280.0
	return base * noise_mult

func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	sneaking = Input.is_action_pressed("sneak")
	velocity = dir * speed * (0.5 if sneaking else 1.0)
	move_and_slide()
	var m := get_global_mouse_position() - global_position
	if m.length() > 4.0:
		aim = m.normalized()

func _process(_delta: float) -> void:
	light.texture_scale = 2.6 if light_on else 0.7
	if flicker and light_on:
		light.energy = randf_range(0.35, 1.2)
	else:
		light.energy = 1.1 if light_on else 0.5
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 10.0, color)
	draw_line(Vector2.ZERO, aim * 16.0, Color.WHITE, 2.0)
