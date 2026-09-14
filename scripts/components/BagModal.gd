extends Control

enum View { BAG, DISCARD }

const VOWELS := "AEIOU"

var _current_view: View = View.BAG

@onready var letter_grid: GridContainer = %LetterGrid
@onready var vowel_ratio: Label = %VowelRatio
@onready var close_button: Button = %CloseButton
@onready var view_bag_btn: Button = %ViewBagButton
@onready var view_discard_btn: Button = %ViewDiscardButton


func _ready() -> void:
	close_button.pressed.connect(_on_close)
	if view_bag_btn and view_discard_btn:
		view_bag_btn.pressed.connect(_on_view_bag)
		view_discard_btn.pressed.connect(_on_view_discard)
	open()


func open() -> void:
	_switch_view(_current_view)


func _on_view_bag() -> void:
	_switch_view(View.BAG)


func _on_view_discard() -> void:
	_switch_view(View.DISCARD)


func _switch_view(v: View) -> void:
	_current_view = v
	if view_bag_btn and view_discard_btn:
		view_bag_btn.button_pressed = (v == View.BAG)
		view_discard_btn.button_pressed = (v == View.DISCARD)
	_populate()


func _populate() -> void:
	for child in letter_grid.get_children():
		child.queue_free()

	var source: Array = []
	if _current_view == View.BAG:
		source = GameState.bag
	else:
		source = GameState.discard_pile

	var counts: Dictionary = {}
	for cap: Dictionary in source:
		var letter: String = str(cap.get("letter", "?"))
		counts[letter] = counts.get(letter, 0) + 1

	var total: int = source.size()
	var vowels: int = 0
	var sorted_keys: Array = counts.keys()
	sorted_keys.sort()

	for letter: String in sorted_keys:
		var c: int = counts[letter]
		var pct: float = float(c) / float(total) * 100.0 if total > 0 else 0.0
		var row := HBoxContainer.new()
		var letter_lbl := Label.new()
		letter_lbl.theme_type_variation = &"BodyLabel"
		letter_lbl.size_flags_horizontal = 3
		letter_lbl.text = letter
		var count_lbl := Label.new()
		count_lbl.theme_type_variation = &"BodyLabel"
		count_lbl.text = "%d (%.0f%%)" % [c, pct]
		row.add_child(letter_lbl)
		row.add_child(count_lbl)
		letter_grid.add_child(row)
		if VOWELS.contains(letter):
			vowels += c

	if total == 0:
		var empty_lbl := Label.new()
		empty_lbl.theme_type_variation = &"BodyLabel"
		if _current_view == View.BAG:
			empty_lbl.text = "Bag is empty"
		else:
			empty_lbl.text = "Discard pile is empty"
		letter_grid.add_child(empty_lbl)

	var consonants: int = total - vowels
	var vpct: float = float(vowels) / float(total) * 100.0 if total > 0 else 0.0
	var cpct: float = float(consonants) / float(total) * 100.0 if total > 0 else 0.0
	var view_label: String = "BAG" if _current_view == View.BAG else "DISCARD"
	vowel_ratio.text = "[%s] Vowels: %d (%.0f%%) · Consonants: %d (%.0f%%)" % [view_label, vowels, vpct, consonants, cpct]


func _on_close() -> void:
	queue_free()
