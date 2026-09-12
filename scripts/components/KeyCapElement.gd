extends Control

signal clicked
signal drag_drop(from: int, to: int)

const MONO_FONT := preload("res://assets/fonts/monogram.ttf")

@onready var label = %LetterLabel
@onready var power_label = %PowerLabel
@onready var mark_frame: Panel = %MarkFrame
@onready var socket_shadow: ColorRect = $SocketShadow
@onready var switch_base: TextureRect = $SwitchBase
@onready var cap_layer: Control = $CapLayer
@onready var cap_texture: TextureRect = $CapLayer/CapTexture
@onready var overlay_texture: TextureRect = $CapLayer/OverlayTexture
@onready var legend_container: MarginContainer = $CapLayer/LegendContainer

@export var embedded_mode: bool = false

var cap_data: Dictionary = {}
var selected := false
var drag_index: int = -1
var skin_id: String = "slate"
var _pressed: bool = false
var is_latched: bool = false
const UNPRESSED_CAP_Y: float = 0.0
const PRESSED_CAP_Y: float = 5.0


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
	_apply_switch_base()
	_apply_skin("cap_unpressed")
	_apply_overlay(data)


func set_embedded_mode(enabled: bool) -> void:
	embedded_mode = enabled
	_apply_switch_base()


func _apply_switch_base() -> void:
	if not KeyCapSkinService:
		return
	var pack_id: String = GameState.active_pack_id.to_lower() if "active_pack_id" in GameState else "mx_red"
	var base_atlas: AtlasTexture = KeyCapSkinService.get_atlas("switches", pack_id)
	if not base_atlas:
		base_atlas = KeyCapSkinService.get_atlas("switches", "mx_red")
	if not base_atlas:
		return
	if embedded_mode:
		socket_shadow.visible = true
		var cropped: AtlasTexture = base_atlas.duplicate() as AtlasTexture
		cropped.region.size.y *= 0.79
		switch_base.texture = cropped
		switch_base.size = Vector2(46, 32)
		switch_base.position = Vector2(8, 28)
	else:
		socket_shadow.visible = false
		switch_base.texture = base_atlas
		switch_base.size = Vector2(46, 32)
		switch_base.position = Vector2(8, 30)
	switch_base.visible = true

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
	_apply_skin("cap_pressed" if latched else "cap_unpressed")
	if animated:
		var tween := create_tween().set_parallel(true)
		var target_y := PRESSED_CAP_Y if latched else UNPRESSED_CAP_Y
		tween.tween_property(cap_layer, "position:y", target_y, 0.05)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "modulate", _depressed_color() if latched else Color.WHITE, 0.05)
	else:
		_update_visual_state(latched)


func _depressed_color() -> Color:
	return Color(0.85, 0.88, 0.95, 1.0)

func _update_visual_state(depressed: bool) -> void:
	_apply_skin("cap_pressed" if depressed else "cap_unpressed")
	cap_layer.position.y = PRESSED_CAP_Y if depressed else UNPRESSED_CAP_Y
	modulate = _depressed_color() if depressed else Color.WHITE


func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _pressed:
			_press_down()
		elif not event.pressed and _pressed:
			_release_up()


func _press_down() -> void:
	_pressed = true
	if not is_latched:
		_update_visual_state(true)


func _release_up() -> void:
	_pressed = false
	clicked.emit()
	if not is_latched:
		_update_visual_state(false)


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
