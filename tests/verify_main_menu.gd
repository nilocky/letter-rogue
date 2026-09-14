extends SceneTree

func _ready() -> void:
	var scr: GDScript = load("res://scripts/screens/MainMenuScreen.gd")
	if not scr.can_instantiate():
		print("FAIL: MainMenuScreen.gd failed to compile")
		quit(1)
	print("PASS: MainMenuScreen.gd compiles cleanly")
	quit(0)
