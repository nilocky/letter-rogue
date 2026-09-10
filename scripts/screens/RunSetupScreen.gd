extends Control

const KeyCapScene := preload("res://scenes/components/KeyCapElement.tscn")

const PACK_ACCENTS := {
	"mx_red": Color(0.85, 0.15, 0.15),
	"mx_blue": Color(0.2, 0.4, 0.9),
	"mx_brown": Color(0.55, 0.35, 0.15),
	"mx_black": Color(0.12, 0.12, 0.14),
	"mx_speed": Color(0.85, 0.85, 0.9),
}

@onready var back_button: Button = %BackButton
@onready var pack_accent: ColorRect = %PackAccent
@onready var pack_name: Label = %PackName
@onready var pack_desc: Label = %PackDesc
@onready var prev_pack_button: Button = %PrevPackButton
@onready var next_pack_button: Button = %NextPackButton
@onready var pack_dots: Label = %PackDots
@onready var bag_buttons: GridContainer = %BagButtons
@onready var bag_preview: HBoxContainer = %BagPreview
@onready var start_button: Button = %StartButton

var _pack_index: int = 0
var _bag_id: String = "standard"
var _bag_button_by_id: Dictionary = {}


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	prev_pack_button.pressed.connect(_on_prev_pack)
	next_pack_button.pressed.connect(_on_next_pack)
	start_button.pressed.connect(_on_start_pressed)
	_build_bag_buttons()
	_render_pack()
	_render_bag()


func _build_bag_buttons() -> void:
	var group := ButtonGroup.new()
	for bag: Dictionary in KeyCapService.get_starter_bags():
		var bag_id: String = str(bag.get("id", ""))
		var btn := Button.new()
		btn.text = str(bag.get("name", bag_id))
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(0, 120)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_bag_selected.bind(bag_id))
		bag_buttons.add_child(btn)
		_bag_button_by_id[bag_id] = btn


func _render_pack() -> void:
	var packs: Array = PackService.get_available_packs()
	if packs.is_empty():
		pack_name.text = "-"
		pack_desc.text = ""
		pack_dots.text = "0 / 0"
		start_button.disabled = true
		return
	start_button.disabled = false
	_pack_index = wrapi(_pack_index, 0, packs.size())
	var pack: Dictionary = packs[_pack_index]
	var pack_id: String = str(pack.get("id", ""))
	pack_name.text = str(pack.get("name", pack_id))
	pack_desc.text = str(pack.get("desc", ""))
	var accent: Color = PACK_ACCENTS.get(pack_id, Color(0.5, 0.5, 0.5))
	pack_accent.color = accent
	pack_dots.text = "%d / %d" % [_pack_index + 1, packs.size()]


func _current_pack_id() -> String:
	var packs: Array = PackService.get_available_packs()
	if packs.is_empty():
		return ""
	return str(packs[_pack_index].get("id", ""))


func _render_bag() -> void:
	for id: String in _bag_button_by_id:
		var btn: Button = _bag_button_by_id[id]
		btn.button_pressed = id == _bag_id
		btn.modulate = Color(1.0, 0.85, 0.4) if id == _bag_id else Color.WHITE
	for child in bag_preview.get_children():
		child.queue_free()
	for tile: Dictionary in KeyCapService.load_starter_bag(_bag_id):
		var elem: Control = KeyCapScene.instantiate()
		elem.custom_minimum_size = Vector2(64, 64)
		elem.size = Vector2(64, 64)
		bag_preview.add_child(elem)
		elem.setup(tile)


func _on_prev_pack() -> void:
	_pack_index -= 1
	_render_pack()


func _on_next_pack() -> void:
	_pack_index += 1
	_render_pack()


func _on_bag_selected(bag_id: String) -> void:
	_bag_id = bag_id
	_render_bag()


func _on_back_pressed() -> void:
	EventBus.run_setup_cancelled.emit()


func _on_start_pressed() -> void:
	var pack_id := _current_pack_id()
	if pack_id == "":
		return
	EventBus.run_started.emit(pack_id, _bag_id)
