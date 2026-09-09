extends Control

@onready var letter_label = $LetterLabel
@onready var cap_slot = $CapSlot

var letter: String = ""
var placed_cap: Dictionary = {}

func setup(l: String):
	letter = l
	letter_label.text = l
	placed_cap = {}

func place_cap(cap: Dictionary):
	placed_cap = cap
	cap_slot.visible = true
	cap_slot.text = cap["letter"]
	letter_label.visible = false

func clear():
	placed_cap = {}
	cap_slot.visible = false
	letter_label.visible = true

func is_occupied() -> bool:
	return placed_cap.size() > 0
