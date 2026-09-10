extends Node

func _ready() -> void:
	var menu: Control = (load("res://scenes/MainMenuScreen.tscn") as PackedScene).instantiate()
	add_child(menu)
	get_window().size = Vector2i(768, 1376)
	await get_tree().process_frame
	await get_tree().process_frame

	var list: Control = menu.get_node_or_null("VBoxContainer/ScrollContainer/PackMargin/PackList")
	print("scroll rect=", menu.get_node("VBoxContainer/ScrollContainer").get_global_rect())
	if list == null:
		print("NO LIST")
		get_tree().quit(0)
		return
	print("list pos=", list.get_global_position(), " size=", list.size)
	for child in list.get_children():
		print("pack btn pos=", child.get_global_position())
	get_tree().quit(0)