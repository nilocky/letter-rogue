extends Control

signal clicked
signal drag_drop(from: int, to: int)

const MONO_FONT := preload("res://assets/fonts/monogram.ttf")

@onready var label = %Label
@onready var ability_label = %AbilityLabel
@onready var rarity_bg = %RarityBg
@onready var finish_label = %FinishLabel
@onready var sticker_label = %StickerLabel
@onready var condition_label = %ConditionLabel
@onready var index_label = %IndexLabel
@onready var mark_frame: Panel = %MarkFrame

var cap_data: Dictionary = {}
var selected := false
var drag_index: int = -1  # >= 0 enables drag-and-drop for word-strip tiles

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

func override_letter(letter: String) -> void:
	label.text = letter


func set_word_index(i: int) -> void:
	index_label.visible = i > 0
	index_label.text = str(i) if i > 0 else ""


func set_used(used: bool) -> void:
	modulate = Color(0.5, 0.5, 0.5, 0.75) if used else Color.WHITE


func set_redraw_marked(marked: bool) -> void:
	mark_frame.visible = marked


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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		clicked.emit()

func _get_drag_data(at_position: Vector2) -> Variant:
	if drag_index < 0:
		return null
	var preview := Label.new()
	preview.text = label.text
	preview.add_theme_font_override("font", MONO_FONT)
	preview.add_theme_font_size_override("font_size", 24)
	set_drag_preview(preview)
	return {"slot": drag_index}

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return drag_index >= 0 and typeof(data) == TYPE_DICTIONARY

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var from: int = int(data.get("slot", -1))
	if from != drag_index:
		drag_drop.emit(from, drag_index)

func set_selected(s: bool):
	selected = s
	modulate = Color(1, 1, 0.5) if s else Color.WHITE
