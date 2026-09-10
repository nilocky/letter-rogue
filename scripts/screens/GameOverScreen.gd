# scripts/screens/GameOverScreen.gd
extends Control

@onready var body_label = %BodyLabel
@onready var restart_button = %RestartButton


func _ready():
	restart_button.pressed.connect(_on_restart_pressed)


func show_game_over(reached_round: int) -> void:
	body_label.text = "Reached round %d with $%d" % [reached_round, GameState.money]


func _on_restart_pressed():
	get_parent()._switch_to_menu()