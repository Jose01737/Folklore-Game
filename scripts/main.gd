extends Node2D
## Builds the title screen, the level for the current region, and the HUD in code.

const PlayerScript = preload("res://scripts/player.gd")
const EntityScript = preload("res://scripts/entity.gd")
const InterScript = preload("res://scripts/interactable.gd")
const ShelterScript = preload("res://scripts/shelter.gd")
const PhantomScript = preload("res://scripts/phantom.gd")

const SHELTER_COST := 3
const MAX_SHELTERS := 2

const W := 1600
const H := 1200
const START := Vector2(120, 120)
const EXIT_POS := Vector2(W - 140, H - 140)

var state := "title"
var world: Node2D
var player: CharacterBody2D
var wall_rects: Array = []
var invuln := 0.0
var toast_t := 0.0
var ward_pending := false
var nav: AStarGrid2D
var phantom_t := 8.0
var vignette: ColorRect

const WHISPERS := [
	"Someone whispers your name.",
	"Footsteps behind you. You stop. They stop.",
	"You are sure the notes in your pocket have been rewritten.",
	"Something breathes in time with you.",
	"The dark moves when you look away."]

var canvas_mod: CanvasModulate
var hud: CanvasLayer
var info_label: Label
var prompt_label: Label
var toast_label: Label
var title_label: Label
var sanity_bar: ProgressBar
var journal_panel: PanelContainer
var journal_text: RichTextLabel

func _ready() -> void:
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	_build_hud()
	_show_title()

# ---------------------------------------------------------------- HUD / UI
func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	vignette = ColorRect.new()
	vignette.size = Vector2(1280, 720)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float intensity = 0.0;\nvoid fragment() {\n\tvec2 uv = UV - vec2(0.5);\n\tfloat d = length(uv * vec2(1.0, 0.8));\n\tfloat v = smoothstep(0.2, 0.7, d) * intensity;\n\tCOLOR = vec4(0.4, 0.0, 0.02, v);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	vignette.material = mat
	hud.add_child(vignette)
	info_label = Label.new()
	info_label.position = Vector2(16, 10)
	hud.add_child(info_label)
	sanity_bar = ProgressBar.new()
	sanity_bar.position = Vector2(16, 36)
	sanity_bar.size = Vector2(240, 14)
	sanity_bar.show_percentage = false
	hud.add_child(sanity_bar)
	prompt_label = Label.new()
	prompt_label.position = Vector2(340, 600)
	prompt_label.size = Vector2(600, 30)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(prompt_label)
	toast_label = Label.new()
	toast_label.position = Vector2(200, 640)
	toast_label.size = Vector2(880, 70)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(toast_label)
	title_label = Label.new()
	title_label.position = Vector2(140, 60)
	title_label.size = Vector2(1000, 600)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 20)
	hud.add_child(title_label)
	journal_panel = PanelContainer.new()
	journal_panel.position = Vector2(240, 60)
	journal_panel.size = Vector2(800, 600)
	journal_panel.visible = false
	journal_text = RichTextLabel.new()
	journal_text.bbcode_enabled = true
	journal_text.custom_minimum_size = Vector2(780, 580)
	journal_panel.add_child(journal_text)
	hud.add_child(journal_panel)

func _toast(text: String, secs: float = 4.0) -> void:
	toast_label.text = text
	toast_t = secs

func _show_title() -> void:
	state = "title"
	_set_vignette(0.0)
	if world:
		world.queue_free()
		world = null
	canvas_mod.color = Color.WHITE
	info_label.text = ""
	prompt_label.text = ""
	toast_label.text = ""
	journal_panel.visible = false
	sanity_bar.visible = false
	var t := "FOLKLORE\n(working title)\n\nChoose your survivor:\n"
	var i := 1
	for id in DataDB.characters:
		var c: Dictionary = DataDB.characters[id]
		t += "\n%d) %s, %s\n    %s" % [i, c.name, c.role, c.perk]
		i += 1
	if GameState.has_save():
		t += "\n\n[C] Continue saved game"
	title_label.text = t
	title_label.visible = true

func _refresh_journal() -> void:
	var t := "[b]FIELD JOURNAL[/b]\n\n"
	var cur: String = GameState.region().entity
	var ids: Array = GameState.lore.keys()
	if not ids.has(cur):
		ids.append(cur)
	for eid in ids:
		var e: Dictionary = DataDB.entities[eid]
		var known: Array = GameState.lore.get(eid, [])
		var clues: Array = e.lore_clues
		t += "[b]%s[/b] (%s)\n" % [e.name, e.origin]
		if known.size() > 0:
			t += "%s\n" % e.summary
		for i in clues.size():
			t += ("  - " + clues[i] + "\n") if known.has(i) else "  - ???\n"
		t += "\n"
	t += "[b]INVENTORY[/b]\n"
	for it in GameState.inventory:
		var d: Dictionary = DataDB.items[it]
		t += "  %s: %s\n" % [d.name, d.desc]
	if GameState.inventory.is_empty():
		t += "  (empty)\n"
	journal_text.text = t

# ---------------------------------------------------------------- LEVEL
func _start_region() -> void:
	state = "play"
	title_label.visible = false
	sanity_bar.visible = true
	journal_panel.visible = false
	if world:
		world.queue_free()
	world = Node2D.new()
	add_child(world)
	wall_rects = []
	var reg: Dictionary = GameState.region()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(GameState.region_id())
	canvas_mod.color = Color(reg.ambient).lightened(0.05)

	var floor_rect := ColorRect.new()
	floor_rect.size = Vector2(W, H)
	floor_rect.color = Color(reg.floor)
	floor_rect.z_index = -10
	world.add_child(floor_rect)

	var wall_color := Color(reg.wall)
	for r in [Rect2(-40, -40, W + 80, 40), Rect2(-40, H, W + 80, 40), Rect2(-40, 0, 40, H), Rect2(W, 0, 40, H)]:
		_add_wall(r, wall_color)

	var keepouts := [
		Rect2(0, 0, 320, 320), Rect2(W - 320, H - 320, 320, 320),
		Rect2(W * 0.6 - 120, H * 0.6 - 120, 240, 240), Rect2(W * 0.4 - 100, H * 0.5 - 100, 200, 200)]
	var placed := 0
	var tries := 0
	while placed < 10 and tries < 200:
		tries += 1
		var horiz := rng.randf() < 0.5
		var size := Vector2(rng.randi_range(160, 380), 24) if horiz else Vector2(24, rng.randi_range(160, 380))
		var pos := Vector2(rng.randf_range(120, W - 480), rng.randf_range(120, H - 480))
		var r := Rect2(pos, size)
		var bad := false
		for k in keepouts:
			if r.intersects(k):
				bad = true
				break
		if not bad:
			wall_rects.append(r)
			_add_wall(r, wall_color)
			placed += 1

	nav = _build_nav()
	player = PlayerScript.new()
	world.add_child(player)
	player.setup(GameState.character())
	player.global_position = GameState.save_pos if GameState.has_checkpoint else START

	var ent_id: String = reg.entity
	var ent_data: Dictionary = DataDB.entities[ent_id]
	var ri := GameState.region_index

	_spawn_inter("save", "", "", 0, Vector2(200, 200), "Rest at the " + String(reg.save_point_name))
	_spawn_inter("save", "", "", 0, Vector2(W * 0.4, H * 0.5), "Rest at the " + String(reg.save_point_name))
	_spawn_inter("exit", "", "", 0, EXIT_POS, "Leave " + String(reg.name))

	for i in 3:
		_spawn_inter("note", "r%d_note_%d" % [ri, i], ent_id, i, _free_pos(rng), "Read torn note")
	var picks: Array = [ent_data.weakness_item]
	var item_ids: Array = DataDB.items.keys()
	while picks.size() < 4:
		var c: String = item_ids[rng.randi() % item_ids.size()]
		if not picks.has(c):
			picks.append(c)
	for i in picks.size():
		_spawn_inter("item", "r%d_item_%d" % [ri, i], picks[i], 0, _free_pos(rng), "Pick up " + String(DataDB.items[picks[i]].name))

	for i in 5:
		_spawn_inter("scrap", "r%d_scrap_%d" % [ri, i], "", 0, _free_pos(rng), "Pick up scrap wood")
	for s in GameState.shelters:
		_spawn_shelter(Vector2(float(s.x), float(s.y)), float(s.dur), String(s.ward))

	if not GameState.banished_here:
		var e: CharacterBody2D = EntityScript.new()
		world.add_child(e)
		e.setup(ent_id, player, Vector2(W * 0.6, H * 0.6))
		e.nav = nav
		e.walls = wall_rects
		e.caught.connect(_on_caught)
		e.wailed.connect(func(t: String): _toast(t, 4.0))
	_toast(String(reg.intro), 6.0)

func _add_wall(r: Rect2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.position = r.position + r.size / 2.0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	cs.shape = rs
	body.add_child(cs)
	var vis := ColorRect.new()
	vis.size = r.size
	vis.position = -r.size / 2.0
	vis.color = color
	body.add_child(vis)
	world.add_child(body)

func _free_pos(rng: RandomNumberGenerator) -> Vector2:
	for i in 80:
		var p := Vector2(rng.randf_range(80, W - 80), rng.randf_range(80, H - 80))
		var ok := p.distance_to(START) > 160.0 and p.distance_to(EXIT_POS) > 100.0
		for r in wall_rects:
			if (r as Rect2).grow(36).has_point(p):
				ok = false
				break
		if ok:
			return p
	return Vector2(W / 2.0, H / 2.0)

func _spawn_inter(kind: String, key: String, payload: String, index: int, pos: Vector2, label: String) -> void:
	if key != "" and GameState.collected.has(key):
		return
	var n: Node2D = InterScript.new()
	n.kind = kind
	n.key = key
	n.payload = payload
	n.index = index
	n.label_text = label
	n.position = pos
	world.add_child(n)

# ---------------------------------------------------------------- GAMEPLAY
func _nearest_interactable() -> Node2D:
	var best: Node2D = null
	var bd := 48.0
	for n in get_tree().get_nodes_in_group("interactable"):
		var d: float = (n as Node2D).global_position.distance_to(player.global_position)
		if d < bd:
			best = n
			bd = d
	return best

func _interact() -> void:
	var n := _nearest_interactable()
	if n == null:
		if player.in_shelter != null:
			_sync_shelters()
			GameState.sanity = player.sanity_max
			GameState.save_game(player.global_position)
			_toast("You rest inside the shelter. Game saved.")
		return
	match n.kind:
		"note":
			var eid: String = n.payload
			GameState.learn_clue(eid, n.index)
			var bonus := int(GameState.character().get("lore_bonus", 0))
			var clues: Array = DataDB.entities[eid].lore_clues
			for i in clues.size():
				if bonus <= 0:
					break
				if GameState.learn_clue(eid, i):
					bonus -= 1
			_toast("Note: " + String(clues[n.index]) + "\n(Added to journal. Press J.)", 8.0)
			GameState.collected.append(n.key)
			n.queue_free()
		"scrap":
			GameState.scrap += 1
			_toast("Scrap wood: %d (B builds a shelter for %d)" % [GameState.scrap, SHELTER_COST])
			GameState.collected.append(n.key)
			n.queue_free()
		"item":
			if GameState.inventory.size() >= 8:
				_toast("Inventory full.")
				return
			GameState.inventory.append(n.payload)
			_toast("Picked up: " + String(DataDB.items[n.payload].name))
			GameState.collected.append(n.key)
			n.queue_free()
		"save":
			_sync_shelters()
			GameState.sanity = player.sanity_max
			GameState.save_game(player.global_position)
			_toast("Game saved. The light steadies your nerves.")
		"exit":
			_next_region()

func _use_item(slot: int) -> void:
	if slot >= GameState.inventory.size():
		return
	var item_id: String = GameState.inventory[slot]
	var target: Node = null
	var best := 190.0
	for e in get_tree().get_nodes_in_group("entity"):
		if e.banished:
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		if d < best:
			target = e
			best = d
	if target == null:
		_toast("Nothing nearby to use that on.")
		return
	GameState.inventory.remove_at(slot)
	if item_id == target.data.weakness_item:
		target.banish()
		GameState.banished_here = true
		SteamManager.unlock("ACH_BANISH_" + String(target.entity_id).to_upper())
		_toast(String(target.data.banish_text), 6.0)
	else:
		target.enrage(10.0)
		_toast(String(target.data.enrage_text), 5.0)

func _on_caught() -> void:
	if invuln > 0.0 or state != "play":
		return
	GameState.deaths += 1
	invuln = 3.0
	GameState.sanity = player.sanity_max * 0.6
	player.global_position = GameState.save_pos if GameState.has_checkpoint else START
	for e in get_tree().get_nodes_in_group("entity"):
		if not e.banished:
			e.reset()
	_toast("It found you. You wake at the last light, shaking.", 4.0)

func _next_region() -> void:
	GameState.region_index += 1
	GameState.collected = []
	GameState.banished_here = false
	GameState.has_checkpoint = false
	GameState.shelters = []
	if GameState.region_index >= DataDB.regions.size():
		SteamManager.unlock("ACH_SURVIVED_THE_WORLD")
		var deaths := GameState.deaths
		GameState.delete_save()
		if world:
			world.queue_free()
			world = null
		state = "ending"
		_set_vignette(0.0)
		sanity_bar.visible = false
		info_label.text = ""
		prompt_label.text = ""
		canvas_mod.color = Color.WHITE
		title_label.text = "YOU SURVIVED THE WORLD.\n\nEight nightmares. Eight countries.\nDeaths: %d\n\nPress any key." % deaths
		title_label.visible = true
		return
	GameState.sanity = float(GameState.character().sanity_max)
	GameState.save_game(START)
	_start_region()

func _process(delta: float) -> void:
	if state != "play" or player == null:
		return
	invuln = maxf(0.0, invuln - delta)
	toast_t -= delta
	if toast_t <= 0.0:
		toast_label.text = ""
	var drain := 0.0
	for e in get_tree().get_nodes_in_group("entity"):
		if e.banished:
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		if d < 280.0:
			drain += (1.0 - d / 280.0) * 9.0
	drain *= player.sanity_drain_mult
	player.in_shelter = null
	for sh in get_tree().get_nodes_in_group("shelter"):
		if sh.contains(player.global_position):
			player.in_shelter = sh
			break
	if player.in_shelter != null:
		GameState.sanity += 3.0 * delta
		if player.in_shelter.hit_t > 0.0 and toast_t <= 0.0:
			_toast("Something is scratching at the walls...", 2.0)
	elif drain > 0.0:
		GameState.sanity -= drain * delta
	else:
		GameState.sanity += 0.6 * delta
	GameState.sanity = clampf(GameState.sanity, 0.0, player.sanity_max)
	player.flicker = GameState.sanity < 30.0
	_update_dread(delta)
	if GameState.sanity <= 0.0:
		_on_caught()
	_update_hud()

func _update_hud() -> void:
	var reg: Dictionary = GameState.region()
	var c: Dictionary = GameState.character()
	var inv := ""
	for i in GameState.inventory.size():
		inv += "[%d] %s   " % [i + 1, DataDB.items[GameState.inventory[i]].name]
	info_label.text = "%s | %s, %s | Deaths: %d | Scrap: %d\n\n%s\nWASD move | Mouse aim | F light | Shift sneak | E interact | 1-8 use item | B build shelter | G ward | J journal | Esc menu" % [
		c.name, reg.name, reg.country, GameState.deaths, GameState.scrap, inv]
	sanity_bar.max_value = player.sanity_max
	sanity_bar.value = GameState.sanity
	var n := _nearest_interactable()
	if n != null:
		prompt_label.text = "[E] " + n.label_text
	elif player.in_shelter != null:
		prompt_label.text = "[E] Rest and save    [G] Ward shelter"
	elif GameState.scrap >= SHELTER_COST:
		prompt_label.text = "[B] Build shelter"
	else:
		prompt_label.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if state == "title":
		var ids: Array = DataDB.characters.keys()
		var n: int = event.keycode - KEY_1
		if n >= 0 and n < ids.size():
			GameState.new_game(ids[n])
			_start_region()
		elif event.keycode == KEY_C and GameState.has_save():
			if GameState.load_game():
				_start_region()
		return
	if state == "ending":
		_show_title()
		return
	if ward_pending:
		ward_pending = false
		var ws: int = event.keycode - KEY_1
		if ws >= 0 and ws < 8:
			_ward(ws)
		else:
			_toast("Warding cancelled.")
		return
	if event.keycode == KEY_B and not event.is_action_pressed("interact"):
		_build_shelter()
	elif event.keycode == KEY_G:
		_start_ward()
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("journal"):
		journal_panel.visible = not journal_panel.visible
		if journal_panel.visible:
			_refresh_journal()
	elif event.keycode == KEY_ESCAPE:
		_show_title()
	else:
		var slot: int = event.keycode - KEY_1
		if slot >= 0 and slot < 8:
			_use_item(slot)

# ---------------------------------------------------------------- SHELTERS
func _spawn_shelter(pos: Vector2, durability: float, ward: String) -> void:
	var s: Node2D = ShelterScript.new()
	s.position = pos
	s.durability = durability
	s.warded_against = ward
	s.collapsed.connect(func(_sh): _toast("The shelter collapses!", 4.0))
	world.add_child(s)

func _sync_shelters() -> void:
	GameState.shelters = []
	for sh in get_tree().get_nodes_in_group("shelter"):
		if sh.durability > 0.0:
			GameState.shelters.append({"x": sh.global_position.x, "y": sh.global_position.y,
				"dur": sh.durability, "ward": sh.warded_against})

func _build_shelter() -> void:
	if state != "play" or player == null:
		return
	if GameState.scrap < SHELTER_COST:
		_toast("You need %d scrap wood to build a shelter (you have %d)." % [SHELTER_COST, GameState.scrap])
		return
	var existing: Array = get_tree().get_nodes_in_group("shelter")
	if existing.size() >= MAX_SHELTERS:
		_toast("You can only keep %d shelters in one area." % MAX_SHELTERS)
		return
	var p: Vector2 = player.global_position
	if p.x < 60 or p.y < 60 or p.x > W - 60 or p.y > H - 60:
		_toast("Too close to the edge to build.")
		return
	for r in wall_rects:
		if (r as Rect2).grow(40).has_point(p):
			_toast("Too close to a wall to build.")
			return
	for sh in existing:
		if (sh as Node2D).global_position.distance_to(p) < 90.0:
			_toast("Too close to another shelter.")
			return
	for n in get_tree().get_nodes_in_group("interactable"):
		if (n as Node2D).global_position.distance_to(p) < 60.0:
			_toast("Something is in the way.")
			return
	for e in get_tree().get_nodes_in_group("entity"):
		if not e.banished and e.global_position.distance_to(p) < 120.0:
			_toast("Not with that thing so close!")
			return
	GameState.scrap -= SHELTER_COST
	_spawn_shelter(p, 100.0, "")
	_toast("Shelter built. Stand inside to hide. E rests and saves. G wards it.", 5.0)

func _start_ward() -> void:
	if state != "play" or player == null:
		return
	if player.in_shelter == null:
		_toast("Stand inside a shelter to ward it.")
		return
	if player.in_shelter.warded_against != "":
		_toast("This shelter is already warded.")
		return
	ward_pending = true
	_toast("Ward the shelter with which item? Press 1-8, or any other key to cancel.", 6.0)

func _ward(slot: int) -> void:
	if slot >= GameState.inventory.size() or player.in_shelter == null:
		_toast("Warding cancelled.")
		return
	var item_id: String = GameState.inventory[slot]
	GameState.inventory.remove_at(slot)
	var ent_id: String = GameState.region().entity
	if item_id == DataDB.entities[ent_id].weakness_item:
		player.in_shelter.warded_against = ent_id
		_toast("The %s settles into the walls. This shelter is now safe from the %s." % [
			DataDB.items[item_id].name, DataDB.entities[ent_id].name], 6.0)
		SteamManager.unlock("ACH_WARDED_SHELTER")
	else:
		_toast("Nothing happens. The %s is wasted." % DataDB.items[item_id].name, 4.0)

# ---------------------------------------------------------------- NAV + DREAD
func _build_nav() -> AStarGrid2D:
	var a := AStarGrid2D.new()
	a.region = Rect2i(0, 0, int(W / 32) + 1, int(H / 32) + 1)
	a.cell_size = Vector2(32, 32)
	a.offset = Vector2(16, 16)
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	a.update()
	for r in wall_rects:
		var g: Rect2 = (r as Rect2).grow(16.0)
		for x in range(int(g.position.x / 32.0), int(g.end.x / 32.0) + 1):
			for y in range(int(g.position.y / 32.0), int(g.end.y / 32.0) + 1):
				var c := Vector2i(x, y)
				if a.is_in_boundsv(c):
					a.set_point_solid(c, true)
	return a

func _set_vignette(v: float) -> void:
	if vignette and vignette.material:
		(vignette.material as ShaderMaterial).set_shader_parameter("intensity", v)

## Low sanity: pulsing red vignette, fake monsters at the edge of your light, whispers.
func _update_dread(delta: float) -> void:
	var low := clampf(1.0 - GameState.sanity / 45.0, 0.0, 1.0)
	var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() / (260.0 - 120.0 * low))
	_set_vignette(low * pulse)
	if low <= 0.0 or player.in_shelter != null:
		return
	phantom_t -= delta
	if phantom_t > 0.0:
		return
	phantom_t = lerpf(11.0, 4.0, low) + randf_range(0.0, 3.0)
	var ent_color := Color.WHITE
	var eid: String = GameState.region().entity
	ent_color = Color(DataDB.entities[eid].get("color", "#ffffff"))
	var p: Node2D = PhantomScript.new()
	p.color = ent_color
	p.position = player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(140.0, 260.0)
	world.add_child(p)
	if toast_t <= 0.0:
		_toast(WHISPERS[randi() % WHISPERS.size()], 3.0)
