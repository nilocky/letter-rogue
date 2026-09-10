# scripts/screens/MainMenuScreen.gd
extends Control

@onready var pack_list = %PackList
@onready var start_button = %StartButton

var _pack_buttons: Dictionary = {}  # pack_id:String -> Button


func _ready():
	start_button.pressed.connect(_on_start_pressed)
	start_button.disabled = true
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for pack in PackService.get_available_packs():
		var pack_id := str(pack["id"])
		var btn := Button.new()
		btn.text = "%s\n%s" % [pack["name"], pack["desc"]]
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(0, 104)
		btn.add_theme_font_size_override("font_size", 28)
		btn.pressed.connect(_on_pack_selected.bind(pack_id))
		pack_list.add_child(btn)
		_pack_buttons[pack_id] = btn
	var packs := PackService.get_available_packs()
	if not packs.is_empty():
		_on_pack_selected(str(packs[0]["id"]))


func _on_pack_selected(pack_id: String):
	PackService.select_pack(pack_id)
	start_button.disabled = false
	for id: String in _pack_buttons:
		var btn: Button = _pack_buttons[id]
		var selected := id == pack_id
		btn.button_pressed = selected
		btn.modulate = Color(1.0, 0.85, 0.4) if selected else Color.WHITE


func _on_start_pressed():
	if GameState.active_pack_id == "":
		var packs = PackService.get_available_packs()
		if packs.size() > 0:
			_on_pack_selected(str(packs[0]["id"]))
	EventBus.run_started.emit()
