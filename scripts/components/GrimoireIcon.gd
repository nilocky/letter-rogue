extends Control
class_name GrimoireIcon

var _data: Dictionary = {}

func setup(data: Dictionary) -> void:
	_data = data
	tooltip_text = "%s\n%s" % [str(data.get("name", "?")), str(data.get("description", ""))]
	var lbl := Label.new()
	lbl.text = str(data.get("name", "?"))[0]
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(lbl)

func _get_drag_data(position: Vector2) -> Variant:
	if _data.is_empty():
		return null
	var preview := ColorRect.new()
	preview.custom_minimum_size = Vector2(50, 50)
	preview.color = Color(0.8, 0.5, 0.2, 0.8)
	set_drag_preview(preview)
	return {"type": "grimoire", "from_index": get_index(), "data": _data.duplicate()}