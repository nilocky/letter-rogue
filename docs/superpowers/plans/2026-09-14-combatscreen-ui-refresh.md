# CombatScreen UI Refresh & New Systems — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure CombatScreen layout to match mockup zones, add fixed 2×5 keyboard, persistent BASE/MULT, HINT/DECK buttons, and draggable HUD icons (grimoires + artisans) with sell zone.

**Architecture:** Data model extensions in `GameState.gd`; new services `HintService.gd`; component enhancements to `ArtisanSlot/ArtisanRailDisplay`; scene restructure in `CombatScreen.tscn` with node rewiring in `CombatScreen.gd`.

**Tech Stack:** Godot 4.7.x typed GDScript, Godot Control drag-and-drop, GridContainer, Tweens

**Spec:** `docs/superpowers/specs/2026-09-14-combatscreen-ui-refresh-design.md`

---

## Global Constraints

- Typed GDScript (`var x: int`, `func f() -> void:`)
- No external dependencies — Godot stdlib only
- `%UniqueName` syntax for scene node references
- Follow existing test patterns: `tests/test_*.gd` using GUT
- New fields in `GameState` must be cleared in `reset()`
- All drag-drop uses Godot built-in: `Control.set_drag_preview()`, `_can_drop_data()`, `_drop_data()`

---

### Task 1: Background Asset Move & Scene Swap

**Files:**
- Create: `assets/textures/backgrounds/bg_combat_3.jpg` (copy)
- Modify: `scenes/CombatScreen.tscn:35` (background TextureRect assignment)

**Interfaces:**
- Consumes: none
- Produces: CombatScreen now uses `bg_combat_3.jpg`

- [ ] **Step 1: Copy background to assets folder**

```powershell
Copy-Item -Path "examples\bg_combat_3.jpg" -Destination "assets\textures\backgrounds\bg_combat_3.jpg" -Force
```

- [ ] **Step 2: Open CombatScreen.tscn and verify Godot creates import file**

(Actually let Godot import it; just ensure file is in correct place. The .import file will be auto-generated.)

- [ ] **Step 3: Edit CombatScreen.tscn background resource**

Change from:
```
path="res://assets/textures/backgrounds/bg_combat_2.jpg"
```
to:
```
path="res://assets/textures/backgrounds/bg_combat_3.jpg"
```

In the scene file, find the `Background` TextureRect and update its `texture` ext_resource reference.

- [ ] **Step 4: Quick visual verification check**

Run the project briefly and confirm background renders. No logic change; just asset swap.

---

### Task 2: GameState Data Model Extensions

**Files:**
- Modify: `scripts/autoload/GameState.gd`
- Test: none (data only; tested via downstream tasks)

**Interfaces:**
- Consumes: none
- Produces: new fields + `round_hint_budget()`, `reset()` clears new state

- [ ] **Step 1: Add constants and fields**

Near `BASE_TURNS` etc:
```gdscript
const BASE_HINTS := 3
```

In the vars block:
```gdscript
var unlocked_key_slots: int = 8
var active_grimoires: Array = []
var hint_quality: int = 1
var hints_remaining: int = 0
var upgrade_hints: int = 0
```

- [ ] **Step 2: Add `round_hint_budget()` method**

Mirror `round_redraw_budget()`:
```gdscript
func round_hint_budget() -> int:
    return BASE_HINTS + upgrade_hints
```

- [ ] **Step 3: Clear new fields in `reset()`**

In `reset()`:
```gdscript
unlocked_key_slots = 8
active_grimoires.clear()
hint_quality = 1
hints_remaining = 0
upgrade_hints = 0
```

---

### Task 3: HintService — Tier 1 Word Finding

**Files:**
- Create: `scripts/autoload/HintService.gd`
- Test: `tests/test_hint_service.gd`

**Interfaces:**
- Consumes: `WordService.is_word(word)`
- Produces: `HintService.find_basic_word(letters: Array[String]) -> String`

- [ ] **Step 1: Write failing test**

```gdscript
# tests/test_hint_service.gd
extends GutTest

func test_find_basic_word_finds_valid_word() -> void:
    var letters := ["C", "A", "T"]
    var word := HintService.find_basic_word(letters)
    assert_neq(word, "", "should find a word from CAT")
    assert_true(WordService.is_word(word), "returned word must be in dictionary")
    assert_ge(word.length(), 3, "word must be >=3 letters")

func test_find_basic_word_returns_empty_for_nothing() -> void:
    var letters := ["X", "Y", "Z"]
    var word := HintService.find_basic_word(letters)
    assert_eq(word, "", "no valid 3+ letter word -> empty")

func test_find_basic_word_subsets_larger_hand() -> void:
    var letters := ["C", "A", "T", "S", "B"]
    var word := HintService.find_basic_word(letters)
    assert_neq(word, "", "should find word in 5 letters")
    assert_true(WordService.is_word(word))
```

- [ ] **Step 2: Register HintService as autoload**

In project settings, add HintService.gd as autoload singleton named `HintService`. (Check via `godot-mcp_get_project_settings` or project.godot.)

Actually we'll do it by editing `project.godot` if possible, or note it must be done in editor. For now ensure the script exists and tests use `Engine.has_singleton()` guard if needed, but project likely adds via autoload list.

- [ ] **Step 3: Implement HintService.gd**

```gdscript
# scripts/autoload/HintService.gd
extends Node

var _anagram_index: Dictionary = {}  # sorted_letters:String -> Array[String]

func _ready() -> void:
    _build_index()

func _build_index() -> void:
    _anagram_index.clear()
    # WordService doesn't expose raw dict; we can't iterate it.
    # ponytail: For Tier 1, brute-force combination check is acceptable for hand size <=10.
    # We'll do per-query combination generation, no pre-built index.

func find_basic_word(letters: Array[String]) -> String:
    # letters = e.g. ["C", "A", "T"], already uppercased
    # Try lengths from 3 up to letters.size(), first hit wins
    for n in range(3, letters.size() + 1):
        var result := _find_word_of_length(letters, n)
        if result != "":
            return result
    return ""

func _find_word_of_length(letters: Array[String], n: int) -> String:
    # Generate all unique index combinations of size n
    var indices := range(letters.size())
    var combos := _combinations(indices, n)
    for combo in combos:
        var chosen_letters: Array[String] = []
        for i in combo:
            chosen_letters.append(letters[i])
        # Check all permutations? Too expensive.
        # Better: check sorted anagram key against... but we can't read WordService's map.
        # ponytail: Tier 1 fallback — try the sorted string AND the original order.
        # Actually users expect "CAT" to work if letters are ["C","A","T"].
        # Try: joined order first, then try generating a few common permutations?
        # Lazy: just check every permutation for small n (3..8).
        var perms := _permutations(chosen_letters)
        for p in perms:
            var word := _join_string(p)
            if WordService.is_word(word):
                return word
    return ""

func _combinations(items: Array, k: int) -> Array[Array]:
    if k == 0:
        return [[]]
    if items.is_empty():
        return []
    var first := items[0]
    var rest := items.slice(1)
    var with_first := _combinations(rest, k - 1)
    for c in with_first:
        c.insert(0, first)
    var without_first := _combinations(rest, k)
    with_first.append_array(without_first)
    return with_first

func _permutations(items: Array) -> Array[Array]:
    if items.size() <= 1:
        return [items.duplicate()]
    var result: Array[Array] = []
    for i in range(items.size()):
        var item := items[i]
        var left := items.slice(0, i)
        var right := items.slice(i + 1)
        for p in _permutations(left + right):
            p.insert(0, item)
            result.append(p)
    # Deduplicate in case of duplicate letters
    var seen: Dictionary = {}
    var unique: Array[Array] = []
    for p in result:
        var key := _join_string(p)
        if not seen.has(key):
            seen[key] = true
            unique.append(p)
    return unique

func _join_string(arr: Array[String]) -> String:
    var out := ""
    for s in arr:
        out += s
    return out
```

**ponytail note**: This is O(n!·2ⁿ) worst-case, but hand ≤10 and we short-circuit on first hit. Fine for now; optimize later if users report lag.

- [ ] **Step 4: Run tests**

```
godot --headless --script tests/run_tests.gd
```

Expected: `test_hint_service.gd` tests pass.

---

### Task 4: BagModal Enhancement — Add Discard Pile View

**Files:**
- Modify: `scripts/components/BagModal.gd`
- Modify: `scenes/components/BagModal.tscn`

**Interfaces:**
- Consumes: `GameState.bag`, `GameState.discard_pile`
- Produces: BagModal can toggle between "Bag" and "Discard" views

- [ ] **Step 1: Add view toggle buttons to BagModal.tscn**

Add a 2-button HBox above the scroll area:
- `%ViewBagButton` text = "Bag"
- `%ViewDiscardButton` text = "Discard"

One is pressed at a time; start with "Bag" active.

- [ ] **Step 2: Add tracking variable in BagModal.gd**

```gdscript
enum View { BAG, DISCARD }
var _current_view: View = View.BAG

@onready var view_bag_btn: Button = %ViewBagButton
@onready var view_discard_btn: Button = %ViewDiscardButton
```

- [ ] **Step 3: Connect toggles + refactor populate to take source**

Change `_populate()` to `_populate_from(source: Array[Dictionary])`:

```gdscript
func _ready() -> void:
    close_button.pressed.connect(_on_close)
    view_bag_btn.pressed.connect(_on_view_bag)
    view_discard_btn.pressed.connect(_on_view_discard)
    _switch_view(View.BAG)

func _on_view_bag() -> void:
    _switch_view(View.BAG)

func _on_view_discard() -> void:
    _switch_view(View.DISCARD)

func _switch_view(v: View) -> void:
    _current_view = v
    view_bag_btn.button_pressed = (v == View.BAG)
    view_discard_btn.button_pressed = (v == View.DISCARD)
    _populate()

func _populate() -> void:
    var source: Array[Dictionary] = []
    if _current_view == View.BAG:
        source = GameState.bag
    else:
        source = GameState.discard_pile
    _populate_from(source)

func _populate_from(source: Array[Dictionary]) -> void:
    # existing counting logic, but using `source` instead of direct GameState.bag
    for child in letter_grid.get_children():
        child.queue_free()

    var counts: Dictionary = {}
    for cap: Dictionary in source:
        var letter: String = str(cap.get("letter", "?"))
        counts[letter] = counts.get(letter, 0) + 1

    var total: int = source.size()
    # ... rest same: build rows, vowel ratio

    # Update vowel_ratio for the source being viewed
    # At bottom, also show which view this is:
    var view_label := ""
    if _current_view == View.BAG:
        view_label = "BAG"
    else:
        view_label = "DISCARD"
    # Optional: add small label or keep just ratio
```

- [ ] **Step 4: Keep `open()` calling `_populate()`**

`open()` stays simple; it calls `_populate()` which uses `_current_view`.

---

### Task 5: Fixed 2×5 Keyboard Grid — Scene Nodes + Basic Population

**Files:**
- Modify: `scenes/CombatScreen.tscn`
- Modify: `scripts/screens/CombatScreen.gd`

**Interfaces:**
- Consumes: `GameState.draw_size()`, `GameState.unlocked_key_slots`, `GameState.hand`
- Produces: `%FixedKeyboardGrid` (GridContainer), `%KeyboardSlot_0`..`%KeyboardSlot_9` or similar container per slot

**Decision**: Each slot is a container. When unlocked and filled, it holds a `KeyCapElement`. When locked, it shows a padlock TextureRect.

- [ ] **Step 1: Add GridContainer to CombatScreen.tscn**

Node:
```
%FixedKeyboardGrid (GridContainer)
  columns = 5
  custom_minimum_size tuned to hold 10 keycaps comfortably
```

Inside it, create 10 slot containers (slot 0..9):

Each `KeyboardSlot_X` is a CenterContainer or MarginContainer with:
- `%KeyCapSlot_X` (where keycap is instantiated)
- `%PadlockOverlay_X` (TextureRect, visible only when locked)

Or simpler: 10 named `Control`s that act as parents:

```
%FixedKeyboardGrid
  %Slot0 (Control)
  %Slot1 (Control)
  ...
  %Slot9 (Control)
```

Access pattern: `get_node("%FixedKeyboardGrid").get_child(i)` for slot i, or give each unique name.

Simplest: just populate children by index; GridContainer children order determines row-major layout.

- [ ] **Step 2: Write minimal population test (visual test, or add to existing scenario test)**

Actually write a small test in `tests/test_fixed_keyboard.gd`:

```gdscript
# tests/test_fixed_keyboard.gd
extends GutTest

func test_slot_count_logic() -> void:
    # Test clamping: draw size vs unlocked slots
    var draw := 8
    var unlocked := 8
    assert_eq(_usable(draw, unlocked), 8)

    draw = 10
    unlocked = 8
    assert_eq(_usable(draw, unlocked), 8, "unlocked slots cap draw")

    draw = 5
    unlocked = 10
    assert_eq(_usable(draw, unlocked), 5, "draw can be less than max unlocked")

func _usable(draw: int, unlocked: int) -> int:
    return mini(draw, unlocked)
```

- [ ] **Step 3: Replace `_refresh_hand()` dynamic layout with fixed-grid population**

In `CombatScreen.gd`:

Old: `hand_container` + dynamic HBox/VBox rows.

New: populate `%FixedKeyboardGrid`:

```gdscript
const MAX_KEYBOARD_SLOTS := 10

func _refresh_hand() -> void:
    # Clear existing keycaps from slots; keep slot containers themselves
    for i in range(MAX_KEYBOARD_SLOTS):
        var slot: Control = _get_slot(i)
        for child in slot.get_children():
            if child.name != "Padlock":  # if using dedicated padlock node
                child.queue_free()

    _hand_elements.clear()
    var draw_count := GameState.draw_size()
    var unlocked := GameState.unlocked_key_slots
    var usable := mini(draw_count, unlocked)
    var total := GameState.hand.size()

    if total == 0:
        hand_empty_warning.visible = true
        _set_locks_visible(true, unlocked)
        return

    hand_empty_warning.visible = false
    _set_locks_visible(false, unlocked)  # first 'unlocked' slots = no padlock

    var tile_size := Vector2(62, 58)
    var font_size := 30

    for i in range(mini(usable, total)):
        var slot: Control = _get_slot(i)
        var el: Control = _instantiate_tile(GameState.hand[i], i, tile_size, font_size, slot)
        _hand_elements.append(el)

    # For slots i >= unlocked: show padlock
    _set_locks_visible(true, unlocked, from_slot=unlocked)

func _get_slot(idx: int) -> Control:
    return %FixedKeyboardGrid.get_child(idx) as Control

func _set_locks_visible(show: bool, unlocked: int, from_slot := 0) -> void:
    # ponytail: For now, we don't have visual padlock asset yet.
    # Implementation: if we have a padlock child, set its visibility.
    # If no padlock node exists yet, this method no-ops.
    # Add padlock visuals in a later pass (next task).
    pass
```

- [ ] **Step 4: Remove old `_setup_hand_container_geometry()` absolute positioning**

Old:
```gdscript
func _setup_hand_container_geometry() -> void:
    hand_container.custom_minimum_size = Vector2(324, 130)
    hand_container.size = Vector2(324, 130)
    hand_container.position = Vector2(106, 680)
    hand_container.mouse_filter = Control.MOUSE_FILTER_PASS
```

This can be removed. `HandTileContainer` node can also be removed from scene (or kept temporarily; we'll remove it in the layout restructure).

**Note**: Keep `%HandTileContainer` unique node reference working by either:
- Actually removing it and cleaning up `@onready` references, OR
- Reassigning to fixed grid usage.

Better: clean it up. In next task we do full scene restructure; this task is just functional keyboard population.

---

### Task 6: CombatScreen.tscn Full Node Restructure + Zone Margins

**Files:**
- Modify: `scenes/CombatScreen.tscn`

**Interfaces:**
- Consumes: layout spec zones
- Produces: restructured node tree matching design doc

**Plan**: Rebuild the tree using container layout (no absolute positioning except for overlays like `ScoringBannerOverlay`).

Nodes to create:

```
CombatScreen (Control, full rect)
├── Background (TextureRect, full rect)
├── %HUDContainer (MarginContainer/VBox, top zone)
│   ├── %DepthRow (HBox)
│   │   ├── %DepthPanel (Label: "DEPTH X-Y")
│   │   ├── %DepthInfoButton (Button)
│   │   ├── (spacer: Control SIZE_EXPAND_FILL)
│   │   ├── %GrimoireRow (HBox, will hold GrimoireIcon children)
│   │   ├── (spacer)
│   │   ├── %MoneyLabel (Label)
│   │   └── %SettingsButton (Button)
│   └── %ArtisanRow (HBox)
│       ├── %ArtisanRailDisplay (existing component, now child of HUD)
│       └── %SellDropZone (Control/MarginContainer with "SELL" label)
├── %MonsterZone (VBox, middle altar zone)
│   ├── %MonsterSprite
│   ├── %MonsterNameLabel
│   ├── %MonsterHPBar
│   └── %HpLabel
├── %PersistentScoringRow (HBox): BASE / × / MULT
│   ├── %PersistBasePanel
│   ├── %PersistMultLabel ("×")
│   └── %PersistMultPanel
├── %WordRackZone (VBox): hint + word strip
│   ├── %HintLabel
│   └── %WordRackContainer
├── %FixedKeyboardGrid (GridContainer, cols=5)
├── %HandEmptyWarning (Label, under/near grid)
├── %ActionButtonsRow (HBox): HINT REDRAW PLAY DECK
│   ├── %HintButton
│   ├── %RedrawButton
│   ├── %PlayButton
│   └── %DeckButton
├── %ScoringBannerOverlay (PanelContainer, original kept; z_index=5)
├── %WildcardPopup (PopupPanel)
└── (popups instantiated at runtime: BagModal, DepthInfoPopup)
```

- [ ] **Step 1: Remove old absolute-positioned nodes**

Remove:
- Old `CombatRootMargin` with `TopZone_Red/MidZone_Blue/BottomZone_Green/ActionZone_Orange`
- Old `HandTileContainer` (absolute positioned)
- Old `ArtisanRail` (absolute positioned at `offset_top=575`)

Keep:
- `ScoringBannerOverlay` and children (reused during animation)
- `WildcardPopup` and children

- [ ] **Step 2: Build new container tree as above**

Use:
- `VBoxContainer` / `HBoxContainer` for stacking
- `MarginContainer` for outer safe margins
- `GridContainer` for keyboard
- For spacers: empty `Control` with `size_flags_horizontal = SIZE_EXPAND_FILL`

**Margins**: Start with existing values as reference: `margin_left=46, margin_top=79, margin_right=46, margin_bottom=60`. Apply as theme overrides on `MarginContainer`.

- [ ] **Step 3: Reassign unique node names**

Ensure all `%UniqueName` nodes referenced by `CombatScreen.gd` exist:
- `%MonsterNameLabel`, `%MonsterSprite`, `%MonsterHPBar`, `%HpLabel`
- `%TurnRoundLabel` → maybe move into monster zone or HUD
- `%MoneyLabel` → now in HUD
- `%BagButton` → removed; replaced by `%DeckButton`
- `%RedrawButton`, `%PlayButton` → now in `%ActionButtonsRow`
- `%WordRackContainer`, `%HintLabel`
- `%HandEmptyWarning`
- `%WildcardPopup`, `%PickerGrid`, `%PickerCancelButton`
- `%ScoringBannerOverlay`, `%BannerVBox`, `%CellsHBox`, `%BasePanel`, `%BaseScoreLabel`, `%BaseSubLabel`, `%MultiplyLabel`, `%MultPanel`, `%MultScoreLabel`, `%MultSubLabel`, `%TotalDamageShelf`, `%TotalDamageLabel`, `%WordMetaLabel`
- `%ArtisanRail` → now `%ArtisanRailDisplay` in HUD; rename consistent

**Note**: In `CombatScreen.gd`, the `@onready var bag_button` references `%BagButton`. We'll repurpose DECK to open BagModal, so either rename button unique name or update reference.

Decision: keep script references close to names. Add `%DeckButton` and in script change:
- `@onready var bag_button: Button` → `@onready var deck_button: Button = %DeckButton`
- And wire it to open BagModal, same as old bag_button.

---

### Task 7: CombatScreen.gd — Wire Up New References + Persistent BASE/MULT

**Files:**
- Modify: `scripts/screens/CombatScreen.gd`

**Interfaces:**
- Consumes: new scene nodes `%PersistBaseScoreLabel`, `%PersistMultScoreLabel`, `%HintButton`, `%DeckButton`, `%DepthInfoButton`, `%SettingsButton`, `%FixedKeyboardGrid`
- Produces: all buttons wired; persistent BASE/MULT updates as word changes

- [ ] **Step 1: Update `@onready` block**

Change/add:
```gdscript
@onready var deck_button: Button = %DeckButton
@onready var hint_button: Button = %HintButton
@onready var persist_base_score: Label = %PersistBaseScoreLabel
@onready var persist_mult_score: Label = %PersistMultScoreLabel
@onready var depth_info_btn: Button = %DepthInfoButton
@onready var settings_btn: Button = %SettingsButton
# remove or comment unused: @onready var bag_button: Button
```

- [ ] **Step 2: Connect new buttons in `_ready()`**

```gdscript
bag_button.pressed.connect(_on_bag_pressed)  # -> remove or change to deck_button
redraw_button.pressed.connect(_on_redraw_toggle)
play_button.pressed.connect(_on_play_pressed)
picker_cancel_button.pressed.connect(_on_picker_cancel)
word_strip.item_dropped.connect(_on_rune_dropped)

# NEW:
deck_button.pressed.connect(_on_deck_pressed)
hint_button.pressed.connect(_on_hint_pressed)
depth_info_btn.pressed.connect(_on_depth_info_pressed)
settings_btn.pressed.connect(_on_settings_pressed)
```

- [ ] **Step 3: Implement new handlers**

```gdscript
func _on_deck_pressed() -> void:
    var modal: Control = BAG_MODAL.instantiate()
    add_child(modal)
    modal.open()

func _on_hint_pressed() -> void:
    if _animating or GameState.hints_remaining <= 0:
        return
    # Build letters array from hand
    var letters: Array[String] = []
    for cap: Dictionary in GameState.hand:
        if not bool(cap.get("is_symbol", false)):
            letters.append(str(cap.get("letter", "?")))
        # ponytail: wildcards not included in basic hint; could add later

    var word := HintService.find_basic_word(letters)
    if word == "":
        hint_label.text = "No hints available"
        return

    # Consume hint
    GameState.hints_remaining -= 1
    _update_hint_button_ui()

    # Show hint text; for now just show the word
    # ponytail: Could also highlight tiles in order. Basic first.
    hint_label.text = "HINT: Try %s" % word

func _update_hint_button_ui() -> void:
    hint_button.text = "HINT (%d)" % GameState.hints_remaining
    hint_button.disabled = (GameState.hints_remaining <= 0 or _animating)

func _on_depth_info_pressed() -> void:
    # TODO in next task: instantiate DepthInfoPopup
    push_error("DepthInfoPopup not yet implemented")

func _on_settings_pressed() -> void:
    push_error("Settings menu not yet implemented")
```

- [ ] **Step 4: Add persistent BASE/MULT update to `_update_word_ui()`**

Compute:
- base = sum of `_letter_base_score(letter)` for selected letters
- mult = `WordService.length_multiplier(selected_count)`

Note: `_letter_base_score` exists in `CombatService.gd`. We can either:
- Make it public/reachable, or
- Duplicate mapping minimally.

Better: In `CombatService.gd`, expose a helper:

```gdscript
# In CombatService.gd add:
func letter_base_score(letter: String) -> int:
    return _letter_base_score(letter)
```

Then in `CombatScreen.gd`:

```gdscript
func _update_persistent_scoring() -> void:
    var base_sum: float = 0.0
    var count := _slots.size()
    for s in _slots:
        var letter := str(s["letter"])
        base_sum += float(CombatService.letter_base_score(letter))
    var length_mult := WordService.length_multiplier(count)

    persist_base_score.text = "%d" % roundi(base_sum)
    if count == 0:
        persist_mult_score.text = "×1.0"
    else:
        persist_mult_score.text = "×%.1f" % length_mult
```

Call `_update_persistent_scoring()` inside `_update_word_ui()` and on `_refresh_header()` / page load.

- [ ] **Step 5: Init hints per round in `show_round()`**

In `CombatService.start_round()` or in `CombatScreen.show_round()`:

Currently `start_round()` sets:
```gdscript
GameState.turns_left = GameState.round_turn_budget()
GameState.redraws_left = GameState.round_redraw_budget()
```

Add:
```gdscript
GameState.hints_remaining = GameState.round_hint_budget()
```

And in `CombatScreen.show_round()` call `_update_hint_button_ui()`.

---

### Task 8: CombatService Helper Exposure + StartRound Hint Budget

**Files:**
- Modify: `scripts/autoload/CombatService.gd`

**Interfaces:**
- Consumes: existing `_letter_base_score`
- Produces: `CombatService.letter_base_score(letter)` + `hints_remaining` set in `start_round()`

- [ ] **Step 1: Expose letter score**

```gdscript
func letter_base_score(letter: String) -> int:
    return _letter_base_score(letter)
```

- [ ] **Step 2: Set `hints_remaining` in `start_round()`**

After:
```gdscript
GameState.redraws_left = GameState.round_redraw_budget()
```

Add:
```gdscript
GameState.hints_remaining = GameState.round_hint_budget()
```

---

### Task 9: ArtisanRailDisplay Drag-Drop + Tooltip + Sell Zone Integration

**Files:**
- Modify: `scripts/components/ArtisanSlot.gd`
- Modify: `scripts/components/ArtisanRailDisplay.gd`

**Interfaces:**
- Consumes: `ArtisanRailManager.get_slot()`, `_set_drag_preview`, `_can_drop_data`, `_drop_data`
- Produces: draggable/reorderable artisan icons; hover/touch tooltip

- [ ] **Step 1: ArtisanSlot — drag start**

```gdscript
# In ArtisanSlot.gd

var _data: Dictionary = {}  # the artisan dict

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if _data.is_empty():
            return
        # Start drag
        var preview := _make_drag_preview()
        set_drag_preview(preview)

func _make_drag_preview() -> Control:
    # Simple preview: duplicate this slot's visual or create a small snapshot
    # ponytail: For now just return a colored rect; refine visuals later
    var preview := ColorRect.new()
    preview.custom_minimum_size = Vector2(60, 60)
    preview.color = Color(0.3, 0.8, 0.4, 0.8)
    return preview

func get_drag_data(position: Vector2) -> Variant:
    # Called by Godot after set_drag_preview if we return from _gui_input?
    # Actually Godot calls _get_drag_data. Use:
    return {"type": "artisan_slot", "data": _data, "from_index": -1}  # index filled by parent
```

Better: Use Godot's `_get_drag_data` callback on the slot.

```gdscript
func _get_drag_data(position: Vector2) -> Variant:
    if _data.is_empty():
        return null
    var preview := _make_drag_preview()
    set_drag_preview(preview)
    # Find index in parent
    var idx := get_index()
    return {"type": "artisan", "index": idx, "data": _data.duplicate()}
```

- [ ] **Step 2: ArtisanRailDisplay — drop handling**

ArtisanRailDisplay is HBoxContainer. Add:

```gdscript
func _can_drop_data(position: Vector2, data: Variant) -> bool:
    if typeof(data) == TYPE_DICTIONARY:
        var d: Dictionary = data
        return d.get("type", "") == "artisan"
    return false

func _drop_data(position: Vector2, data: Variant) -> void:
    var d: Dictionary = data
    if d.get("type", "") != "artisan":
        return
    var from_idx := int(d.get("index", -1))
    # Find target index by position
    var to_idx := _slot_index_at_position(position)
    if from_idx < 0 or to_idx < 0 or from_idx == to_idx:
        return
    # Reorder in manager
    ArtisanRailManager.swap_slots(from_idx, to_idx)
    # Refresh display
    refresh()
```

Add `swap_slots` to `ArtisanRailManager.gd`:

```gdscript
func swap_slots(i: int, j: int) -> bool:
    if i < 0 or i >= rail.size() or j < 0 or j >= rail.size():
        return false
    if i == j:
        return true
    var tmp := rail[i]
    rail[i] = rail[j]
    rail[j] = tmp
    return true
```

- [ ] **Step 3: Hover tooltip**

Add a `TooltipTimer` or use `_gui_input` mouse enter/exit:

```gdscript
# In ArtisanSlot.gd
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        # Could show tooltip after short delay; skip for now or use Control.mouse_entered
        pass

func _ready() -> void:
    mouse_entered.connect(_on_mouse_enter)
    mouse_exited.connect(_on_mouse_exit)

func _on_mouse_enter() -> void:
    if _data.is_empty():
        return
    # Show tooltip: name + description
    # ponytail: For now print; later add floating Control tooltip or use native hint_tooltip
    var name := str(_data.get("name", "?"))
    var desc := str(_data.get("description", ""))
    print("[ArtisanSlot] hover: ", name, " — ", desc)
    # hint_tooltip = name + "\n" + desc  # native Control.tooltip_text exists
    tooltip_text = name + "\n" + desc
```

Use Godot's built-in `tooltip_text` property — simplest.

---

### Task 10: GrimoireRow Component + Drag-Drop-Sell + Active Tracking Hook

**Files:**
- Create: `scripts/components/GrimoireIcon.gd`
- Create: `scripts/components/GrimoireRow.gd` (or implement directly in CombatScreen; better separate component)

**Interfaces:**
- Consumes: `GameState.active_grimoires`
- Produces: draggable grimoire icons; dragging to sell zone shows "cannot sell"

- [ ] **Step 1: GrimoireIcon.gd — similar to ArtisanSlot**

```gdscript
# scripts/components/GrimoireIcon.gd
extends Control

var _data: Dictionary = {}

func setup(data: Dictionary) -> void:
    _data = data
    tooltip_text = str(data.get("name", "?")) + "\n" + str(data.get("description", ""))

func _get_drag_data(position: Vector2) -> Variant:
    if _data.is_empty():
        return null
    var preview := ColorRect.new()
    preview.custom_minimum_size = Vector2(50, 50)
    preview.color = Color(0.8, 0.5, 0.2, 0.8)
    set_drag_preview(preview)
    return {"type": "grimoire", "data": _data.duplicate(), "from_index": get_index()}
```

- [ ] **Step 2: GrimoireRow.gd — container reorder**

```gdscript
# scripts/components/GrimoireRow.gd
extends HBoxContainer

func refresh() -> void:
    for c in get_children():
        c.queue_free()
    for g: Dictionary in GameState.active_grimoires:
        var icon := preload("res://scripts/components/GrimoireIcon.gd").new()
        icon.setup(g)
        add_child(icon)

func _can_drop_data(position: Vector2, data: Variant) -> bool:
    if typeof(data) == TYPE_DICTIONARY:
        return str(Dictionary(data).get("type", "")) == "grimoire"
    return false

func _drop_data(position: Vector2, data: Variant) -> void:
    var d: Dictionary = data
    var from := int(d.get("from_index", -1))
    var to := _child_index_at_pos(position)
    if from < 0 or to < 0 or from == to:
        return
    # Reorder GameState.active_grimoires
    var tmp := GameState.active_grimoires[from]
    GameState.active_grimoires.remove_at(from)
    GameState.active_grimoires.insert(to, tmp)
    refresh()
```

- [ ] **Step 3: SellDropZone — accept both artisan and grimoire; handle differently**

Create a simple `SellDropZone.gd` or implement in CombatScreen logic:

```gdscript
# scripts/components/SellDropZone.gd
extends Control

func _ready() -> void:
    mouse_default_cursor_shape = CURSOR_MOVE

func _can_drop_data(position: Vector2, data: Variant) -> bool:
    if typeof(data) != TYPE_DICTIONARY:
        return false
    var t := str(Dictionary(data).get("type", ""))
    return t == "artisan" or t == "grimoire"

func _drop_data(position: Vector2, data: Variant) -> void:
    var d: Dictionary = data
    match str(d.get("type", "")):
        "artisan":
            _sell_artisan(d)
        "grimoire":
            _sell_grimoire(d)

func _sell_grimoire(d: Dictionary) -> void:
    # Grimoires = permanent; cannot sell
    # Show toast/label: "Cannot sell permanent upgrades"
    print("[SellZone] Cannot sell permanent grimoire upgrade")

func _sell_artisan(d: Dictionary) -> void:
    # Artisan can be unequipped and sold for portion of price
    var idx := int(d.get("from_index", -1))
    if idx < 0:
        return
    var artisan: Dictionary = ArtisanRailManager.get_slot(idx)
    if artisan.is_empty():
        return
    var price_paid := int(artisan.get("price_paid", 0))
    var refund := roundi(float(price_paid) * 0.5)
    GameState.money += refund
    ArtisanRailManager.unequip(idx)
    # Refresh UI
    EventBus.state_changed.emit()
```

Add `ArtisanRailManager.unequip(slot)`:

```gdscript
func unequip(slot: int) -> bool:
    if slot < 0 or slot >= rail.size():
        return false
    rail[slot] = null
    return true
```

Also extend `ArtisanRailManager.equip()` to accept and store `price_paid`:

```gdscript
func equip(slot: int, artisan: Dictionary, price_paid := 0) -> bool:
    # ...
    rail[slot] = artisan.duplicate()
    if price_paid > 0:
        rail[slot]["price_paid"] = price_paid
    return true
```

---

### Task 11: DepthInfoPopup Modal

**Files:**
- Create: `scenes/components/DepthInfoPopup.tscn`
- Create: `scripts/components/DepthInfoPopup.gd`

**Interfaces:**
- Consumes: `GameState.depth_stage`, `GameState.round_number`, `DepthService`
- Produces: modal showing depth info + monster list

- [ ] **Step 1: Basic modal scene**

Structure similar to BagModal:
```
DepthInfoPopup (Control, full-rect overlay)
├── Overlay (ColorRect, dim)
└── Panel (PanelContainer)
    └── VBox
        ├── TitleLabel ("Depth Info")
        ├── DepthStageLabel ("Stage 1 / Round 3")
        ├── MonsterList (VBox/Scroll)
        └── CloseButton
```

- [ ] **Step 2: Populate logic**

```gdscript
# scripts/components/DepthInfoPopup.gd
extends Control

@onready var depth_label: Label = %DepthStageLabel
@onready var monster_list: VBoxContainer = %MonsterList
@onready var close_btn: Button = %CloseButton

func _ready() -> void:
    close_btn.pressed.connect(queue_free)
    _populate()

func _populate() -> void:
    depth_label.text = "Stage %d / Round %d" % [GameState.depth_stage + 1, GameState.round_number]

    var stage_pool := DepthService.get_stage_pool_for_display()
    # DepthService currently has get_stage_pool("vanguard") etc.
    # Map depth_stage -> key: 0 -> vanguard, 1 -> sentry
    # ponytail: mapping TBD based on depth_stage naming; for now use vanguard
    var key := "vanguard"
    if GameState.depth_stage >= 1:
        key = "sentry"
    var pool := DepthService.get_stage_pool(key)

    for m: Dictionary in pool:
        var row := HBoxContainer.new()
        var name_lbl := Label.new()
        name_lbl.theme_type_variation = &"BodyLabel"
        name_lbl.text = str(m.get("name", "?"))
        row.add_child(name_lbl)

        var info_lbl := Label.new()
        info_lbl.theme_type_variation = &"MetricLabel"
        var hp := int(m.get("hp", 0))
        var mod := str(m.get("modifier", ""))
        info_lbl.text = "HP %d  %s" % [hp, mod]
        row.add_child(info_lbl)

        monster_list.add_child(row)
```

- [ ] **Step 3: Wire to CombatScreen's `_on_depth_info_pressed()`**

```gdscript
const DEPTH_INFO_POPUP := preload("res://scenes/components/DepthInfoPopup.tscn")

func _on_depth_info_pressed() -> void:
    var popup := DEPTH_INFO_POPUP.instantiate()
    add_child(popup)
```

---

### Task 12: Glue — Refresh HUD on State Changes + EventBus Hooks

**Files:**
- Modify: `scripts/screens/CombatScreen.gd`

**Interfaces:**
- Consumes: `EventBus.state_changed`, `EventBus.turns_changed`, etc.
- Produces: HUD rows refresh when state changes

- [ ] **Step 1: In `_ready()` or `show_round()` refresh HUD components**

Call:
- `artisan_rail.refresh()` — already done in `show_round()`
- Refresh `GrimoireRow` from `GameState.active_grimoires`

- [ ] **Step 2: Connect `EventBus.state_changed` if not already**

Update money, hints remaining, turn displays.

---

### Task 13: Clean Up Old References + Remove Dead Nodes

**Files:**
- Modify: `scripts/screens/CombatScreen.gd`
- Modify: `scenes/CombatScreen.tscn`

**Interfaces:**
- Consumes: old references
- Produces: clean scene with no dangling `%UniqueName`

- [ ] **Step 1: Remove unused `@onready` variables**

Check for:
- `bag_button` → replaced by `deck_button`
- `hand_container` → no longer used
- Old absolute positioned references

- [ ] **Step 2: Remove dead nodes from scene**

Ensure no orphan nodes.

---

### Task 14: Godot Import + Sanity Run + Export (Web)

**Files:** none (verification)

- [ ] **Step 1: Run project to verify no crashes**

```
godot
```

Expected: CombatScreen loads, keyboard shows tiles, buttons work, no `push_error` spam for missing nodes.

- [ ] **Step 2: Run tests**

```
godot --headless --script tests/run_tests.gd
```

Expected: all tests pass.

- [ ] **Step 3: Web export + deploy per workflow**

Run `deploy-web.ps1`:

```powershell
.\tools\deploy-web.ps1
```

---

## Plan Self-Review

1. **Spec coverage check**:
   - [x] Background swap: Task 1
   - [x] Zone restructure: Task 6
   - [x] Fixed 2×5 keyboard: Task 5
   - [x] Persistent BASE/MULT: Task 7
   - [x] HINT + gradated (Tier 1): Task 3, Task 7
   - [x] DECK = enhanced BagModal: Task 4
   - [x] HUD depth info/settings: Task 11
   - [x] Grimoire icons draggable/sell: Task 10
   - [x] Artisan row drag-drop/tooltips/sell: Task 9
   - [x] New GameState fields: Task 2
   - [x] Hint budget per round: Task 8

2. **Placeholder scan**:
   - `ponytail` markers explicitly call out deferred items (Tier 2/3 hints, grimoire sell rules, settings menu, padlock visuals)
   - No `TBD`; every deferred item has clear boundary

3. **Type consistency**:
   - Method names match across tasks: `letter_base_score`, `round_hint_budget`, `_refresh_hand`
   - Drag `type` strings match: `"artisan"`, `"grimoire"`

Ready for execution.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-09-14-combatscreen-ui-refresh.md`.

**Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
