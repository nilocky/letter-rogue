extends Control

signal clicked
signal drag_drop(from: int, to: int)

const MONO_FONT := preload("res://assets/fonts/monogram.ttf")

@onready var label = %LetterLabel
@onready var power_label = %PowerLabel
@onready var mark_frame: Panel = %MarkFrame
@onready var cap_texture: TextureRect = $CapTexture
@onready var overlay_texture: TextureRect = $OverlayTexture

var cap_data: Dictionary = {}
var selected := false
var drag_index: int = -1
var skin_id: String = "slate"
var _pressed: bool = false
var is_latched: bool = false
const DEEP_TRAVEL_PX: float = 5.0


func setup(data: Dictionary):
	cap_data = data
	label.text = data["letter"]
	if data.get("is_symbol", false):
		label.add_theme_color_override("font_color", Color.GOLD)

	var strength: Variant = data.get("ability_strength", 0)
	if strength > 0:
		power_label.text = str(strength)
		power_label.show()
	else:
		power_label.hide()

	skin_id = str(data.get("skin", "slate"))
	_apply_skin("cap_unpressed")
	_apply_overlay(data)


func _apply_skin(state: String) -> void:
	if not KeyCapSkinService:
		return
	var atlas: AtlasTexture = KeyCapSkinService.get_atlas(state, skin_id)
	if atlas:
		cap_texture.texture = atlas


func _apply_overlay(data: Dictionary) -> void:
	if not KeyCapSkinService:
		return
	var overlay_key := ""
	var finish := str(data.get("finish", ""))
	if finish in ["foil", "holographic"]:
		overlay_key = finish
	elif str(data.get("condition", "")) == "glass":
		overlay_key = "glass"
	elif str(data.get("sticker", "")) == "gold":
		overlay_key = "sticker_gold"
	if overlay_key == "":
		overlay_texture.visible = false
		return
	var atlas: AtlasTexture = KeyCapSkinService.get_atlas("overlays", overlay_key)
	if atlas:
		overlay_texture.texture = atlas
		overlay_texture.visible = true


func override_letter(letter: String) -> void:
	label.text = letter


func set_used(used: bool) -> void:
	modulate = Color(0.5, 0.5, 0.5, 0.75) if used else Color.WHITE


func set_redraw_marked(marked: bool) -> void:
	mark_frame.visible = marked


func set_latched(latched: bool, animated: bool = true) -> void:
	is_latched = latched
	if latched:
		_apply_skin("cap_pressed")
		if animated:
			var tween := create_tween().set_parallel(true)
			tween.tween_property(self, "position:y", position.y + DEEP_TRAVEL_PX, 0.05)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "modulate", Color(0.8, 0.82, 0.88, 1.0), 0.05)
		else:
			position.y += DEEP_TRAVEL_PX
			modulate = Color(0.8, 0.82, 0.88, 1.0)
	else:
		_apply_skin("cap_unpressed")
		if animated:
			var tween := create_tween().set_parallel(true)
			tween.tween_property(self, "position:y", position.y - DEEP_TRAVEL_PX, 0.08)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "modulate", Color.WHITE, 0.08)
		else:
			position.y -= DEEP_TRAVEL_PX
			modulate = Color.WHITE


func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _pressed:
			_press_down()
		elif not event.pressed and _pressed:
			_release_up()


func _press_down() -> void:
	_pressed = true
	_apply_skin("cap_pressed")


func _release_up() -> void:
	_pressed = false
	_apply_skin("cap_unpressed")
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
