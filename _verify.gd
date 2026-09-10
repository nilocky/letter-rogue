extends Node

const SCENES: Array[String] = [
	"res://scenes/MainMenuScreen.tscn",
	"res://scenes/CombatScreen.tscn",
	"res://scenes/ShopScreen.tscn",
	"res://scenes/GameOverScreen.tscn",
	"res://scenes/components/KeyCapElement.tscn",
]

func _ready() -> void:
	get_window().size = Vector2i(768, 1376)
	await get_tree().process_frame
	await get_tree().process_frame
	var failed: bool = false
	for path in SCENES:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			print("FAIL cannot load: ", path)
			failed = true
			continue
		if not packed.can_instantiate():
			print("FAIL cannot instantiate: ", path)
			failed = true
			continue
		var node: Node = packed.instantiate()
		if node.get_script() == null:
			print("FAIL no script: ", path)
			failed = true
			node.free()
			continue
		add_child(node)
		await get_tree().process_frame
		if node is Control:
			var c: Control = node as Control
			print("OK ", path, " script=", node.get_script().resource_path, " size=", c.size)
			if c.size.x <= 0.0 or c.size.y <= 0.0:
				print("WARN zero size: ", path)
		else:
			print("UNEXPECTED non-Control root: ", path)
		remove_child(node)
		node.free()
		await get_tree().process_frame
	if failed:
		get_tree().quit(1)
	else:
		get_tree().quit(0)