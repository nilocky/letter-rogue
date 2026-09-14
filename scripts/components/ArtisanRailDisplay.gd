extends HBoxContainer
class_name ArtisanRailDisplay

var _slots: Array = []

func _ready() -> void:
	_build_slots()

func _build_slots() -> void:
	for child in get_children():
		child.queue_free()
	_slots.clear()
	for i in 5:
		var slot := preload("res://scenes/components/ArtisanSlot.tscn").instantiate() as ArtisanSlot
		add_child(slot)
		_slots.append(slot)

func refresh() -> void:
	for i in 5:
		var artisan: Dictionary = ArtisanRailManager.get_slot(i)
		_slots[i].set_artisan(artisan)

func trigger_slot(index: int) -> void:
	if index >= 0 and index < _slots.size():
		_slots[index].trigger_glow()
		_slots[index].trigger_shake()


func _can_drop_data(position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY:
		var d: Dictionary = data
		return str(d.get("type", "")) == "artisan"
	return false


func _drop_data(position: Vector2, data: Variant) -> void:
	var d: Dictionary = data
	if str(d.get("type", "")) != "artisan":
		return
	var from_idx := int(d.get("from_index", -1))
	var to_idx := _slot_index_at_position(position)
	if from_idx < 0 or to_idx < 0 or from_idx == to_idx:
		return
	if ArtisanRailManager.swap_slots(from_idx, to_idx):
		refresh()


func _slot_index_at_position(position: Vector2) -> int:
	var shown: Array = []
	for slot in _slots:
		if slot.visible:
			shown.append(slot)
	if shown.is_empty():
		return -1
	var slot_w: float = shown[0].size.x
	var idx := int(floor(position.x / maxf(slot_w, 1.0)))
	return shown[clampi(idx, 0, shown.size() - 1)].get_index()
