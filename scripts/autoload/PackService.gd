extends Node

var available_packs: Array = []

func _ready():
	_load_packs()

func _load_packs():
	var json_str = FileAccess.get_file_as_string("res://data/packs.json")
	if json_str == "":
		return
	var data = JSON.parse_string(json_str)
	available_packs = data["packs"]

func select_pack(pack_id: String):
	GameState.active_pack_id = pack_id
	EventBus.pack_selected.emit(pack_id)

func get_available_packs() -> Array:
	return available_packs
