extends CharacterBody2D
## One generic monster. Behavior and stats come from data/entities.json.

const Util = preload("res://scripts/util.gd")

signal caught
signal wailed(text: String)

var data: Dictionary = {}
var entity_id := ""
var player: Node2D
var home := Vector2.ZERO
var banished := false
var enraged := 0.0
var wander_dir := Vector2.ZERO
var wander_t := 0.0
var windup := 0.0
var dash := 0.0
var cooldown := 2.0
var dash_dir := Vector2.ZERO
var lunge := 0.0
var lure_t := 6.0
var color := Color.WHITE
var nav: AStarGrid2D = null     # set by main; lets monsters route around walls
var walls: Array = []
var cell := 32
var path_t := 0.0
var path_dir := Vector2.ZERO
var path_target := Vector2(-9999, -9999)

func setup(id: String, p: Node2D, pos: Vector2) -> void:
	entity_id = id
	data = DataDB.entities[id]
	player = p
	home = pos
	global_position = pos
	color = Color(data.get("color", "#ffffff"))
	collision_layer = 4
	collision_mask = 1
	add_to_group("entity")
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 12.0
	shape.shape = c
	add_child(shape)
	var glow := PointLight2D.new()   # faint glimmer so you sense something is out there
	glow.texture = Util.make_radial()
	glow.texture_scale = 0.5
	glow.energy = 0.25
	glow.color = color
	add_child(glow)

func reset() -> void:
	global_position = home
	enraged = 0.0
	windup = 0.0
	dash = 0.0
	lunge = 0.0

func enrage(seconds: float) -> void:
	enraged = seconds

func banish() -> void:
	banished = true
	visible = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)

func _clear_line(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 16.0) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(n))
		for r in walls:
			if (r as Rect2).grow(14.0).has_point(p):
				return false
	return true

func _open_cell(c: Vector2i) -> Vector2i:
	var r := nav.region
	c = Vector2i(clampi(c.x, r.position.x, r.end.x - 1), clampi(c.y, r.position.y, r.end.y - 1))
	if not nav.is_point_solid(c):
		return c
	for ring in range(1, 4):
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				var n := c + Vector2i(dx, dy)
				if nav.is_in_boundsv(n) and not nav.is_point_solid(n):
					return n
	return c

func _compute_dir(target: Vector2) -> Vector2:
	var direct := target - global_position
	if _clear_line(global_position, target):
		return direct.normalized()
	var s := _open_cell(Vector2i(global_position / float(cell)))
	var g := _open_cell(Vector2i(target / float(cell)))
	var path: PackedVector2Array = nav.get_point_path(s, g)
	for i in range(1, path.size()):
		if path[i].distance_to(global_position) > 20.0:
			return (path[i] - global_position).normalized()
	return direct.normalized()

## Direction to walk toward a target, going around walls when needed.
func _dir_to(target: Vector2) -> Vector2:
	if nav == null:
		return (target - global_position).normalized()
	path_t -= get_physics_process_delta_time()
	if path_t <= 0.0 or target.distance_to(path_target) > 40.0:
		path_t = 0.25
		path_target = target
		path_dir = _compute_dir(target)
	return path_dir

func _wander(delta: float, spd: float) -> Vector2:
	wander_t -= delta
	if wander_t <= 0.0:
		wander_t = randf_range(1.5, 4.0)
		wander_dir = Vector2.from_angle(randf() * TAU) if randf() < 0.7 else Vector2.ZERO
	return wander_dir * spd

func _physics_process(delta: float) -> void:
	if banished or player == null:
		return
	enraged = maxf(0.0, enraged - delta)
	var to_p: Vector2 = player.global_position - global_position
	var dist := to_p.length()
	var sight: float = float(data.sight) * (1.6 if player.light_on else 0.8)
	var aware: bool = dist < sight or dist < player.noise_radius() or enraged > 0.0
	var spd: float = float(data.speed) * (1.6 if enraged > 0.0 else 1.0)
	var vel := Vector2.ZERO
	var sh = player.in_shelter
	if sh != null:
		var sd: float = sh.global_position.distance_to(global_position)
		if sh.warded_against == entity_id:
			aware = false
			if sd < 150.0:
				velocity = (global_position - sh.global_position).normalized() * spd
				move_and_slide()
				return
		elif sd < 90.0:
			sh.damage(8.0 * delta)
			velocity = Vector2.ZERO
			windup = 0.0
			dash = 0.0
			lunge = 0.0
			return
		elif aware and sd < sight * 0.7:
			velocity = _dir_to(sh.global_position) * spd * 0.6
			move_and_slide()
			return
		else:
			aware = false
	var behavior: String = data.behavior
	if behavior == "mimic" and enraged > 0.0:
		behavior = "stalk"
	match behavior:
		"stalk":
			vel = _dir_to(player.global_position) * spd if aware else _wander(delta, spd * 0.4)
		"gaze":
			if aware:
				var seen: bool = dist < player.view_radius() and player.aim.dot(-to_p.normalized()) > 0.7
				if not seen:
					vel = _dir_to(player.global_position) * spd
			else:
				vel = _wander(delta, spd * 0.3)
		"charge":
			if dash > 0.0:
				dash -= delta
				vel = dash_dir * spd * 3.0
			elif windup > 0.0:
				windup -= delta
				dash_dir = to_p.normalized()
				if windup <= 0.0:
					dash = 0.7
					cooldown = 3.0
			elif aware:
				cooldown -= delta
				if dist > 220.0:
					vel = _dir_to(player.global_position) * spd * 0.7
				if cooldown <= 0.0 and dist < 300.0:
					windup = 0.9
			else:
				vel = _wander(delta, spd * 0.4)
		"mimic":
			lure_t -= delta
			if lunge > 0.0:
				lunge -= delta
				vel = _dir_to(player.global_position) * spd * 2.4
			elif dist < 130.0 and player.in_shelter == null:
				lunge = 2.0
			else:
				if lure_t <= 0.0 and dist < 500.0:
					lure_t = randf_range(10.0, 16.0)
					wailed.emit(String(data.get("lure_text", "")))
				if dist < player.noise_radius():
					vel = _dir_to(player.global_position) * spd * 0.3
	velocity = vel
	move_and_slide()
	if dist < 20.0 and player.in_shelter == null:
		caught.emit()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if banished:
		return
	var shake := Vector2.ZERO
	if windup > 0.0:
		shake = Vector2(randf_range(-3, 3), randf_range(-3, 3))
	draw_circle(shake, 13.0, color)
	draw_circle(shake + Vector2(-4, -3), 2.5, Color(1, 0.1, 0.1))
	draw_circle(shake + Vector2(4, -3), 2.5, Color(1, 0.1, 0.1))
	if enraged > 0.0:
		draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 24, Color.RED, 2.0)
