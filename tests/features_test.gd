extends SceneTree
func _initialize():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var gs = root.get_node("GameState")
	gs.new_game("mateo")
	main._start_region()
	for i in 5: await physics_frame
	var e = get_nodes_in_group("entity")[0]
	assert(e.nav != null)
	# --- pathfinding: put a tall wall between monster and player
	var wall := Rect2()
	var left := Vector2.ZERO
	var right := Vector2.ZERO
	for r in main.wall_rects:
		if r.size.y <= r.size.x:
			continue
		var cy: float = r.position.y + r.size.y / 2.0
		var l := Vector2(r.position.x - 70.0, cy)
		var rt := Vector2(r.end.x + 70.0, cy)
		if l.x < 80 or rt.x > 1520:
			continue
		if main.wall_rects.all(func(o): return o == r or (not o.grow(40).has_point(l) and not o.grow(40).has_point(rt))):
			wall = r
			left = l
			right = rt
			break
	assert(wall.size != Vector2.ZERO)
	main.player.global_position = right
	gs.sanity = main.player.sanity_max
	e.global_position = left
	e.enraged = 60.0
	var min_d := 9999.0
	main.invuln = 999.0   # observe without dying
	for i in 1500:
		await physics_frame
		e.enraged = 60.0
		main.player.global_position = right
		min_d = minf(min_d, e.global_position.distance_to(right))
	print("monster closest approach around wall:", snappedf(min_d, 1.0), " (wall ", wall, ")")
	assert(min_d < 40.0)
	# --- dread: low sanity draws phantoms + vignette
	main.invuln = 0.0
	e.banish()
	main.player.in_shelter = null
	gs.sanity = 10.0
	main.phantom_t = 0.0
	main.toast_t = 0.0
	await physics_frame
	await process_frame
	var ph := get_nodes_in_group("entity").size()
	var found := false
	for n in main.world.get_children():
		if n.get_script() == main.PhantomScript:
			found = true
	var inten: float = (main.vignette.material as ShaderMaterial).get_shader_parameter("intensity")
	print("phantom spawned:", found, " vignette intensity:", snappedf(inten, 0.01))
	assert(found and inten > 0.3)
	gs.sanity = 100.0
	await process_frame
	await process_frame
	assert((main.vignette.material as ShaderMaterial).get_shader_parameter("intensity") == 0.0)
	print("ALL FEATURE TESTS PASSED")
	quit()
