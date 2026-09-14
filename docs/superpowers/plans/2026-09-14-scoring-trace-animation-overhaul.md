# Scoring Trace Pipeline & High-Juice Combat Animation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor scoring into a traced pipeline (`ScoringTrace`) and overhaul combat animation with Balatro-style juice, Artisan rail display, monster hitstop, and minimal AudioManager.

**Architecture:** `CombatService.calculate_word()` produces an ordered trace of scoring events. `CombatScreen._play_score_animation()` drives from the trace instead of recomputing ad-hoc. New components: `ArtisanSlot`/`ArtisanRailDisplay` for visual rail, `AudioManager` for SFX, `ScreenShake` utility. All animation guards check `_skip_requested` for fast-forward.

**Tech Stack:** Godot 4.7.x typed GDScript, CPUParticles2D, Tweens

**Spec:** `docs/superpowers/specs/2026-09-14-scoring-trace-animation-overhaul-design.md`

## Global Constraints

- Typed GDScript (`var x: int`, `func f() -> void`)
- No external dependencies — Godot stdlib only
- All `AudioManager.play()` calls guarded with `if Engine.has_singleton("AudioManager")`
- Container-based responsive UI — no fixed positions outside HandTileContainer
- Tween lifecycle: always `create_tween()`, never orphaned tweens
- `%UniqueName` syntax for scene node references

---

### Task 1: ScoringTrace Data Contract & CombatService Refactor

**Files:**
- Modify: `scripts/autoload/CombatService.gd`
- Test: `tests/test_scoring_trace.gd`

**Interfaces:**
- Consumes: `WordFormService.detect(slots)`, `ArtisanRailManager.cascade()`, `WordService.length_multiplier()`
- Produces: `CombatService.calculate_word()` now returns `{"damage", "money", "letter_scores", "form_data", "flat_bonus", "trace": [ScoringEvent...]}`

- [ ] **Step 1: Write failing test for trace structure**

```gdscript
# tests/test_scoring_trace.gd
extends GutTest

func test_calculate_word_returns_trace() -> void:
    var slots := _make_slots(["C", "A", "T"])
    var res := CombatService.calculate_word(slots)
    assert_has(res, "trace", "calculate_word should return a trace")
    assert_gt(res["trace"].size(), 0, "trace should have at least one event")
    var first: Dictionary = res["trace"][0]
    assert_has(first, "step_type")
    assert_has(first, "running_chips")
    assert_has(first, "running_mult")

func test_trace_has_correct_phases() -> void:
    var slots := _make_slots(["H", "E", "L", "L", "O"])
    var res := CombatService.calculate_word(slots)
    var types: Array = res["trace"].map(func(e): return e["step_type"])
    assert_has(types, "tile_hop")
    assert_has(types, "form_ignite")
    assert_has(types, "clash_resolve")

func test_trace_artisan_cascade() -> void:
    # Temporarily equip a known artisan in slot 0
    var artisan := {"id": "test_art", "trigger": {"type": "word_length", "min": 0}, "effect": {"type": "add_flat", "value": 10}}
    ArtisanRailManager.rail[0] = artisan
    var slots := _make_slots(["C", "A", "T"])
    var res := CombatService.calculate_word(slots)
    ArtisanRailManager.rail[0] = null
    var types: Array = res["trace"].map(func(e): return e["step_type"])
    assert_has(types, "artisan_trigger")

func test_trace_skip_for_short_word() -> void:
    var slots := _make_slots(["A", "T"])
    var res := CombatService.calculate_word(slots)
    var types: Array = res["trace"].map(func(e): return e["step_type"])
    assert_has(types, "form_ignite", "short words still produce form_ignite (length_mult=1.0, no form)")

func _make_slots(letters: Array) -> Array:
    var slots := []
    for letter in letters:
        slots.append({"cap": {"letter": letter, "is_symbol": false}, "letter": letter, "hand_idx": -1})
    return slots
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --script tests/run_tests.gd`
Expected: test_scoring_trace fails because calculate_word has no "trace" key

- [ ] **Step 3: Add `_trace_event()` helper and refactor `calculate_word()`**

Add helper:
```gdscript
static func _trace_event(
    step_type: String,
    source_index: int,
    label: String,
    delta_chips: float,
    delta_mult: float,
    x_mult: float,
    running_chips: float,
    running_mult: float,
    annotation: String
) -> Dictionary:
    return {
        "step_type": step_type,
        "source_index": source_index,
        "label": label,
        "delta_chips": delta_chips,
        "delta_mult": delta_mult,
        "x_mult": x_mult,
        "running_chips": running_chips,
        "running_mult": running_mult,
        "annotation": annotation
    }
```

Rewrite `calculate_word()` to build `var trace: Array = []` as it computes each phase:

**Phase A** — inside the slot loop, after computing `contribution`:
```gdscript
trace.append(_trace_event("tile_hop", i, str(s["letter"]), contribution, 0.0, 1.0, total_base, 1.0, "+%d" % roundi(contribution)))
# If Red sticker or Lubed condition: append retrigger
if not disabled and (str(cap.get("sticker", "")) == "red" or str(cap.get("condition", "")) == "lubed"):
    trace.append(_trace_event("tile_retrigger", i, str(s["letter"]), contribution, 0.0, 1.0, total_base + contribution, 1.0, "RE-TRIGGER!"))
    total_base += contribution  # apply retrigger contribution
```

**Phase B** — after form detection:
```gdscript
var running_chips := total_base + float(form_base)
var running_mult := length_mult * form_mult
trace.append(_trace_event("form_ignite", -1, form_data.get("name", ""), float(form_base), running_mult - 1.0, 1.0, running_chips, running_mult, form_data.get("form_id", "")))
```

**Phase C** — inside artisan cascade, for each triggered artisan:
```gdscript
# After computing flat_contribution or xmult_contribution:
if flat_contribution > 0:
    running_mult += float(flat_contribution)
    trace.append(_trace_event("artisan_trigger", slot, artisan_name, 0.0, float(flat_contribution), 1.0, running_chips, running_mult, "+%d" % flat_contribution))
if xmult_contribution > 1.0:
    running_mult *= xmult_contribution
    trace.append(_trace_event("artisan_trigger", slot, artisan_name, 0.0, 0.0, xmult_contribution, running_chips, running_mult, "x%.1f" % xmult_contribution))
```

**Phase D:**
```gdscript
var final_damage := roundi(running_chips * running_mult) + flat_bonus
trace.append(_trace_event("clash_resolve", -1, "", 0.0, 0.0, 1.0, running_chips, running_mult, "= %d DMG" % final_damage))
```

Return `trace` in the result dict:
```gdscript
var result: Dictionary = {
    "damage": final_damage,
    "money": money,
    "letter_scores": letter_scores,
    "form_data": form_data,
    "flat_bonus": flat_bonus,
    "trace": trace
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --script tests/run_tests.gd`
Expected: all test suites pass

- [ ] **Step 5: Commit**

```bash
git add scripts/autoload/CombatService.gd tests/test_scoring_trace.gd
git commit -m "feat: ScoringTrace pipeline with event-driven calculate_word"
```

---

### Task 2: Minimal AudioManager Autoload

**Files:**
- Create: `scripts/autoload/AudioManager.gd`
- Modify: `project.godot` (add autoload entry)

**Interfaces:**
- Produces: `AudioManager.play(sfx_id: String, pitch: float = 1.0) -> void`

- [ ] **Step 1: Write AudioManager.gd**

```gdscript
extends Node
## Minimal SFX player. Plays from res://assets/audio/{sfx_id}.ogg.
## No-op if file missing. Caches loaded streams.

var _cache: Dictionary = {}

func play(sfx_id: String, pitch: float = 1.0) -> void:
    if not _cache.has(sfx_id):
        var path := "res://assets/audio/%s.ogg" % sfx_id
        if not ResourceLoader.exists(path):
            path = "res://assets/audio/%s.wav" % sfx_id
            if not ResourceLoader.exists(path):
                return
        var stream: AudioStream = load(path)
        if stream == null:
            return
        _cache[sfx_id] = stream

    var player := AudioStreamPlayer2D.new()
    player.stream = _cache[sfx_id]
    player.pitch_scale = pitch
    player.finished.connect(player.queue_free)
    add_child(player)
    player.play()
```

- [ ] **Step 2: Add autoload to project.godot**

Add to `project.godot` autoload section:
```
AudioManager="*res://scripts/autoload/AudioManager.gd"
```

Use the GDScript-based approach (match existing autoload format from project.godot).

- [ ] **Step 3: Verify autoload works**

Run: `godot --headless --eval "print(Engine.has_singleton(\"AudioManager\"))"`
Expected: prints True

- [ ] **Step 4: Create placeholder audio files**

Create empty placeholder `.ogg` files so the game doesn't silently skip:
- `res://assets/audio/tile_hop.ogg`
- `res://assets/audio/form_ignite.ogg`
- `res://assets/audio/artisan_trigger.ogg`
- `res://assets/audio/slam_impact.ogg`

These can be 1-second silence generated via any tool, or just empty files. For now, create minimal valid OGG files (or use .wav alternatives if easier). The AudioManager guards against missing files, so these can be real SFX added later.

- [ ] **Step 5: Commit**

```bash
git add scripts/autoload/AudioManager.gd project.godot res/assets/audio/
git commit -m "feat: AudioManager autoload with guard-based SFX playback"
```

---

### Task 3: ScreenShake Utility

**Files:**
- Create: `scripts/components/ScreenShake.gd`

**Interfaces:**
- Produces: `ScreenShake.shake(node: Node, magnitude: float, duration: float) -> void`

- [ ] **Step 1: Write ScreenShake.gd**

```gdscript
class_name ScreenShake
## Static screen shake utility. Shakes a node's position for `duration` seconds.

static func shake(node: Node, magnitude: float, duration: float) -> void:
    var orig: Vector2 = node.position
    var tw := node.create_tween()
    var steps := maxi(ceili(duration / 0.05), 4)
    for _i in range(steps):
        var offset := Vector2(
            randf_range(-magnitude, magnitude),
            randf_range(-magnitude * 0.6, magnitude * 0.6)
        )
        tw.tween_callback(node.set_position.bind(orig + offset))
        tw.tween_interval(duration / float(steps))
    tw.tween_callback(node.set_position.bind(orig))
```

- [ ] **Step 2: Commit**

```bash
git add scripts/components/ScreenShake.gd
git commit -m "feat: ScreenShake static utility for reusable camera/node shake"
```

---

### Task 4: Artisan Rail Visual Display

**Files:**
- Create: `scripts/components/ArtisanSlot.gd`
- Create: `scenes/components/ArtisanSlot.tscn`
- Create: `scripts/components/ArtisanRailDisplay.gd`
- Create: `scenes/components/ArtisanRailDisplay.tscn`
- Modify: `scenes/CombatScreen.tscn` (add ArtisanRailDisplay node)
- Modify: `scripts/screens/CombatScreen.gd` (wire ArtisanRailDisplay)

**Interfaces:**
- Consumes: `ArtisanRailManager.rail` (Array, 5 slots)
- Produces: `ArtisanRailDisplay` node with `refresh()`, `trigger_slot(index)` methods

- [ ] **Step 1: Write ArtisanSlot.gd**

```gdscript
extends PanelContainer
class_name ArtisanSlot

@onready var icon_rect: TextureRect = %IconRect
@onready var name_label: Label = %NameLabel
@onready var empty_placeholder: Label = %EmptyPlaceholder

func set_artisan(data: Dictionary) -> void:
    if data.is_empty():
        clear()
        return
    name_label.text = str(data.get("name", "?"))
    var icon_path: String = str(data.get("icon", ""))
    if icon_path != "":
        icon_rect.texture = load(icon_path) as Texture2D
    icon_rect.show()
    name_label.show()
    empty_placeholder.hide()
    modulate = Color.WHITE

func clear() -> void:
    icon_rect.texture = null
    icon_rect.hide()
    name_label.text = ""
    name_label.hide()
    empty_placeholder.show()
    modulate = Color(0.3, 0.3, 0.3, 0.5)

func trigger_glow() -> void:
    var tw := create_tween()
    modulate = Color(2.0, 2.0, 1.0, 1.0)
    tw.tween_property(self, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_LINEAR)

func trigger_shake() -> void:
    var orig := rotation
    var tw := create_tween()
    tw.tween_property(self, "rotation", -4.0, 0.08).set_trans(Tween.TRANS_LINEAR)
    tw.tween_property(self, "rotation", 4.0, 0.08).set_trans(Tween.TRANS_LINEAR)
    tw.tween_property(self, "rotation", -2.0, 0.06).set_trans(Tween.TRANS_LINEAR)
    tw.tween_property(self, "rotation", orig, 0.06).set_trans(Tween.TRANS_LINEAR)
```

- [ ] **Step 2: Create ArtisanSlot.tscn**

Root: `PanelContainer` (custom_minimum_size 80x80, theme with dark StyleBoxFlat)
- `IconRect` (%IconRect, TextureRect, centered, size 48x48, position centered)
- `NameLabel` (%NameLabel, Label, bottom of slot, font_size 10, micro text)
- `EmptyPlaceholder` (%EmptyPlaceholder, Label, center, text "—", Color(0.4, 0.4, 0.4))

Attach `ArtisanSlot.gd` as script.

- [ ] **Step 3: Write ArtisanRailDisplay.gd**

```gdscript
extends HBoxContainer
class_name ArtisanRailDisplay

var _slots: Array = []

func _ready() -> void:
    _build_slots()

func _build_slots() -> void:
    for child in get_children():
        child.queue_free()
    _slots.clear()
    for i in 5:
        var slot := preload("res://scenes/components/ArtisanSlot.tscn").instantiate() as ArtisanSlot
        add_child(slot)
        _slots.append(slot)

func refresh() -> void:
    for i in 5:
        var artisan: Dictionary = ArtisanRailManager.get_slot(i)
        _slots[i].set_artisan(artisan)

func trigger_slot(index: int) -> void:
    if index >= 0 and index < _slots.size():
        _slots[index].trigger_glow()
        _slots[index].trigger_shake()
```

- [ ] **Step 4: Create ArtisanRailDisplay.tscn**

Root: `HBoxContainer` with theme constant override `separation = 8`, alignment center, custom_minimum_size = full width, height 90.
Attach `ArtisanRailDisplay.gd`.

- [ ] **Step 5: Add to CombatScreen.tscn**

Add `ArtisanRailDisplay` node as child of CombatScreen root, after the word strip container. Give it `%ArtisanRail` unique name.

- [ ] **Step 6: Wire in CombatScreen.gd**

Add to CombatScreen.gd:
```gdscript
@onready var artisan_rail: ArtisanRailDisplay = %ArtisanRail
```

In `show_round()`:
```gdscript
artisan_rail.refresh()
```

- [ ] **Step 7: Commit**

```bash
git add scripts/components/ArtisanSlot.gd scenes/components/ArtisanSlot.tscn scripts/components/ArtisanRailDisplay.gd scenes/components/ArtisanRailDisplay.tscn scenes/CombatScreen.tscn scripts/screens/CombatScreen.gd
git commit -m "feat: Artisan rail visual display with 5-slot UI"
```

---

### Task 5: CombatScreen Animation Overhaul

**Files:**
- Modify: `scripts/screens/CombatScreen.gd`

**Interfaces:**
- Consumes: `CombatService.calculate_word().trace`, `AudioManager.play()`, `ArtisanRailDisplay.trigger_slot()`, `ScreenShake.shake()`

- [ ] **Step 1: Add state variables and skip handling**

Add to CombatScreen.gd's variable section:
```gdscript
var _is_scoring: bool = false
var _skip_requested: bool = false
```

Update `_gui_input`:
```gdscript
func _gui_input(event: InputEvent) -> void:
    if _animating and event is InputEventMouseButton and not event.pressed:
        _skip_requested = true
```

- [ ] **Step 2: Rewrite `_play_score_animation()` to drive from trace**

Replace the existing `_play_score_animation()` body entirely. Pseudocode structure:

```gdscript
func _play_score_animation() -> void:
    _animating = true
    _is_scoring = true
    _skip_requested = false
    _set_controls_enabled(false)

    var res: Dictionary = CombatService.calculate_word(_slots, false)
    var trace: Array = res.get("trace", [])

    # Banner entrance
    _banner_show()
    if not _skip_requested:
        await get_tree().create_timer(0.2).timeout

    var current_chips: float = 0.0
    var current_mult: float = 1.0

    for event in trace:
        if _skip_requested:
            # Fast-forward: update running totals from event
            current_chips = event["running_chips"]
            current_mult = event["running_mult"]
            continue

        match event["step_type"]:
            "tile_hop":
                await _animate_tile_hop(event, current_chips)
                current_chips = event["running_chips"]
            "tile_retrigger":
                await _animate_tile_retrigger(event, current_chips)
                current_chips = event["running_chips"]
            "form_ignite":
                await _animate_form_ignite(event, current_chips, current_mult)
                current_chips = event["running_chips"]
                current_mult = event["running_mult"]
            "artisan_trigger":
                await _animate_artisan_trigger(event, current_mult)
                current_mult = event["running_mult"]
            "clash_resolve":
                await _animate_clash(event, res["damage"], current_chips, current_mult)

    # Apply final values
    base_score_label.text = "%d" % roundi(current_chips)
    mult_score_label.text = "×%.1f" % current_mult

    # HP drop + commit (same as current code)
    await _hp_drop_and_commit(res["damage"])
```

- [ ] **Step 3: Write `_animate_tile_hop(event, current_chips)`**

```gdscript
func _animate_tile_hop(event: Dictionary, current_chips: float) -> void:
    var idx: int = event["source_index"]
    var tiles: Array = _get_word_tiles()
    if idx < 0 or idx >= tiles.size():
        return
    var tile: Control = tiles[idx] as Control
    var origin: Vector2 = tile.global_position

    # Hop up -12px then slam back
    var hop := create_tween()
    hop.tween_property(tile, "global_position", origin + Vector2(0, -12), 0.12) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    hop.tween_property(tile, "global_position", origin, 0.15) \
        .set_trans(Tween.TRANS_LINEAR)

    # Score float + particle
    _spawn_tile_score(tile, event["delta_chips"])

    # Chips label punch
    base_score_label.text = "%d" % roundi(event["running_chips"])
    var punch := create_tween()
    base_score_label.scale = Vector2(1.25, 1.25)
    punch.tween_property(base_score_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_LINEAR)

    # Ability floating text
    if idx < _slots.size():
        var cap: Dictionary = _slots[idx].get("cap", {})
        if event["delta_chips"] > 0.0 and _has_ability_modifier(cap):
            _spawn_floating_text(tile, _ability_float_text(cap, event["delta_chips"]))

    # Audio
    if Engine.has_singleton("AudioManager"):
        AudioManager.play("tile_hop", 1.0 + float(idx) * 0.06)

    await hop.finished
    if not _skip_requested:
        await get_tree().create_timer(0.15).timeout

func _get_word_tiles() -> Array:
    var tiles: Array = []
    for c in word_strip.get_children():
        if c is WordRuneSlot:
            tiles.append(c)
    return tiles
```

- [ ] **Step 4: Write `_animate_tile_retrigger(event, current_chips)`**

```gdscript
func _animate_tile_retrigger(event: Dictionary, current_chips: float) -> void:
    var idx: int = event["source_index"]
    var tiles: Array = _get_word_tiles()
    if idx < 0 or idx >= tiles.size():
        return
    var tile: Control = tiles[idx] as Control
    var origin: Vector2 = tile.global_position

    # Smaller hop for retrigger
    var hop := create_tween()
    hop.tween_property(tile, "global_position", origin + Vector2(0, -6), 0.08) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    hop.tween_property(tile, "global_position", origin, 0.1) \
        .set_trans(Tween.TRANS_LINEAR)

    # "RE-TRIGGER!" floating text
    _spawn_floating_text(tile, event["annotation"])

    # Chips label punch
    base_score_label.text = "%d" % roundi(event["running_chips"])
    var punch := create_tween()
    base_score_label.scale = Vector2(1.15, 1.15)
    punch.tween_property(base_score_label, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_LINEAR)

    await hop.finished
    if not _skip_requested:
        await get_tree().create_timer(0.1).timeout
```

- [ ] **Step 5: Write `_animate_form_ignite(event, current_chips, current_mult)`**

```gdscript
func _animate_form_ignite(event: Dictionary, current_chips: float, current_mult: float) -> void:
    # Word metadata
    var word := ""
    for s in _slots:
        word += str(s["letter"])
    if word.length() >= 3:
        var meta: Dictionary = WordService.get_word_meta(word)
        if meta.get("is_valid", false):
            word_meta_label.text = "%s · %s · \"%s\" · V%d/C%d" % [
                word, meta["part_of_speech"], meta["short_def"],
                meta["vowel_count"], meta["consonant_count"]
            ]
            word_meta_label.show()

    # Form base damage lands into chips
    if event["delta_chips"] > 0:
        base_score_label.text = "%d" % roundi(event["running_chips"])
        var chip_punch := create_tween()
        base_score_label.scale = Vector2(1.3, 1.3)
        chip_punch.tween_property(base_score_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_LINEAR)

    if _skip_requested:
        mult_score_label.text = "×%.1f" % event["running_mult"]
        return

    await get_tree().create_timer(0.2).timeout

    # Mult panel pulse
    if Engine.has_singleton("AudioManager"):
        AudioManager.play("form_ignite")

    var scale_pulse := create_tween()
    mult_panel.scale = Vector2(1.25, 1.25)
    scale_pulse.tween_property(mult_panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_LINEAR)

    mult_score_label.add_theme_color_override("font_color", Color(1, 0.34, 0.13, 1))
    mult_sub_label.add_theme_color_override("font_color", Color(1, 0.6, 0.3, 1))

    # Ramp mult display
    if event["delta_mult"] > 0 or event["running_mult"] > 1.0:
        var ramp := create_tween()
        ramp.tween_method(_ramp_mult_display, 1.0, event["running_mult"], 0.3) \
            .set_trans(Tween.TRANS_LINEAR)
        await ramp.finished
    else:
        mult_score_label.text = "×%.1f" % event["running_mult"]

    await get_tree().create_timer(0.2).timeout
```

- [ ] **Step 6: Write `_animate_artisan_trigger(event, current_mult)`**

```gdscript
func _animate_artisan_trigger(event: Dictionary, current_mult: float) -> void:
    var idx: int = event["source_index"]
    artisan_rail.trigger_slot(idx)

    # Mult counter update
    mult_score_label.text = "×%.1f" % event["running_mult"]

    # Scale punch on mult
    var punch := create_tween()
    mult_score_label.scale = Vector2(1.3, 1.3)
    punch.tween_property(mult_score_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_LINEAR)

    # X-Mult gets screen micro-shake
    if event["x_mult"] > 1.0:
        ScreenShake.shake(%MonsterDisplayArea, 3.0, 0.1)

    if Engine.has_singleton("AudioManager"):
        AudioManager.play("artisan_trigger")

    if not _skip_requested:
        await get_tree().create_timer(0.2).timeout
```

- [ ] **Step 7: Write `_animate_clash(event, final_damage, chips, mult)`**

```gdscript
func _animate_clash(event: Dictionary, final_damage: int, chips: float, mult: float) -> void:
    # Final values
    base_score_label.text = "%d" % roundi(chips)
    mult_score_label.text = "×%.1f" % mult

    # Chips & Mult boxes sync pulse
    var sync_pulse := create_tween()
    sync_pulse.set_parallel(true)
    base_score_label.scale = Vector2(1.15, 1.15)
    mult_score_label.scale = Vector2(1.15, 1.15)
    sync_pulse.tween_property(base_score_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_LINEAR)
    sync_pulse.tween_property(mult_score_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_LINEAR)

    if _skip_requested:
        total_shelf.show()
        total_damage_label.text = "= %d DMG" % final_damage
        return

    await get_tree().create_timer(0.15).timeout

    # Total damage reveal
    total_shelf.show()
    total_damage_label.text = "= %d DMG" % final_damage
    var flash := create_tween()
    total_damage_label.scale = Vector2(0.5, 0.5)
    flash.tween_property(total_damage_label, "scale", Vector2(1.4, 1.4), 0.15) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    flash.tween_property(total_damage_label, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_LINEAR)

    # Particle burst on banner
    ParticleBurstFx.burst(self, total_damage_label.global_position + Vector2(0, -20), Color(1, 0.85, 0.2), 12, {"vel_min": 60, "vel_max": 120, "lifetime": 0.4})

    if Engine.has_singleton("AudioManager"):
        AudioManager.play("slam_impact")

    await get_tree().create_timer(0.25).timeout

    # Projectile to monster
    await _projectile_to_monster(final_damage)

    # Monster hitstop
    _monster_hitstop(final_damage)
```

- [ ] **Step 8: Write `_monster_hitstop(damage)`**

```gdscript
func _monster_hitstop(damage: int) -> void:
    # White flash
    var flash_tw := create_tween()
    flash_tw.tween_property(monster_sprite, "modulate", Color(5, 5, 5, 1), 0.03)
    flash_tw.tween_property(monster_sprite, "modulate", Color.WHITE, 0.08)

    # Knockback
    var orig_pos := monster_sprite.position
    var kb_tw := create_tween()
    kb_tw.tween_property(monster_sprite, "position", orig_pos + Vector2(0, 6), 0.1) \
        .set_trans(Tween.TRANS_LINEAR)
    kb_tw.tween_property(monster_sprite, "position", orig_pos, 0.15) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

    # Screen shake
    ScreenShake.shake(%MonsterDisplayArea, 6.0, 0.2)

    # Squash hit (existing)
    _squash_hit()

    # HP bar drain
    var hp_total: int = GameState.monster_hp_scaled()
    var hp_remaining: int = int(GameState.current_monster.get("hp_remaining", hp_total))
    var hp_new: int = maxi(hp_remaining - damage, 0)
    var hp_from: float = hp_bar.value
    var hp_tween := create_tween()
    hp_tween.tween_method(func(v: float) -> void: hp_bar.value = v, hp_from, float(hp_new), 0.35) \
        .set_trans(Tween.TRANS_LINEAR)

    _spawn_damage_float(damage)
    await hp_tween.finished
```

- [ ] **Step 9: Update `_hp_drop_and_commit(damage)` — extract remaining logic**

After `_monster_hitstop` completes, do banner fade + commit:
```gdscript
func _hp_drop_and_commit(final_damage: int) -> void:
    # Fade banner
    if not _skip_requested:
        var fade := create_tween()
        fade.tween_property(scoring_banner, "modulate:a", 0.0, 0.2)
        await fade.finished

    CombatService.commit_word(_slots)
    _banner_reset()
```

- [ ] **Step 10: Update `_projectile_to_monster()` to not duplicate hitstop**

The existing `_projectile_to_monster()` has inline shake and flash. Since hitstop is now in `_monster_hitstop()`, remove the inline shake/flash from `_projectile_to_monster()`:

```gdscript
func _projectile_to_monster(dmg: int) -> void:
    # ... keep projectile tween + particle burst ...
    # Remove the inline shake loop, flash, and _squash_hit — those are now in _monster_hitstop
```

- [ ] **Step 11: Update `_hp_drop` path in existing code**

The HP drop logic moves from inline in `_play_score_animation()` into `_monster_hitstop()`. Remove the old HP drop code from `_play_score_animation()`.

- [ ] **Step 12: Run tests to verify no regressions**

Run: `godot --headless --script tests/run_tests.gd`
Expected: all test suites pass

- [ ] **Step 13: Commit**

```bash
git add scripts/screens/CombatScreen.gd
git commit -m "feat: overhaul scoring animation with trace-driven playback, skip, artisan cascade, monster hitstop"
```
