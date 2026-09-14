extends PanelContainer
class_name ArtisanSlot

@onready var icon_rect: TextureRect = %IconRect
@onready var name_label: Label = %NameLabel
@onready var empty_placeholder: Label = %EmptyPlaceholder

func set_artisan(data: Dictionary) -> void:
	if data.is_empty():
		clear()
		return
	name_label.text = str(data.get("name", "?"))
	var icon_path: String = str(data.get("icon", ""))
	if icon_path != "":
		icon_rect.texture = load(icon_path) as Texture2D
	icon_rect.show()
	name_label.show()
	empty_placeholder.hide()
	modulate = Color.WHITE

func clear() -> void:
	icon_rect.texture = null
	icon_rect.hide()
	name_label.text = ""
	name_label.hide()
	empty_placeholder.show()
	modulate = Color(0.3, 0.3, 0.3, 0.5)

func trigger_glow() -> void:
	var tw := create_tween()
	modulate = Color(2.0, 2.0, 1.0, 1.0)
	tw.tween_property(self, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_LINEAR)

func trigger_shake() -> void:
	var orig := rotation
	var tw := create_tween()
	tw.tween_property(self, "rotation", -4.0, 0.08).set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(self, "rotation", 4.0, 0.08).set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(self, "rotation", -2.0, 0.06).set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(self, "rotation", orig, 0.06).set_trans(Tween.TRANS_LINEAR)
