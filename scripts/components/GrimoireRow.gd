extends HBoxContainer
class_name GrimoireRow

func refresh() -> void:
	for c in get_children():
		c.queue_free()
	for g: Dictionary in GameState.active_grimoires:
		var icon := GrimoireIcon.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.setup(g)
		add_child(icon)

func _can_drop_data(position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY:
		var d: Dictionary = data
		return str(d.get("type", "")) == "grimoire"
	return false

func _drop_data(position: Vector2, data: Variant) -> void:
	var d: Dictionary = data
	if str(d.get("type", "")) != "grimoire":
		return
	var from_idx := int(d.get("from_index", -1))
	var to_idx := _child_index_at_pos(position)
	if from_idx < 0 or to_idx < 0 or from_idx == to_idx:
		return
	var tmp: Dictionary = GameState.active_grimoires[from_idx]
	GameState.active_grimoires.remove_at(from_idx)
	GameState.active_grimoires.insert(to_idx, tmp)
	refresh()

func _child_index_at_pos(position: Vector2) -> int:
	var count := get_child_count()
	if count == 0:
		return -1
	var w := get_child(0).size.x
	var idx := int(floor(position.x / maxf(w, 1.0)))
	return clampi(idx, 0, count - 1)