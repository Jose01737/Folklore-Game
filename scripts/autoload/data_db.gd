extends Node
## Loads all game content from /data/*.json. Edit those files to change the game.

var entities: Dictionary = {}
var characters: Dictionary = {}
var regions: Dictionary = {}
var items: Dictionary = {}

func _ready() -> void:
	entities = _load_json("res://data/entities.json")
	characters = _load_json("res://data/characters.json")
	regions = _load_json("res://data/regions.json")
	items = _load_json("res://data/items.json")

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing data file: " + path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("Bad JSON in: " + path)
	return {}
