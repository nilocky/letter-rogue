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
