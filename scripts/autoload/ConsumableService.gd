extends Node
## Consumables: Tarot / Spectral / Grimoire item effects that mutate the bag or word forms.

var _consumables_cache: Dictionary = {}


func _ready() -> void:
	_load_consumables()


func _load_consumables() -> void:
	var text := FileAccess.get_file_as_string("res://data/consumables.json")
	var data: Variant = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY:
		_consumables_cache = data


func get_tarot() -> Array:
	return _consumables_cache.get("tarot", [])


func get_spectral() -> Array:
	return _consumables_cache.get("spectral", [])


func get_grimoires() -> Array:
	return _consumables_cache.get("grimoire", [])


func apply(item: Dictionary) -> Dictionary:
	var effect_type: String = str(item.get("effect_type", ""))
	var params: Dictionary = item.get("effect_params", {})
	match effect_type:
		"remove_tile":
			if GameState.bag.is_empty():
				return {"ok": false, "reason": "empty_bag"}
			var cheapest: Dictionary = _find_cheapest_tile()
			GameState.bag.erase(cheapest)
			EffectPipeline.trigger("on_bag_mutated", ["remove_tile", [cheapest]])
			return {"ok": true, "removed": cheapest}
		"duplicate_tile":
			if GameState.bag.is_empty():
				return {"ok": false, "reason": "empty_bag"}
			var pick: Dictionary = GameState.bag[randi() % GameState.bag.size()].duplicate(true)
			GameState.bag.append(pick)
			EffectPipeline.trigger("on_bag_mutated", ["duplicate_tile", [pick]])
			return {"ok": true, "added": pick}
		"wildcard_tile":
			if GameState.bag.is_empty():
				return {"ok": false, "reason": "empty_bag"}
			var idx: int = randi() % GameState.bag.size()
			GameState.bag[idx]["letter"] = "*"
			GameState.bag[idx]["ability_id"] = "wild"
			GameState.bag[idx]["is_symbol"] = true
			EffectPipeline.trigger("on_bag_mutated", ["wildcard_tile", [GameState.bag[idx]]])
			return {"ok": true}
		"lube_tile":
			if GameState.bag.is_empty():
				return {"ok": false, "reason": "empty_bag"}
			var l_idx: int = randi() % GameState.bag.size()
			GameState.bag[l_idx]["condition"] = "lubed"
			EffectPipeline.trigger("on_bag_mutated", ["lube_tile", [GameState.bag[l_idx]]])
			return {"ok": true, "affected": GameState.bag[l_idx]}
		"destroy_random":
			var count: int = int(params.get("count", 1))
			var destroyed: Array = []
			for _i in range(mini(count, GameState.bag.size())):
				var d_idx: int = randi() % GameState.bag.size()
				destroyed.append(GameState.bag[d_idx])
				GameState.bag.remove_at(d_idx)
			GameState.money += 25
			EffectPipeline.trigger("on_bag_mutated", ["destroy_random", destroyed])
			return {"ok": true, "destroyed": destroyed.size(), "money_gained": 25}
		"overclock_tile":
			if GameState.bag.is_empty():
				return {"ok": false, "reason": "empty_bag"}
			var o_idx: int = randi() % GameState.bag.size()
			GameState.bag[o_idx]["finish"] = "polychrome"
			GameState.upgrade_redraws = maxi(GameState.upgrade_redraws - 1, 0)
			EffectPipeline.trigger("on_bag_mutated", ["overclock_tile", [GameState.bag[o_idx]]])
			return {"ok": true, "affected": GameState.bag[o_idx]}
		"ghost_wire":
			var g_count: int = int(params.get("count", 2))
			var transformed := 0
			for i in range(mini(g_count, GameState.hand.size())):
				GameState.hand[i]["letter"] = "*"
				GameState.hand[i]["ability_id"] = "wild"
				GameState.hand[i]["is_symbol"] = true
				transformed += 1
			return {"ok": true, "transformed": transformed}
		"level_word_form":
			var form_id: String = str(params.get("form_id", ""))
			var level: int = GameState.word_form_levels.get(form_id, 0) + 1
			GameState.word_form_levels[form_id] = level
			return {"ok": true, "form_id": form_id, "level": level}
	return {"ok": false, "reason": "unknown_effect"}


func _find_cheapest_tile() -> Dictionary:
	var cheapest: Dictionary = {}
	var min_price: int = 999
	for cap in GameState.bag:
		var price: int = int(cap.get("price", 1))
		if price < min_price:
			min_price = price
			cheapest = cap
	return cheapest