extends SceneTree
func _initialize():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var gs = root.get_node("GameState")
	gs.new_game("imani")
	gs.region_index = 0
	main._start_region()
	for i in 10: await physics_frame
	var e = get_nodes_in_group("entity")[0]
	# not enough scrap
	main._build_shelter()
	assert(get_nodes_in_group("shelter").size() == 0)
	# scrap pickups exist
	var scraps = get_nodes_in_group("interactable").filter(func(n): return n.kind == "scrap")
	print("scrap pickups:", scraps.size())
	for s in scraps.slice(0, 3):
		main.player.global_position = s.global_position
		main._interact()
	assert(gs.scrap == 3)
	# build far from monster, in open ground
	var spot := Vector2(800, 400)
	for cand in [Vector2(800, 400), Vector2(500, 900), Vector2(1100, 300), Vector2(900, 900), Vector2(400, 600)]:
		if main.wall_rects.all(func(r): return not r.grow(260).has_point(cand)):
			spot = cand
			break
	main.player.global_position = spot
	e.global_position = Vector2(1400, 1100)
	main._build_shelter()
	assert(get_nodes_in_group("shelter").size() == 1 and gs.scrap == 0)
	var sh = get_nodes_in_group("shelter")[0]
	main.player.global_position = sh.global_position
	gs.sanity = 10.0
	for i in 60: await physics_frame
	assert(main.player.in_shelter == sh)
	print("sanity regen in shelter:", snappedf(gs.sanity, 0.1))
	assert(gs.sanity > 10.0)
	# monster that noticed you comes and breaks it (unwarded)
	e.global_position = sh.global_position + Vector2(150, 0)
	for i in 300: await physics_frame
	print("durability after attack:", snappedf(sh.durability, 0.1), " deaths:", gs.deaths)
	assert(sh.durability < 100.0 and gs.deaths == 0)
	# ward it with the right item: monster is repelled and durability stops dropping
	sh.durability = 100.0
	gs.inventory = [e.data.weakness_item]
	main._start_ward()
	assert(main.ward_pending)
	main.ward_pending = false
	main._ward(0)
	assert(sh.warded_against == "aswang")
	e.global_position = sh.global_position + Vector2(60, 0)
	for i in 120: await physics_frame
	print("warded durability:", sh.durability, " monster dist:", snappedf(e.global_position.distance_to(sh.global_position), 1.0))
	assert(sh.durability == 100.0 and gs.deaths == 0)
	# rest saves shelters + scrap; load restores them
	gs.scrap = 2
	main._interact()
	gs.new_game("hana")
	assert(gs.load_game())
	print("loaded shelters:", gs.shelters, " scrap:", gs.scrap)
	main._start_region()
	await physics_frame
	var sh2 = get_nodes_in_group("shelter")
	assert(sh2.size() == 1 and sh2[0].warded_against == "aswang")
	# collapse
	sh2[0].damage(500.0)
	await physics_frame
	await physics_frame
	assert(get_nodes_in_group("shelter").size() == 0)
	print("ALL SHELTER TESTS PASSED")
	quit()
