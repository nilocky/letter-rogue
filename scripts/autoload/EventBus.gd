extends Node

signal combat_word_generated(word: String, monster_name: String)
signal hand_drawn(hand: Array)
signal caps_played(played_caps: Array, slots: Array)
signal score_calculated(score: int, breakdown: Dictionary)
signal monster_damaged(remaining_hp: int, max_hp: int)
signal player_hit(damage: int, remaining_hp: int)
signal round_won(money_earned: int)
signal round_lost
signal game_over
signal shop_inventory_generated(inventory: Array)
signal cap_purchased(cap: Dictionary)
signal cap_sold(cap: Dictionary)
signal shop_rerolled
signal pack_selected(pack_id: String)
signal fight_pressed
signal run_started
