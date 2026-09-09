# scripts/screens/MainMenuScreen.gd
extends Control

@onready var pack_list = $VBoxContainer/PackList
@onready var start_button = $VBoxContainer/StartButton

func _ready():
	var packs = PackService.get_available_packs()
	for pack in packs:
		var btn = Button.new()
		btn.text = pack["name"] + "\n" + pack["description"]
		btn.connect("pressed", Callable(self, "_on_pack_selected").bind(pack["id"]))
		pack_list.add_child(btn)

func _on_pack_selected(pack_id: String):
	PackService.select_pack(pack_id)
	start_button.disabled = false

func _on_start_pressed():
	EventBus.run_started.emit()
