extends SceneTree
func _initialize():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var gs = root.get_node("GameState")
	var db = root.get_node("DataDB")
	print("regions:", db.regions.size(), " entities:", db.entities.size())
	gs.new_game("imani")
	for ri in db.regions.size():
		gs.region_index = ri
		gs.collected = []
		gs.banished_here = false
		gs.has_checkpoint = false
		main._start_region()
		for i in 90: await physics_frame
		var ents = get_nodes_in_group("entity")
		var inters = get_nodes_in_group("interactable")
		print(gs.region_id(), " entities=", ents.size(), " interactables=", inters.size())
		# teleport next to entity, give the right item, use it
		var e = ents[0]
		main.player.global_position = e.global_position + Vector2(60, 0)
		gs.inventory = ["brick", e.data.weakness_item] if e.data.weakness_item != "brick" else ["garlic", "brick"]
		main._use_item(0)   # wrong item -> enrage
		assert(e.enraged > 0.0)
		var slot = gs.inventory.find(e.data.weakness_item)
		main._use_item(slot)
		assert(e.banished)
		# note pickup + save point
		for n in get_nodes_in_group("interactable"):
			if n.kind == "note":
				main.player.global_position = n.global_position
				main._interact()
				break
		for n in get_nodes_in_group("interactable"):
			if n.kind == "save":
				main.player.global_position = n.global_position
				main._interact()
				break
		main._refresh_journal()
		main._update_hud()
	# save/load roundtrip
	gs.region_index = 3
	var before = gs.lore.duplicate(true)
	gs.save_game(Vector2(300, 300))
	gs.new_game("hana")
	assert(gs.load_game())
	print("loaded char=", gs.character_id, " region=", gs.region_index, " lore keys=", gs.lore.keys().size(), " pos=", gs.save_pos)
	main._start_region()
	for i in 30: await physics_frame
	# death + ending
	main._on_caught()
	print("deaths:", gs.deaths)
	gs.region_index = db.regions.size() - 1
	main._start_region()
	await physics_frame
	main._next_region()
	print("state after finish:", main.state, " save exists:", gs.has_save())
	quit()
