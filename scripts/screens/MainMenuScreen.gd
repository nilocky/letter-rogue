# scripts/screens/MainMenuScreen.gd
extends Control

@onready var start_button: Button = %StartButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	start_button.disabled = false


func _on_start_pressed() -> void:
	EventBus.run_setup_requested.emit()