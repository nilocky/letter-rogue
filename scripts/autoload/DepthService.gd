extends Node
## Depth: 8-stage encounter generation + milestone modifiers.

var _depths_cache: Dictionary = {}
var _modifiers_cache: Dictionary = {}


func _ready() -> void:
	_load_depths()
	_load_modifiers()


func _load_depths() -> void:
	var text := FileAccess.get_file_as_string("res://data/depths.json")
	var data: Variant = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY:
		_depths_cache = data


func _load_modifiers() -> void:
	_modifiers_cache = {
		"cursed": {
			"name": "Curse",
			"description": "25% chance per turn: random tile in hand becomes Cursed (0 score, cannot be redrawn)",
			"type": "on_draw"
		},
		"spore_cloud": {
			"name": "Spore Cloud",
			"description": "Vowels worth -1 score; Consonants worth +1 score (swaps each round)",
			"type": "on_score"
		},
		"reflective": {
			"name": "Reflection",
			"description": "Mirror words (palindromes) gain +50% damage",
			"type": "on_score"
		},
		"void_touch": {
			"name": "Void Corruption",
			"description": "One random letter banned per encounter",
			"type": "on_encounter"
		},
		"abyssal": {
			"name": "Abyssal Power",
			"description": "Boss gains +25% HP each cycle, all modifiers active",
			"type": "passive"
		}
	}


func get_stage_pool(stage: String) -> Array:
	return _depths_cache.get(stage, [])


func get_depth_name(stage: int) -> String:
	var name_map: Dictionary = {
		0: "VANGUARD",
		1: "SENTRY",
		2: "BOSS GATE",
		3: "CATACOMBS",
		4: "FUNGAL DEPTHS",
		5: "CRYSTAL CAVERNS",
		6: "VOID THRESHOLD",
		7: "ABYSSAL CROWN"
	}
	return name_map.get(stage, "ABYSSAL CROWN")


func get_depth_modifier(stage: int) -> Dictionary:
	var mod_map: Dictionary = {
		3: "cursed",
		4: "spore_cloud",
		5: "reflective",
		6: "void_touch",
		7: "abyssal"
	}
	var key: String = mod_map.get(stage, "")
	if key == "":
		return {}
	return _modifiers_cache[key]


func get_milestone_reward_depths() -> Array:
	return [3, 5, 7]


func generate_encounter(stage: int) -> Dictionary:
	var pool_map: Dictionary = {
		0: "vanguard",
		1: "sentry",
		2: "bosses",
		3: "catacombs",
		4: "fungal_depths",
		5: "crystal_caverns",
		6: "void_threshold",
		7: "abyssal_crown"
	}
	var pool_name: String = pool_map.get(stage, "abyssal_crown")
	var pool: Array = get_stage_pool(pool_name)
	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()].duplicate(true)