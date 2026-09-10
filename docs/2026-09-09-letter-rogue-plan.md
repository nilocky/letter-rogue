# Letter Rogue V1 → V2 (Spell Your Own Words) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the existing Letter Rogue V1 codebase (match-key-caps-to-monster-word) into V2, where each turn you spell your own dictionary word from a random hand drawn from your bag.

**Architecture:** Keep the autoload-service + EventBus + GameRoot state-machine pattern. Add one new autoload (`WordService`: dictionary + word-length multiplier). Rewrite the four core stateful autoloads (`GameState`, `EventBus`, `KeyCapService`, `CombatService`) and the two gameplay screens (`CombatScreen`, `ShopScreen`). Reuse `KeyCapElement` for tiles; delete `WordSlot`. All data remains JSON in `data/`, now including `data/words.json`.

**Tech Stack:** Godot 4.7.x, GDScript, JSON data files, Container-based responsive UI.

**Spec:** `docs/2026-09-09-letter-rogue-spec.md` — the plan argues from the spec, so the spec travels with it; executors read both.

## Global Constraints

Copied from the spec. Every task's requirements implicitly include this section:

- Godot 4.7.x, GDScript only. No external libraries/dependencies.
- All data in JSON files under `data/`. Word dictionary file: `data/words.json`.
- Autoload order (exact): `EventBus, GameState, PackService, KeyCapService, ShopService, WordService, CombatService`.
- **UI node references use `%UniqueName`** (`%Name`) in scripts; every referenced node sets `unique_name_in_owner = true` in its `.tscn` (AGENTS.md). No `$Path/To/Node` lookups for scene nodes.
- **No player HP anywhere.** No shield, no heal. Losing = turn budget exhausted while monster alive.
- Turn budget default **3** per round (`BASE_TURNS`); redraw tokens default **3** per round (`BASE_REDRAWS`); draw size default **5** (`BASE_DRAW`).
- Draw size = `pack_draw_base() + upgrade_draw + next_draw_bonus`; tiles drawn from bag WITHOUT removal, returned to bag at end of turn (no discard pile).
- Exactly ONE dictionary word per turn; confirm blocked unless length ≥ 3, `WordService.is_word(word)`, buildable from hand.
- Wildcards `*` (any letter, Epic), `~` (vowel A E I O U, Rare), `#` (consonant, Rare) are the ONLY symbol-faced tiles; 0 base power, count toward length, letter chosen by the player on click.
- Letter tiles are real A–Z and carry abilities `bonus_points`, `double_score`, `money_bonus`, `bonus_damage`.
- Letter power tiers: common ETAOINRS=1, uncommon HLD CUMFPGWYB=2, rare VKXJQZ=4.
- Word damage = `round(sum of tile contributions × length_multiplier)`; multiplier: 3→1.0, 4→1.3, 5→1.6, 6→2.0, 7+→2.5.
- Boss modifier semantics: `vowel_lock` (only vowels contribute), `consonant_lock` (only consonants contribute), `no_repeats` (same letter once per word — enforced at build), `silence` (abilities/finishes/stickers/conditions disabled).
- EventBus V2 signal set only (see Task 4). Old signals `player_hit`, `caps_played`, `score_calculated`, `combat_word_generated` removed.
- Web (HTML5) export is the shipping artifact; all data must load from `res://` inside the exported pck (no runtime file access).
- UI must be responsive: desktop landscape, mobile/WebView portrait, arbitrary aspect. `Emulate Touch From Mouse` stays on.
- No audio.

---

## Task 1: Data rework — monsters, key caps, packs, and word dictionary

**Files:**
- Modify: `data/monsters.json` (rewrite — drop `word_pool`, `attack_pattern`, `hp`→keep `hp`/`max_hp` base, add `is_boss`, `boss_modifier`)
- Modify: `data/key_caps.json` (rewrite — letter faces + abilities; wildcard symbols only for `is_symbol` tiles)
- Modify: `data/packs.json` (rewrite — draw/score modifiers per V2)
- Create: `data/words.json` (word dictionary)
- Create: `tools/build_words.py` (one-off generator for `words.json`)

**Interfaces:**
- Consumes: nothing.
- Produces: data shapes consumed by all later tasks. Every `KeyCap` has keys `letter`, `ability_id`, `rarity`, `ability_strength`, `is_symbol`, and optional `finish`/`sticker`/`condition`. Every `Monster` has `name`, `hp`, `max_hp`, `is_boss`, `boss_modifier`. `words.json` is `{"words": ["CAT", ...]}`.

- [ ] **Step 1: Rewrite `data/monsters.json`**

Read the current file first, then replace its entire contents with:

```json
{
  "normal": [
    {"id": "goblin", "name": "Goblin", "hp": 10, "max_hp": 10, "is_boss": false, "boss_modifier": null},
    {"id": "skeleton", "name": "Skeleton", "hp": 15, "max_hp": 15, "is_boss": false, "boss_modifier": null},
    {"id": "slime", "name": "Slime", "hp": 8, "max_hp": 8, "is_boss": false, "boss_modifier": null},
    {"id": "orc", "name": "Orc", "hp": 18, "max_hp": 18, "is_boss": false, "boss_modifier": null},
    {"id": "golem", "name": "Golem", "hp": 25, "max_hp": 25, "is_boss": false, "boss_modifier": null}
  ],
  "bosses": [
    {"id": "vowel_witch", "name": "Vowel Witch", "hp": 30, "max_hp": 30, "is_boss": true, "boss_modifier": "vowel_lock"},
    {"id": "consonant_king", "name": "Consonant King", "hp": 30, "max_hp": 30, "is_boss": true, "boss_modifier": "consonant_lock"},
    {"id": "echo_phantom", "name": "Echo Phantom", "hp": 30, "max_hp": 30, "is_boss": true, "boss_modifier": "no_repeats"},
    {"id": "silence_wraith", "name": "Silence Wraith", "hp": 30, "max_hp": 30, "is_boss": true, "boss_modifier": "silence"}
  ]
}
```

Expected: no `word_pool` or `attack_pattern` keys remain.

- [ ] **Step 2: Rewrite `data/key_caps.json`**

Replace with letter tiles plus three wildcard symbols. Abilities ride on letters. Starter bag is the same 8 common letters; every ability-bearing tile uses the full `KeyCap` shape (rare/legendary tiles carry `finish`/`sticker`/`condition` as examples so the modifier UI is exercised):

```json
{
  "starter_bag": [
    {"letter": "E", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
    {"letter": "T", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
    {"letter": "A", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
    {"letter": "O", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
    {"letter": "I", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
    {"letter": "N", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
    {"letter": "S", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
    {"letter": "R", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false}
  ],
  "shop_pool": [
    {"letter": "E", "ability_id": "double_score", "rarity": "Rare", "ability_strength": 2, "is_symbol": false},
    {"letter": "X", "ability_id": "bonus_points", "rarity": "Rare", "ability_strength": 3, "is_symbol": false},
    {"letter": "Z", "ability_id": "bonus_points", "rarity": "Rare", "ability_strength": 5, "is_symbol": false},
    {"letter": "Q", "ability_id": "bonus_points", "rarity": "Rare", "ability_strength": 4, "is_symbol": false},
    {"letter": "J", "ability_id": "bonus_damage", "rarity": "Rare", "ability_strength": 3, "is_symbol": false},
    {"letter": "B", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
    {"letter": "W", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
    {"letter": "V", "ability_id": "money_bonus", "rarity": "Rare", "ability_strength": 2, "is_symbol": false},
    {"letter": "K", "ability_id": "bonus_points", "rarity": "Rare", "ability_strength": 4, "is_symbol": false},
    {"letter": "C", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
    {"letter": "M", "ability_id": "double_score", "rarity": "Rare", "ability_strength": 2, "is_symbol": false},
    {"letter": "P", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
    {"letter": "F", "ability_id": "bonus_damage", "rarity": "Rare", "ability_strength": 2, "is_symbol": false},
    {"letter": "G", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
    {"letter": "Y", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
    {"letter": "L", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
    {"letter": "D", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
    {"letter": "U", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
    {"letter": "H", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false},
    {"letter": "*", "ability_id": "wild", "rarity": "Epic", "ability_strength": 0, "is_symbol": true},
    {"letter": "~", "ability_id": "vowel_wild", "rarity": "Rare", "ability_strength": 0, "is_symbol": true},
    {"letter": "#", "ability_id": "consonant_wild", "rarity": "Rare", "ability_strength": 0, "is_symbol": true},
    {"letter": "X", "ability_id": "bonus_points", "rarity": "Legendary", "ability_strength": 2, "is_symbol": false, "finish": "foil", "sticker": "gold", "condition": "glass"},
    {"letter": "S", "ability_id": "bonus_points", "rarity": "Legendary", "ability_strength": 1, "is_symbol": false, "finish": "polychrome", "sticker": "red"},
    {"letter": "R", "ability_id": "double_score", "rarity": "Legendary", "ability_strength": 2, "is_symbol": false, "sticker": "blue"}
  ]
}
```

Expected: letter tiles carry A–Z faces and ability ids from `{bonus_points, double_score, money_bonus, bonus_damage, wild, vowel_wild, consonant_wild}`; `is_symbol` is true only for `*`, `~`, `#`.

- [ ] **Step 3: Rewrite `data/packs.json`**

```json
{
  "packs": [
    {"id": "mx_red", "name": "MX Red", "desc": "+1 tile drawn per turn", "draw_modifier": 1, "score_modifier": 0, "base_draw": 0, "start_money": 0},
    {"id": "mx_blue", "name": "MX Blue", "desc": "+2 power per tile used in a word", "draw_modifier": 0, "score_modifier": 2, "base_draw": 0, "start_money": 0},
    {"id": "mx_brown", "name": "MX Brown", "desc": "+1 power per tile used; start with +$5", "draw_modifier": 0, "score_modifier": 1, "base_draw": 0, "start_money": 5},
    {"id": "mx_black", "name": "MX Black", "desc": "+3 power per tile used, -1 tile drawn per turn", "draw_modifier": -1, "score_modifier": 3, "base_draw": 0, "start_money": 0},
    {"id": "mx_speed", "name": "MX Speed", "desc": "Draw 6 tiles per turn", "draw_modifier": 0, "score_modifier": 0, "base_draw": 6, "start_money": 0}
  ]
}
```

- [ ] **Step 4: Generate `data/words.json`**

Create `tools/build_words.py`:

```python
import json, re, sys

def main(src: str, dst: str) -> None:
    pat = re.compile(r"^[A-Z]{3,}$")
    seen = set()
    with open(src, encoding="utf-8") as f:
        for line in f:
            w = line.strip().upper()
            if pat.match(w) and w not in seen:
                seen.add(w)
    words = sorted(seen)
    with open(dst, "w", encoding="utf-8") as f:
        json.dump({"words": words}, f, separators=(",", ":"))
    print(f"wrote {len(words)} words to {dst}")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
```

Run it against a public-domain newline-delimited word list (any OS wordlist works; dwyl/english-words `words_alpha.txt` is a good source):

Run: `python tools/build_words.py <path-to-wordlist> data/words.json`
Expected: stdout prints `wrote N words to data/words.json`, e.g. `wrote 370099 words`. Keep the raw wordlist OUT of the repo (`data/raw/` should be gitignored); `words.json` is committed.

- [ ] **Step 5: Verify JSON loads**

Run: `python -c "import json;[json.load(open(f,encoding='utf-8')) for f in ['data/words.json','data/key_caps.json','data/monsters.json','data/packs.json']]; print('ok')"`
Expected: prints `ok`. Also confirm `data/words.json` contains only words length ≥ 3.

- [ ] **Step 6: Commit**

```bash
git add data/monsters.json data/key_caps.json data/packs.json data/words.json tools/build_words.py
git commit -m "data: rework monsters/keycaps/packs for spell-your-words, add word dictionary"
```

---

## Task 2: WordService autoload (dictionary + length multiplier)

**Files:**
- Create: `scripts/autoload/WordService.gd`
- Modify: `project.godot` (register `WordService` autoload, exact order: `EventBus, GameState, PackService, KeyCapService, ShopService, WordService, CombatService` — `PackService` before `KeyCapService` because draw reads the pack, and `WordService` before `CombatService` because combat validates words)
- Test: none (manual check in Step 4 — pure service, exercised via CombatService/CombatScreen in later tasks)

**Interfaces:**
- Consumes: `res://data/words.json`.
- Produces:
  - `func is_word(word: String) -> bool`
  - `func length_multiplier(length: int) -> float`
  - `func word_count() -> int`

- [ ] **Step 1: Write `scripts/autoload/WordService.gd`**

```gdscript
extends Node
## Word dictionary + word-length scoring helper. Pure lookups; no state.

const WORDS_PATH := "res://data/words.json"

var _words: Dictionary = {}  # word:String -> true
var _count: int = 0


func _ready() -> void:
	_load_dictionary()


func _load_dictionary() -> void:
	var text := FileAccess.get_file_as_string(WORDS_PATH)
	if text.is_empty():
		push_error("WordService: missing %s" % WORDS_PATH)
		return
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or not data.has("words"):
		push_error("WordService: %s has no 'words' array" % WORDS_PATH)
		return
	for w: String in data["words"]:
		_words[w] = true
	_count = _words.size()


func is_word(word: String) -> bool:
	return _words.has(word)


func length_multiplier(length: int) -> float:
	match length:
		3:
			return 1.0
		4:
			return 1.3
		5:
			return 1.6
		6:
			return 2.0
		_:
			return 2.5


func word_count() -> int:
	return _count
```

- [ ] **Step 2: Register the autoload**

Open `project.godot`, find the `[autoload]` section. Add (in this relative order, placing it before `CombatService`):

```
WordService="*res://scripts/autoload/WordService.gd"
```

- [ ] **Step 3: Reload the project**

Run the project in the Godot editor (or `godot --headless --check-only` if available). Expected: project boots with no parse errors and the WordService autoload appears in the autoload list.

- [ ] **Step 4: Smoke-test the service**

Run the project, open the remote scene tree / console and evaluate `WordService.is_word("CAT")`, `WordService.is_word("ZZZ")`, `WordService.length_multiplier(6)`, `WordService.word_count()`. Expected: `true`, `false`, `2.0`, `> 1000`.

- [ ] **Step 5: Commit**

```bash
git add scripts/autoload/WordService.gd project.godot
git commit -m "feat: add WordService autoload with dictionary and length multiplier"
```

---

## Task 3: Rework GameState (no HP, turn/redraw budgets, upgrades)

**Files:**
- Modify: `scripts/autoload/GameState.gd` (replace contents)

**Interfaces:**
- Consumes: nothing (holds state only).
- Produces (used by every later task — keep names exact):
  - Constants: `BASE_TURNS := 3`, `BASE_REDRAWS := 3`, `BASE_DRAW := 5`
  - Fields: `money:int`, `round_number:int`, `bag:Array`, `hand:Array`, `current_monster:Dictionary`, `turns_left:int`, `redraws_left:int`, `upgrade_draw:int`, `upgrade_turns:int`, `upgrade_redraws:int`, `next_draw_bonus:int`, `active_pack_id:String`, `shop_inventory:Array`, `pack_start_money_granted:bool`
  - `func reset() -> void`
  - `func round_turn_budget() -> int`
  - `func round_redraw_budget() -> int`
  - `func draw_size() -> int`
  - `func monster_hp_scaled() -> int`
  - `func round_reward() -> int`

- [ ] **Step 1: Replace the contents of `GameState.gd`**

Remove `hp`, `max_hp`, `shield`, `extra_draw`, `discard`, `_shuffle_*` references and all V1 combat mutation helpers. Replace the file with:

```gdscript
extends Node
## Runtime state for the whole run. Data only; behaviour lives in services.

signal state_changed

const BASE_TURNS := 3
const BASE_REDRAWS := 3
const BASE_DRAW := 5

var money: int = 10
var round_number: int = 1
var bag: Array = []
var hand: Array = []
var current_monster: Dictionary = {}
var shop_inventory: Array = []
var active_pack_id: String = ""

var turns_left: int = 0
var redraws_left: int = 0

var upgrade_draw: int = 0
var upgrade_turns: int = 0
var upgrade_redraws: int = 0
var next_draw_bonus: int = 0
var pack_start_money_granted: bool = false


func reset() -> void:
	money = 10
	round_number = 1
	bag = []
	hand = []
	current_monster = {}
	shop_inventory = []
	active_pack_id = ""
	turns_left = 0
	redraws_left = 0
	upgrade_draw = 0
	upgrade_turns = 0
	upgrade_redraws = 0
	next_draw_bonus = 0
	pack_start_money_granted = false


func round_turn_budget() -> int:
	return BASE_TURNS + upgrade_turns


func round_redraw_budget() -> int:
	return BASE_REDRAWS + upgrade_redraws


func draw_size() -> int:
	var base := BASE_DRAW
	if active_pack_id != "":
		var pack := PackService.pack_by_id(active_pack_id)
		if not pack.is_empty():
			if int(pack.get("base_draw", 0)) > 0:
				base = int(pack["base_draw"])
			else:
				base = BASE_DRAW + int(pack.get("draw_modifier", 0))
	return maxi(base + upgrade_draw + next_draw_bonus, 3)


func monster_hp_scaled() -> int:
	var base := int(current_monster.get("hp", 10))
	return int(round(float(base) * (1.0 + float(round_number - 1) * 0.15)))


func round_reward() -> int:
	return 5 + round_number * 2
```

- [ ] **Step 2: Check nothing else references removed fields**

Run: `rg -n "max_hp|\.hp|shield|extra_draw|GameState\.discard" scripts/`
Expected: matches only inside `GameState.gd` (none) or files you have not yet reworked — CombatService/CombatScreen/KeyCapService still reference some; that is expected mid-rework and resolved by Tasks 5–8. No NEW references may be introduced.

- [ ] **Step 3: Commit**

```bash
git add scripts/autoload/GameState.gd
git commit -m "state: rework GameState to turn-budget model, drop hp/shield/discard"
```

---

## Task 4: Rework EventBus signals (V2 set)

**Files:**
- Modify: `scripts/autoload/EventBus.gd` (replace contents)

**Interfaces:**
- Consumes: nothing.
- Produces the signal set (exact signatures used across Tasks 5–8):

```gdscript
signal run_started
signal pack_selected(pack_id: String)
signal fight_pressed

signal hand_drawn(hand: Array)
signal turn_started(turns_left: int, redraws_left: int)
signal turns_changed(turns_left: int)
signal redraws_changed(redraws_left: int)
signal word_committed(word: String, damage: int, tiles_used: int)
signal monster_damaged(remaining_hp: int, max_hp: int)
signal round_won(money_earned: int)
signal round_lost
signal game_over(reached_round: int)

signal shop_inventory_generated(inventory: Array)
signal cap_purchased(cap: Dictionary)
signal cap_sold(cap: Dictionary)
signal shop_rerolled
signal upgrade_purchased(upgrade_id: String, level: int)
```

- [ ] **Step 1: Replace `EventBus.gd` contents**

Delete the removed signals (`player_hit`, `caps_played`, `score_calculated`, `combat_word_generated`) and add the new ones above. The file contains only `extends Node` plus `signal` declarations (all emit sites moved to services in Tasks 5–7).

- [ ] **Step 2: Commit**

```bash
git add scripts/autoload/EventBus.gd
git commit -m "events: update signal set for spell-your-words flow"
```

---

## Task 5: Rework KeyCapService (turn draw, targeted redraw, trimmed abilities)

**Files:**
- Modify: `scripts/autoload/KeyCapService.gd` (replace contents)

**Interfaces:**
- Consumes: `GameState` fields from Task 3, `PackService.pack_by_id`, `EventBus` from Task 4.
- Produces:
  - `func draw_hand() -> void`
  - `func redraw_tiles(indices: Array) -> bool`
  - `func resolve_ability(cap: Dictionary) -> Dictionary`
  - `func hand_size() -> int`
- Deletes V1 API: `play_caps`, `_shuffle_discard_into_bag`, `_break_check`, all heal/shield/extra-draw logic.

- [ ] **Step 1: Replace `KeyCapService.gd` contents**

```gdscript
extends Node
## Draws a random hand from the bag each turn; targeted redraw swaps.
## Also resolves a tile's ability into scoring effects.

func draw_hand() -> void:
	GameState.hand.clear()
	# Consume the blue-sticker bonus AFTER computing the draw size.
	var target: int = mini(GameState.draw_size(), GameState.bag.size())
	GameState.next_draw_bonus = 0
	if target == 0:
		EventBus.hand_drawn.emit(GameState.hand)
		return
	var pool := range(GameState.bag.size())
	pool.shuffle()
	for i in range(target):
		GameState.hand.append(GameState.bag[pool[i]])
	EventBus.hand_drawn.emit(GameState.hand)


func hand_size() -> int:
	return GameState.hand.size()


## Replace the tiles at `indices` with new random tiles from the bag.
## Costs 1 redraw token per swapped tile. Returns false (no change) on
## invalid indices or insufficient tokens.
func redraw_tiles(indices: Array) -> bool:
	if indices.is_empty():
		return false
	var idx := indices.duplicate()
	for i in idx:
		if typeof(i) != TYPE_INT or i < 0 or i >= GameState.hand.size():
			return false
	if idx.size() > GameState.redraws_left:
		return false
	idx.sort()
	idx.reverse()
	var returned: Array = []
	for i in idx:
		returned.append(GameState.hand[i])
		GameState.hand.remove_at(i)
	# Remove the returned tiles from the bag so they cannot be drawn straight
	# back, then redraw replacements, then return them to the bag.
	for cap in returned:
		GameState.bag.erase(cap)
	var need: int = returned.size()
	var avail: int = GameState.bag.size()
	var pool := range(avail)
	pool.shuffle()
	var drawn: int = 0
	for k in range(mini(need, avail)):
		GameState.hand.append(GameState.bag[pool[k]])
		drawn += 1
	GameState.bag.append_array(returned)
	if drawn < need:
		for cap in returned:
			if drawn >= need:
				break
			GameState.hand.append(cap)
			drawn += 1
	GameState.redraws_left -= idx.size()
	EventBus.redraws_changed.emit(GameState.redraws_left)
	EventBus.hand_drawn.emit(GameState.hand)
	return true


## Returns scoring effects contributed by a tile, keyed by effect name.
## Only additive/multiplicative score effects live here; money/glass/lucky
## side effects are applied during combat commit (see CombatService).
func resolve_ability(cap: Dictionary) -> Dictionary:
	var ability: String = str(cap.get("ability_id", ""))
	match ability:
		"bonus_points":
			return {"score": int(cap.get("ability_strength", 0))}
		"double_score":
			return {"score_multiplier": 2.0}
		"money_bonus":
			return {"money": int(cap.get("ability_strength", 1))}
		"bonus_damage":
			return {"bonus": int(cap.get("ability_strength", 1))}
		_:
			return {}
```

- [ ] **Step 2: Grep for removed API usages**

Run: `rg -n "play_caps|_shuffle_discard_into_bag|resolve_ability|draw_hand" scripts/`
Expected: hits in `KeyCapService.gd`, `CombatService.gd`, `CombatScreen.gd`, `ShopScreen.gd`, `game_root.gd` — these are reworked in Tasks 6–8. No hits outside those.

- [ ] **Step 3: Commit**

```bash
git add scripts/autoload/KeyCapService.gd
git commit -m "service: rework KeyCapService for bag-draw turns and targeted redraw"
```

---

## Task 6: Rework CombatService (round/turn loop, word damage, win/lose)

**Files:**
- Modify: `scripts/autoload/CombatService.gd` (replace contents)

**Interfaces:**
- Consumes: `GameState`, `KeyCapService.draw_hand`/`resolve_ability`, `WordService.is_word`/`length_multiplier`, `PackService.pack_by_id`, `EventBus`.
- Produces:
  - `func start_round() -> void`
  - `func validate_word(slots: Array) -> Dictionary` (slots: Array of `{"cap": Dictionary, "letter": String}` in word order)
  - `func calculate_word(slots: Array, log: bool = false) -> Dictionary` — returns `{"damage": int, "money": int, "letter_scores": Array[float]}`, pure (no GameState mutation). `letter_scores` holds each slot's per-letter contribution (used by CombatScreen's score animation); `log=true` prints a `[score]` breakdown to the console.
  - `func commit_word(slots: Array) -> void` — damage + side effects + end-of-turn bookkeeping
  - `func skip_turn() -> void`
  - `func _apply_monster_damage(damage: int, money: int) -> void` (private)
  - `func end_turn() -> void` (private usage; called by commit/skip)
- Deletes V1 API: `start_combat`, `calculate_score`, `apply_monster_damage`, `monster_attack`, `_boss_matched_letters`, word-pool generation.

Scoring rules encoded (from spec): letter tier ETAOINRS=1 / HLD CUMFPGWYB=2 / VKXJQZ=4; wildcards 0 base power; boss `vowel_lock`/`consonant_lock` zero non-matching contributions; `silence` disables abilities/finishes/stickers/conditions; damage = `round(total × WordService.length_multiplier(slots.size()))` then + flat `bonus_damage`.

- [ ] **Step 1: Replace `CombatService.gd` contents**

```gdscript
extends Node
## Round and turn loop. Round = N turns (budget); each turn spells one word.

const COMMON_LETTERS := "ETAOINRS"
const UNCOMMON_LETTERS := "HLDCUMFPGWYB"
const VOWELS := "AEIOU"

const REWARD_BASE := 5


func start_round() -> void:
	GameState.turns_left = GameState.round_turn_budget()
	GameState.redraws_left = GameState.round_redraw_budget()
	GameState.next_draw_bonus = 0
	GameState.current_monster["hp_remaining"] = GameState.monster_hp_scaled()
	EventBus.turn_started.emit(GameState.turns_left, GameState.redraws_left)
	KeyCapService.draw_hand()


## Validate a word built from `slots` (each {"cap": Dictionary, "letter": String}).
func validate_word(slots: Array) -> Dictionary:
	if slots.size() < 3:
		return {"ok": false, "reason": "too_short"}
	var word := ""
	var letters: Array = []
	for s in slots:
		word += str(s["letter"])
		letters.append(str(s["letter"]))
	if not WordService.is_word(word):
		return {"ok": false, "reason": "not_word"}
	var modifier: String = str(GameState.current_monster.get("boss_modifier", ""))
	if modifier == "no_repeats":
		var seen: Dictionary = {}
		for letter in letters:
			if seen.has(letter):
				return {"ok": false, "reason": "repeat_letter"}
			seen[letter] = true
	return {"ok": true, "word": word}


## Deterministic damage/money for a word. Does NOT mutate GameState.
func calculate_word(slots: Array, log: bool = false) -> Dictionary:
	var disabled: bool = str(GameState.current_monster.get("boss_modifier", "")) == "silence"
	var pack := PackService.pack_by_id(GameState.active_pack_id)
	var per_tile: int = int(pack.get("score_modifier", 0)) if not pack.is_empty() else 0
	var modifier: String = str(GameState.current_monster.get("boss_modifier", ""))

	var total := 0.0
	var flat := 0
	var money := 0
	var letter_scores: Array = []
	for s in slots:
		var cap: Dictionary = s["cap"]
		var letter: String = str(s["letter"])
		var is_vowel: bool = VOWELS.contains(letter)
		var contribution := 0.0
		if not bool(cap.get("is_symbol", false)):
			contribution = float(_letter_base_score(str(cap["letter"])))
		if not disabled:
			contribution += float(per_tile)
			var ability := KeyCapService.resolve_ability(cap)
			contribution += float(ability.get("score", 0))
			contribution *= float(ability.get("score_multiplier", 1.0))
			money += int(ability.get("money", 0))
			flat += int(ability.get("bonus", 0))
			match str(cap.get("finish", "")):
				"foil":
					contribution += 3.0
				"holographic":
					contribution += 1.0
				"polychrome":
					contribution *= 1.5
			if str(cap.get("sticker", "")) == "red":
				contribution *= 2.0
			elif str(cap.get("sticker", "")) == "gold":
				money += 2
			if str(cap.get("condition", "")) == "glass":
				contribution *= 2.0
		if modifier == "vowel_lock" and not is_vowel:
			contribution = 0.0
		elif modifier == "consonant_lock" and is_vowel:
			contribution = 0.0
		total += contribution
		letter_scores.append(contribution)
	var mult: float = WordService.length_multiplier(slots.size())
	var damage: int = int(round(total * mult)) + flat
	if log:
		var word := ""
		for s in slots:
			word += str(s["letter"])
		print("[score] word=\"%s\" (mult x%.1f, %d letters)" % [word, mult, slots.size()])
		for i in range(slots.size()):
			print("[score]   %s: %.1f power" % [str(slots[i]["letter"]), float(letter_scores[i])])
		print("[score]   total=%.1f x mult -> %d dmg (+%d bonus) +$%d" % [total, damage, flat, money])
	return {"damage": damage, "money": money, "letter_scores": letter_scores}


## Commit a word: deal damage, collect money, roll lucky/glass/blue side
## effects, then advance the turn. Emits win/lose/game_over as needed.
func commit_word(slots: Array) -> void:
	var res := calculate_word(slots)
	var word := ""
	for s in slots:
		word += str(s["letter"])
	EventBus.word_committed.emit(word, res["damage"], slots.size())

	var lucky_extra_damage := 0
	var money_gain: int = res["money"]
	for s in slots:
		var cap: Dictionary = s["cap"]
		var disabled: bool = str(GameState.current_monster.get("boss_modifier", "")) == "silence"
		if disabled:
			continue
		if str(cap.get("sticker", "")) == "blue":
			GameState.next_draw_bonus += 1
		if str(cap.get("condition", "")) == "glass":
			if randf() < 0.25:
				GameState.bag.erase(cap)
		elif str(cap.get("condition", "")) == "lucky":
			if randf() < 0.2:
				lucky_extra_damage += 10
			if randf() < 0.0667:
				money_gain += 10

	_apply_monster_damage(int(res["damage"]) + lucky_extra_damage, money_gain)


func skip_turn() -> void:
	EventBus.word_committed.emit("", 0, 0)
	_end_turn()


func _letter_base_score(letter: String) -> int:
	if COMMON_LETTERS.contains(letter):
		return 1
	if UNCOMMON_LETTERS.contains(letter):
		return 2
	return 4  # V K X J Q Z


func _apply_monster_damage(damage: int, money_gain: int) -> void:
	var remaining: int = int(GameState.current_monster.get("hp_remaining", GameState.monster_hp_scaled()))
	remaining -= damage
	GameState.current_monster["hp_remaining"] = remaining
	if money_gain > 0:
		GameState.money += money_gain
	if remaining <= 0:
		var reward: int = GameState.round_reward()
		GameState.money += reward
		GameState.turns_left = 0
		EventBus.monster_damaged.emit(0, GameState.monster_hp_scaled())
		EventBus.round_won.emit(reward)
	else:
		EventBus.monster_damaged.emit(remaining, GameState.monster_hp_scaled())
		_end_turn()


func _monster_hp_remaining() -> int:
	return int(GameState.current_monster.get("hp_remaining", GameState.monster_hp_scaled()))


func _end_turn() -> void:
	GameState.turns_left -= 1
	EventBus.turns_changed.emit(GameState.turns_left)
	if GameState.turns_left <= 0:
		# Emit only game_over; round_lost is not emitted (GameRoot handles
		# game_over, emitting both caused a double game-over transition).
		EventBus.game_over.emit(GameState.round_number)
	else:
		EventBus.turn_started.emit(GameState.turns_left, GameState.redraws_left)
		KeyCapService.draw_hand()
```

- [ ] **Step 2: Seed `hp_remaining` on round start**

This is already handled inside `start_round()` above (`GameState.current_monster["hp_remaining"] = GameState.monster_hp_scaled()`). GameRoot sets `GameState.current_monster` *before* calling `start_round` (see Task 7). No extra edit needed — skip to Step 3.

- [ ] **Step 3: Commit**

```bash
git add scripts/autoload/CombatService.gd
git commit -m "service: rework CombatService to turn-budget word combat"
```

---

## Task 7: Rework game_root flow (round cadence, upgrades after win, start money)

**Files:**
- Modify: `scripts/game_root.gd`

**Interfaces:**
- Consumes: `EventBus` V2 signals, `CombatService.start_round`, `GameState.reset`, `GameState.round_number`, `GameState.money`, `PackService.pack_by_id`, `ShopService.new_shop`.
- Produces: the top-level state transitions — on `round_won` → increment round + always show shop, on `fight_pressed` → combat (boss every 3rd round), on `game_over(reached_round)` → game over, on `run_started` → reset + grant pack money + first fight.

- [ ] **Step 1: Read `scripts/game_root.gd`**

Identify the state machine (`MENU, PACK_SELECT, COMBAT, SHOP, GAME_OVER`) and where it connects `round_won`/`fight_pressed`.

- [ ] **Step 2: Replace `scripts/game_root.gd` with the V2 flow**

Replace the whole file with the state machine below. Key flow rules: shop opens after **every** won round (bosses included); the next fight's boss-vs-normal choice is made on `fight_pressed` from `round_number % 3 == 0`; `run_started` carries no args (the menu sets `active_pack_id` via `PackService.select_pack`), so preserve the pack id across `GameState.reset()`.

```gdscript
extends Node
## Top-level state machine: menu -> combat <-> shop -> game over.

enum State { MENU, PACK_SELECT, COMBAT, SHOP, GAME_OVER }

var current_state: State = State.MENU
var current_screen: Node = null

const MENU_SCENE := preload("res://scenes/MainMenuScreen.tscn")
const COMBAT_SCENE := preload("res://scenes/CombatScreen.tscn")
const SHOP_SCENE := preload("res://scenes/ShopScreen.tscn")
const GAME_OVER_SCENE := preload("res://scenes/GameOverScreen.tscn")

var _monsters_cache: Dictionary = {}


func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	EventBus.fight_pressed.connect(_on_fight_pressed)
	EventBus.round_won.connect(_on_round_won)
	EventBus.game_over.connect(_on_game_over)
	_switch_to_menu()


func _switch_to_menu() -> void:
	GameState.reset()
	current_state = State.MENU
	_show(MENU_SCENE)


func _on_run_started() -> void:
	var pack_id: String = GameState.active_pack_id
	GameState.reset()
	GameState.active_pack_id = pack_id
	var pack: Dictionary = PackService.pack_by_id(pack_id)
	if not pack.is_empty() and not GameState.pack_start_money_granted:
		GameState.money += int(pack.get("start_money", 0))
		GameState.pack_start_money_granted = true
	GameState.bag = _load_starter_bag()
	_fight_or_boss()


func _on_fight_pressed() -> void:
	_fight_or_boss()


func _fight_or_boss() -> void:
	var boss_round: bool = GameState.round_number % 3 == 0
	var list: Array = _monster_list_for("bosses" if boss_round else "normal")
	if list.is_empty():
		return
	var entry: Dictionary = list[randi() % list.size()].duplicate(true)
	entry["hp_remaining"] = _scaled_hp(entry, GameState.round_number)
	GameState.current_monster = entry
	current_state = State.COMBAT
	_show(COMBAT_SCENE)
	CombatService.start_round()


func _on_round_won(_money_earned: int) -> void:
	GameState.round_number += 1
	ShopService.new_shop()
	current_state = State.SHOP
	_show(SHOP_SCENE)


func _on_game_over(reached_round: int) -> void:
	current_state = State.GAME_OVER
	_show(GAME_OVER_SCENE)
	if current_screen.has_method("show_game_over"):
		current_screen.show_game_over(reached_round)


func _show(scene: PackedScene) -> void:
	if current_screen:
		current_screen.queue_free()
	current_screen = scene.instantiate()
	add_child(current_screen)


func _load_starter_bag() -> Array:
	var text := FileAccess.get_file_as_string("res://data/key_caps.json")
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return []
	return (data.get("starter_bag", []) as Array).duplicate(true)


func _monster_list_for(pool: String) -> Array:
	if _monsters_cache.is_empty():
		var text := FileAccess.get_file_as_string("res://data/monsters.json")
		var data: Variant = JSON.parse_string(text)
		if typeof(data) == TYPE_DICTIONARY:
			_monsters_cache = data
	return _monsters_cache.get(pool, [])


func _scaled_hp(entry: Dictionary, round_number: int) -> int:
	return int(round(float(entry.get("hp", 10)) * (1.0 + float(round_number - 1) * 0.15)))
```

Note: the old file's `print()` debug lines and the `round_lost` connection are removed by this replacement. `run_started` stays a no-arg signal (Task 4).

> **Implemented addition — F1 debug shortcut:** the final `game_root.gd` also adds `_unhandled_input`, where pressing **F1 in a debug build** (`OS.is_debug_build()`) resets state, forces pack `mx_red`, grants $50, loads the starter bag, generates a shop, and jumps straight to the SHOP screen. Debug-only; no effect in release builds.

- [ ] **Step 3: Grep for stale signal connections**

Run: `rg -n "player_hit|combat_word_generated|score_calculated|caps_played|start_combat|calculate_score|monster_attack" scripts/`
Expected: only remaining hits are in `CombatScreen.gd` / `ShopScreen.gd` / `KeyCapService` leftovers scheduled for deletion in Task 8; otherwise fix now.

- [ ] **Step 4: Commit**

```bash
git add scripts/game_root.gd
git commit -m "flow: rewire game_root to turn-budget rounds and shop upgrades"
```

---

## Task 8: Rebuild CombatScreen (word builder UI) and delete WordSlot

**Files:**
- Modify: `scripts/screens/CombatScreen.gd` (replace contents)
- Modify: `scenes/CombatScreen.tscn` (restructure node tree)
- Delete: `scripts/components/WordSlot.gd`, `scripts/components/WordSlot.gd.uid`, `scenes/components/WordSlot.tscn`
- Modify: `scenes/components/WordSlot.tscn.uid` (delete) and the `.uid` companion for deleted scripts

**Interfaces:**
- Consumes: `CombatService.start_round/validate_word/calculate_word/commit_word/skip_turn`, `KeyCapService.draw_hand/redraw_tiles`, `EventBus` V2, `GameState`.
- Produces: the interactive combat screen.

UI model (word builder, no monster-word slots):
- Top bar: monster name + HP (`monster_hp` label), turn pips (`turns_label` "Turns left: N"), redraw count (`redraws_label` "Redraws: N"), money label.
- Center: `word_strip` (HBox of `Label` letters of the word being built), `hint_label` (validity/damage preview "CAT · 6 dmg" or reason), and controls: Backspace button, Redraw button, Skip Turn button, Confirm button.
- Bottom: `hand_container` (HBox, wrap) of `KeyCapElement` buttons (square, `custom_minimum_size = 64×64`). Used tiles show a 1-based position badge (`set_used`/`set_word_index`); clicking a used tile **deselects it** (returns it to the usable pool via `_remove_slot_by_hand_index`). Redraw mode: toggling Redraw makes hand tiles clickable to mark for swap; a "confirm swap" applies `redraw_tiles`.
- Word strip: tiles are `44×44` `KeyCapElement`s. **Drag-and-drop reorders** the word (`drag_index` + `drag_drop` → `_on_word_drop(from, to)`); clicking a wildcard slot re-opens its picker; clicking a non-wildcard slot removes it.
- Confirm: on valid word, `_play_score_animation` runs a **sequential per-tile letter-hop** (0.22s interval, per-tile power floats up and fades via `_spawn_score_label`), gated by an `_animating` flag that disables controls (`_set_controls_enabled`); then `commit_word` deals damage. Tiles carry a `hand_idx` so the same physical tile can't be reused twice.
- Wildcard flow: clicking a wildcard tile (in the hand or already in the word strip) opens a **`WildcardPopup` (PopupPanel)** with a `PickerGrid` (GridContainer) of letter buttons + a `PickerCancelButton`. Letter set is chosen by the tile's `ability_id` (`vowel_wild` → A E I O U, `consonant_wild` → consonants, else A–Z). Picking assigns that slot's effective letter; Cancel closes without assigning. *(Implemented as a popup rather than the inline `letter_picker` HBox originally scaffolded.)*

The screen rebuilds the whole word strip + hand on each `hand_drawn`/`turns_changed`/`redraws_changed` event. Word construction happens in local arrays (each entry `{"cap": Dictionary, "letter": String}`), with hand tiles added front-to-back by index.

- [ ] **Step 1: Delete WordSlot**

```bash
git rm scripts/components/WordSlot.gd scenes/components/WordSlot.tscn
git rm scripts/components/WordSlot.gd.uid scenes/components/WordSlot.tscn.uid
```

- [ ] **Step 2: Read the current `CombatScreen.gd` and `.tscn`**

Note existing node paths for the top bar/container hierarchy so the rebuild reuses names where cheap (the `.tscn` will be restructured by hand in Step 4).

- [ ] **Step 3: Replace `CombatScreen.gd`**

Replace with a script that: on `_ready()` subscribes to the V2 signals; renders monster (name + `hp_remaining`/scaled max), counters, hand, and word strip; exposes buttons. Full scaffold (adjust node paths to your `.tscn`):

```gdscript
extends Control
## Word-builder combat screen: spell one dictionary word per turn.

@onready var monster_label: Label = %MonsterLabel
@onready var hp_label: Label = %HpLabel
@onready var turns_label: Label = %TurnsLabel
@onready var redraws_label: Label = %RedrawsLabel
@onready var money_label: Label = %MoneyLabel
@onready var word_strip: HBoxContainer = %WordStrip
@onready var hint_label: Label = %HintLabel
@onready var hand_container: HBoxContainer = %HandContainer
@onready var confirm_button: Button = %ConfirmButton
@onready var backspace_button: Button = %BackspaceButton
@onready var redraw_button: Button = %RedrawButton
@onready var skip_button: Button = %SkipButton
@onready var wildcard_popup: PopupPanel = %WildcardPopup
@onready var picker_grid: GridContainer = %PickerGrid
@onready var picker_cancel_button: Button = %PickerCancelButton
@onready var hand_empty_warning: Label = %HandEmptyWarning

var _slots: Array = []  # {"cap": Dictionary, "letter": String} in word order
var _pending_redraw: Array = []  # hand indices to swap
var _redraw_mode: bool = false
var _wildcard_pending: Dictionary = {}  # {"cap":..., "index": int} awaiting letter

const KeyCapElementScene := preload("res://scenes/components/KeyCapElement.tscn")


func _ready() -> void:
	EventBus.hand_drawn.connect(_on_hand_drawn)
	EventBus.turns_changed.connect(_on_turns_changed)
	EventBus.redraws_changed.connect(_on_redraws_changed)
	EventBus.monster_damaged.connect(_on_monster_damaged)
	EventBus.round_won.connect(_on_round_won)
	# No round_lost subscription: CombatService emits only game_over (Task 6).
	confirm_button.pressed.connect(_on_confirm_pressed)
	backspace_button.pressed.connect(_on_backspace_pressed)
	redraw_button.pressed.connect(_on_redraw_toggle)
	skip_button.pressed.connect(_on_skip_pressed)
	picker_cancel_button.pressed.connect(_on_picker_cancel)


func show_round() -> void:
	_refresh_header()
	_refresh_hand()


func _refresh_header() -> void:
	var monster: Dictionary = GameState.current_monster
	if monster.is_empty():
		return
	monster_label.text = str(monster.get("name", "?"))
	var total: int = GameState.monster_hp_scaled()
	var remaining: int = int(monster.get("hp_remaining", total))
	hp_label.text = "HP %d/%d" % [maxi(remaining, 0), total]
	turns_label.text = "Turns: %d" % GameState.turns_left
	redraws_label.text = "Redraws: %d" % GameState.redraws_left
	money_label.text = "$%d" % GameState.money


func _on_hand_drawn(hand: Array) -> void:
	_refresh_header()
	_refresh_hand()
	_clear_word()


func _on_turns_changed(turns: int) -> void:
	_refresh_header()


func _on_redraws_changed(redraws: int) -> void:
	_refresh_header()


func _on_monster_damaged(remaining: int, max_hp: int) -> void:
	hp_label.text = "HP %d/%d" % [maxi(remaining, 0), max_hp]


func _on_round_won(_money_earned: int) -> void:
	set_process_input(false)
	_clear_word()
	_refresh_header()





func _refresh_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	hand_container.queue_redraw()
	for i in range(GameState.hand.size()):
		var el: Control = KeyCapElementScene.instantiate()
		hand_container.add_child(el)
		el.setup(GameState.hand[i])
		el.clicked.connect(_on_hand_clicked.bind(i))
	hand_empty_warning.visible = GameState.hand.is_empty()


func _on_hand_clicked(idx: int) -> void:
	if GameState.turns_left <= 0:
		return
	if _redraw_mode:
		if idx in _pending_redraw:
			_pending_redraw.erase(idx)
		else:
			_pending_redraw.append(idx)
		_redraw_button_ui()
		return
	var cap: Dictionary = GameState.hand[idx]
	if bool(cap.get("is_symbol", false)):
		_wildcard_pending = {"cap": cap, "index": idx, "hand_idx": idx}
		_show_letter_picker(cap)
		return
	if _slot_uses_hand_index(idx):
		return
	# Pass the hand index so the same physical tile can't be reused.
	_add_slot(cap, str(cap["letter"]), idx)


func _slot_uses_hand_index(idx: int) -> bool:
	for s in _slots:
		if int(s.get("hand_idx", -1)) == idx:
			return true
	return false


func _add_slot(cap: Dictionary, letter: String, hand_idx: int = -1) -> void:
	var boss_modifier: String = str(GameState.current_monster.get("boss_modifier", ""))
	if boss_modifier == "no_repeats":
		for s in _slots:
			if str(s["letter"]) == letter:
				hint_label.text = "Can't repeat letters"
				return
	_slots.append({"cap": cap, "letter": letter, "hand_idx": hand_idx})
	_refresh_word()


func _on_backspace_pressed() -> void:
	if _slots.is_empty():
		return
	_slots.pop_back()
	_refresh_word()


func _on_skip_pressed() -> void:
	if GameState.turns_left > 0:
		CombatService.skip_turn()


func _on_redraw_toggle() -> void:
	_redraw_mode = not _redraw_mode
	if not _redraw_mode:
		_pending_redraw.clear()
	_redraw_button_ui()


func _redraw_button_ui() -> void:
	redraw_button.text = "Redraw (%d marked)" % _pending_redraw.size() if _redraw_mode else "Redraw mode"
	confirm_button.disabled = _redraw_mode


func _refresh_word() -> void:
	for child in word_strip.get_children():
		child.queue_free()
	var word := ""
	for s in _slots:
		word += str(s["letter"])
		var lbl := Label.new()
		lbl.text = str(s["letter"])
		word_strip.add_child(lbl)
	var valid: Dictionary = CombatService.validate_word(_slots) if _slots.size() >= 3 else {"ok": false}
	if valid.get("ok", false):
		var res: Dictionary = CombatService.calculate_word(_slots)
		hint_label.text = "%s · %d dmg" % [str(valid["word"]), int(res["damage"])]
		confirm_button.disabled = false
	else:
		hint_label.text = _reason_text(valid.get("reason", "keep building"))
		confirm_button.disabled = true


func _reason_text(reason: String) -> String:
	match reason:
		"not_word":
			return "Not a word"
		"repeat_letter":
			return "Can't repeat letters here"
		_:
			return "Keep building (min 3 letters)"


func _on_confirm_pressed() -> void:
	if confirm_button.disabled:
		return
	if GameState.turns_left <= 0:
		return
	var valid: Dictionary = CombatService.validate_word(_slots)
	if not valid.get("ok", false):
		return
	CombatService.commit_word(_slots)


func _clear_word() -> void:
	_slots.clear()
	_pending_redraw.clear()
	_redraw_mode = false
	redraw_button.text = "Redraw mode"
	_refresh_word()


func _build_letter_picker() -> void:
	var letters: Array = _letters_for_wild("")
	for c in letters:
		var b := Button.new()
		b.text = str(c)
		b.custom_minimum_size = Vector2(36, 36)
		b.pressed.connect(_on_wild_letter.bind(str(c)))
		letter_picker.add_child(b)


func _letters_for_wild(_cap: Dictionary) -> Array:
	# populated on demand per wildcard type
	var ab: String = str(_wildcard_pending.get("cap", {}).get("ability_id", ""))
	if ab == "vowel_wild":
		return ["A", "E", "I", "O", "U"].duplicate()
	if ab == "consonant_wild":
		var cons: Array = []
		for c in "BCDFGHJKLMNPQRSTVWXYZ":
			cons.append(c)
		return cons
	var allc: Array = []
	for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
		allc.append(c)
	return allc


# NOTE: `_build_letter_picker` and `_show_letter_picker` below are the ORIGINAL
# inline-HBox wildcard helpers. In the final implementation these are superseded
# by the `WildcardPopup` flow (`_open_picker`/`_build_picker_grid`/`_on_wild_letter`
# /`_on_picker_cancel`) — see the UI-model note in this task. `_letters_for_wild`
# is retained unchanged (signature `cap: Dictionary`).


func _show_letter_picker(cap: Dictionary) -> void:
	for child in letter_picker.get_children():
		child.queue_free()
	var letters: Array = _letters_for_wild(cap)
	for c in letters:
		var b := Button.new()
		b.text = str(c)
		b.custom_minimum_size = Vector2(36, 36)
		var hidx: int = int(_wildcard_pending.get("hand_idx", -1))
		b.pressed.connect(func() -> void:
			_add_slot(_wildcard_pending["cap"], str(c), hidx)
			letter_picker.visible = false)
		letter_picker.add_child(b)
	letter_picker.visible = true
```

- [ ] **Step 4: Restructure `scenes/CombatScreen.tscn`**

The `.tscn` must expose these unique-named nodes (use `unique_name_in_owner = true` so `%Name` lookups resolve): `MonsterLabel`, `HpLabel`, `TurnsLabel`, `RedrawsLabel`, `MoneyLabel`, `WordStrip` (HBox), `HintLabel`, `HandContainer` (HBox, with `size_flags_horizontal = 3` to expand), `ConfirmButton`, `BackspaceButton`, `RedrawButton`, `SkipButton`, `WildcardPopup` (PopupPanel), `PickerGrid` (GridContainer), `PickerCancelButton` (Button), `HandEmptyWarning` (Label). Remove all `WordSlot` instances. Keep a Container-only, anchor/responsive hierarchy:

```
CombatScreen (Control, full rect)
├─ MarginContainer (full rect)
│  └─ VBoxContainer
│     ├─ HBoxContainer            # top bar
│     │  ├─ VBoxContainer (monster)
│     │  │  ├─ MonsterLabel
│     │  │  └─ HpLabel
│     │  ├─ TurnsLabel
│     │  ├─ RedrawsLabel
│     │  └─ MoneyLabel
│     ├─ Label (monster modifier / name subtitle, optional)
│     ├─ WordStrip (HBoxContainer)
│     ├─ HintLabel
│     ├─ HBoxContainer            # word controls
│     │  ├─ ConfirmButton
│     │  ├─ BackspaceButton
│     │  ├─ RedrawButton
│     │  └─ SkipButton
│     ├─ HandEmptyWarning (Label)
│     └─ HandContainer (HBoxContainer)
└─ WildcardPopup (PopupPanel, not visible by default)   # overlaid, outside VBox
   └─ Margin (MarginContainer)
      └─ VBox (VBoxContainer)
         ├─ Scroll (ScrollContainer)
         │  └─ PickerGrid (GridContainer, columns)   # letter buttons, filled at runtime
         └─ PickerCancelButton (Button)
```

`WildcardPopup` is opened via `popup_centered(Vector2i(280, 240))` and letter buttons are built on demand from the wildcard tile's `ability_id`. Set `ConfirmButton.disabled = true` by default in the scene.

- [ ] **Step 5: Convert `KeyCapElement.gd` to `%UniqueName`**

`scripts/components/KeyCapElement.gd` currently resolves its children with `$Label`, `$AbilityLabel`, `$RarityBg`, `$FinishLabel`, `$StickerLabel`, `$ConditionLabel` (AGENTS.md violation). Rewrite those `@onready` lines to `%Label`, `%AbilityLabel`, `%RarityBg`, `%FinishLabel`, `%StickerLabel`, `%ConditionLabel`, and in `scenes/components/KeyCapElement.tscn` set `unique_name_in_owner = true` on each of those child nodes.

The final element also gains (used by CombatScreen):
- A seventh `%IndexLabel` node and `func set_word_index(i: int)` — shows the tile's 1-based word position, hidden when `i <= 0`.
- `func set_used(used: bool)` — dims the tile (`modulate`) when it's already in the word.
- `func override_letter(letter: String)` — repaints the face for a wildcard's chosen letter.
- A `signal drag_drop(from: int, to: int)` plus a `drag_index: int` field and `_get_drag_data`/`_can_drop_data`/`_drop_data` overrides enabling **word-strip reordering** (drag is disabled when `drag_index < 0`).

Keep `signal clicked` — `_refresh_hand`/`_refresh_word` bind it per tile.

- [ ] **Step 6: Manual play-test**

Run the game. Enter combat. Expected: hand of 5 tiles appears; clicking tiles builds a word in the strip with a damage preview and used tiles dim + show their position badge; clicking a used tile deselects it; dragging word-strip tiles reorders the word; a valid dictionary word enables Confirm; confirming plays the per-tile score animation then deals damage, returns tiles, decrements turns, redraws the next hand; after the monster dies `round_won` fires; exhausting turns ends the run. Also verify the wildcard popup picker (with Cancel), redraw swap, and skip each behave.

- [ ] **Step 7: Commit**

```bash
git add -A scripts/screens/CombatScreen.gd scenes/CombatScreen.tscn scripts/components/KeyCapElement.gd scenes/components/KeyCapElement.tscn
git add -A scripts/components/WordSlot.gd scenes/components/WordSlot.tscn 2>/dev/null
git rm --cached scripts/components/WordSlot.gd scenes/components/WordSlot.tscn
git rm --cached scripts/components/WordSlot.gd.uid scenes/components/WordSlot.tscn.uid 2>/dev/null
git commit -m "combat: rebuild CombatScreen as word builder, delete WordSlot"
```

---

## Task 9: Rework ShopService + ShopScreen (tile shop + upgrades)

**Files:**
- Modify: `scripts/autoload/ShopService.gd`
- Modify: `scripts/screens/ShopScreen.gd`
- Modify: `scenes/ShopScreen.tscn`

**Interfaces:**
- Consumes: `GameState`, `EventBus` V2, `data/key_caps.json` shop pool.
- Produces:
  - `func new_shop() -> void` (generates inventory + refreshes upgrade prices; emits `shop_inventory_generated`)
  - `func buy_cap(cap: Dictionary) -> bool`
  - `func sell_cap(cap: Dictionary) -> bool`
  - `func sell_value(cap: Dictionary) -> int` — the refund value (max(round(price × SELL_RATIO), 1)); also drives the bag's sell-value badge
  - `func reroll() -> bool`
  - `func upgrade_defs() -> Array` — static upgrade metadata
  - `func upgrade_cost(id: String) -> int`
  - `func purchase_upgrade(id: String) -> bool`
- Upgrade metadata (from spec): `bigger_bag` (draw, base $6), `extra_turn` (turns, base $8), `extra_redraw` (redraws, base $5); price = base × 2^owned.

UI model (ShopScreen):
- Each inventory offer tile and each bag tile is a `KeyCapElement` with a **price badge** overlay (`_make_tile` adds a `$N` Label, `MOUSE_FILTER_IGNORE`, anchored bottom-wide). Inventory tiles show their buy `price`; bag tiles show their `sell_value`.
- Clicking an offer tile opens the **`BuyDialog` (ConfirmationDialog)** whose OK button is disabled when you can't afford it (`_describe_cap` shows letter/rarity/ability/finish/sticker/condition + price).
- Clicking a bag tile opens the **`SellDialog` (ConfirmationDialog)**; for Eternal tiles the OK button is disabled and the text reads "Eternal — cannot be sold". Confirmed buy/sell then calls `buy_cap`/`sell_cap`.

`%UniqueName` compliance: `ShopScreen.gd` must resolve `%InventoryGrid`, `%BagGrid`, `%MoneyLabel`, `%RerollButton`, `%FightButton`, `%UpgradeBox`, plus the two dialogs `%BuyDialog` and `%SellDialog`, with `unique_name_in_owner = true` on those nodes in `ShopScreen.tscn`. Also note `ShopService.buy_cap`/`sell_cap` take a `cap: Dictionary` (not an index) — the screen's click handlers store the pending cap in `_pending_purchase`/`_pending_sale`.

- [ ] **Step 1: Read `ShopService.gd` and `ShopScreen.gd`**

Note current buy/sell/reroll helpers and the screen's inventory/bag grids.

- [ ] **Step 2: Rewrite `ShopService.gd`**

```gdscript
extends Node
## Shop: tile inventory buy/sell/reroll plus persistent run upgrades.

const SHOP_SIZE := 5
const REROLL_COST := 3
const SELL_RATIO := 0.5

const UPGRADES := [
	{"id": "bigger_bag", "name": "Bigger Bag", "desc": "+1 tile drawn per turn", "field": "upgrade_draw", "base": 6},
	{"id": "extra_turn", "name": "Extra Turn", "desc": "+1 turn per round", "field": "upgrade_turns", "base": 8},
	{"id": "extra_redraw", "name": "Extra Redraw", "desc": "+1 redraw token per round", "field": "upgrade_redraws", "base": 5}
]

var _pool: Array = []


func _ready() -> void:
	_load_pool()


func _load_pool() -> void:
	var text := FileAccess.get_file_as_string("res://data/key_caps.json")
	var data: Variant = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY:
		_pool = data.get("shop_pool", [])


func new_shop() -> void:
	GameState.shop_inventory.clear()
	for i in range(SHOP_SIZE):
		GameState.shop_inventory.append(_weighted_pick())
	EventBus.shop_inventory_generated.emit(GameState.shop_inventory)


func _weighted_pick() -> Dictionary:
	var rarity_roll := randf()
	var rarity := "Normal"
	if rarity_roll < 0.05:
		rarity = "Legendary"
	elif rarity_roll < 0.20:
		rarity = "Epic"
	elif rarity_roll < 0.55:
		rarity = "Rare"
	var candidates: Array = _pool.filter(func(c: Dictionary) -> bool:
		return str(c.get("rarity", "")) == rarity)
	if candidates.is_empty():
		candidates = _pool
	var cap: Dictionary = candidates[randi() % candidates.size()].duplicate(true)
	cap["price"] = _price_for(cap)
	return cap


func _price_for(cap: Dictionary) -> int:
	var base := 3
	match str(cap.get("rarity", "Normal")):
		"Rare":
			base = 6
		"Epic":
			base = 10
		"Legendary":
			base = 15
	var total: int = base
	total += int(cap.get("ability_strength", 0))
	match str(cap.get("finish", "")):
		"foil":
			total += 2
		"holographic":
			total += 3
		"polychrome":
			total += 5
	if cap.has("sticker"):
		total += 2
	if cap.has("condition"):
		total += 2
	return total


func buy_cap(cap: Dictionary) -> bool:
	var price: int = int(cap.get("price", 0))
	if GameState.money < price:
		return false
	GameState.money -= price
	GameState.bag.append(cap)
	GameState.shop_inventory.erase(cap)
	EventBus.cap_purchased.emit(cap)
	return true


func sell_cap(cap: Dictionary) -> bool:
	if str(cap.get("condition", "")) == "eternal":
		return false
	var value: int = maxi(int(round(int(cap.get("price", 0)) * SELL_RATIO)), 1)
	GameState.bag.erase(cap)
	GameState.money += value
	EventBus.cap_sold.emit(cap)
	return true


func reroll() -> bool:
	if GameState.money < REROLL_COST:
		return false
	GameState.money -= REROLL_COST
	new_shop()
	EventBus.shop_rerolled.emit()
	return true


func upgrade_defs() -> Array:
	return UPGRADES


func owned_level(id: String) -> int:
	match id:
		"bigger_bag":
			return GameState.upgrade_draw
		"extra_turn":
			return GameState.upgrade_turns
		"extra_redraw":
			return GameState.upgrade_redraws
	return 0


func upgrade_cost(id: String) -> int:
	for u in UPGRADES:
		if u["id"] == id:
			return int(u["base"]) * int(pow(2, owned_level(id)))
	return 999999


func purchase_upgrade(id: String) -> bool:
	var cost: int = upgrade_cost(id)
	if GameState.money < cost:
		return false
	var level: int = owned_level(id)
	GameState.money -= cost
	match id:
		"bigger_bag":
			GameState.upgrade_draw += 1
		"extra_turn":
			GameState.upgrade_turns += 1
		"extra_redraw":
			GameState.upgrade_redraws += 1
	EventBus.upgrade_purchased.emit(id, level + 1)
	return true
```

- [ ] **Step 3: Rework `ShopScreen.gd`**

Keep the existing buy/sell/reroll grid wiring, then add an upgrade column. Remove any HP/pack/condition labels that no longer apply. Concrete additions:

```gdscript
@onready var upgrade_box: VBoxContainer = %UpgradeBox

func _ready() -> void:
	# ...existing buy/sell/reroll subscriptions...
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	_build_upgrade_buttons()

func _build_upgrade_buttons() -> void:
	for child in upgrade_box.get_children():
		child.queue_free()
	for u in ShopService.upgrade_defs():
		var row := HBoxContainer.new()
		var info := VBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = "%s (owned %d)" % [str(u["name"]), ShopService.owned_level(u["id"])]
		var desc_lbl := Label.new()
		desc_lbl.text = str(u["desc"])
		info.add_child(name_lbl)
		info.add_child(desc_lbl)
		var buy_btn := Button.new()
		buy_btn.text = "$%d" % ShopService.upgrade_cost(u["id"])
		var uid: String = str(u["id"])
		buy_btn.pressed.connect(func() -> void:
			if ShopService.purchase_upgrade(uid):
				_refresh_upgrade_row(uid)
				_refresh_money()
			else:
				print("cannot afford upgrade")
		)
		row.add_child(info)
		row.add_child(buy_btn)
		upgrade_box.add_child(row)

func _on_upgrade_purchased(id: String, _level: int) -> void:
	_build_upgrade_buttons()

func _refresh_money() -> void:
	money_label.text = "$%d" % GameState.money
```

Add the unique-named nodes `UpgradeBox` (VBoxContainer), `MoneyLabel` to `ShopScreen.tscn` and place the upgrade section under a scroll container so portrait fits.

`%UniqueName` compliance: convert the existing `$Content/InventoryGrid`, `$Content/BagGrid`, `$TopBar/MoneyLabel`, `$TopBar/RerollButton`, and `$FightButton` to `%`-lookups with `unique_name_in_owner = true` (full final node set in the UI-model note at the top of this task).

- [ ] **Step 4: Manual play-test**

Win a round, enter shop. Expected: 5 buyable tiles + reroll + sell-bag all work; the upgrade column shows three rows with escalating prices; buying Bigger Bag raises next round's hand size by 1; Extra Turn raises the per-round turn budget; Extra Redraw raises redraw tokens.

- [ ] **Step 5: Commit**

```bash
git add scripts/autoload/ShopService.gd scripts/screens/ShopScreen.gd scenes/ShopScreen.tscn
git commit -m "shop: add persistent run upgrades (draw/turn/redraw) and rework to V2 economy"
```

---

## Task 10: Rework GameOver + MainMenu (V2 copy, no HP)

**Files:**
- Modify: `scripts/screens/GameOverScreen.gd`
- Modify: `scripts/screens/MainMenuScreen.gd` (copy tweaks)
- Modify: `scenes/GameOverScreen.tscn`, `scenes/MainMenuScreen.tscn`

**Interfaces:**
- Consumes: `EventBus.game_over(reached_round)`, `GameState`.
- Produces: game-over copy showing round reached + money; main-menu copy unchanged in structure.

- [ ] **Step 1: Update `GameOverScreen.gd`**

The scene shows a title ("Run Over" / "You Died"), a body label, and a retry button back to the menu. Remove HP references. Expose exactly `show_game_over(reached_round: int)` (Task 7's `game_root.gd` calls it on the instantiated screen):

```gdscript
func show_game_over(reached_round: int) -> void:
	body_label.text = "Reached round %d with $%d" % [reached_round, GameState.money]
```

`%UniqueName` compliance: `GameOverScreen.gd`'s `$VBoxContainer/FinalScoreLabel` → `%BodyLabel` and `$VBoxContainer/RestartButton` → `%RestartButton`; set `unique_name_in_owner = true` on the `BodyLabel` and `RestartButton` nodes in `GameOverScreen.tscn`.

- [ ] **Step 2: Tweak MainMenu copy + convert to `%UniqueName`**

Verify the New Run + pack select flow still routes through `run_started`/`pack_selected`. Update any tooltips/copy that reference matching letters to HP-free word-spelling copy. Convert `MainMenuScreen.gd`'s `$VBoxContainer/ScrollContainer/PackList` → `%PackList` and `$VBoxContainer/StartButton` → `%StartButton`, with `unique_name_in_owner = true` on those two nodes in `MainMenuScreen.tscn`.

- [ ] **Step 3: Manual test**

Lose a round. Expected: Game Over appears with the round reached; Retry returns to the menu; a fresh run resets money/round/upgrades and grants the selected pack's start money.

- [ ] **Step 4: Commit**

```bash
git add scripts/screens/GameOverScreen.gd scenes/GameOverScreen.tscn scripts/screens/MainMenuScreen.gd scenes/MainMenuScreen.tscn
git commit -m "screens: game over shows round reached; menu copy to V2"
```

---

## Task 11: Web delivery — HTML5 export, Docker static host, WebView check

**Files:**
- Modify: `project.godot` (Web export preset, `Emulate Touch From Mouse`)
- Create: `deploy/web/Dockerfile`
- Create: `deploy/web/nginx.conf` (or a plain static server if simpler)
- Create: `.dockerignore` (exclude `data/raw`, build caches)
- Modify: `.gitignore` (add `.godot/`, export `build/` output dir)
- Create: `docs/web-delivery.md` (build + host + embed notes)

**Interfaces:**
- Consumes: the finished game from Tasks 1–10.
- Produces: a reproducible HTML5 build + Docker image serving it.

- [ ] **Step 1: Add the Web export preset**

In the editor: Project → Export → Add → Web. Set: `Runnable` true; renderer/threads at Web-safe defaults; **Export Path** `build/web/index.html`. Leave `Embedded Pck` unchecked. Confirm in `project.godot` under `[preset.1]` that the preset id maps to "Web". Also enable Project Settings → Input Devices → Pointing → `Emulate Touch From Mouse` (and confirm it stays enabled in exported settings). Ensure `window/stretch/mode="canvas_items"`, `window/stretch/aspect="expand"`, and `window/stretch/scale_mode` at the Web-safe default are set — the current working `project.godot` dropped `stretch/aspect="expand"` and `emulate_touch_from_mouse`; restore both. Remove the `MCPRuntimeProbe` autoload from `project.godot` and add `addons/godot_mcp/*` to the Web export's exclude filter so the dev-only MCP plugin never ships.

- [ ] **Step 2: Export the web build**

Run: `godot --headless --export-release "Web" build/web/index.html`
Expected: `build/web/index.html`, `.pck`, `.wasm`, `.js` are produced. The `.pck` embeds `data/words.json` — verify by grepping the pck is large enough / contains the dictionary (the pck is a Godot container; simplest check is runtime: the game loads and validates words from the hosted build).

- [ ] **Step 3: Write the Docker static host**

`deploy/web/Dockerfile`:

```dockerfile
FROM nginx:alpine
COPY deploy/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY build/web /usr/share/nginx/html
```

`deploy/web/nginx.conf`:

```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;
    gzip on;
    gzip_types text/css application/javascript application/wasm application/json;
    location / {
        try_files $uri $uri/ =404;
    }
    location ~* \.(wasm|pck|js)$ {
        add_header Cache-Control "public, max-age=31536000, immutable";
    }
}
```

- [ ] **Step 4: Build and run the container**

Run from the **repo root** (the Dockerfile does `COPY build/web` and `COPY deploy/web/nginx.conf`, so the build context must be the repository root, not `deploy/web`): `docker build -f deploy/web/Dockerfile -t letter-rogue-web .` then `docker run --rm -p 8080:80 letter-rogue-web`
Expected: opening `http://localhost:8080/` serves the game in a browser tab.

- [ ] **Step 5: WebView smoke test**

Load `http://localhost:8080/` inside a WebView (Android `WebView`, iOS `WKWebView`, or any embedded webview browser) at both landscape and portrait sizes. Expected: game boots, dictionary validation works (spell a real word successfully, a fake word is rejected), hand/tiles render, and the layout reflows for the viewport with no console errors (Godot Web logs go to browser devtools).

- [ ] **Step 6: Write `docs/web-delivery.md`**

Document: how to re-export, how to rebuild/serve the Docker image, the WebView-policy risk note for the iOS App Store (store review restrictions on embedded webviews), and the port/CORS notes.

- [ ] **Step 7: Commit**

```bash
git add project.godot deploy/web .dockerignore .gitignore docs/web-delivery.md
git add build/web 2>/dev/null
git commit -m "web: add HTML5 export preset, Docker static host, delivery docs"
```

---

## Task 12: Full-run manual verification

**Files:** none (verification only).

- [ ] **Step 1: Fresh run with MX Red**

New run → combat. Confirm: hand of 6, spells words, monster dies within 3 turns against the first low-HP monster; money grows; after the round the shop opens.

- [ ] **Step 2: Wildcards + upgrades**

Buy a wildcard when offered; verify the wildcard popup picker appears (with a working Cancel) and the chosen letter participates in the word. Buy Bigger Bag twice and Extra Turn; confirm hand size +1 per bag level and 5 turns next round.

- [ ] **Step 3: Boss cadence + each modifier**

Reach round 3 (boss). Verify each of the four boss modifiers applies its constraint (vowel_lock / consonant_lock zero non-matching power; no_repeats blocks duplicate letters; silence disables modifiers). Confirm boss HP uses the scaled value and round reward is `5 + round*2`.

- [ ] **Step 4: Lose path**

Deliberately skip all turns in a round. Confirm Game Over shows "Reached round N"; retry restarts cleanly with `upgrades`/money reset.

- [ ] **Step 5: Web export final check**

Re-export and load in the Docker container + a WebView at landscape and portrait. Confirm dictionary words validate in the hosted build.

- [ ] **Step 6: Code-compliance checks**

Run `rg '\$[A-Za-z_]' scripts/` — Expected: no `$NodePath` scene-node references remain (only `"$"` money-string literals in text assignments are OK). Run `rg 'unique_name_in_owner' scenes/` — Expected: a match on every node a script references via `%Name`. Run `rg 'MCPRuntimeProbe' project.godot` — Expected: no match (dev-only MCP plugin excluded from the Web export, whose exclude filter lists `addons/godot_mcp/*`).
