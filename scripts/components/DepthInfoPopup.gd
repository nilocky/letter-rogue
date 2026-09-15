extends Control

@onready var depth_label: Label = %DepthStageLabel
@onready var modifier_label: Label = %ModifierLabel
@onready var monster_list: VBoxContainer = %MonsterList
@onready var close_btn: Button = %CloseButton


func _ready() -> void:
	close_btn.pressed.connect(queue_free)
	_populate()


func _populate() -> void:
	depth_label.text = "Depth %s / Round %d" % [DepthService.get_depth_name(GameState.depth_stage), GameState.round_number]
	
	var modifier: Dictionary = DepthService.get_depth_modifier(GameState.depth_stage)
	if not modifier.is_empty():
		var desc: String = modifier.description
		# Show current void banned letter
		if GameState.depth_stage == 6:
			var banned: String = CombatService.get_depth_void_banned_letter()
			if banned != "":
				desc += " (Banned: %s)" % banned
		modifier_label.text = "Modifier: %s — %s" % [modifier.name, desc]
		modifier_label.show()
	else:
		modifier_label.hide()
	
	var pool_map: Dictionary = {
		0: "vanguard",
		1: "sentry",
		2: "bosses",
		3: "catacombs",
		4: "fungal_depths",
		5: "crystal_caverns",
		6: "void_threshold",
		7: "abyssal_crown"
	}
	var pool_name: String = pool_map.get(GameState.depth_stage, "abyssal_crown")
	
	for m: Dictionary in DepthService.get_stage_pool(pool_name):
		var row := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.theme_type_variation = &"BodyLabel"
		name_lbl.text = str(m.get("name", "?"))
		row.add_child(name_lbl)
		var info_lbl := Label.new()
		info_lbl.theme_type_variation = &"MetricLabel"
		var modifier_text: String = str(m.get("modifier", ""))
		if modifier_text != "":
			info_lbl.text = "HP %d  [%s]" % [int(m.get("hp", 0)), modifier_text]
		else:
			info_lbl.text = "HP %d" % int(m.get("hp", 0))
		row.add_child(info_lbl)
		monster_list.add_child(row)