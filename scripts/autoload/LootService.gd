extends Node

const DROP_PATH := "res://data/drop_tables.json"

var _tables: Dictionary = {}

func _ready() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DROP_PATH))
	if typeof(data) == TYPE_DICTIONARY:
		for t: Variant in data.get("drop_tables", []):
			var table: Dictionary = t
			_tables[str(table["id"])] = table

func roll_drops(monster: Dictionary) -> Array:
	var table_id: String = str(monster.get("drop_table_id", ""))
	if table_id == "" or not _tables.has(table_id):
		return []
	var drops: Array = []
	for entry: Variant in _tables[table_id]["entries"]:
		var e: Dictionary = entry
		var w: int = int(e.get("weight", 1))
		if randf() < float(w) / 10.0:
			drops.append({"type": str(e.get("type", "money")),
				"label": str(e.get("label", "?")), "value": int(e.get("value", 0))})
	return drops
