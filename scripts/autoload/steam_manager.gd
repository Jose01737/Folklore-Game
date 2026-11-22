extends Node
## Safe Steam wrapper. Does nothing unless the GodotSteam plugin is installed.

var steam_ready := false
var steam: Object = null

func _ready() -> void:
	if Engine.has_singleton("Steam"):
		steam = Engine.get_singleton("Steam")
		if steam.has_method("steamInitEx"):
			var result = steam.steamInitEx()
			steam_ready = (result is Dictionary and int(result.get("status", 1)) == 0) or result == true
		elif steam.has_method("steamInit"):
			steam.steamInit()
			steam_ready = true
		print("Steam ready: ", steam_ready)

func _process(_delta: float) -> void:
	if steam_ready and steam.has_method("run_callbacks"):
		steam.run_callbacks()

func unlock(achievement_id: String) -> void:
	if not steam_ready:
		print("[achievement stub] ", achievement_id)
		return
	steam.setAchievement(achievement_id)
	steam.storeStats()
