extends Node
## Global run state, input setup, and save/load.

const SAVE_PATH := "user://savegame.json"

var character_id := ""
var region_index := 0
var inventory: Array = []
var lore: Dictionary = {}      # entity_id -> [clue indexes known]
var collected: Array = []      # keys of picked-up notes/items in current region
var banished_here := false
var deaths := 0
var save_pos := Vector2.ZERO
var has_checkpoint := false
var sanity := 100.0
var scrap := 0
var shelters: Array = []   # [{x, y, dur, ward}]

func _ready() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("interact", [KEY_E])
	_add_action("sneak", [KEY_SHIFT])
	_add_action("journal", [KEY_J, KEY_TAB])
	_add_action("flashlight", [KEY_F])

func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func new_game(char_id: String) -> void:
	character_id = char_id
	region_index = 0
	inventory = []
	lore = {}
	collected = []
	banished_here = false
	deaths = 0
	has_checkpoint = false
	scrap = 0
	shelters = []
	var c: Dictionary = DataDB.characters[char_id]
	var start: String = c.get("start_item", "")
	if start != "":
		inventory.append(start)
	sanity = float(c.sanity_max)

func character() -> Dictionary:
	return DataDB.characters.get(character_id, {})

func region_id() -> String:
	return DataDB.regions.keys()[region_index]

func region() -> Dictionary:
	return DataDB.regions[region_id()]

func learn_clue(entity_id: String, idx: int) -> bool:
	if not lore.has(entity_id):
		lore[entity_id] = []
	if lore[entity_id].has(idx):
		return false
	lore[entity_id].append(idx)
	return true

func save_game(pos: Vector2) -> void:
	save_pos = pos
	has_checkpoint = true
	var d := {
		"character_id": character_id,
		"region_index": region_index,
		"inventory": inventory,
		"lore": lore,
		"collected": collected,
		"banished_here": banished_here,
		"deaths": deaths,
		"save_pos": [pos.x, pos.y],
		"sanity": sanity,
		"scrap": scrap,
		"shelters": shelters,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func load_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return false
	if not DataDB.characters.has(d.get("character_id", "")):
		return false
	character_id = d.character_id
	region_index = clampi(int(d.get("region_index", 0)), 0, DataDB.regions.size() - 1)
	inventory = d.get("inventory", [])
	collected = d.get("collected", [])
	banished_here = bool(d.get("banished_here", false))
	deaths = int(d.get("deaths", 0))
	sanity = float(d.get("sanity", 100.0))
	scrap = int(d.get("scrap", 0))
	shelters = d.get("shelters", [])
	var sp: Array = d.get("save_pos", [120, 120])
	save_pos = Vector2(float(sp[0]), float(sp[1]))
	has_checkpoint = true
	lore = {}
	var raw: Dictionary = d.get("lore", {})
	for k in raw:
		var arr: Array = []
		for x in raw[k]:
			arr.append(int(x))
		lore[k] = arr
	return true
