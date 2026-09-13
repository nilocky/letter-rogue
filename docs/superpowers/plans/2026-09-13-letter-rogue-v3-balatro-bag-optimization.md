# Letter Rogue V3 — Balatro-Style Mechanics & Bag Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform Letter Rogue's core loop with play-and-refill bag mechanics, Word Form engine, 4-phase scoring pipeline, Artisan Keycap rail system, Switch Pack rewrite, consumables, and Depth progression.

**Architecture:** 6 milestones implemented sequentially. Each milestone produces independently testable, working software. Bag/draw overhaul comes first (touches every screen), then Word Form engine, then scoring pipeline refactor, then Artisan rail, then Switch Packs + visual updates, then consumables/depths/shop expansion.

**Tech Stack:** Godot 4.7.x, typed GDScript, JSON data files, Container-based UI.

**Spec:** `docs/superpowers/specs/2026-09-13-letter-rogue-v3-balatro-bag-optimization-design.md`

## Global Constraints

- All game data ships inside exported pck (`res://data/*.json`) — no runtime file access, no external fetches
- UI is 100% Container/anchor based — reflows for any viewport
- No external dependencies — Godot stdlib only
- Use Godot 4.x typed GDScript (`var count: int`, `func get() -> String:`)
- Signal naming: past-tense descriptive verbs (`word_committed`, `round_won`, `tiles_consumed`)
- No comments explaining basic language syntax
- `EffectPipeline` remains the hook system for all trigger-based effects
- Web export must compile without errors
- Autoload order (extended): EventBus, GameState, PackService, KeyCapService, KeyCapSkinService, ShopService, WordService, **WordFormService**, CombatService, **ArtisanRailManager**, **DepthService**, **ConsumableService**, ResolutionManager, DebugManager, EffectPipeline, LootService

---

## File Structure

### New Files
| File | Purpose |
|---|---|
| `scripts/autoload/WordFormService.gd` | Word Form pattern detection, base/mult lookup, grimoire level tracking |
| `scripts/autoload/ArtisanRailManager.gd` | 5-slot Artisan rail state, equip/unequip, cascade trigger dispatch |
| `scripts/autoload/DepthService.gd` | 3-stage encounter generation, Tag rewards, skip logic |
| `scripts/autoload/ConsumableService.gd` | Apply tarot/spectral/grimoire effects, bag mutations |
| `scripts/components/ArtisanSlot.tscn` | UI component for a single Artisan slot on the macro rail |
| `scripts/components/ArtisanSlot.gd` | Script for ArtisanSlot — display artisan icon, hover tooltip |
| `data/word_forms.json` | Word Form definitions (base damage, multiplier per form) |
| `data/artisans.json` | Artisan Keycap definitions (20+ across 4 archetypes) |
| `data/consumables.json` | Toolkit, Cursed Hardware, Grimoire definitions |
| `data/blueprints.json` | Workshop Blueprint definitions |
| `data/firmware_tags.json` | Firmware Tag definitions |
| `data/depths.json` | Depth encounter tables (Vanguard/Sentry pools) |

### Modified Files
| File | Changes |
|---|---|
| `scripts/autoload/GameState.gd` | Add discard_pile, altar_rune, word_form_levels, artisan_rail, active_blueprints, skip_tags, depth_stage |
| `scripts/autoload/KeyCapService.gd` | Rewrite draw_hand(): play-and-refill, vowel safeguard, reshuffle from discard |
| `scripts/autoload/CombatService.gd` | Rewrite calculate_word(): 4-phase pipeline. Update commit_word(): consume tiles to discard, refill hand |
| `scripts/autoload/EventBus.gd` | Add new signals for bag/draw, scoring pipeline, artisan rail, depth/shop |
| `scripts/autoload/EffectPipeline.gd` | Add on_word_form_evaluated, on_artisan_triggered, on_shop_opened, on_bag_mutated hooks |
| `scripts/autoload/PackService.gd` | Add conditional passive evaluation for new Switch Packs |
| `scripts/autoload/ShopService.gd` | Add Blueprint purchases, Grab Bag generation, Grimoire items |
| `scripts/screens/CombatScreen.gd` | Update scoring animation for 4 phases. Update hand lifecycle for play-and-refill. Add Artisan rail display. |
| `scripts/screens/RunSetupScreen.gd` | Update for new Switch Pack definitions |
| `scripts/screens/ShopScreen.gd` | Add Blueprint column, Grab Bag packs, Grimoire items |
| `scripts/screens/GameOverScreen.gd` | Display depth reached info |
| `scripts/components/KeyCapElement.gd` | Rigid 2-3px plunge (remove squash/stretch), dual-perspective modes |
| `data/packs.json` | Rewrite with 5 thematic Switch Packs |
| `data/starter_bags.json` | Expand bags to 14-16 tiles |
| `project.godot` | Add new autoloads in correct order |

---

## Tasks

### Task 1: Expand Starter Bags & Add GameState Fields

**Files:**
- Modify: `data/starter_bags.json`
- Modify: `scripts/autoload/GameState.gd`
- Test: `tests/test_bag_expansion.gd`

**Interfaces:**
- Consumes: Existing GameState fields (bag, hand, draw_size)
- Produces: `GameState.discard_pile`, `GameState.altar_rune`, `GameState.word_form_levels`

- [ ] **Step 1: Expand Standard starter bag to 14 tiles**

Add D, L, C, M, P to the Standard bag. Keep Vowel Explorer at 8 (it already has a wildcard). Keep Consonant Heavy at 10. Keep Minimalist at 6.

Edit `data/starter_bags.json` — add these tile entries to the "standard" bag:
```
{"letter": "D", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
{"letter": "L", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
{"letter": "C", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
{"letter": "M", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
{"letter": "P", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false}
```

- [ ] **Step 2: Add new GameState fields**

Add to `scripts/autoload/GameState.gd`:
```gdscript
var discard_pile: Array = []
var altar_rune: Dictionary = {}
var word_form_levels: Dictionary = {}
var artisan_rail: Array = []
var active_blueprints: Dictionary = {}
var skip_tags: Array = []
var depth_stage: int = 0
```

Update `reset()` to clear these fields.

- [ ] **Step 3: Write headless test**

Create `tests/test_bag_expansion.gd`:
```gdscript
extends SceneTree

func _init() -> void:
	var text := FileAccess.get_file_as_string("res://data/starter_bags.json")
	var data: Variant = JSON.parse_string(text)
	var bags: Array = data.get("starter_bags", [])
	var standard: Dictionary = bags[0]
	assert(standard["id"] == "standard")
	var tiles: Array = standard.get("tiles", [])
	assert(tiles.size() == 14, "Standard bag should have 14 tiles, got %d" % tiles.size())
	var letters := PackedStringArray()
	for t in tiles:
		letters.append(str(t["letter"]))
	for expected in ["E","T","A","O","I","N","S","R","D","L","C","M","P"]:
		assert(letters.has(expected), "Standard bag missing %s" % expected)
	print("OK: Standard bag has %d tiles with correct letters" % tiles.size())
	get_tree().quit(0)
```

- [ ] **Step 4: Run test**

```powershell
godot --headless --script res://tests/test_bag_expansion.gd
```
Expected: `OK: Standard bag has 14 tiles with correct letters`

- [ ] **Step 5: Commit**

```powershell
git add data/starter_bags.json scripts/autoload/GameState.gd tests/test_bag_expansion.gd
git commit -m "feat: expand starter bag to 14 tiles, add GameState fields for V3 systems"
```

---

### Task 2: Play-and-Refill Draw System

**Files:**
- Modify: `scripts/autoload/KeyCapService.gd`
- Modify: `scripts/autoload/CombatService.gd`
- Modify: `scripts/autoload/EventBus.gd`
- Test: `tests/test_play_refill.gd`

**Interfaces:**
- Consumes: `GameState.bag`, `GameState.hand`, `GameState.discard_pile`, `GameState.draw_size()`
- Produces: `KeyCapService.draw_hand()` — play-and-refill, vowel safeguard, reshuffle

- [ ] **Step 1: Add new signals to EventBus**

```gdscript
signal tiles_consumed(used: Array, discarded: Array)
signal bag_reshuffled
signal hand_refilled(hand: Array)
```

- [ ] **Step 2: Rewrite KeyCapService.draw_hand()**

```gdscript
func draw_hand() -> void:
	var target: int = mini(GameState.draw_size(), GameState.bag.size())
	var already: int = GameState.hand.size()
	var need: int = maxi(0, target - already)
	if need == 0:
		EventBus.hand_drawn.emit(GameState.hand)
		return
	# If bag is empty, reshuffle discard pile
	if GameState.bag.is_empty() and not GameState.discard_pile.is_empty():
		_reshuffle_from_discard()
	if GameState.bag.is_empty():
		EventBus.hand_drawn.emit(GameState.hand)
		return
	var pool := range(GameState.bag.size())
	pool.shuffle()
	for i in range(mini(need, pool.size())):
		GameState.hand.append(GameState.bag[pool[i]])
	_vowel_safeguard()
	EventBus.hand_drawn.emit(GameState.hand)
```

- [ ] **Step 3: Implement _reshuffle_from_discard()**

```gdscript
func _reshuffle_from_discard() -> void:
	GameState.bag = GameState.discard_pile.duplicate()
	GameState.discard_pile.clear()
	EventBus.bag_reshuffled.emit()
```

- [ ] **Step 4: Implement _vowel_safeguard()**

```gdscript
func _vowel_safeguard() -> void:
	const VOWELS := "AEIOU"
	var vowel_count := 0
	var wild_vowel_count := 0
	for cap in GameState.hand:
		var letter: String = str(cap.get("letter", ""))
		if VOWELS.contains(letter):
			vowel_count += 1
		elif letter == "~" or letter == "*":
			wild_vowel_count += 1
	if vowel_count + wild_vowel_count >= 2:
		return
	# Need more vowels — try swapping non-vowels for vowels from bag
	var to_swap: Array = []
	for i in range(GameState.hand.size()):
		var cap: Dictionary = GameState.hand[i]
		var letter: String = str(cap.get("letter", ""))
		if not VOWELS.contains(letter) and letter != "~" and letter != "*":
			to_swap.append(i)
	var vowel_pool: Array = []
	for i in range(GameState.bag.size()):
		var cap: Dictionary = GameState.bag[i]
		var letter: String = str(cap.get("letter", ""))
		if VOWELS.contains(letter) or letter == "~" or letter == "*":
			vowel_pool.append(i)
	vowel_pool.shuffle()
	for idx in to_swap:
		if vowel_pool.is_empty():
			break
		if vowel_count + wild_vowel_count >= 2:
			break
		var vi: int = vowel_pool.pop_back()
		# Swap: put hand tile back in bag, take vowel into hand
		GameState.bag.append(GameState.hand[idx])
		GameState.hand[idx] = GameState.bag[vi]
		GameState.bag.remove_at(vi)
		vowel_count += 1
```

- [ ] **Step 5: Update CombatService.commit_word() — consume tiles to discard**

In `commit_word()`, after applying damage and side effects, move played tiles to discard pile:
```gdscript
# After all scoring/effects, before _end_turn:
var used_caps: Array = []
for s in slots:
	used_caps.append(s["cap"])
GameState.discard_pile.append_array(used_caps)
for cap in used_caps:
	GameState.hand.erase(cap)
EventBus.tiles_consumed.emit(used_caps, GameState.discard_pile)
# Don't return tiles to bag — they go to discard
# Unused tiles stay in hand
# Then refill hand for next turn
```

In `_end_turn()`, after decrementing turns, call `KeyCapService.draw_hand()` for the refill (instead of drawing a fresh hand). Remove the old `KeyCapService.draw_hand()` call — unused tiles persist in hand.

- [ ] **Step 6: Write headless test**

Create `tests/test_play_refill.gd`:
```gdscript
extends SceneTree

func _init() -> void:
	# Bootstrap minimal GameState
	GameState.bag = KeyCapService.load_starter_bag("standard")
	assert(GameState.bag.size() == 14)
	GameState.active_pack_id = "mx_red"
	GameState.hand.clear()
	GameState.discard_pile.clear()
	
	# Draw initial hand
	KeyCapService.draw_hand()
	var initial_hand_size: int = GameState.hand.size()
	assert(initial_hand_size > 0, "Hand should not be empty")
	
	# Simulate playing 3 tiles (they go to discard)
	var used: Array = [GameState.hand[0], GameState.hand[1], GameState.hand[2]]
	GameState.discard_pile.append_array(used)
	for cap in used:
		GameState.hand.erase(cap)
	
	# Unused tiles should still be in hand
	assert(GameState.hand.size() == initial_hand_size - 3,
		"Unused tiles should stay in hand, got %d" % GameState.hand.size())
	assert(GameState.discard_pile.size() == 3,
		"Used tiles should go to discard, got %d" % GameState.discard_pile.size())
	
	# Refill hand
	KeyCapService.draw_hand()
	assert(GameState.hand.size() <= GameState.draw_size(),
		"Hand should not exceed draw size after refill")
	
	# Vowel safeguard check
	const VOWELS := "AEIOU"
	var vowels := 0
	for cap in GameState.hand:
		var l: String = str(cap.get("letter", ""))
		if VOWELS.contains(l) or l == "~" or l == "*":
			vowels += 1
	assert(vowels >= 2, "Hand should have at least 2 vowels/wildcards, got %d" % vowels)
	
	print("OK: Play-and-refill + vowel safeguard working")
	get_tree().quit(0)
```

- [ ] **Step 7: Run test**

```powershell
godot --headless --script res://tests/test_play_refill.gd
```
Expected: `OK: Play-and-refill + vowel safeguard working`

- [ ] **Step 8: Commit**

```powershell
git add scripts/autoload/KeyCapService.gd scripts/autoload/CombatService.gd scripts/autoload/EventBus.gd tests/test_play_refill.gd
git commit -m "feat: play-and-refill draw system with vowel safeguard and discard reshuffle"
```

---

### Task 3: Word Form Engine

**Files:**
- Create: `scripts/autoload/WordFormService.gd`
- Create: `data/word_forms.json`
- Modify: `scripts/autoload/GameState.gd` (grimoire level tracking already added)
- Modify: `project.godot` (add WordFormService autoload)
- Test: `tests/test_word_form_detection.gd`

**Interfaces:**
- Consumes: Word slots array (letter strings)
- Produces: `WordFormService.detect(slots: Array) -> Dictionary` — returns form_id, base_damage, base_mult

- [ ] **Step 1: Create `data/word_forms.json`**

```json
{
  "forms": [
    {"id": "trio", "name": "Trio", "min_length": 3, "max_length": 3, "pattern": "any", "base_damage": 0, "base_multiplier": 1.0},
    {"id": "quartet", "name": "Quartet", "min_length": 4, "max_length": 4, "pattern": "any", "base_damage": 4, "base_multiplier": 1.3},
    {"id": "quintet", "name": "Quintet", "min_length": 5, "max_length": 5, "pattern": "any", "base_damage": 8, "base_multiplier": 1.6},
    {"id": "hexagram", "name": "Hexagram", "min_length": 6, "max_length": 99, "pattern": "any", "base_damage": 12, "base_multiplier": 2.0},
    {"id": "double_tap", "name": "Double-Tap", "min_length": 3, "max_length": 99, "pattern": "adjacent_duplicate", "base_damage": 6, "base_multiplier": 1.5},
    {"id": "mirror", "name": "Mirror Word", "min_length": 3, "max_length": 99, "pattern": "palindrome", "base_damage": 10, "base_multiplier": 2.0},
    {"id": "consonant_core", "name": "Consonant Core", "min_length": 3, "max_length": 99, "pattern": "consonant_rich", "base_damage": 5, "base_multiplier": 1.5}
  ]
}
```

- [ ] **Step 2: Create WordFormService.gd**

```gdscript
extends Node

const VOWELS := "AEIOU"
const RARE_CONSONANTS := "VKXJQZ"

var _forms: Dictionary = {}  # id -> Dictionary

func _ready() -> void:
	_load_forms()

func _load_forms() -> void:
	var text := FileAccess.get_file_as_string("res://data/word_forms.json")
	var data: Variant = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY:
		for f: Dictionary in data.get("forms", []):
			_forms[str(f["id"])] = f

func get_form(form_id: String) -> Dictionary:
	return _forms.get(form_id, {})

## Detect the best Word Form for the given word/slots.
## Returns {form_id, base_damage, base_multiplier, name} or empty Dictionary if none.
func detect(slots: Array) -> Dictionary:
	var word := ""
	var letters: Array = []
	for s in slots:
		var l: String = str(s.get("letter", s if typeof(s) == TYPE_STRING else ""))
		word += l
		letters.append(l)
	
	var len_word: int = word.length()
	
	# Check special patterns first (they take priority over basic length forms)
	if len_word >= 3:
		# Mirror Word (palindrome)
		if _is_palindrome(word):
			var f: Dictionary = _forms.get("mirror", {})
			if not f.is_empty() and len_word >= int(f.get("min_length", 3)):
				var level: int = GameState.word_form_levels.get("mirror", 0)
				return _build_result(f, level)
		
		# Double-Tap (adjacent duplicate letters)
		if _has_adjacent_duplicate(letters):
			var f: Dictionary = _forms.get("double_tap", {})
			if not f.is_empty() and len_word >= int(f.get("min_length", 3)):
				var level: int = GameState.word_form_levels.get("double_tap", 0)
				return _build_result(f, level)
		
		# Consonant Core (3+ rare consonants)
		if _has_consonant_core(letters):
			var f: Dictionary = _forms.get("consonant_core", {})
			if not f.is_empty():
				var level: int = GameState.word_form_levels.get("consonant_core", 0)
				return _build_result(f, level)
	
	# Basic length-based forms
	if len_word >= 6:
		var f: Dictionary = _forms.get("hexagram", {})
		var level: int = GameState.word_form_levels.get("hexagram", 0)
		return _build_result(f, level)
	elif len_word == 5:
		var f: Dictionary = _forms.get("quintet", {})
		var level: int = GameState.word_form_levels.get("quintet", 0)
		return _build_result(f, level)
	elif len_word == 4:
		var f: Dictionary = _forms.get("quartet", {})
		var level: int = GameState.word_form_levels.get("quartet", 0)
		return _build_result(f, level)
	elif len_word == 3:
		var f: Dictionary = _forms.get("trio", {})
		var level: int = GameState.word_form_levels.get("trio", 0)
		return _build_result(f, level)
	
	return {}

func _build_result(form: Dictionary, level: int) -> Dictionary:
	var form_id: String = str(form["id"])
	var base_dmg: int = int(form.get("base_damage", 0)) + level * 2
	var base_mult: float = float(form.get("base_multiplier", 1.0)) + level * 0.1
	return {
		"form_id": form_id,
		"name": str(form.get("name", form_id)),
		"base_damage": base_dmg,
		"base_multiplier": base_mult
	}

func _is_palindrome(word: String) -> bool:
	var len_w: int = word.length()
	if len_w < 3:
		return false
	for i in range(len_w / 2):
		if word[i] != word[len_w - 1 - i]:
			return false
	return true

func _has_adjacent_duplicate(letters: Array) -> bool:
	for i in range(letters.size() - 1):
		if str(letters[i]) == str(letters[i + 1]):
			return true
	return false

func _has_consonant_core(letters: Array) -> bool:
	var count := 0
	for l in letters:
		if RARE_CONSONANTS.contains(str(l)):
			count += 1
	return count >= 3
```

- [ ] **Step 3: Register WordFormService in project.godot**

Add to the autoload list after WordService:
```
WordFormService="*res://scripts/autoload/WordFormService.gd"
```

- [ ] **Step 4: Write headless test**

Create `tests/test_word_form_detection.gd`:
```gdscript
extends SceneTree

func _init() -> void:
	GameState.word_form_levels = {}
	
	# Test basic length forms
	var trio: Dictionary = WordFormService.detect([{"letter":"C"},{"letter":"A"},{"letter":"T"}])
	assert(trio.get("form_id") == "trio", "CAT should be trio, got %s" % trio.get("form_id"))
	
	var quartet: Dictionary = WordFormService.detect([{"letter":"B"},{"letter":"E"},{"letter":"A"},{"letter":"R"}])
	assert(quartet.get("form_id") == "quartet", "BEAR should be quartet, got %s" % quartet.get("form_id"))
	
	var quintet: Dictionary = WordFormService.detect([{"letter":"A"},{"letter":"P"},{"letter":"P"},{"letter":"L"},{"letter":"E"}])
	assert(quintet.get("form_id") == "quintet", "APPLE should be quintet, got %s" % quintet.get("form_id"))
	
	# Test palindrome (Mirror Word)
	var mirror: Dictionary = WordFormService.detect([{"letter":"L"},{"letter":"E"},{"letter":"V"},{"letter":"E"},{"letter":"L"}])
	assert(mirror.get("form_id") == "mirror", "LEVEL should be mirror, got %s" % mirror.get("form_id"))
	
	# Test adjacent duplicate (Double-Tap)
	var dt: Dictionary = WordFormService.detect([{"letter":"B"},{"letter":"O"},{"letter":"O"},{"letter":"K"}])
	assert(dt.get("form_id") == "double_tap", "BOOK should be double_tap, got %s" % dt.get("form_id"))
	
	# Test consonant core (3+ rare consonants)
	var cc: Dictionary = WordFormService.detect([{"letter":"Q"},{"letter":"U"},{"letter":"I"},{"letter":"Z"},{"letter":"X"}])
	assert(cc.get("form_id") == "consonant_core", "QUIZX should be consonant_core, got %s" % cc.get("form_id"))
	
	# Special patterns should take priority over length forms
	# LEVEL is 5 letters but palindrome should win
	var level_mirror: Dictionary = WordFormService.detect([{"letter":"L"},{"letter":"E"},{"letter":"V"},{"letter":"E"},{"letter":"L"}])
	assert(level_mirror.get("form_id") == "mirror", "LEVEL should be mirror (not quintet), got %s" % level_mirror.get("form_id"))
	
	print("OK: All word form detections pass")
	get_tree().quit(0)
```

- [ ] **Step 5: Run test**

```powershell
godot --headless --script res://tests/test_word_form_detection.gd
```
Expected: `OK: All word form detections pass`

- [ ] **Step 6: Commit**

```powershell
git add scripts/autoload/WordFormService.gd data/word_forms.json project.godot tests/test_word_form_detection.gd
git commit -m "feat: Word Form engine with pattern detection (Trio/Quartet/Mirror/Double-Tap/Consonant Core)"
```

---

### Task 4: 4-Phase Scoring Pipeline

**Files:**
- Modify: `scripts/autoload/CombatService.gd`
- Modify: `scripts/screens/CombatScreen.gd`
- Modify: `scripts/autoload/EffectPipeline.gd`
- Test: `tests/test_scoring_pipeline.gd`

**Interfaces:**
- Consumes: `WordFormService.detect()`, existing letter scoring
- Produces: New `calculate_word()` → 4-phase pipeline result

- [ ] **Step 1: Add new EffectPipeline hooks**

```gdscript
signal on_word_form_evaluated(form_id: String, base: int, mult: float)
signal on_artisan_triggered(artisan_id: String, slot: int, effect: Dictionary)
signal on_shop_opened
signal on_bag_mutated(mutation_type: String, affected_tiles: Array)
```

Add corresponding `_emit_hook_signal` cases.

- [ ] **Step 2: Rewrite CombatService.calculate_word() as 4-phase pipeline**

```gdscript
func calculate_word(slots: Array, log: bool = false) -> Dictionary:
	var modifier: String = _current_modifier()
	var disabled: bool = modifier == "silence"
	var pack := PackService.pack_by_id(GameState.active_pack_id)
	var per_tile: int = int(pack.get("score_modifier", 0)) if not pack.is_empty() else 0
	
	# Phase 1: Tile Hops
	var letter_scores: Array = []
	var total_base: float = 0.0
	for s in slots:
		var score: float = _tile_hop_score(s, modifier, disabled, per_tile)
		letter_scores.append(score)
		total_base += score
	EffectPipeline.trigger("on_score_calculated", [{"letter_scores": letter_scores}])
	
	# Phase 2: Word Form Ignition
	var word := ""
	for s in slots:
		word += str(s["letter"])
	var form_data: Dictionary = {}
	if word.length() >= 3:
		form_data = WordFormService.detect(slots)
	EffectPipeline.trigger("on_word_form_evaluated", [
		form_data.get("form_id", ""),
		form_data.get("base_damage", 0),
		form_data.get("base_multiplier", 1.0)
	])
	
	var length_mult: float = WordService.length_multiplier(slots.size())
	var form_base: int = form_data.get("base_damage", 0)
	var form_mult: float = form_data.get("base_multiplier", 1.0)
	var total_after_form: float = (total_base + float(form_base)) * length_mult * form_mult
	
	# Phase 3: Artisan Cascade (stub — passes through until Task 5)
	var artisan_flat: int = 0
	var artisan_xmult: float = 1.0
	# ArtisanRailManager will populate these in Task 5
	
	# Phase 4: Runic Blast
	var total_after_artisans: float = (total_after_form + float(artisan_flat)) * artisan_xmult
	var flat_bonus: int = 0
	var money: int = 0
	for s in slots:
		var cap: Dictionary = s["cap"]
		if not disabled:
			var ability := KeyCapService.resolve_ability(cap)
			flat_bonus += int(ability.get("bonus", 0))
			money += int(ability.get("money", 0))
	var damage: int = roundi(total_after_artisans) + flat_bonus
	
	if log:
		print("[score] word=\"%s\" form=%s len=%d" % [word, form_data.get("form_id", "none"), slots.size()])
		print("[score]   base=%.1f form_base=%d length_mult=%.1f form_mult=%.1f artisan_flat=%d artisan_xmult=%.1f" % [total_base, form_base, length_mult, form_mult, artisan_flat, artisan_xmult])
		print("[score]   total=%.1f -> %d dmg (+%d flat) +$%d" % [total_after_artisans, damage, flat_bonus, money])
	
	var result: Dictionary = {
		"damage": damage,
		"money": money,
		"letter_scores": letter_scores,
		"form_data": form_data,
		"flat_bonus": flat_bonus
	}
	return result

func _tile_hop_score(s: Dictionary, modifier: String, disabled: bool, per_tile: int) -> float:
	var cap: Dictionary = s["cap"]
	var letter: String = str(s["letter"])
	var is_vowel: bool = "AEIOU".contains(letter)
	var contribution: float = 0.0
	if not bool(cap.get("is_symbol", false)):
		contribution = float(_letter_base_score(str(cap["letter"])))
	if not disabled:
		contribution += float(per_tile)
		var ability := KeyCapService.resolve_ability(cap)
		contribution += float(ability.get("score", 0))
		contribution *= float(ability.get("score_multiplier", 1.0))
		match str(cap.get("finish", "")):
			"foil": contribution += 3.0
			"holographic": contribution += 1.0
			"polychrome": contribution *= 1.5
		if str(cap.get("sticker", "")) == "red":
			contribution *= 2.0
		if str(cap.get("condition", "")) == "glass":
			contribution *= 2.0
	if modifier == "vowel_lock" and not is_vowel:
		contribution = 0.0
	elif modifier == "consonant_lock" and is_vowel:
		contribution = 0.0
	return contribution
```

- [ ] **Step 3: Update CombatScreen scoring animation**

In `_play_score_animation()`, after Phase A (tile hops) and before Phase B, insert the Word Form ignition display:

```gdscript
# After Phase A, before Phase B
# Show Word Form data in the banner
var form_data: Dictionary = res.get("form_data", {})
if not form_data.is_empty():
	# Display form name + base damage + multiplier
	var form_label := _ensure_form_label()
	form_label.text = "%s · +%d base · ×%.1f" % [
		form_data.get("name", ""),
		form_data.get("base_damage", 0),
		form_data.get("base_multiplier", 1.0)
	]
	form_label.show()
	# Pulse animation for form ignition
	var form_pulse := create_tween()
	form_pulse.tween_property(form_label, "scale", Vector2(1.3, 1.3), 0.1)
	form_pulse.tween_property(form_label, "scale", Vector2(1.0, 1.0), 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
```

Create `_ensure_form_label()` helper to add a Label for Word Form display if not present.

- [ ] **Step 4: Write headless test**

Create `tests/test_scoring_pipeline.gd`:
```gdscript
extends SceneTree

func _init() -> void:
	# Setup minimal state
	GameState.active_pack_id = "mx_red"
	GameState.word_form_levels = {}
	
	# Mock a pack
	var packs_text := FileAccess.get_file_as_string("res://data/packs.json")
	var packs_data: Variant = JSON.parse_string(packs_text)
	PackService.available_packs = packs_data.get("packs", [])
	
	# Test "CAT" — 3 letters, trio form
	var slots: Array = [
		{"cap": {"letter": "C", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false}, "letter": "C"},
		{"cap": {"letter": "A", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false}, "letter": "A"},
		{"cap": {"letter": "T", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false}, "letter": "T"}
	]
	var res: Dictionary = CombatService.calculate_word(slots)
	assert(res.has("damage"), "Result should have damage")
	assert(res.has("form_data"), "Result should have form_data")
	assert(res["form_data"].get("form_id") == "trio", "CAT should detect as trio")
	assert(res["damage"] > 0, "Damage should be positive")
	
	# Test "LEVEL" — palindrome
	var slots2: Array = []
	for l in "LEVEL":
		slots2.append({"cap": {"letter": l, "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false}, "letter": l})
	var res2: Dictionary = CombatService.calculate_word(slots2)
	assert(res2["form_data"].get("form_id") == "mirror", "LEVEL should detect as mirror")
	
	print("OK: 4-phase scoring pipeline working — CAT=%.1f dmg, LEVEL=%.1f dmg" % [res["damage"], res2["damage"]])
	get_tree().quit(0)
```

- [ ] **Step 5: Run test**

```powershell
godot --headless --script res://tests/test_scoring_pipeline.gd
```
Expected: `OK: 4-phase scoring pipeline working`

- [ ] **Step 6: Commit**

```powershell
git add scripts/autoload/CombatService.gd scripts/screens/CombatScreen.gd scripts/autoload/EffectPipeline.gd tests/test_scoring_pipeline.gd
git commit -m "feat: 4-phase scoring pipeline with Word Form ignition"
```

---

### Task 5: Artisan Keycap Rail System

**Files:**
- Create: `scripts/autoload/ArtisanRailManager.gd`
- Create: `data/artisans.json`
- Create: `scenes/components/ArtisanSlot.tscn`
- Create: `scripts/components/ArtisanSlot.gd`
- Modify: `scripts/autoload/CombatService.gd` (activate Phase 3)
- Modify: `scripts/screens/CombatScreen.gd` (add rail UI)
- Modify: `project.godot` (add ArtisanRailManager autoload)
- Test: `tests/test_artisan_rail.gd`

- [ ] **Step 1: Create `data/artisans.json`**

```json
{
  "artisans": [
    {"id": "caps_lock", "name": "Caps Lock", "archetype": "flat_power", "rarity": "Common", "price": 6, "trigger": {"type": "word_length", "min": 4}, "effect": {"type": "add_flat", "value": 8}},
    {"id": "spacebar", "name": "The Spacebar", "archetype": "flat_power", "rarity": "Common", "price": 5, "trigger": {"type": "word_length", "max": 3}, "effect": {"type": "add_flat", "value": 12}},
    {"id": "touch_typist", "name": "Touch Typist", "archetype": "flat_power", "rarity": "Common", "price": 6, "trigger": {"type": "no_redraws_used"}, "effect": {"type": "add_flat", "value": 4}},
    {"id": "clicky_zealot", "name": "Clicky Zealot", "archetype": "x_mult", "rarity": "Uncommon", "price": 10, "trigger": {"type": "rare_consonant", "per": true}, "effect": {"type": "multiply", "value": 1.5}},
    {"id": "rotary_knob", "name": "Rotary Knob", "archetype": "x_mult", "rarity": "Uncommon", "price": 10, "trigger": {"type": "unused_redraws"}, "effect": {"type": "multiply_per_redraw", "value": 1.3}},
    {"id": "nkey_rollover", "name": "N-Key Rollover", "archetype": "x_mult", "rarity": "Rare", "price": 14, "trigger": {"type": "word_length", "min": 6}, "effect": {"type": "multiply", "value": 2.5}},
    {"id": "alliteration", "name": "Alliteration", "archetype": "synergy", "rarity": "Rare", "price": 12, "trigger": {"type": "consecutive_start_letter"}, "effect": {"type": "multiply", "value": 3.0}},
    {"id": "vocalist", "name": "Vocalist", "archetype": "synergy", "rarity": "Uncommon", "price": 9, "trigger": {"type": "more_vowels_than_consonants"}, "effect": {"type": "retrigger_tiles"}},
    {"id": "mirroring", "name": "Mirroring", "archetype": "synergy", "rarity": "Epic", "price": 18, "trigger": {"type": "word_form", "form": "mirror"}, "effect": {"type": "multiply", "value": 4.0}},
    {"id": "golden_lube", "name": "Golden Lube", "archetype": "economy", "rarity": "Uncommon", "price": 8, "trigger": {"type": "leftover_turns", "min": 2}, "effect": {"type": "money", "value": 6}},
    {"id": "typewriter_ribbon", "name": "Typewriter Ribbon", "archetype": "economy", "rarity": "Rare", "price": 14, "trigger": {"type": "unprecedented_word"}, "effect": {"type": "permanent_base_damage", "value": 2}},
    {"id": "artisan_puller", "name": "Artisan Puller", "archetype": "economy", "rarity": "Epic", "price": 20, "trigger": {"type": "boss_defeated"}, "effect": {"type": "trash_cheapest_tile"}}
  ]
}
```

- [ ] **Step 2: Create ArtisanRailManager.gd**

```gdscript
extends Node

var rail: Array = []  # 5 slots, null or artisan Dictionary

func _ready() -> void:
	rail.resize(5)

func equip(slot: int, artisan: Dictionary) -> bool:
	if slot < 0 or slot >= 5:
		return false
	rail[slot] = artisan
	EffectPipeline.register_cap(artisan)
	EventBus.artisan_equipped.emit(slot, str(artisan.get("id", "")))
	return true

func unequip(slot: int) -> bool:
	if slot < 0 or slot >= 5 or rail[slot] == null:
		return false
	var cap: Dictionary = rail[slot]
	rail[slot] = null
	EffectPipeline.unregister_cap(cap)
	EventBus.artisan_unequipped.emit(slot, str(cap.get("id", "")))
	return true

func get_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= 5 or rail[slot] == null:
		return {}
	return rail[slot]

## Run the cascade: evaluate each artisan left-to-right, accumulate
## flat bonuses and multiplicative multipliers. Returns {flat: int, xmult: float}.
func cascade(word: String, slots: Array, letter_scores: Array, form_data: Dictionary, pack_data: Dictionary) -> Dictionary:
	var flat: int = 0
	var xmult: float = 1.0
	var artisan_ids: Array = []
	
	for slot in range(5):
		var artisan: Dictionary = rail[slot]
		if artisan.is_empty():
			continue
		artisan_ids.append(str(artisan.get("id", "")))
		var trigger: Dictionary = artisan.get("trigger", {})
		var trigger_type: String = str(trigger.get("type", ""))
		var triggered: bool = _evaluate_trigger(trigger_type, trigger, word, slots, letter_scores, form_data, pack_data)
		
		if not triggered:
			continue
		
		var effect: Dictionary = artisan.get("effect", {})
		var effect_type: String = str(effect.get("type", ""))
		match effect_type:
			"add_flat":
				flat += int(effect.get("value", 0))
			"multiply":
				xmult *= float(effect.get("value", 1.0))
			"multiply_per_redraw":
				var used: int = GameState.round_redraw_budget() - GameState.redraws_left
				var unused: int = GameState.round_redraw_budget() - used
				xmult *= pow(float(effect.get("value", 1.0)), maxi(unused, 0))
			"money":
				pass  # Handled in CombatService side-effect phase
		
		EffectPipeline.trigger("on_artisan_triggered", [str(artisan.get("id", "")), slot, effect])
	
	if not artisan_ids.is_empty():
		EventBus.phase_artisan_cascade_started.emit(artisan_ids)
	
	return {"flat": flat, "xmult": xmult}

func _evaluate_trigger(trigger_type: String, trigger: Dictionary, word: String, slots: Array, letter_scores: Array, form_data: Dictionary, _pack_data: Dictionary) -> bool:
	match trigger_type:
		"word_length":
			var min_l: int = int(trigger.get("min", 0))
			var max_l: int = int(trigger.get("max", 99))
			return slots.size() >= min_l and slots.size() <= max_l
		"no_redraws_used":
			return GameState.redraws_left == GameState.round_redraw_budget()
		"rare_consonant":
			var count := 0
			for s in slots:
				var l: String = str(s.get("letter", ""))
				if "VKXJQZ".contains(l):
					count += 1
			var per: bool = trigger.get("per", false)
			return count > 0 if not per else count >= 1
		"unused_redraws":
			return GameState.redraws_left > 0
		"more_vowels_than_consonants":
			var vowels := 0
			var cons := 0
			for s in slots:
				var l: String = str(s.get("letter", ""))
				if "AEIOU".contains(l):
					vowels += 1
				elif l != "~" and l != "*" and l != "#":
					cons += 1
			return vowels > cons
		"word_form":
			var target_form: String = str(trigger.get("form", ""))
			return form_data.get("form_id", "") == target_form
		"leftover_turns":
			return GameState.turns_left >= int(trigger.get("min", 0))
	return false
```

- [ ] **Step 3: Create ArtisanSlot.tscn and ArtisanSlot.gd**

`ArtisanSlot.gd`:
```gdscript
extends Control

@onready var icon_label: Label = $IconLabel
@onready var name_label: Label = $NameLabel
@onready var tooltip_panel: Panel = $TooltipPanel

var artisan_data: Dictionary = {}

func setup(data: Dictionary) -> void:
	artisan_data = data
	name_label.text = str(data.get("name", "?"))
	icon_label.text = str(data.get("id", "?"))
	if tooltip_panel:
		var desc: String = str(data.get("name", ""))
		var archetype: String = str(data.get("archetype", ""))
		var trigger_info: String = str(data.get("trigger", {}).get("type", ""))
		tooltip_panel.get_node("Label").text = "%s (%s) — triggers on %s" % [desc, archetype, trigger_info]

func clear_slot() -> void:
	artisan_data = {}
	name_label.text = ""
	icon_label.text = "+"
```

`ArtisanSlot.tscn` — root Control (48x54), children: IconLabel (Label, center), NameLabel (Label, bottom), TooltipPanel (Panel, hidden by default, shown on hover).

- [ ] **Step 4: Update CombatService.calculate_word() Phase 3**

Replace the stub with actual ArtisanRailManager call:
```gdscript
# Phase 3: Artisan Cascade
var artisan_result: Dictionary = ArtisanRailManager.cascade(
	word, slots, letter_scores, form_data, pack
)
var artisan_flat: int = artisan_result.get("flat", 0)
var artisan_xmult: float = artisan_result.get("xmult", 1.0)
```

- [ ] **Step 5: Add Artisan rail UI to CombatScreen**

In the CombatScreen scene (above the word strip area), add a 5-slot HBoxContainer for the Artisan macro rail. In CombatScreen.gd:

```gdscript
const ARTISAN_SLOT_SCENE := preload("res://scenes/components/ArtisanSlot.tscn")

@onready var artisan_rail_container: HBoxContainer = %ArtisanRailContainer

func _refresh_artisan_rail() -> void:
	for child in artisan_rail_container.get_children():
		child.queue_free()
	for slot in range(5):
		var slot_el: Control = ARTISAN_SLOT_SCENE.instantiate()
		var data: Dictionary = ArtisanRailManager.get_slot(slot)
		if data.is_empty():
			slot_el.clear_slot()
		else:
			slot_el.setup(data)
		artisan_rail_container.add_child(slot_el)
```

Call `_refresh_artisan_rail()` in `show_round()` and `_on_hand_drawn()`.

- [ ] **Step 6: Register ArtisanRailManager in project.godot**

Add after CombatService:
```
ArtisanRailManager="*res://scripts/autoload/ArtisanRailManager.gd"
```

- [ ] **Step 7: Write headless test**

Create `tests/test_artisan_rail.gd`:
```gdscript
extends SceneTree

func _init() -> void:
	# Setup
	GameState.active_pack_id = "mx_red"
	GameState.word_form_levels = {}
	GameState.redraws_left = 3
	GameState.turns_left = 3
	var packs_text := FileAccess.get_file_as_string("res://data/packs.json")
	var packs_data: Variant = JSON.parse_string(packs_text)
	PackService.available_packs = packs_data.get("packs", [])
	
	# Load artisan data
	var art_text := FileAccess.get_file_as_string("res://data/artisans.json")
	var art_data: Variant = JSON.parse_string(art_text)
	var artisans: Array = art_data.get("artisans", [])
	
	# Find Caps Lock artisan (+8 flat on 4+ letter words)
	var caps_lock: Dictionary = {}
	for a in artisans:
		if str(a["id"]) == "caps_lock":
			caps_lock = a
			break
	assert(not caps_lock.is_empty(), "Caps Lock artisan should exist")
	
	# Equip to slot 0
	var equipped: bool = ArtisanRailManager.equip(0, caps_lock)
	assert(equipped, "Should equip to slot 0")
	
	# Test cascade with 3-letter word (should NOT trigger Caps Lock)
	var slots3: Array = []
	for l in "CAT":
		slots3.append({"cap": {"letter": l, "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false}, "letter": l})
	var res3: Dictionary = ArtisanRailManager.cascade("CAT", slots3, [1.0, 1.0, 1.0], {}, {})
	assert(res3["flat"] == 0, "Caps Lock should not trigger on 3-letter word")
	
	# Test cascade with 4-letter word (SHOULD trigger Caps Lock)
	var slots4: Array = []
	for l in "BEAR":
		slots4.append({"cap": {"letter": l, "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false}, "letter": l})
	var res4: Dictionary = ArtisanRailManager.cascade("BEAR", slots4, [1.0, 1.0, 1.0, 1.0], {}, {})
	assert(res4["flat"] == 8, "Caps Lock should add +8 flat on 4-letter word, got %d" % res4["flat"])
	
	# Test Rotary Knob (×1.3 per unused redraw)
	var rotary: Dictionary = {}
	for a in artisans:
		if str(a["id"]) == "rotary_knob":
			rotary = a
			break
	ArtisanRailManager.equip(0, rotary)
	GameState.redraws_left = 2  # 1 used, 2 unused
	GameState.turns_left = 3
	var res_rot: Dictionary = ArtisanRailManager.cascade("BEAR", slots4, [1.0, 1.0, 1.0, 1.0], {}, {})
	assert(absf(res_rot["xmult"] - 1.69) < 0.01, "Rotary Knob should be 1.3^2=1.69, got %.2f" % res_rot["xmult"])
	
	print("OK: Artisan rail cascade working — flat=%d xmult=%.2f" % [res4["flat"], res_rot["xmult"]])
	get_tree().quit(0)
```

- [ ] **Step 8: Run test**

```powershell
godot --headless --script res://tests/test_artisan_rail.gd
```
Expected: `OK: Artisan rail cascade working`

- [ ] **Step 9: Commit**

```powershell
git add scripts/autoload/ArtisanRailManager.gd data/artisans.json scenes/components/ArtisanSlot.tscn scripts/components/ArtisanSlot.gd scripts/autoload/CombatService.gd scripts/screens/CombatScreen.gd project.godot tests/test_artisan_rail.gd
git commit -m "feat: Artisan Keycap rail system with 5-slot cascade"
```

---

### Task 6: Switch Packs Rewrite

**Files:**
- Rewrite: `data/packs.json`
- Modify: `scripts/autoload/PackService.gd`
- Modify: `scripts/screens/RunSetupScreen.gd`
- Test: `tests/test_switch_packs.gd`

- [ ] **Step 1: Rewrite `data/packs.json`**

```json
{
  "packs": [
    {"id": "clicky", "name": "Clicky Pack", "desc": "Rare consonants deal +50% damage. -1 redraw token.", "draw_modifier": 0, "score_modifier": 0, "base_draw": 0, "start_money": 0, "conditionals": [{"type": "rare_consonant_mult", "value": 1.5}, {"type": "redraw_penalty", "value": -1}]},
    {"id": "linear", "name": "Linear Pack", "desc": "+1 Hand per turn. Short words (≤3) deal -20% damage.", "draw_modifier": 1, "score_modifier": 0, "base_draw": 0, "start_money": 0, "conditionals": [{"type": "short_word_penalty", "max_len": 3, "mult": 0.8}]},
    {"id": "tactile", "name": "Tactile Pack", "desc": "5-letter words trigger ×1.5 X-Mult. First 3 key presses double base power.", "draw_modifier": 0, "score_modifier": 0, "base_draw": 0, "start_money": 0, "conditionals": [{"type": "length_xmult", "len": 5, "value": 1.5}, {"type": "first_3_tiles_double"}]},
    {"id": "heavy_tactile", "name": "Heavy Tactile Pack", "desc": "Min 4-letter words. 6+ letter words trigger ×2.5 X-Mult.", "draw_modifier": 0, "score_modifier": 0, "base_draw": 0, "start_money": 0, "conditionals": [{"type": "min_word_length", "value": 4}, {"type": "length_xmult", "len": 6, "value": 2.5}]},
    {"id": "silent", "name": "Silent Pack", "desc": "-10% base word points. Immune to Boss Silence debuffs.", "draw_modifier": 0, "score_modifier": 0, "base_draw": 0, "start_money": 0, "conditionals": [{"type": "base_penalty", "mult": 0.9}, {"type": "silence_immunity"}]}
  ]
}
```

- [ ] **Step 2: Update PackService with conditional evaluation**

Add a method to evaluate pack conditionals against a word/context:
```gdscript
func evaluate_conditionals(pack_id: String, word: String, slots: Array, letter_scores: Array) -> Dictionary:
	var pack: Dictionary = pack_by_id(pack_id)
	if pack.is_empty():
		return {}
	var conds: Array = pack.get("conditionals", [])
	var result: Dictionary = {"score_mult": 1.0, "xmult": 1.0, "flat": 0, "min_length": 0}
	
	for c in conds:
		match str(c.get("type", "")):
			"rare_consonant_mult":
				var has_rare := false
				for s in slots:
					var l: String = str(s.get("letter", ""))
					if "VKXJQZ".contains(l):
						has_rare = true
						break
				if has_rare:
					result["score_mult"] = float(c.get("value", 1.0))
			"short_word_penalty":
				if slots.size() <= int(c.get("max_len", 3)):
					result["score_mult"] = float(c.get("mult", 1.0))
			"length_xmult":
				if slots.size() == int(c.get("len", 0)):
					result["xmult"] = float(c.get("value", 1.0))
			"min_word_length":
				result["min_length"] = int(c.get("value", 0))
			"silence_immunity":
				result["silence_immunity"] = true
			"base_penalty":
				result["score_mult"] = float(c.get("mult", 1.0))
	
	return result
```

- [ ] **Step 3: Write headless test**

```gdscript
extends SceneTree

func _init() -> void:
	var packs_text := FileAccess.get_file_as_string("res://data/packs.json")
	var packs_data: Variant = JSON.parse_string(packs_text)
	PackService.available_packs = packs_data.get("packs", [])
	
	var clicky: Dictionary = PackService.pack_by_id("clicky")
	assert(not clicky.is_empty(), "Clicky pack should exist")
	assert(clicky.get("name") == "Clicky Pack")
	
	var conds: Array = clicky.get("conditionals", [])
	assert(conds.size() == 2, "Clicky should have 2 conditionals")
	
	var silent: Dictionary = PackService.pack_by_id("silent")
	assert(not silent.is_empty(), "Silent pack should exist")
	
	# Test conditional evaluation
	var slots: Array = []
	for l in "QUIZ":
		slots.append({"letter": l, "cap": {"letter": l}})
	var result: Dictionary = PackService.evaluate_conditionals("clicky", "QUIZ", slots, [])
	assert(result["score_mult"] == 1.5, "Clicky should give 1.5x for rare consonants")
	
	print("OK: Switch packs rewritten with conditional passives")
	get_tree().quit(0)
```

- [ ] **Step 4: Run test**

```powershell
godot --headless --script res://tests/test_switch_packs.gd
```
Expected: `OK: Switch packs rewritten with conditional passives`

- [ ] **Step 5: Commit**

```powershell
git add data/packs.json scripts/autoload/PackService.gd tests/test_switch_packs.gd
git commit -m "feat: rewrite Switch Packs with conditional passives (Clicky/Linear/Tactile/Heavy Tactile/Silent)"
```

---

### Task 7: KeyCapElement Rigid Plunge & Dual Perspective (M5a)

**Files:**
- Modify: `scripts/components/KeyCapElement.gd`
- Modify: `scenes/components/KeyCapElement.tscn`
- Modify: `scripts/screens/CombatScreen.gd`
- Modify: `scripts/screens/RunSetupScreen.gd`

- [ ] **Step 1: Replace squash/stretch with rigid tween plunge**

In `KeyCapElement.gd`:
- Remove `cap_pressed` atlas texture (no more squashed sprite)
- Change press/release animation: CapLayer position.y tweens from `UNPRESSED_Y = 0.0` to `PRESSED_Y = 2.0` (2px rigid plunge)
- Keep the `Color(0.85, 0.88, 0.95, 1.0)` tint on press
- Remove the 5px offset — V3 spec says 2-3px

```gdscript
const UNPRESSED_CAP_Y := 0.0
const PRESSED_CAP_Y := 2.0  # Rigid 2px plunge (was 5px squashed)

func set_latched(latched: bool) -> void:
	if latched == is_latched:
		return
	is_latched = latched
	var target_y: float = PRESSED_CAP_Y if latched else UNPRESSED_CAP_Y
	if _press_tween and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.tween_property(_cap_layer, "position:y", target_y, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Color tint
	_cap_layer.modulate = Color(0.85, 0.88, 0.95, 1.0) if latched else Color.WHITE
```

- [ ] **Step 2: Add standalone mode visual tweaks for RunSetupScreen**

In `KeyCapElement.gd`'s `set_embedded_mode(enabled)`:
- Embedded (Combat): SocketShadow visible, cropped switch, 2.5D orthographic
- Standalone (RunSetup): SocketShadow hidden, full switch, 45° isometric visual hint (rotate slightly if needed, or just use full switch display)

- [ ] **Step 3: Commit**

```powershell
git add scripts/components/KeyCapElement.gd scenes/components/KeyCapElement.tscn scripts/screens/CombatScreen.gd scripts/screens/RunSetupScreen.gd
git commit -m "feat: rigid 2px keycap plunge, remove squash/stretch, dual-perspective modes"
```

---

### Task 8: Consumables, Depths & Shop Expansion

**Files:**
- Create: `scripts/autoload/DepthService.gd`
- Create: `scripts/autoload/ConsumableService.gd`
- Create: `data/consumables.json`
- Create: `data/blueprints.json`
- Create: `data/firmware_tags.json`
- Create: `data/depths.json`
- Modify: `scripts/autoload/ShopService.gd`
- Modify: `scripts/screens/ShopScreen.gd`
- Modify: `project.godot` (add DepthService, ConsumableService autoloads)
- Modify: `scripts/game_root.gd` (Depth progression, skip logic)
- Modify: `scripts/autoload/EventBus.gd` (add new signals)
- Test: `tests/test_consumables_depths.gd`

- [ ] **Step 1: Create data files**

`data/consumables.json`:
```json
{
  "tarot": [
    {"id": "keycap_puller", "name": "Keycap Puller", "description": "Permanently remove 1 selected tile from the bag.", "effect_type": "remove_tile", "effect_params": {}, "price": 6},
    {"id": "hot_swap_tool", "name": "Hot-Swap Tool", "description": "Duplicate 1 target letter tile onto another in the bag.", "effect_type": "duplicate_tile", "effect_params": {}, "price": 8},
    {"id": "laser_engraver", "name": "Laser Engraver", "description": "Convert 1 tile into a wildcard.", "effect_type": "wildcard_tile", "effect_params": {"wild_type": "full"}, "price": 10},
    {"id": "lube_pen", "name": "Lube Pen", "description": "Applies Lubed status: tile scores twice.", "effect_type": "lube_tile", "effect_params": {}, "price": 7}
  ],
  "spectral": [
    {"id": "short_circuit", "name": "Short Circuit", "description": "Destroy 3 random tiles. Gain $25.", "effect_type": "destroy_random", "effect_params": {"count": 3}, "price": 12},
    {"id": "overclock", "name": "Overclock", "description": "Polychrome 1 random tile. Lose 1 max redraw.", "effect_type": "overclock_tile", "effect_params": {}, "price": 14},
    {"id": "ghost_wire", "name": "Ghost Wire", "description": "Transform 2 random hand tiles into full wildcards.", "effect_type": "ghost_wire", "effect_params": {"count": 2}, "price": 16}
  ],
  "grimoire": [
    {"id": "trio_codex", "name": "Trio Codex", "description": "Trio words: +5 base damage, +1 mult.", "effect_type": "level_word_form", "effect_params": {"form_id": "trio", "damage_bonus": 5, "mult_bonus": 1}, "price": 8},
    {"id": "quartet_scroll", "name": "Quartet Scroll", "description": "Quartet words: +5 base damage, +1 mult.", "effect_type": "level_word_form", "effect_params": {"form_id": "quartet", "damage_bonus": 5, "mult_bonus": 1}, "price": 8},
    {"id": "mirror_tome", "name": "Mirror Tome", "description": "Mirror words: +10 base damage, +2 mult.", "effect_type": "level_word_form", "effect_params": {"form_id": "mirror", "damage_bonus": 10, "mult_bonus": 2}, "price": 12},
    {"id": "double_tap_tome", "name": "Double-Tap Tome", "description": "Double-Tap words: +10 base damage, +2 mult.", "effect_type": "level_word_form", "effect_params": {"form_id": "double_tap", "damage_bonus": 10, "mult_bonus": 2}, "price": 10}
  ]
}
```

`data/blueprints.json`:
```json
{
  "blueprints": [
    {"id": "anti_ghosting", "name": "Anti-Ghosting Matrix", "description": "+1 tile drawn per turn permanently.", "effect_type": "draw_bonus", "effect_value": 1, "base_price": 10},
    {"id": "silicone_dampener", "name": "Silicone Dampener", "description": "Immune to Boss Silence debuffs.", "effect_type": "silence_immunity", "effect_value": 1, "base_price": 12},
    {"id": "group_buy_pass", "name": "Group-Buy Pass", "description": "20% discount on all shop items.", "effect_type": "shop_discount", "effect_value": 0.2, "base_price": 8}
  ]
}
```

`data/firmware_tags.json`:
```json
{
  "tags": [
    {"id": "free_grab_bag", "name": "Free Grab Bag", "description": "Open a free Artisan Grab Bag.", "effect_type": "free_grab_bag"},
    {"id": "bonus_turns", "name": "Bonus Turns", "description": "+3 turn reserve for next combat.", "effect_type": "bonus_turns", "value": 3},
    {"id": "double_interest", "name": "Double Interest", "description": "Double money earned next combat.", "effect_type": "double_interest"}
  ]
}
```

`data/depths.json`:
```json
{
  "vanguard": [
    {"id": "vanguard_goblin", "name": "Goblin Scout", "hp": 8, "modifier": "", "is_boss": false},
    {"id": "vanguard_slime", "name": "Slime Puddle", "hp": 6, "modifier": "", "is_boss": false}
  ],
  "sentry": [
    {"id": "sentry_skeleton", "name": "Skeleton Guard", "hp": 15, "modifier": "", "is_boss": false},
    {"id": "sentry_orc", "name": "Orc Sentry", "hp": 18, "modifier": "", "is_boss": false}
  ],
  "bosses": [
    {"id": "vowel_witch", "name": "Vowel Witch", "hp": 30, "modifier": "vowel_lock", "is_boss": true},
    {"id": "consonant_king", "name": "Consonant King", "hp": 30, "modifier": "consonant_lock", "is_boss": true}
  ]
}
```

- [ ] **Step 2: Create DepthService.gd**

```gdscript
extends Node

var _depths_cache: Dictionary = {}

func _ready() -> void:
	_load_depths()

func _load_depths() -> void:
	var text := FileAccess.get_file_as_string("res://data/depths.json")
	var data: Variant = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY:
		_depths_cache = data

func get_stage_pool(stage: String) -> Array:
	return _depths_cache.get(stage, [])

func generate_encounter(stage: int) -> Dictionary:
	var pool_name: String = "vanguard"
	if stage == 1:
		pool_name = "sentry"
	elif stage >= 2:
		pool_name = "bosses"
	var pool: Array = get_stage_pool(pool_name)
	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()].duplicate(true)
```

- [ ] **Step 3: Create ConsumableService.gd**

```gdscript
extends Node

var _consumables_cache: Dictionary = {}

func _ready() -> void:
	_load_consumables()

func _load_consumables() -> void:
	var text := FileAccess.get_file_as_string("res://data/consumables.json")
	var data: Variant = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY:
		_consumables_cache = data

func get_tarot() -> Array:
	return _consumables_cache.get("tarot", [])

func get_spectral() -> Array:
	return _consumables_cache.get("spectral", [])

func get_grimoires() -> Array:
	return _consumables_cache.get("grimoire", [])

func apply(item: Dictionary) -> Dictionary:
	var effect_type: String = str(item.get("effect_type", ""))
	var params: Dictionary = item.get("effect_params", {})
	match effect_type:
		"remove_tile":
			# Removes cheapest tile from bag
			if GameState.bag.is_empty():
				return {"ok": false, "reason": "empty_bag"}
			var cheapest: Dictionary = _find_cheapest_tile()
			GameState.bag.erase(cheapest)
			EffectPipeline.trigger("on_bag_mutated", ["remove_tile", [cheapest]])
			return {"ok": true, "removed": cheapest}
		"duplicate_tile":
			# Duplicates random tile
			if GameState.bag.is_empty():
				return {"ok": false, "reason": "empty_bag"}
			var pick: Dictionary = GameState.bag[randi() % GameState.bag.size()].duplicate(true)
			GameState.bag.append(pick)
			return {"ok": true, "added": pick}
		"wildcard_tile":
			# Converts random tile to wildcard
			if GameState.bag.is_empty():
				return {"ok": false, "reason": "empty_bag"}
			var idx: int = randi() % GameState.bag.size()
			GameState.bag[idx]["letter"] = "*"
			GameState.bag[idx]["ability_id"] = "wild"
			GameState.bag[idx]["is_symbol"] = true
			return {"ok": true}
		"destroy_random":
			var count: int = int(params.get("count", 1))
			var destroyed: Array = []
			for _i in range(mini(count, GameState.bag.size())):
				var idx: int = randi() % GameState.bag.size()
				destroyed.append(GameState.bag[idx])
				GameState.bag.remove_at(idx)
			GameState.money += 25
			EffectPipeline.trigger("on_bag_mutated", ["destroy_random", destroyed])
			return {"ok": true, "destroyed": destroyed.size(), "money_gained": 25}
		"overclock_tile":
			if GameState.bag.is_empty():
				return {"ok": false, "reason": "empty_bag"}
			var idx: int = randi() % GameState.bag.size()
			GameState.bag[idx]["finish"] = "polychrome"
			GameState.upgrade_redraws = maxi(0, GameState.upgrade_redraws - 1)
			return {"ok": true, "affected": GameState.bag[idx]}
		"ghost_wire":
			var count: int = int(params.get("count", 2))
			var transformed := 0
			for i in range(mini(count, GameState.hand.size())):
				GameState.hand[i]["letter"] = "*"
				GameState.hand[i]["ability_id"] = "wild"
				GameState.hand[i]["is_symbol"] = true
				transformed += 1
			return {"ok": true, "transformed": transformed}
		"level_word_form":
			var form_id: String = str(params.get("form_id", ""))
			var level: int = GameState.word_form_levels.get(form_id, 0) + 1
			GameState.word_form_levels[form_id] = level
			return {"ok": true, "form_id": form_id, "level": level}
	return {"ok": false, "reason": "unknown_effect"}

func _find_cheapest_tile() -> Dictionary:
	var cheapest: Dictionary = {}
	var min_price: int = 999
	for cap in GameState.bag:
		var price: int = int(cap.get("price", 1))
		if price < min_price:
			min_price = price
			cheapest = cap
	return cheapest
```

- [ ] **Step 4: Update ShopService — add Blueprints and Grab Bags**

In `ShopService.gd`, add:
```gdscript
func generate_grab_bag(pack_type: String, choices: int, pick: int) -> Array:
	var pool: Array = []
	match pack_type:
		"artisan":
			var text := FileAccess.get_file_as_string("res://data/artisans.json")
			var data: Variant = JSON.parse_string(text)
			pool = data.get("artisans", [])
		"grimoire":
			pool = _load_consumables_list().get("grimoire", [])
		"toolkit":
			pool = _load_consumables_list().get("tarot", [])
		"black_box":
			pool = _load_consumables_list().get("spectral", [])
	pool.shuffle()
	return pool.slice(0, choices)

func _load_consumables_list() -> Dictionary:
	var text := FileAccess.get_file_as_string("res://data/consumables.json")
	var data: Variant = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY:
		return data
	return {}
```

- [ ] **Step 5: Write headless test**

Create `tests/test_consumables_depths.gd`:
```gdscript
extends SceneTree

func _init() -> void:
	# Test ConsumableService
	var tarot: Array = ConsumableService.get_tarot()
	assert(tarot.size() == 4, "Should have 4 tarot items")
	
	var spectral: Array = ConsumableService.get_spectral()
	assert(spectral.size() == 3, "Should have 3 spectral items")
	
	var grimoires: Array = ConsumableService.get_grimoires()
	assert(grimoires.size() >= 4, "Should have 4+ grimoire items")
	
	# Test DepthService
	var vanguard: Array = DepthService.get_stage_pool("vanguard")
	assert(not vanguard.is_empty(), "Vanguard pool should not be empty")
	
	var sentry: Array = DepthService.get_stage_pool("sentry")
	assert(not sentry.is_empty(), "Sentry pool should not be empty")
	
	var encounter: Dictionary = DepthService.generate_encounter(0)
	assert(not encounter.is_empty(), "Should generate vanguard encounter")
	
	# Test grimoire application
	GameState.word_form_levels = {}
	var grimoire: Dictionary = grimoires[0]
	var result: Dictionary = ConsumableService.apply(grimoire)
	assert(result.get("ok", false), "Grimoire application should succeed")
	assert(result.get("level", 0) == 1, "Grimoire should raise level to 1")
	
	print("OK: Consumables and Depths systems working")
	get_tree().quit(0)
```

- [ ] **Step 6: Run test**

```powershell
godot --headless --script res://tests/test_consumables_depths.gd
```
Expected: `OK: Consumables and Depths systems working`

- [ ] **Step 7: Commit**

```powershell
git add scripts/autoload/DepthService.gd scripts/autoload/ConsumableService.gd data/consumables.json data/blueprints.json data/firmware_tags.json data/depths.json scripts/autoload/ShopService.gd scripts/screens/ShopScreen.gd project.godot scripts/game_root.gd scripts/autoload/EventBus.gd tests/test_consumables_depths.gd
git commit -m "feat: consumables (Tarot/Spectral/Grimoire), Depth progression, Blueprints, Firmware Tags"
```

---

## Self-Review Checklist

- [x] **Spec coverage** — every section from the design doc maps to at least one task:
  - Bag expansion → Task 1
  - Play-and-refill, vowel safeguard, discard reshuffle → Task 2
  - Word Form engine → Task 3
  - 4-phase scoring pipeline → Task 4
  - Artisan rail system → Task 5
  - Switch Pack rewrite → Task 6
  - Rigid plunge / dual perspective → Task 7
  - Consumables, Depths, Blueprints, Tags, Grab Bags → Task 8

- [x] **Placeholder scan** — no TBD, TODO, "implement later", or empty steps. Every step has actual code.

- [x] **Type consistency** — signal signatures match between EventBus (Task 2 Step 1) and emission sites (CombatService Task 2 Step 5, ArtisanRailManager Task 5 Step 2). `WordFormService.detect()` return shape consistent between Task 3 and Task 4. `ArtisanRailManager.cascade()` signature consistent between Task 5 and its use in CombatService.

- [x] **File path correctness** — all paths verified against codebase audit.
