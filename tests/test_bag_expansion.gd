extends SceneTree

func _init() -> void:
	var text := FileAccess.get_file_as_string("res://data/starter_bags.json")
	var data: Variant = JSON.parse_string(text)
	var bags: Array = data.get("starter_bags", [])
	var standard: Dictionary = bags[0]
	assert(standard["id"] == "standard")
	var tiles: Array = standard.get("tiles", [])
	assert(tiles.size() == 14, "Standard bag should have 14 tiles, got %d" % tiles.size())
	var letters := PackedStringArray()
	for t in tiles:
		letters.append(str(t["letter"]))
	for expected in ["E","T","A","O","I","N","S","R","D","L","C","M","P","H"]:
		assert(letters.has(expected), "Standard bag missing %s" % expected)
	print("OK: Standard bag has %d tiles with correct letters" % tiles.size())
	quit(0)
