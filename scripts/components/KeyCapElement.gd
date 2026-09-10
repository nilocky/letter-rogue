extends Control

signal clicked

@onready var label = %Label
@onready var ability_label = %AbilityLabel
@onready var rarity_bg = %RarityBg
@onready var finish_label = %FinishLabel
@onready var sticker_label = %StickerLabel
@onready var condition_label = %ConditionLabel

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

	# Modifier badges
	var finish = data.get("finish", "")
	finish_label.text = _modifier_abbr(finish)
	finish_label.visible = finish != ""

	var sticker = data.get("sticker", "")
	sticker_label.text = _modifier_abbr(sticker)
	sticker_label.visible = sticker != ""

	var condition = data.get("condition", "")
	condition_label.text = _modifier_abbr(condition)
	condition_label.visible = condition != ""

func _modifier_abbr(id: String) -> String:
	match id:
		"foil": return "FL"
		"holographic": return "HL"
		"polychrome": return "PC"
		"double_shot": return "DS"
		"neon": return "NN"
		"gold": return "GD"
		"red": return "RD"
		"blue": return "BL"
		"rainbow": return "RB"
		"glow": return "GW"
		"glass": return "GL"
		"steel": return "ST"
		"gold_held": return "GO"
		"lucky": return "LU"
		"eternal": return "ET"
		"rental": return "RT"
		_: return ""

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		clicked.emit()

func set_selected(s: bool):
	selected = s
	modulate = Color(1, 1, 0.5) if s else Color.WHITE
