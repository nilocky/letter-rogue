# scripts/screens/ShopScreen.gd
extends Control

@onready var inventory_grid = $InventoryGrid
@onready var bag_grid = $BagGrid
@onready var money_label = $MoneyLabel
@onready var reroll_button = $RerollButton

var KeyCapScene = preload("res://scenes/components/KeyCapElement.tscn")

func _ready():
	EventBus.shop_inventory_generated.connect(_on_inventory_generated)
	_adjust_layout()
	_refresh_ui()

func _adjust_layout():
	var viewport_size = get_viewport_rect().size
	if viewport_size.x < viewport_size.y:
		inventory_grid.columns = 3
		bag_grid.columns = 3
	else:
		inventory_grid.columns = 5
		bag_grid.columns = 5

func _on_inventory_generated(inventory: Array):
	_refresh_ui()

func _refresh_ui():
	for c in inventory_grid.get_children():
		c.queue_free()
	for c in bag_grid.get_children():
		c.queue_free()

	money_label.text = "$" + str(GameState.money)

	for i in range(GameState.shop_inventory.size()):
		var cap = GameState.shop_inventory[i]
		var elem = KeyCapScene.instantiate()
		elem.setup(cap)
		var price_label = Label.new()
		price_label.text = "$" + str(cap["price"])
		elem.add_child(price_label)
		elem.connect("gui_input", Callable(self, "_on_shop_item_clicked").bind(i))
		inventory_grid.add_child(elem)

	for i in range(GameState.bag.size()):
		var cap = GameState.bag[i]
		var elem = KeyCapScene.instantiate()
		elem.setup(cap)
		elem.connect("gui_input", Callable(self, "_on_bag_item_clicked").bind(i))
		bag_grid.add_child(elem)

func _on_shop_item_clicked(index: int, event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		ShopService.buy_cap(index)
		_refresh_ui()

func _on_bag_item_clicked(index: int, event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		ShopService.sell_cap(index)
		_refresh_ui()

func _on_reroll_pressed():
	ShopService.reroll()
	_refresh_ui()

func _on_fight_pressed():
	EventBus.fight_pressed.emit()
