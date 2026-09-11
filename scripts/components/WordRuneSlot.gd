class_name WordRuneSlot
extends PanelContainer

signal rune_dismissed(slot_instance: WordRuneSlot)

@onready var letter_label: Label = %LetterLabel
@onready var power_label: Label = %PowerLabel

var tile_data: Dictionary = {}
var slot_index: int = -1
var drag_start_pos := Vector2.ZERO

func setup(letter: String, power: int, index: int, data: Dictionary = {}) -> void:
	tile_data = data
	letter_label.text = letter
	if power > 0:
		power_label.text = str(power)
		power_label.show()
	else:
		power_label.hide()
	slot_index = index

func _get_drag_data(at_position: Vector2) -> Variant:
	var preview := duplicate() as Control
	preview.modulate = Color(1.2, 1.2, 1.5, 0.95)
	preview.scale = Vector2(1.12, 1.12)
	var pc := Control.new()
	pc.add_child(preview)
	preview.position = -at_position * 1.12 + Vector2(0, -10)
	set_drag_preview(pc)
	modulate.a = 0.2
	return {"source_slot": self, "tile_data": tile_data}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_start_pos = event.position
		elif event.position.distance_to(drag_start_pos) < 10.0:
			rune_dismissed.emit(self)
