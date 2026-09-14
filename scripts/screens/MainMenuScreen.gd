# scripts/screens/MainMenuScreen.gd
extends Control

const HOVER_SCALE: float = 1.04
const HOVER_TINT: Color = Color(1.18, 1.12, 1.02, 1.0)

@onready var start_button: Button = %StartButton
@onready var achievements_button: Button = %AchievementsButton
@onready var collection_button: Button = %CollectionButton
@onready var settings_button: Button = %SettingsButton

var _hover_tweens: Dictionary = {}


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	achievements_button.pressed.connect(_on_achievements_pressed)
	collection_button.pressed.connect(_on_collection_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	for btn: Button in [start_button, achievements_button, collection_button, settings_button]:
		btn.button_down.connect(_on_button_down.bind(btn))
		btn.mouse_entered.connect(_on_hover_enter.bind(btn))
		btn.mouse_exited.connect(_on_hover_exit.bind(btn))
		_hover_tweens[btn] = null


func _on_hover_enter(btn: Button) -> void:
	_kill_hover_tween(btn)
	var tw: Tween = btn.create_tween().set_parallel(true)
	_hover_tweens[btn] = tw
	tw.tween_property(btn, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), 0.08)
	tw.tween_property(btn, "modulate", HOVER_TINT, 0.08)


func _on_hover_exit(btn: Button) -> void:
	_kill_hover_tween(btn)
	var tw: Tween = btn.create_tween().set_parallel(true)
	_hover_tweens[btn] = tw
	tw.tween_property(btn, "scale", Vector2.ONE, 0.12)
	tw.tween_property(btn, "modulate", Color.WHITE, 0.12)


func _kill_hover_tween(btn: Button) -> void:
	var tw: Variant = _hover_tweens.get(btn)
	if tw is Tween and tw.is_valid():
		tw.kill()
	_hover_tweens[btn] = null


func _on_button_down(btn: Button) -> void:
	ParticleBurst.burst(self, btn.global_position + btn.size * 0.5, Color(0.55, 0.4, 1.0), 12, {"vel_min": 80.0, "vel_max": 180.0})
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.05)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_start_pressed() -> void:
	EventBus.run_setup_requested.emit()


func _on_achievements_pressed() -> void:
	print("Achievements screen not implemented yet")


func _on_collection_pressed() -> void:
	print("Collection screen not implemented yet")


func _on_settings_pressed() -> void:
	print("Settings screen not implemented yet")