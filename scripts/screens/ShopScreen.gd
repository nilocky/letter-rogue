extends Control

@onready var inventory_grid = %InventoryGrid
@onready var bag_grid = %BagGrid
@onready var money_label = %MoneyLabel
@onready var reroll_button = %RerollButton
@onready var fight_button = %FightButton
@onready var upgrade_box: VBoxContainer = %UpgradeBox

var KeyCapScene = preload("res://scenes/components/KeyCapElement.tscn")


func _ready():
	reroll_button.pressed.connect(_on_reroll_pressed)
	fight_button.pressed.connect(_on_fight_pressed)
	EventBus.shop_inventory_generated.connect(_on_inventory_generated)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	_build_upgrade_buttons()
	_refresh_ui()


func _on_inventory_generated(_inventory: Array):
	_refresh_ui()


func _refresh_ui():
	_refresh_money()
	for c in inventory_grid.get_children():
		c.queue_free()
	for i in range(GameState.shop_inventory.size()):
		var cap = GameState.shop_inventory[i]
		var elem = KeyCapScene.instantiate()
		elem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var price_label = Label.new()
		price_label.text = "$" + str(cap["price"])
		elem.add_child(price_label)
		inventory_grid.add_child(elem)
		elem.setup(cap)
		elem.clicked.connect(_on_shop_item_clicked.bind(i))
	for c in bag_grid.get_children():
		c.queue_free()
	for i in range(GameState.bag.size()):
		var cap = GameState.bag[i]
		var elem = KeyCapScene.instantiate()
		elem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bag_grid.add_child(elem)
		elem.setup(cap)
		elem.clicked.connect(_on_bag_item_clicked.bind(i))


func _on_shop_item_clicked(index: int):
	if index < GameState.shop_inventory.size():
		ShopService.buy_cap(GameState.shop_inventory[index])
		_refresh_ui()


func _on_bag_item_clicked(index: int):
	if index < GameState.bag.size():
		ShopService.sell_cap(GameState.bag[index])
		_refresh_ui()


func _on_reroll_pressed():
	ShopService.reroll()
	_refresh_ui()


func _on_fight_pressed():
	EventBus.fight_pressed.emit()


func _build_upgrade_buttons():
	for child in upgrade_box.get_children():
		child.queue_free()
	for u in ShopService.upgrade_defs():
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl = Label.new()
		name_lbl.text = "%s (owned %d)" % [str(u["name"]), ShopService.owned_level(u["id"])]
		var desc_lbl = Label.new()
		desc_lbl.text = str(u["desc"])
		info.add_child(name_lbl)
		info.add_child(desc_lbl)
		var buy_btn = Button.new()
		buy_btn.text = "$%d" % ShopService.upgrade_cost(u["id"])
		var uid: String = str(u["id"])
		buy_btn.pressed.connect(func():
			if ShopService.purchase_upgrade(uid):
				_build_upgrade_buttons()
				_refresh_money()
			else:
				print("cannot afford upgrade")
		)
		row.add_child(info)
		row.add_child(buy_btn)
		upgrade_box.add_child(row)


func _on_upgrade_purchased(_id: String, _level: int):
	_build_upgrade_buttons()


func _refresh_money():
	money_label.text = "$%d" % GameState.money
