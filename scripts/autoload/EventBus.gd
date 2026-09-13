extends Node

signal tiles_consumed(used: Array, discarded: Array)
signal bag_reshuffled
signal hand_refilled(hand: Array)

signal run_setup_requested
signal run_setup_cancelled
signal run_started(pack_id: String, starter_bag_id: String)
signal fight_pressed

signal hand_drawn(hand: Array)
signal turn_started(turns_left: int, redraws_left: int)
signal turns_changed(turns_left: int)
signal redraws_changed(redraws_left: int)
signal word_committed(word: String, damage: int, tiles_used: int)
signal monster_damaged(remaining_hp: int, max_hp: int)
signal round_won(summary: Dictionary)
signal round_lost
signal game_over(reached_round: int)

signal shop_requested
signal game_complete

signal shop_inventory_generated(inventory: Array)
signal cap_purchased(cap: Dictionary)
signal cap_sold(cap: Dictionary)
signal shop_rerolled
signal upgrade_purchased(upgrade_id: String, level: int)
