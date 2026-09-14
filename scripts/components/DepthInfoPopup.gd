extends Control

@onready var depth_label: Label = %DepthStageLabel
@onready var monster_list: VBoxContainer = %MonsterList
@onready var close_btn: Button = %CloseButton


func _ready() -> void:
	close_btn.pressed.connect(queue_free)
	_populate()


func _populate() -> void:
	depth_label.text = "Stage %d / Round %d" % [GameState.depth_stage + 1, GameState.round_number]
	var pool_name: String = "vanguard"
	if GameState.depth_stage == 1:
		pool_name = "sentry"
	elif GameState.depth_stage >= 2:
		pool_name = "bosses"
	for m: Dictionary in DepthService.get_stage_pool(pool_name):
		var row := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.theme_type_variation = &"BodyLabel"
		name_lbl.text = str(m.get("name", "?"))
		row.add_child(name_lbl)
		var info_lbl := Label.new()
		info_lbl.theme_type_variation = &"MetricLabel"
		info_lbl.text = "HP %d  %s" % [int(m.get("hp", 0)), str(m.get("modifier", ""))]
		row.add_child(info_lbl)
		monster_list.add_child(row)