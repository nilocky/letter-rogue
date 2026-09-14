extends PanelContainer
class_name ArtisanSlot

@onready var icon_rect: TextureRect = %IconRect

func set_artisan(data: Dictionary) -> void:
	if data.is_empty():
		clear()
		return
	var icon_path: String = str(data.get("icon", ""))
	if icon_path != "":
		icon_rect.texture = load(icon_path) as Texture2D
	icon_rect.show()
	visible = true
	modulate = Color.WHITE
	tooltip_text = "%s\n%s" % [str(data.get("name", "?")), str(data.get("description", ""))]

func clear() -> void:
	icon_rect.texture = null
	icon_rect.hide()
	visible = false
	modulate = Color(0.3, 0.3, 0.3, 0.5)
	tooltip_text = ""

func _get_drag_data(position: Vector2) -> Variant:
	if get_slot_data().is_empty():
		return null
	var preview := ColorRect.new()
	preview.custom_minimum_size = Vector2(60, 60)
	preview.color = Color(0.3, 0.8, 0.4, 0.8)
	set_drag_preview(preview)
	return {"type": "artisan", "from_index": get_index()}

func get_slot_data() -> Dictionary:
	return ArtisanRailManager.get_slot(get_index())

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
