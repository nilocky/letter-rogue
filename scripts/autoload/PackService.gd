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

func get_available_packs() -> Array:
	return available_packs

func pack_by_id(pack_id: String) -> Dictionary:
	for pack in available_packs:
		if str(pack.get("id", "")) == pack_id:
			return pack
	return {}

func evaluate_conditionals(pack_id: String, word: String, slots: Array, _letter_scores: Array) -> Dictionary:
	var pack: Dictionary = pack_by_id(pack_id)
	if pack.is_empty():
		return {}
	var conds: Array = pack.get("conditionals", [])
	var result: Dictionary = {"score_mult": 1.0, "xmult": 1.0, "flat": 0, "min_length": 0}

	for c in conds:
		match str(c.get("type", "")):
			"rare_consonant_mult":
				var has_rare := false
				for s in slots:
					var l: String = str(s.get("letter", ""))
					if "VKXJQZ".contains(l):
						has_rare = true
						break
				if has_rare:
					result["score_mult"] = float(c.get("value", 1.0))
			"short_word_penalty":
				if slots.size() <= int(c.get("max_len", 3)):
					result["score_mult"] = float(c.get("mult", 1.0))
			"length_xmult":
				if slots.size() == int(c.get("len", 0)):
					result["xmult"] = float(c.get("value", 1.0))
			"min_word_length":
				result["min_length"] = int(c.get("value", 0))
			"silence_immunity":
				result["silence_immunity"] = true
			"base_penalty":
				result["score_mult"] = float(c.get("mult", 1.0))

	return result
