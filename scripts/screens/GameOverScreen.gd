# scripts/screens/GameOverScreen.gd
extends Control

@onready var final_score_label = $VBoxContainer/FinalScoreLabel
@onready var restart_button = $VBoxContainer/RestartButton

func _ready():
	final_score_label.text = "Game Over!\nRound: " + str(GameState.round) + "\nMoney: $" + str(GameState.money)

func _on_restart_pressed():
	get_parent()._switch_to_menu()
