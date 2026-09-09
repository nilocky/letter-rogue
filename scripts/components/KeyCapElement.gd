extends Control

@onready var label = $Label
@onready var ability_label = $AbilityLabel
@onready var rarity_bg = $RarityBg

var cap_data: Dictionary = {}
var selected := false

func setup(data: Dictionary):
	cap_data = data
	label.text = data["letter"]
	ability_label.text = data.get("ability_id", "")
	if data.get("is_symbol", false):
		label.add_theme_color_override("font_color", Color.GOLD)
	match data["rarity"]:
		"Rare":
			rarity_bg.color = Color(0.2, 0.4, 0.8)
		"Epic":
			rarity_bg.color = Color(0.6, 0.2, 0.8)
		"Legendary":
			rarity_bg.color = Color(0.8, 0.4, 0.1)
		_:
			rarity_bg.color = Color(0.3, 0.3, 0.3)

func set_selected(s: bool):
	selected = s
	modulate = Color(1, 1, 0.5) if s else Color.WHITE
