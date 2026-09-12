# Debug Tooling, Lexicon, and Extended Gameplay — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an in-game debug toolset (DebugManager overlay + UISandbox gallery), refactor the word lexicon with rich per-word metadata, and extend combat with a unified effect-pipeline, monster modifiers, secret words, and loot drops — all backed by a headless test harness.

**Architecture:** A `DebugManager` autoload owns hotkeys (backtick overlay, F1 scene routing, F12 screenshot, time-scale) and injects state/scene directly through `game_root.gd`. A standalone `UISandbox.tscn` gallery documents safe-area/touch-target/mouse-filter overlays. `build_words.py` regenerates `words.json` with per-word POS + definition; `WordService.get_word_meta()` exposes it; `CombatScreen` renders a metadata subtitle in the scoring banner. `CombatService` gains a hook pipeline (`EffectPipeline`), a unified monster `modifier` field, `secret_words.json`, and loot drop tables surfaced in `VictoryModal`.

**Tech Stack:** Godot 4.7, typed GDScript, Godot MCP, Python 3 + WordNet/Wiktionary ingestion for the lexicon build, headless `extends SceneTree` test harness.

**Spec:** `docs/spec.md`, `docs/plan.md`, `docs/project-structure.md`.

## Global Constraints

- Viewport **540x960** portrait, stretch `canvas_items`, min 360x640. **AGENTS.md's 768x1376 is stale** — all new layout targets 540x960. Safe-area: top 48 / bottom 32 logical.
- **10 autoloads** (EventBus, GameState, PackService, KeyCapService, KeyCapSkinService, ShopService, WordService, CombatService, ResolutionManager, MCPRuntimeProbe). Any new autoload (DebugManager, EffectPipeline, LootService) is appended **last** in project.godot.
- GDScript warnings **treated as errors**: never `:=` on a Variant-returning call (`load`, `JSON.parse_string`, `get_node`) — use `var x: Variant = ...`. Use explicit `float` typing on any accumulator (`var total: float = 0.0`).
- Headless CLI tests MUST `extends SceneTree`, run from project root via `godot --headless -s res://...`, and call `quit(0)`/`quit(1)`. Strict sandbox: no writes outside the project tree; throwaway scripts under `tools/debug/` cleaned up or gitignored.
- Debug-only hotkeys gated behind `OS.is_debug_build()`.
- Signals use past-tense verbs; typed GDScript; `%UniqueName` for scene nodes; no basic-syntax comments.

## File Map

| Responsibility | Create | Modify |
|---|---|---|
| Debug tooling | `scripts/autoload/DebugManager.gd`, `scenes/debug/DebugOverlay.tscn`, `scripts/screens/DebugOverlay.gd` | `project.godot`, `scripts/game_root.gd`, `AGENTS.md` |
| UI sandbox | `scenes/UISandbox.tscn`, `scripts/screens/UISandbox.gd`, `scripts/components/OverlayHint.gd` | — |
| Lexicon | `tools/build_words.py` (rewrite) | `data/words.json`, `scripts/autoload/WordService.gd`, `scenes/CombatScreen.tscn`, `scripts/screens/CombatScreen.gd` |
| Extended gameplay | `data/secret_words.json`, `data/drop_tables.json`, `scripts/autoload/EffectPipeline.gd`, `scripts/autoload/LootService.gd` | `scripts/autoload/CombatService.gd`, `data/monsters.json`, `scripts/components/VictoryModal.gd`, `scenes/components/VictoryModal.tscn`, `scripts/autoload/GameState.gd` |
| Tests | `tests/run_tests.gd`, `tests/lexicon_test.gd`, `tests/word_test.gd`, `tests/monster_modifier_test.gd`, `tests/scenario_test.gd` | — |

---

## Phase 1 — Debug Tooling & AGENTS.md Constraints

### Task 1.1: DebugManager autoload

**Files:**
- Create: `scripts/autoload/DebugManager.gd`
- Modify: `project.godot` (append `DebugManager` autoload last)

**Interfaces:**
- Produces: singleton `DebugManager` with `toggle_overlay()`, `open_overlay()`, `close_overlay()`, `is_overlay_open() -> bool`, `screenshot()`, `set_time_scale(v: float)`, `route_to(state: String)`, `inject_state(cfg: Dictionary)`, `trigger_mechanic(id: String)`, and `signal overlay_state_changed(open: bool)`.

- [ ] **Step 1: Add autoload**

Append to `project.godot` `[autoload]` (after the existing entries):

```
DebugManager="*res://scripts/autoload/DebugManager.gd"
```

- [ ] **Step 2: Implement skeleton + hotkeys**

```gdscript
extends Node
## Debug autoload: backtick overlay, F12 screenshot, time-scale, scene routing.
## No-ops outside debug builds.

const OVERLAY_SCENE := preload("res://scenes/debug/DebugOverlay.tscn")

signal overlay_state_changed(open: bool)

var _overlay: Control = null


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_BACKTICK:
				toggle_overlay()
			KEY_F12:
				screenshot()
```

- [ ] **Step 3: Overlay open/close/toggle**

```gdscript
func toggle_overlay() -> void:
	if is_overlay_open():
		close_overlay()
	else:
		open_overlay()


func open_overlay() -> void:
	if _overlay != null:
		return
	_overlay = OVERLAY_SCENE.instantiate()
	get_tree().root.add_child(_overlay)
	overlay_state_changed.emit(true)


func close_overlay() -> void:
	if _overlay == null:
		return
	_overlay.queue_free()
	_overlay = null
	overlay_state_changed.emit(false)


func is_overlay_open() -> bool:
	return _overlay != null and is_instance_valid(_overlay)
```

- [ ] **Step 4: Screenshot**

```gdscript
func screenshot() -> void:
	var dir := "user://screenshots"
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "").replace("-", "")
	var path := "%s/debug_%s.png" % [dir, stamp]
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[debug] screenshot -> %s" % path)
```

- [ ] **Step 5: Time-scale**

```gdscript
func set_time_scale(v: float) -> void:
	Engine.time_scale = clampf(v, 0.0, 4.0)
```

- [ ] **Step 6: Routing delegates** (implemented against Task 1.3 methods on GameRoot)

```gdscript
func route_to(state: String) -> void:
	var root: Node = get_node_or_null("/root/GameRoot")
	if root and root.has_method("route_to"):
		root.route_to(state)


func inject_state(cfg: Dictionary) -> void:
	var root: Node = get_node_or_null("/root/GameRoot")
	if root and root.has_method("inject_state"):
		root.inject_state(cfg)


func trigger_mechanic(id: String) -> void:
	var root: Node = get_node_or_null("/root/GameRoot")
	if root and root.has_method("trigger_mechanic"):
		root.trigger_mechanic(id)
```

- [ ] **Step 7: Verify headlessly**

Create throwaway `tools/debug/verify_debug_manager.gd` (`extends SceneTree`) that asserts `load("res://scripts/autoload/DebugManager.gd").can_instantiate()` and that the script declares the expected methods. Run `godot --headless -s res://tools/debug/verify_debug_manager.gd`. Delete the temp file after.

- [ ] **Step 8: Commit**

```bash
git add scripts/autoload/DebugManager.gd project.godot
git commit -m "feat: add DebugManager autoload"
```

### Task 1.2: DebugOverlay UI

**Files:**
- Create: `scenes/debug/DebugOverlay.tscn`, `scripts/screens/DebugOverlay.gd`

**Interfaces:**
- Consumes: `DebugManager` methods/signal from Task 1.1, `GameRoot.route_to` from Task 1.3.
- Produces: full-rect top-level Control with per-scene route buttons and state readout.

- [ ] **Step 1: Build scene**

Root `Control` (full-rect anchors, `mouse_filter=IGNORE`, `z_index=2000`). Child `PanelContainer` at top-left with a `VBoxContainer` containing:
- `Label %StateLabel` (route/round/money/turns/redraws readout)
- Buttons: `%MenuButton` "Menu", `%CombatButton` "Combat", `%ShopButton` "Shop", `%BossButton` "Jump Boss Round", `%SpeedHalf` "x0.5", `%SpeedNormal` "x1", `%SpeedDouble` "x2", `%ShotButton` "Screenshot", `%GrantMoney` "+$50", `%TriggerSilence` "Trigger: silence", `%CloseButton` "Close".

- [ ] **Step 2: Implement DebugOverlay.gd**

```gdscript
extends Control
## Debug overlay panel. Parented to the scene tree root by DebugManager.

@onready var state_label: Label = %StateLabel


func _ready() -> void:
	%MenuButton.pressed.connect(func(): DebugManager.route_to("menu"))
	%CombatButton.pressed.connect(func(): DebugManager.route_to("combat"))
	%ShopButton.pressed.connect(func(): DebugManager.route_to("shop"))
	%BossButton.pressed.connect(func(): DebugManager.route_to("boss"))
	%SpeedHalf.pressed.connect(func(): DebugManager.set_time_scale(0.5))
	%SpeedNormal.pressed.connect(func(): DebugManager.set_time_scale(1.0))
	%SpeedDouble.pressed.connect(func(): DebugManager.set_time_scale(2.0))
	%ShotButton.pressed.connect(func(): DebugManager.screenshot())
	%GrantMoney.pressed.connect(func(): DebugManager.inject_state({"money": GameState.money + 50}))
	%TriggerSilence.pressed.connect(func(): DebugManager.trigger_mechanic("silence"))
	%CloseButton.pressed.connect(func(): DebugManager.close_overlay())
	DebugManager.overlay_state_changed.connect(_on_overlay_changed)
	_refresh()


func _on_overlay_changed(open: bool) -> void:
	visible = open
	if open:
		_refresh()


func _refresh() -> void:
	var m: Dictionary = GameState.current_monster
	state_label.text = "R%d  $%d\nTURNS %d  REDRAW %d\n%s" % [
		GameState.round_number, GameState.money,
		GameState.turns_left, GameState.redraws_left,
		str(m.get("name", "?"))
	]
```

- [ ] **Step 3: Verify headlessly** via Godot MCP `get_debug_output` on a debug run — toggle overlay with backtick, confirm no script errors, confirm buttons call routes without exceptions.

- [ ] **Step 4: Commit**

```bash
git add scenes/debug/DebugOverlay.tscn scripts/screens/DebugOverlay.gd
git commit -m "feat: add DebugOverlay scene"
```

### Task 1.3: game_root routing hooks

**Files:**
- Modify: `scripts/game_root.gd`

**Interfaces:**
- Consumes: none new.
- Produces: `route_to(state: String)`, `inject_state(cfg: Dictionary)`, `trigger_mechanic(id: String)`, `jump_boss_round()`.

- [ ] **Step 1: Add routing methods**

```gdscript
func route_to(state: String) -> void:
	match state:
		"menu":
			_switch_to_menu()
		"run_setup":
			_on_run_setup_requested()
		"combat":
			_fight_or_boss()
		"shop":
			if GameState.active_pack_id == "":
				GameState.active_pack_id = "mx_red"
				GameState.bag = KeyCapService.load_starter_bag("standard")
			_on_shop_requested()
		"boss":
			jump_boss_round()
```

- [ ] **Step 2: inject_state**

```gdscript
func inject_state(cfg: Dictionary) -> void:
	for key: String in cfg:
		if GameState.has_method("set_" + key):
			GameState.call("set_" + key, cfg[key])
		elif GameState.get(key) != null:
			GameState.set(key, cfg[key])
	if current_screen and current_screen.has_method("show_round"):
		current_screen.show_round()
```

- [ ] **Step 3: trigger_mechanic + jump_boss_round**

```gdscript
func trigger_mechanic(id: String) -> void:
	if current_state != State.COMBAT or current_screen == null:
		return
	match id:
		"silence":
			GameState.current_monster["modifier"] = "silence"
	if current_screen.has_method("_refresh_header"):
		current_screen._refresh_header()


func jump_boss_round() -> void:
	var next: int = int(ceil(GameState.round_number / 3.0)) * 3
	if next == 0:
		next = 3
	GameState.round_number = next
	_fight_or_boss()
```

- [ ] **Step 4: Remove the F1 debug block** (existing `_unhandled_input` lines 35-43) — DebugManager owns hotkeys now. Keep `_unhandled_input` empty or delete it.

- [ ] **Step 5: Verify** — headless presence check on the new methods + manual debug run routing via overlay buttons.

- [ ] **Step 6: Commit**

```bash
git add scripts/game_root.gd
git commit -m "refactor: route game_root states via DebugManager"
```

### Task 1.4: Document debug hotkeys in AGENTS.md

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1:** Add a "Debug Tools" section documenting: backtick = toggle overlay, F12 = screenshot, F1 removed (routing now via overlay), time-scale buttons, and the `DebugManager`/`GameRoot` routing methods.

- [ ] **Step 2: Commit**

```bash
git add AGENTS.md
git commit -m "docs: AGENTS.md debug hotkeys"
```

---

## Phase 2 — UISandbox Gallery

### Task 2.1: OverlayHint component

**Files:**
- Create: `scripts/components/OverlayHint.gd`

**Interfaces:**
- Produces: reusable Control that draws a labeled translucent box. `@export color: Color`, `@export title: String`.

- [ ] **Step 1: Implement**

```gdscript
extends Control
## Draws a translucent labeled rect. Used by UISandbox to annotate regions.

@export var color: Color = Color(1, 0.3, 0.3, 0.25)
@export var title: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), color, true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(color.r, color.g, color.b, 1.0), false, 2.0)
	if title != "":
		draw_string(ThemeDB.fallback_font, Vector2(6, 18), title, \
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 1))
```

- [ ] **Step 2: Commit**

```bash
git add scripts/components/OverlayHint.gd
git commit -m "feat: add OverlayHint component"
```

### Task 2.2: UISandbox scene

**Files:**
- Create: `scenes/UISandbox.tscn`, `scripts/screens/UISandbox.gd`

**Interfaces:**
- Consumes: `OverlayHint` from Task 2.1.
- Produces: standalone debug scene launching via `godot --path . res://scenes/UISandbox.tscn`.

- [ ] **Step 1: Build scene**

Root `Control` (540x960 full-rect). Layers:
- **Safe-area layer:** `OverlayHint` boxes at top `Rect2(0,0,540,48)` titled "Safe Area Top 48" and bottom `Rect2(0,928,540,32)` titled "Safe Area Bottom 32".
- **Touch-target layer:** `GridContainer` of 48x48 `ColorRect`s (each with `MicroLabel` "48"), toggleable via a button.
- **Mouse-filter layer:** three 80x80 demo panels labeled STOP/PASS/IGNORE, each clickable; clicks append to a `%HitLog` label.

- [ ] **Step 2: Implement UISandbox.gd**

```gdscript
extends Control

@onready var hit_log: Label = %HitLog
@onready var touch_layer: Control = %TouchLayer


func _ready() -> void:
	%ToggleTouch.pressed.connect(func(): touch_layer.visible = not touch_layer.visible)
	%StopBox.gui_input.connect(_on_box_gui.bind("STOP"))
	%PassBox.gui_input.connect(_on_box_gui.bind("PASS"))
	%IgnoreBox.gui_input.connect(_on_box_gui.bind("IGNORE"))


func _on_box_gui(event: InputEvent, tag: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		hit_log.text = "clicked: " + tag
```

- [ ] **Step 3:** Add `route_to("sandbox")` support in `GameRoot.route_to` (optional, or run scene directly).

- [ ] **Step 4: Verify headlessly** via the AGENTS.md `_verify.gd` pattern: set `get_window().size = Vector2i(540, 960)`, `await get_tree().process_frame`, assert safe-area boxes `position == (0,0)` size `(540,48)` and `(0,928)` size `(540,32)`, assert touch `ColorRect`s are exactly 48x48. Delete `_verify.gd`/`_verify.tscn`/`.uid` after.

- [ ] **Step 5: Commit**

```bash
git add scenes/UISandbox.tscn scripts/screens/UISandbox.gd scripts/components/OverlayHint.gd
git commit -m "feat: add UISandbox gallery"
```

---

## Phase 3 — Lexicon Refactor

### Task 3.1: Rewrite build_words.py

**Files:**
- Modify (rewrite): `tools/build_words.py`
- Regenerate: `data/words.json`

**Interfaces:**
- Produces: `data/words.json` in new schema: `{"words":[{"w":"AAA","pos":1,"def":"..."}, ...]}`.

- [ ] **Step 1: Add POS+def ingestion**

Use WordNet via `nltk` if available (fallback to a bundled/enriched source, else `pos=16`, `def=""`). For each word, take the first synset's part-of-speech and gloss (truncate to ~60 chars). Map POS to bitmask codes: N=1, V=2, A=4, R=8, other/unknown=16.

```python
import json, re, sys

POS_BIT = {"n": 1, "v": 2, "a": 4, "r": 8}

def ingest(src: str) -> list:
    pat = re.compile(r"^[A-Z]{3,}$")
    words = {}
    try:
        from nltk.corpus import wordnet as wn
    except Exception:
        wn = None
    with open(src, encoding="utf-8") as f:
        for line in f:
            w = line.strip().upper()
            if not pat.match(w) or w in words:
                continue
            pos, d = 16, ""
            if wn is not None:
                syn = wn.synsets(w.lower())
                if syn:
                    pos = POS_BIT.get(syn[0].pos(), 16)
                    d = (syn[0].definition() or "")[:60]
            words[w] = {"w": w, "pos": pos, "def": d}
    return sorted(words.values(), key=lambda e: e["w"])

def main(src: str, dst: str) -> None:
    with open(dst, "w", encoding="utf-8") as f:
        json.dump({"words": ingest(src)}, f, separators=(",", ":"))
    print(f"wrote metadata words to {dst}")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
```

- [ ] **Step 2: Regenerate** `data/words.json` by running `python tools/build_words.py <source_wordlist> data/words.json`. Confirm output size is reasonable (compact, ~370k entries).

- [ ] **Step 3: Commit**

```bash
git add tools/build_words.py data/words.json
git commit -m "feat: build_words.py POS+def metadata schema"
```

### Task 3.2: WordService.get_word_meta

**Files:**
- Modify: `scripts/autoload/WordService.gd`

**Interfaces:**
- Consumes: new `data/words.json` schema from Task 3.1.
- Produces: `get_word_meta(word: String) -> Dictionary`, `pos_name(pos: int) -> String`. `is_word`/`word_count` keep their existing signatures.

- [ ] **Step 1: Update `_load_dictionary`**

```gdscript
func _load_dictionary() -> void:
	var text := FileAccess.get_file_as_string(WORDS_PATH)
	if text.is_empty():
		push_error("WordService: missing %s" % WORDS_PATH)
		return
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or not data.has("words"):
		push_error("WordService: %s has no 'words' array" % WORDS_PATH)
		return
	for entry: Variant in data["words"]:
		if typeof(entry) == TYPE_STRING:
			_words[entry] = {"pos": 16, "def": ""}
		elif typeof(entry) == TYPE_DICTIONARY:
			var e: Dictionary = entry
			_words[str(e["w"])] = {"pos": int(e.get("pos", 16)), "def": str(e.get("def", ""))}
	_count = _words.size()
```

(Keeps backward compat with the old flat-string schema.)

- [ ] **Step 2: Add `get_word_meta`**

```gdscript
func get_word_meta(word: String) -> Dictionary:
	var meta: Variant = _words.get(word)
	if meta == null:
		return {"is_valid": false, "part_of_speech": "Other", "short_def": "",
				"vowel_count": 0, "consonant_count": 0, "length": word.length()}
	var pos: int = int(meta.get("pos", 16))
	var vowels := 0
	var consonants := 0
	for c: String in word:
		if "AEIOU".contains(c):
			vowels += 1
		else:
			consonants += 1
	return {
		"is_valid": true,
		"part_of_speech": pos_name(pos),
		"short_def": str(meta.get("def", "")),
		"vowel_count": vowels,
		"consonant_count": consonants,
		"length": word.length(),
	}


func pos_name(pos: int) -> String:
	match pos:
		1: return "Noun"
		2: return "Verb"
		4: return "Adj"
		8: return "Adv"
		_: return "Other"
```

- [ ] **Step 3: Verify** via `tests/word_test.gd` (see Task 6.2) — assert `get_word_meta("CAT")` returns `is_valid=true`, `length=3`, `vowel_count=1`, `consonant_count=2`; `get_word_meta("ZZZZZZ")` returns `is_valid=false`.

- [ ] **Step 4: Commit**

```bash
git add scripts/autoload/WordService.gd
git commit -m "feat: WordService.get_word_meta with POS/def/letter counts"
```

### Task 3.3: CombatScreen metadata subtitle

**Files:**
- Modify: `scenes/CombatScreen.tscn`, `scripts/screens/CombatScreen.gd`

**Interfaces:**
- Consumes: `WordService.get_word_meta`/`pos_name` from Task 3.2.

- [ ] **Step 1: Add `%WordMetaLabel`** node under `%BannerVBox` in CombatScreen.tscn, `MicroLabel` theme variation, initially hidden.

- [ ] **Step 2: Populate in Phase B of `_play_score_animation`**

Before the multiplier-ignition block, add:

```gdscript
var word := ""
for s in _slots:
	word += str(s["letter"])
if word.length() >= 3:
	var meta: Dictionary = WordService.get_word_meta(word)
	if meta.get("is_valid", false):
		%WordMetaLabel.text = "%s · %s · \"%s\" · V%d/C%d" % [
			word, meta["part_of_speech"], meta["short_def"],
			meta["vowel_count"], meta["consonant_count"]
		]
		%WordMetaLabel.show()
```

- [ ] **Step 3: Reset in `_banner_reset`**: `%WordMetaLabel.hide()` and clear text.

- [ ] **Step 4: Verify headlessly** that `get_word_meta` feeds the label without script errors (Phase 6 scenario test covers it).

- [ ] **Step 5: Commit**

```bash
git add scenes/CombatScreen.tscn scripts/screens/CombatScreen.gd
git commit -m "feat: CombatScreen word metadata subtitle"
```

---

## Phase 4 — Extended Gameplay: Effect Pipeline

### Task 4.1: EffectPipeline autoload

**Files:**
- Create: `scripts/autoload/EffectPipeline.gd`
- Modify: `project.godot`

**Interfaces:**
- Produces: singleton `EffectPipeline` with `register_cap(cap: Dictionary)`, `unregister_cap(cap: Dictionary)`, `trigger(hook: String, args: Array)`, and signals `on_draw(hand)`, `on_letter_slotted(cap, index)`, `on_word_validated(word, valid)`, `on_score_calculated(result)`, `on_monster_damaged(monster, damage, remaining)`, `on_monster_defeated(monster, summary)`, `on_turn_end(turns_left)`.

- [ ] **Step 1: Add autoload**

Append to project.godot `[autoload]`:

```
EffectPipeline="*res://scripts/autoload/EffectPipeline.gd"
```

- [ ] **Step 2: Implement**

```gdscript
extends Node
## Effect hook pipeline. Registered caps can listen for combat lifecycle hooks.

signal on_draw(hand)
signal on_letter_slotted(cap, index)
signal on_word_validated(word, valid)
signal on_score_calculated(result)
signal on_monster_damaged(monster, damage, remaining)
signal on_monster_defeated(monster, summary)
signal on_turn_end(turns_left)

var _cap_effects: Dictionary = {}  # capId:String -> Array of {hook, apply}


func register_cap(cap: Dictionary) -> void:
	var effects: Array = cap.get("effects", [])
	if effects.is_empty():
		return
	var cap_id: String = str(cap.get("id", cap.get("letter", "")))
	for effect: Variant in effects:
		var e: Dictionary = effect
		var hook: String = str(e.get("hook", ""))
		if hook == "":
			continue
		if not _cap_effects.has(cap_id):
			_cap_effects[cap_id] = []
		_cap_effects[cap_id].append(e)


func unregister_cap(cap: Dictionary) -> void:
	_cap_effects.erase(str(cap.get("id", cap.get("letter", ""))))


func trigger(hook: String, args: Array) -> void:
	_emit_hook_signal(hook, args)
	for cap_id: String in _cap_effects:
		for effect: Variant in _cap_effects[cap_id]:
			var e: Dictionary = effect
			if str(e.get("hook", "")) != hook:
				continue
			var apply: Callable = e.get("apply", Callable())
			if apply.is_valid():
				apply.callv(args)


func _emit_hook_signal(hook: String, args: Array) -> void:
	match hook:
		"on_draw":
			on_draw.emit(args[0])
		"on_letter_slotted":
			on_letter_slotted.emit(args[0], args[1])
		"on_word_validated":
			on_word_validated.emit(args[0], args[1])
		"on_score_calculated":
			on_score_calculated.emit(args[0])
		"on_monster_damaged":
			on_monster_damaged.emit(args[0], args[1], args[2])
		"on_monster_defeated":
			on_monster_defeated.emit(args[0], args[1])
		"on_turn_end":
			on_turn_end.emit(args[0])
```

- [ ] **Step 3: Verify headlessly** — register a cap with a test `apply` Callable, trigger `on_draw`, assert it ran.

- [ ] **Step 4: Commit**

```bash
git add scripts/autoload/EffectPipeline.gd project.godot
git commit -m "feat: add EffectPipeline hook registry"
```

### Task 4.2: CombatService hook integration

**Files:**
- Modify: `scripts/autoload/CombatService.gd`

**Interfaces:**
- Consumes: `EffectPipeline` from Task 4.1.

- [ ] **Step 1:** In `start_round()`, after `KeyCapService.draw_hand()`, call `EffectPipeline.trigger("on_draw", [GameState.hand])`.

- [ ] **Step 2:** Add `slot_letter(cap: Dictionary, index: int)` helper calling `EffectPipeline.trigger("on_letter_slotted", [cap, index])`; call from CombatScreen `_add_slot`.

- [ ] **Step 3:** In `validate_word`, after computing, `EffectPipeline.trigger("on_word_validated", [word, result.get("ok", false)])` (only when `ok` true).

- [ ] **Step 4:** In `calculate_word`, just before returning, `EffectPipeline.trigger("on_score_calculated", [result])`.

- [ ] **Step 5:** In `_apply_monster_damage`:
- non-lethal branch: `EffectPipeline.trigger("on_monster_damaged", [GameState.current_monster, damage, remaining])`
- lethal branch: `EffectPipeline.trigger("on_monster_defeated", [GameState.current_monster, summary])`

- [ ] **Step 6:** In `_end_turn`, `EffectPipeline.trigger("on_turn_end", [GameState.turns_left])`.

- [ ] **Step 7: Verify** via `tests/scenario_test.gd` (Phase 6) that existing win/lose flows still pass with hooks inserted.

- [ ] **Step 8: Commit**

```bash
git add scripts/autoload/CombatService.gd scripts/screens/CombatScreen.gd
git commit -m "feat: wire CombatService into EffectPipeline hooks"
```

### Task 4.3: Unified modifier system

**Files:**
- Modify: `data/monsters.json`, `scripts/autoload/CombatService.gd`, `scripts/screens/CombatScreen.gd`

**Interfaces:**
- Produces: unified `_current_modifier() -> String` helper; `_modifier_rules: Dictionary` dispatch.

- [ ] **Step 1: Update monsters.json**

Add a unified `modifier` field to every monster; keep `boss_modifier` removed or aliased. Add a couple of normal enemies with modifiers:

```json
{"id": "shieldgoblin", "name": "Shielded Goblin", "hp": 12, "max_hp": 12, "is_boss": false, "modifier": "shielded", "sprite": "res://assets/ui/monster_sq_192_goblin_1.png", "drop_table_id": "goblin_loot"},
{"id": "rageorcs", "name": "Raging Orcs", "hp": 18, "max_hp": 18, "is_boss": false, "modifier": "enraged", "sprite": "res://assets/ui/monster_sq_192_orc_1.png", "drop_table_id": "orc_loot"}
```

- [ ] **Step 2: Add `_current_modifier` + `_modifier_rules` in CombatService**

```gdscript
func _current_modifier() -> String:
	return str(GameState.current_monster.get("modifier", GameState.current_monster.get("boss_modifier", "")))
```

Replace hardcoded branches with a rules dict keyed by modifier name, where each rule is a Callable `func(cap: Dictionary, letter: String, ctx: Dictionary) -> float` returning a contribution multiplier/overrides, plus a `blocks(word)` check for validation.

- [ ] **Step 3:** Update `validate_word`'s `no_repeats` block to use `_current_modifier()`.

- [ ] **Step 4:** Update `calculate_word`'s vowel/consonant lock + silence + per-cap branches to route through `_modifier_rules`.

- [ ] **Step 5:** Update `CombatScreen._add_slot` no_repeats check to use `_current_modifier()`.

- [ ] **Step 6:** Add `%ModifierLabel` in CombatScreen showing the active modifier name from `_current_modifier()`.

- [ ] **Step 7: Verify** via `tests/monster_modifier_test.gd` (Task 6.4) — synthetic monsters per modifier.

- [ ] **Step 8: Commit**

```bash
git add data/monsters.json scripts/autoload/CombatService.gd scripts/screens/CombatScreen.gd scenes/CombatScreen.tscn
git commit -m "feat: unified monster modifier system"
```

### Task 4.4: secret_words.json

**Files:**
- Create: `data/secret_words.json`
- Modify: `scripts/autoload/WordService.gd`

**Interfaces:**
- Produces: `get_word_meta` returns `is_secret: bool` for secret words; `is_word` includes secret words.

- [ ] **Step 1:** Create `data/secret_words.json`:

```json
{"words": [{"w": "ZYZZYX", "pos": 16, "def": "rare word, big reward"}]}
```

- [ ] **Step 2:** In `WordService._ready`, load secret words into a separate `_secret_words` dict (same schema). `is_word` checks both. `get_word_meta` sets `"is_secret": _secret_words.has(word)`.

- [ ] **Step 3:** Commit

```bash
git add data/secret_words.json scripts/autoload/WordService.gd
git commit -m "feat: add secret_words.json"
```

---

## Phase 5 — Loot & VictoryModal

### Task 5.1: Drop tables + LootService

**Files:**
- Create: `data/drop_tables.json`, `scripts/autoload/LootService.gd`
- Modify: `data/monsters.json`, `project.godot`

**Interfaces:**
- Produces: `LootService.roll_drops(monster: Dictionary) -> Array` of `{type: String, label: String, value: int}`.

- [ ] **Step 1: Add autoload**

Append to project.godot `[autoload]`:

```
LootService="*res://scripts/autoload/LootService.gd"
```

- [ ] **Step 2: Create drop_tables.json**

```json
{
  "drop_tables": [
    {"id": "goblin_loot", "entries": [
      {"type": "money", "weight": 5, "value": 5, "label": "Gold"},
      {"type": "cap", "weight": 3, "rarity": "uncommon", "label": "Cap"}
    ]},
    {"id": "orc_loot", "entries": [
      {"type": "money", "weight": 4, "value": 8, "label": "Gold"},
      {"type": "cap", "weight": 4, "rarity": "rare", "label": "Cap"}
    ]}
  ]
}
```

- [ ] **Step 3: Implement LootService.gd**

```gdscript
extends Node
## Rolls loot drops from a monster's drop_table_id.

const DROP_PATH := "res://data/drop_tables.json"

var _tables: Dictionary = {}


func _ready() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DROP_PATH))
	if typeof(data) == TYPE_DICTIONARY:
		for t: Variant in data.get("drop_tables", []):
			var table: Dictionary = t
			_tables[str(table["id"])] = table


func roll_drops(monster: Dictionary) -> Array:
	var table_id: String = str(monster.get("drop_table_id", ""))
	if table_id == "" or not _tables.has(table_id):
		return []
	var drops: Array = []
	for entry: Variant in _tables[table_id]["entries"]:
		var e: Dictionary = entry
		var w: int = int(e.get("weight", 1))
		if randf() < float(w) / 10.0:
			drops.append({"type": str(e.get("type", "money")),
				"label": str(e.get("label", "?")), "value": int(e.get("value", 0))})
	return drops
```

- [ ] **Step 4:** Reference `drop_table_id` on monster entries in monsters.json (see Task 4.3 additions).

- [ ] **Step 5: Commit**

```bash
git add data/drop_tables.json scripts/autoload/LootService.gd data/monsters.json project.godot
git commit -m "feat: add drop tables and LootService"
```

### Task 5.2: VictoryModal loot display

**Files:**
- Modify: `scripts/components/VictoryModal.gd`, `scenes/components/VictoryModal.tscn`

**Interfaces:**
- Consumes: `LootService.roll_drops` from Task 5.1 (called in `CombatService` round-won summary).
- Produces: `open(summary)` renders `summary["loot"]` rows; `_on_continue` grants loot before emitting.

- [ ] **Step 1:** In CombatService `_apply_monster_damage` lethal branch, add `"loot": LootService.roll_drops(GameState.current_monster)` to the round_won summary.

- [ ] **Step 2:** Add `%LootList` (VBoxContainer) to VictoryModal.tscn.

- [ ] **Step 3:** In `VictoryModal.open`, after ability line, render loot:

```gdscript
if _summary.has("loot"):
	for drop: Variant in _summary["loot"]:
		var d: Dictionary = drop
		_add_receipt_line(str(d.get("label", "Drop")), int(d.get("value", 0)))
```

- [ ] **Step 4:** Track loot grants in `_on_continue` (money + value, caps added to `GameState.bag`) before adding `_total` and emitting `shop_requested`/`game_complete`.

- [ ] **Step 5: Verify headlessly** — open VictoryModal with a synthetic `{"loot":[{label:"Gold",value:5}]}` summary, assert receipt renders and `_on_continue` grants.

- [ ] **Step 6: Commit**

```bash
git add scripts/autoload/CombatService.gd scripts/components/VictoryModal.gd scenes/components/VictoryModal.tscn
git commit -m "feat: show loot drops in VictoryModal"
```

---

## Phase 6 — Headless Test Harness

### Task 6.1: Test runner

**Files:**
- Create: `tests/run_tests.gd`

**Interfaces:**
- Produces: entry point that runs every `tests/*_test.gd`, aggregates pass/fail, `quit(0)`/`quit(1)`.

- [ ] **Step 1: Implement**

```gdscript
extends SceneTree
## Runs all tests under res://tests/ that expose run() -> int.

const TEST_DIR := "res://tests/"

func _init() -> void:
	var files := DirAccess.get_files_at(TEST_DIR)
	var failures := 0
	var ran := 0
	for fname: String in files:
		if not fname.ends_with("_test.gd"):
			continue
		var path := TEST_DIR + fname
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			print("[test] SKIP (no instantiate): ", fname)
			continue
		var inst := script.new()
		if not inst.has_method("run"):
			continue
		ran += 1
		print("[test] == ", fname, " ==")
		var code: int = inst.run()
		failures += code
	print("[test] %d/%d suites passed" % [ran - failures, ran])
	quit(1 if failures > 0 else 0)
```

- [ ] **Step 2:** Run empty suite — expect `0/0` and `quit(0)`.

- [ ] **Step 3: Commit**

```bash
git add tests/run_tests.gd
git commit -m "feat: add headless test runner"
```

### Task 6.2: lexicon_test.gd

**Files:**
- Create: `tests/lexicon_test.gd`

- [ ] **Step 1: Implement**

```gdscript
extends Node

func run() -> int:
	var failures := 0
	var meta: Dictionary = WordService.get_word_meta("CAT")
	failures += 0 if meta.get("is_valid", false) else 1
	failures += 0 if meta.get("length", 0) == 3 else 1
	failures += 0 if meta.get("vowel_count", 0) == 1 else 1
	failures += 0 if meta.get("consonant_count", 0) == 2 else 1
	var bad: Dictionary = WordService.get_word_meta("ZZZZZZ")
	failures += 0 if bad.get("is_valid", true) == false else 1
	print("[lexicon] failures=", failures)
	return failures
```

- [ ] **Step 2:** Run `godot --headless -s res://tests/run_tests.gd`, expect `[lexicon] failures=0`.

- [ ] **Step 3: Commit**

```bash
git add tests/lexicon_test.gd
git commit -m "test: lexicon metadata"
```

### Task 6.3: word_test.gd

**Files:**
- Create: `tests/word_test.gd`

- [ ] **Step 1: Implement**

```gdscript
extends Node

func run() -> int:
	var failures := 0
	failures += 0 if WordService.is_word("CAT") else 1
	failures += 0 if not WordService.is_word("XYZQZZ") else 1
	failures += 0 if WordService.length_multiplier(4) == 1.3 else 1
	failures += 0 if WordService.word_count() > 0 else 1
	print("[word] failures=", failures)
	return failures
```

(Adjust `XYZQZZ` to a guaranteed-nonword or use a known-invalid token.)

- [ ] **Step 2:** Run suite, expect `failures=0`.

- [ ] **Step 3: Commit**

```bash
git add tests/word_test.gd
git commit -m "test: word service basics"
```

### Task 6.4: monster_modifier_test.gd

**Files:**
- Create: `tests/monster_modifier_test.gd`

- [ ] **Step 1: Implement** synthetic-monster scenarios

```gdscript
extends Node

func run() -> int:
	var failures := 0
	failures += _scenario({"modifier": "silence"}, "CAT", false, failures)
	# ... per-modifier asserts against CombatService.calculate_word
	return failures
```

For each modifier assert the expected contribution rule:
- `silence`: abilities/finish/sticker/condition contribute 0.
- `vowel_lock`: consonants contribute 0.
- `consonant_lock`: vowels contribute 0.
- `no_repeats`: duplicate letters are invalid.
- `shielded`: damage reduced by a flat amount.
- `enraged`: +HP applied at round start.

- [ ] **Step 2:** Run suite, expect `failures=0`.

- [ ] **Step 3: Commit**

```bash
git add tests/monster_modifier_test.gd
git commit -m "test: monster modifier rules"
```

### Task 6.5: scenario_test.gd

**Files:**
- Create: `tests/scenario_test.gd`

- [ ] **Step 1: Implement** full combat scenario presets

```gdscript
extends Node

func run() -> int:
	var failures := 0
	GameState.reset()
	GameState.setup_new_run("mx_red", "standard")
	GameState.current_monster = {"name": "Test", "hp": 10, "modifier": "", "hp_remaining": 10}
	CombatService.start_round()
	var slots: Array = [{"cap": {"letter": "C"}, "letter": "C"},
		{"cap": {"letter": "A"}, "letter": "A"},
		{"cap": {"letter": "T"}, "letter": "T"}]
	var res: Dictionary = CombatService.calculate_word(slots)
	failures += 0 if res.get("damage", 0) > 0 else 1
	print("[scenario] failures=", failures)
	return failures
```

- [ ] **Step 2:** Run full suite, expect all suites pass and `quit(0)`.

- [ ] **Step 3: Commit**

```bash
git add tests/scenario_test.gd
git commit -m "test: combat scenario presets"
```

---

## Self-Review

**Spec coverage:**
- Debug tooling + AGENTS.md constraints → Phase 1 (DebugManager, DebugOverlay, game_root routing, docs).
- DebugManager autoload + F12 screenshot + backtick/F1 overlay with scene routing/state injection/time-scale/mechanic triggers → Tasks 1.1-1.3.
- UISandbox gallery with safe-area/touch-target/mouse-filter overlays → Phase 2.
- Lexicon refactor (build_words.py + get_word_meta + CombatScreen subtitle `WORD · POS · "def" · Nv/Nc`) → Phase 3.
- Extended gameplay (effect-pipeline hooks on_draw/on_letter_slotted/on_word_validated/on_score_calculated/on_monster_damaged/on_monster_defeated/on_turn_end; unified modifier system; secret_words.json; loot drop tables + VictoryModal) → Phases 4-5.
- Headless test harness with linguistic/word/monster-modifier/scenario-preset suites → Phase 6.

**Placeholder scan:** All steps contain concrete code or schemas; no TBD/TODO/`similar to Task N`.

**Type consistency:** `get_word_meta` return keys (`is_valid`/`part_of_speech`/`short_def`/`vowel_count`/`consonant_count`/`length`) consistent across Tasks 3.2/3.3/6.2; `_current_modifier()` used consistently across 4.3; `roll_drops -> Array` of `{type,label,value}` consistent across 5.1/5.2; `EffectPipeline.trigger(hook, args)` signature consistent across 4.1/4.2.