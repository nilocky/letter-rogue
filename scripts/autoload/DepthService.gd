extends Node
## Depth: 3-stage encounter generation (Vanguard / Sentry / Boss) + Tag rewards.

var _depths_cache: Dictionary = {}


func _ready() -> void:
	_load_depths()


func _load_depths() -> void:
	var text := FileAccess.get_file_as_string("res://data/depths.json")
	var data: Variant = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY:
		_depths_cache = data


func get_stage_pool(stage: String) -> Array:
	return _depths_cache.get(stage, [])


func generate_encounter(stage: int) -> Dictionary:
	var pool_name: String = "vanguard"
	if stage == 1:
		pool_name = "sentry"
	elif stage >= 2:
		pool_name = "bosses"
	var pool: Array = get_stage_pool(pool_name)
	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()].duplicate(true)