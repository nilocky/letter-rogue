extends Control

@onready var inventory_grid: GridContainer = %InventoryGrid
@onready var bag_grid: GridContainer = %BagGrid
@onready var money_label: Label = %MoneyLabel
@onready var reroll_button: Button = %RerollButton
@onready var fight_button: Button = %FightButton
@onready var upgrade_box: VBoxContainer = %UpgradeBox
@onready var buy_dialog: ConfirmationDialog = %BuyDialog
@onready var sell_dialog: ConfirmationDialog = %SellDialog

const KeyCapScene := preload("res://scenes/components/KeyCapElement.tscn")

var _pending_purchase: Dictionary = {}
var _pending_sale: Dictionary = {}


func _ready() -> void:
	reroll_button.pressed.connect(_on_reroll_pressed)
	fight_button.pressed.connect(_on_fight_pressed)
	buy_dialog.confirmed.connect(_on_buy_confirmed)
	sell_dialog.confirmed.connect(_on_sell_confirmed)
	EventBus.shop_inventory_generated.connect(_on_inventory_generated)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	_build_upgrade_buttons()
	_refresh_ui()


func _on_inventory_generated(_inventory: Array) -> void:
	_refresh_ui()


func _refresh_ui() -> void:
	_refresh_money()
	for c in inventory_grid.get_children():
		c.queue_free()
	for i in range(GameState.shop_inventory.size()):
		var cap: Dictionary = GameState.shop_inventory[i]
		var elem: Control = _make_tile(_on_shop_item_clicked.bind(i), int(cap.get("price", 0)))
		inventory_grid.add_child(elem)
		elem.setup(cap)
	for c in bag_grid.get_children():
		c.queue_free()
	for i in range(GameState.bag.size()):
		var cap: Dictionary = GameState.bag[i]
		var elem: Control = _make_tile(_on_bag_item_clicked.bind(i), ShopService.sell_value(cap))
		bag_grid.add_child(elem)
		elem.setup(cap)


func _make_tile(handler: Callable, price: int) -> Control:
	var elem: Control = KeyCapScene.instantiate()
	elem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elem.custom_minimum_size = Vector2(64, 48)
	var price_label := Label.new()
	price_label.text = "$%d" % price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	price_label.add_theme_font_size_override("font_size", 10)
	price_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	price_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	price_label.offset_top = -12.0
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elem.add_child(price_label)
	elem.clicked.connect(handler)
	return elem


func _on_shop_item_clicked(index: int) -> void:
	if index >= GameState.shop_inventory.size():
		return
	_pending_purchase = GameState.shop_inventory[index]
	buy_dialog.dialog_text = _describe_cap(_pending_purchase)
	buy_dialog.get_ok_button().disabled = GameState.money < int(_pending_purchase.get("price", 0))
	buy_dialog.popup_centered()


func _on_buy_confirmed() -> void:
	if _pending_purchase.is_empty():
		return
	ShopService.buy_cap(_pending_purchase)
	_pending_purchase = {}
	_refresh_ui()


func _on_bag_item_clicked(index: int) -> void:
	if index >= GameState.bag.size():
		return
	_pending_sale = GameState.bag[index]
	sell_dialog.dialog_text = _describe_cap(_pending_sale, true)
	sell_dialog.get_ok_button().disabled = str(_pending_sale.get("condition", "")) == "eternal"
	sell_dialog.popup_centered()


func _on_sell_confirmed() -> void:
	if _pending_sale.is_empty():
		return
	ShopService.sell_cap(_pending_sale)
	_pending_sale = {}
	_refresh_ui()


func _on_reroll_pressed() -> void:
	ShopService.reroll()
	_refresh_ui()


func _on_fight_pressed() -> void:
	EventBus.fight_pressed.emit()


func _describe_cap(cap: Dictionary, selling: bool = false) -> String:
	var lines: PackedStringArray = [
		"Letter: %s" % str(cap.get("letter", "?")),
		"Rarity: %s" % str(cap.get("rarity", "?")),
		"Ability: %s" % _ability_text(cap),
	]
	var finish: String = str(cap.get("finish", ""))
	if finish != "":
		lines.append("Finish: %s" % _finish_text(finish))
	var sticker: String = str(cap.get("sticker", ""))
	if sticker != "":
		lines.append("Sticker: %s" % _sticker_text(sticker))
	var condition: String = str(cap.get("condition", ""))
	if condition != "":
		lines.append("Condition: %s" % _condition_text(condition))
	if selling:
		if condition == "eternal":
			lines.append("Sell: Eternal — cannot be sold")
		else:
			lines.append("Sell for: $%d" % ShopService.sell_value(cap))
	else:
		lines.append("Price: $%d" % int(cap.get("price", 0)))
	return "\n".join(lines)


func _ability_text(cap: Dictionary) -> String:
	var id: String = str(cap.get("ability_id", ""))
	var strength: int = int(cap.get("ability_strength", 0))
	match id:
		"bonus_points":
			return "+%d score" % strength
		"double_score":
			return "Doubles this tile's score"
		"money_bonus":
			return "+$%d when played" % strength
		"bonus_damage":
			return "+%d damage" % strength
		"wild":
			return "Wildcard: any letter"
		"vowel_wild":
			return "Wildcard: any vowel"
		"consonant_wild":
			return "Wildcard: any consonant"
		_:
			return "None"


func _finish_text(id: String) -> String:
	match id:
		"foil": return "Foil (+3 score)"
		"holographic": return "Holographic (+1 score)"
		"polychrome": return "Polychrome (1.5x score)"
		_:
			return id


func _sticker_text(id: String) -> String:
	match id:
		"gold": return "Gold (+$2 when played)"
		"red": return "Red (2x score)"
		"blue": return "Blue (+1 draw next turn)"
		_:
			return id


func _condition_text(id: String) -> String:
	match id:
		"glass": return "Glass (2x score, may break)"
		"lucky": return "Lucky (random bonus)"
		"eternal": return "Eternal (cannot be sold)"
		_:
			return id


func _build_upgrade_buttons() -> void:
	for child in upgrade_box.get_children():
		child.queue_free()
	for u in ShopService.upgrade_defs():
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl := Label.new()
		name_lbl.text = "%s (owned %d)" % [str(u["name"]), ShopService.owned_level(u["id"])]
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var desc_lbl := Label.new()
		desc_lbl.text = str(u["desc"])
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(name_lbl)
		info.add_child(desc_lbl)
		var buy_btn := Button.new()
		buy_btn.text = "$%d" % ShopService.upgrade_cost(u["id"])
		var uid: String = str(u["id"])
		buy_btn.pressed.connect(func() -> void:
			if ShopService.purchase_upgrade(uid):
				_build_upgrade_buttons()
				_refresh_money()
			else:
				print("cannot afford upgrade")
		)
		row.add_child(info)
		row.add_child(buy_btn)
		upgrade_box.add_child(row)


func _on_upgrade_purchased(_id: String, _level: int) -> void:
	_build_upgrade_buttons()


func _refresh_money() -> void:
	money_label.text = "$%d" % GameState.money