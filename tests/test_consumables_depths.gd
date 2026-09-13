extends SceneTree

func _init() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	var depth: Node = root.get_node("DepthService")
	var cons: Node = root.get_node("ConsumableService")
	var shop: Node = root.get_node("ShopService")

	var tarot: Array = cons.get_tarot()
	assert(tarot.size() == 4, "Should have 4 tarot items, got %d" % tarot.size())
	var spectral: Array = cons.get_spectral()
	assert(spectral.size() == 3, "Should have 3 spectral items, got %d" % spectral.size())
	var grimoires: Array = cons.get_grimoires()
	assert(grimoires.size() >= 4, "Should have 4+ grimoire items, got %d" % grimoires.size())

	var vanguard: Array = depth.get_stage_pool("vanguard")
	assert(not vanguard.is_empty(), "Vanguard pool should not be empty")
	var sentry: Array = depth.get_stage_pool("sentry")
	assert(not sentry.is_empty(), "Sentry pool should not be empty")
	var enc: Dictionary = depth.generate_encounter(0)
	assert(not enc.is_empty(), "Should generate vanguard encounter")

	gs.word_form_levels = {}
	var grimoire: Dictionary = grimoires[0]
	var result: Dictionary = cons.apply(grimoire)
	assert(result.get("ok", false), "Grimoire application should succeed")
	assert(result.get("level", 0) == 1, "Grimoire should raise level to 1")

	var blueprints: Array = shop.blueprint_defs()
	assert(blueprints.size() == 3, "Should have 3 blueprints, got %d" % blueprints.size())

	var grab: Array = shop.generate_grab_bag("artisan", 3, 1)
	assert(grab.size() == 3, "Artisan grab bag should offer 3 choices, got %d" % grab.size())
	assert(int(grab[0].get("price", 0)) > 0, "Grab bag items should have prices")

	gs.bag = root.get_node_or_null("KeyCapService").load_starter_bag("standard") if root.get_node_or_null("KeyCapService") else gs.bag
	gs.bag = gs.bag if not gs.bag.is_empty() else [{"letter": "A", "price": 2}, {"letter": "B", "price": 1}]
	gs.money = 50
	var destroy: Dictionary = cons.apply({"effect_type": "destroy_random", "effect_params": {"count": 1}, "price": 12})
	assert(destroy.get("ok", false), "destroy_random should succeed")

	var bp_purchased: bool = shop.purchase_blueprint(blueprints[0])
	assert(bp_purchased, "Should afford blueprint with $50")
	assert(shop.owned_blueprint(str(blueprints[0]["id"])), "Blueprint should be owned after purchase")

	print("OK: Consumables (%d tarot, %d spectral, %d grimoire), Depths (%d vanguard), Blueprints (%d), Grab Bags working" % [tarot.size(), spectral.size(), grimoires.size(), vanguard.size(), blueprints.size()])
	quit(0)