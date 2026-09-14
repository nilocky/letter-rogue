extends Control
class_name SellDropZone

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_MOVE

func _can_drop_data(position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data
	var t := str(d.get("type", ""))
	return t == "artisan" or t == "grimoire"

func _drop_data(position: Vector2, data: Variant) -> void:
	var d: Dictionary = data
	if str(d.get("type", "")) == "grimoire":
		_display_message("Cannot sell permanent upgrades")
		return
	var idx := int(d.get("from_index", -1))
	var artisan: Dictionary = ArtisanRailManager.get_slot(idx)
	if artisan.is_empty():
		return
	var refund := roundi(float(artisan.get("price_paid", 0)) * 0.5)
	GameState.money += refund
	ArtisanRailManager.unequip(idx)
	EventBus.state_changed.emit()
	_display_message("Sold +$%d" % refund)

func _display_message(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.4, 1))
	lbl.position = global_position + Vector2(0, -24)
	get_tree().root.add_child(lbl)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position", lbl.global_position + Vector2(0, -20), 0.8)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(lbl.queue_free)