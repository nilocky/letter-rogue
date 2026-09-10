# scripts/screens/MainMenuScreen.gd
extends Control

@onready var pack_list = %PackList
@onready var start_button = %StartButton


func _ready():
	start_button.pressed.connect(_on_start_pressed)
	for pack in PackService.get_available_packs():
		var btn = Button.new()
		btn.text = pack["name"] + "\n" + pack["desc"]
		btn.pressed.connect(_on_pack_selected.bind(pack["id"]))
		pack_list.add_child(btn)


func _on_pack_selected(pack_id: String):
	PackService.select_pack(pack_id)
	start_button.disabled = false


func _on_start_pressed():
	if GameState.active_pack_id == "":
		var packs = PackService.get_available_packs()
		if packs.size() > 0:
			_on_pack_selected(packs[0]["id"])
	EventBus.run_started.emit()