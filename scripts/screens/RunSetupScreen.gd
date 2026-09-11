extends Control

const KeyCapScene := preload("res://scenes/components/KeyCapElement.tscn")

@onready var back_button: Button = %BackButton
@onready var prev_pack_button: Button = %PrevPackButton
@onready var pack_name: Label = %PackNameLabel
@onready var pack_desc: Label = %PackDescLabel
@onready var next_pack_button: Button = %NextPackButton
@onready var prev_bag_button: Button = %PrevBagButton
@onready var bag_name: Label = %BagNameLabel
@onready var next_bag_button: Button = %NextBagButton
@onready var letter_grid: GridContainer = %LetterGridContainer
@onready var start_button: Button = %StartRunButton

var _pack_index: int = 0
var _bag_index: int = 0
var _bags: Array = []


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	prev_pack_button.pressed.connect(_on_prev_pack)
	next_pack_button.pressed.connect(_on_next_pack)
	prev_bag_button.pressed.connect(_on_prev_bag)
	next_bag_button.pressed.connect(_on_next_bag)
	start_button.pressed.connect(_on_start_pressed)
	_bags = KeyCapService.get_starter_bags()
	_render_pack()
	_render_bag()


func _render_pack() -> void:
	var packs: Array = PackService.get_available_packs()
	if packs.is_empty():
		pack_name.text = "-"
		pack_desc.text = ""
		start_button.disabled = true
		return
	start_button.disabled = false
	_pack_index = wrapi(_pack_index, 0, packs.size())
	var pack: Dictionary = packs[_pack_index]
	var pack_id: String = str(pack.get("id", ""))
	pack_name.text = str(pack.get("name", pack_id))
	pack_desc.text = str(pack.get("desc", ""))


func _current_pack_id() -> String:
	var packs: Array = PackService.get_available_packs()
	if packs.is_empty():
		return ""
	return str(packs[_pack_index].get("id", ""))


func _render_bag() -> void:
	if _bags.is_empty():
		bag_name.text = "-"
		return
	_bag_index = wrapi(_bag_index, 0, _bags.size())
	var bag: Dictionary = _bags[_bag_index]
	var bag_id: String = str(bag.get("id", ""))
	bag_name.text = str(bag.get("name", bag_id))

	for child in letter_grid.get_children():
		child.queue_free()

	var tiles: Array = KeyCapService.load_starter_bag(bag_id)
	for tile: Dictionary in tiles:
		var elem: Control = KeyCapScene.instantiate()
		elem.custom_minimum_size = Vector2(44, 44)
		elem.size = Vector2(44, 44)
		letter_grid.add_child(elem)
		elem.setup(tile)


func _on_prev_pack() -> void:
	_pack_index -= 1
	_render_pack()


func _on_next_pack() -> void:
	_pack_index += 1
	_render_pack()


func _on_prev_bag() -> void:
	_bag_index -= 1
	_render_bag()


func _on_next_bag() -> void:
	_bag_index += 1
	_render_bag()


func _on_back_pressed() -> void:
	EventBus.run_setup_cancelled.emit()


func _on_start_pressed() -> void:
	var pack_id := _current_pack_id()
	if pack_id == "":
		return
	var bag_id: String = ""
	if _bags.size() > 0:
		bag_id = str(_bags[_bag_index].get("id", "standard"))
	EventBus.run_started.emit(pack_id, bag_id)
