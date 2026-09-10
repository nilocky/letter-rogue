extends Control

const VOWELS := "AEIOU"

@onready var letter_grid: GridContainer = %LetterGrid
@onready var vowel_ratio: Label = %VowelRatio
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	close_button.pressed.connect(_on_close)
	open()


func open() -> void:
	_populate()


func _populate() -> void:
	for child in letter_grid.get_children():
		child.queue_free()

	var counts: Dictionary = {}
	for cap: Dictionary in GameState.bag:
		var letter: String = str(cap.get("letter", "?"))
		counts[letter] = counts.get(letter, 0) + 1

	var total: int = GameState.bag.size()
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
		empty_lbl.text = "Bag is empty"
		letter_grid.add_child(empty_lbl)

	var consonants: int = total - vowels
	var vpct: float = float(vowels) / float(total) * 100.0 if total > 0 else 0.0
	var cpct: float = float(consonants) / float(total) * 100.0 if total > 0 else 0.0
	vowel_ratio.text = "Vowels: %d (%.0f%%) · Consonants: %d (%.0f%%)" % [vowels, vpct, consonants, cpct]


func _on_close() -> void:
	queue_free()
