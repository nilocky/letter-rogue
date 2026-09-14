# Letter Rogue — Scoring Trace Pipeline & High-Juice Combat Animation Design

## Overview

Refactor the scoring pipeline to produce an itemized execution log (`ScoringTrace`) decoupling calculation from presentation. Overhaul the scoring animation in `CombatScreen` with Balatro-style sequential pacing, per-step visual juice, Artisan rail visual display, and monster hitstop.

---

## 1. Data Contract: `ScoringTrace`

`CombatService.calculate_word()` returns an enhanced dict with a new `"trace"` key:

```gdscript
# ScoringEvent dictionary shape:
{
    step_type: String,       # "tile_hop" | "tile_retrigger" | "form_ignite" | "artisan_trigger" | "clash_resolve"
    source_index: int,       # slot index (tiles, artisans) or -1 for form/clash
    label: String,           # letter, form name, artisan name
    delta_chips: float,      # added to chips accumulator
    delta_mult: float,       # added to mult accumulator
    x_mult: float,           # multiplicative factor applied to mult (1.0 = none)
    running_chips: float,    # chips after this step
    running_mult: float,     # mult after this step
    annotation: String       # display badge ("+4", "x1.5", "RE-TRIGGER!")
}
```

Backward compat: existing return fields (`damage`, `money`, `letter_scores`, `form_data`, `flat_bonus`) preserved.

---

## 2. `CombatService.calculate_word()` Refactor

### Internal helpers

```gdscript
static func _trace_event(step_type, source_index, label, delta_chips, delta_mult, x_mult, running_chips, running_mult, annotation) -> Dictionary
```

### Phase A: Tile Hops (with retrigger support)

For each tile slot (left to right):
1. Compute base contribution (letter score + pack + ability + finish + sticker + condition + boss modifier)
2. Emit `tile_hop` event with `delta_chips = contribution`, `running_chips` updated
3. If Red sticker or Lubed condition: emit `tile_retrigger` event repeating the same contribution (chips applied again, annotation = "RE-TRIGGER!")

Monster modifier zeroing (vowel_lock/consonant_lock/silence) applied per tile as before.

### Phase B: Word Form Ignition

1. Detect form via `WordFormService.detect(slots)`
2. Emit `form_ignite` event:
   - `delta_chips = form_base`
   - `delta_mult = length_mult × form_mult`
   - running_chips updated, running_mult set from 1.0 to the product
   - annotation = form name badge

### Phase C: Artisan Cascade

For each artisan slot (0→4, left to right):
1. Evaluate trigger; if triggered:
2. Compute effect (flat +Mult or X-Mult)
3. Emit `artisan_trigger` event:
   - `delta_chips = 0`, `delta_mult = flat_value` for +Mult
   - `x_mult = xmult_value` for X-Mult
   - running_chips/running_mult updated
   - annotation = "+N" or "×N"

### Phase D: Clash Resolve

Emit single `clash_resolve` event:
- `running_chips = final_chips`, `running_mult = final_mult`
- `annotation = "= N DMG"` where N = roundi(chips × mult) + flat_bonus

### Trace drives damage computation

`total_damage` = final `roundi(running_chips × running_mult) + flat_bonus`

---

## 3. Scoring Animation Overhaul in `CombatScreen.gd`

### State Machine

```
IDLE → SCORING → (skip request) → SKIP_PENDING → ... → COMMIT → IDLE
```

Variables:
- `_is_scoring: bool` — true during scoring animation
- `_skip_requested: bool` — set true on screen tap during scoring

On `_gui_input` during scoring: `_skip_requested = true`

### Step-by-Step Sequence (driven by trace)

#### Banner Reveal
- `_banner_show()`: fade in + scale bounce (0.2s, TRANS_BACK)
- Chips label initialized to 0, Mult label to ×1.0

#### Phase A: Sequential Tile Hops
For each `tile_hop` event in trace:
- If `_skip_requested`: accumulate chips only, no animation, skip to Phase D
- WordRuneSlot hops up -12px (0.12s, TRANS_QUAD EASE_OUT), slams back
- `_spawn_tile_score()` with score float + ParticleBurst
- `_spawn_floating_text()` if ability modifier present
- Chips label scale punch (1.0→1.25→1.0, 0.12s)
- Audio: `AudioManager.play("tile_hop", 1.0 + index * 0.06)` (chromatic pitch climb)
- Pause 0.2s between tiles

For `tile_retrigger` events:
- Same tile hops again (smaller hop, -6px)
- Annotation "RE-TRIGGER!" floats up
- Same chip accumulation + punch

#### Phase B: Word Form Ignition
- Show `%WordMetaLabel` (word metadata)
- Display form name badge annotation
- Mult panel pulse (scale 1.0→1.25→1.0, 0.15s)
- Mult label ramps from 1.0 to running_mult (0.3s, TRANS_LINEAR)
- Chips updated with form_base
- Audio: `AudioManager.play("form_ignite")`

#### Phase C: Artisan Cascade
For each `artisan_trigger` event:
- If `_skip_requested`: accumulate mult only, no animation
- Corresponding ArtisanSlot shakes (rotation -4° to +4°, 0.15s) and glows
- Number trail flies from ArtisanSlot to Mult counter
- Mult counter punch (red pulse, scale 1.0→1.3→1.0)
- For X-Mult: screen micro-shake (offset 2-3px, 0.1s)
- Audio: `AudioManager.play("artisan_trigger")`

#### Phase D: The Clash
- Chips box and Mult box accelerate toward center
- Shockwave via `ParticleBurst.burst()`
- `%TotalDamageLabel` reveals with bounce (scale 0.5→1.4→1.0, 0.2s, TRANS_BACK)
- Spawn energy projectile to monster center (0.25s, TRANS_CUBIC)
- On impact:
  - Monster sprite flash white (modulate = Color(5,5,5), 0.06s)
  - Monster knockback 6px (0.1s), then settle (0.15s)
  - Screen shake (magnitude 6.0, 0.2s)
  - PixelHPBar smooth drain (0.35s)
  - `_spawn_damage_float()` floating damage text
- Audio: `AudioManager.play("slam_impact")`

#### Resolution
- `CombatService.commit_word(_slots)`
- Banner fade out (0.2s)
- `_banner_reset()`, `_animating = false`

### Skip behavior
- `_skip_requested = true`: collapses all remaining Phase A/B/C delays
- Running totals set to final trace values instantly (chips = final_trace.running_chips, mult = final_trace.running_mult)
- Jumps to Phase D immediately after current step completes
- Phase D animation plays at full timing (the clash is the payoff, skip shouldn't rob it)

---

## 4. Artisan Rail Visual Display

### New files

- `scenes/components/ArtisanSlot.tscn` — single slot scene
- `scripts/components/ArtisanSlot.gd` — slot controller
- `scenes/components/ArtisanRailDisplay.tscn` — 5-slot rail container
- `scripts/components/ArtisanRailDisplay.gd` — rail display manager

### ArtisanSlot

- `TextureRect` for artisan icon (from `res://assets/artisans/`)
- `Label` for artisan name
- States: empty (dim outline), equipped (normal), triggering (glow + shake)
- Method `set_artisan(data: Dictionary)`, `clear()`, `trigger_glow()`, `trigger_shake()`

### ArtisanRailDisplay

- Fixed 5-slot HBoxContainer, each child an `ArtisanSlot`
- `refresh()`: reads `ArtisanRailManager.rail`, populates slots
- `trigger_slot(index)`: animates glow + shake on slot at index
- Called during Phase C animation in `CombatScreen`

### Scene placement

Added to `CombatScreen.tscn` between the hand container and the word strip, centered, same width as word strip. Visibility: shown only when at least one artisan equipped.

---

## 5. Minimal `AudioManager` Autoload

### New file

- `scripts/autoload/AudioManager.gd`

### Interface

```gdscript
func play(sfx_id: String, pitch: float = 1.0) -> void
```

### Behavior
- Looks up `res://assets/audio/{sfx_id}.ogg` (or `.wav`)
- If file exists: create `AudioStreamPlayer2D`, assign stream, set `pitch_scale`, play, auto-free on finished
- If file missing: no-op (graceful — game runs headless or without audio assets)
- Caches loaded streams to avoid repeated disk reads

### Registered SFX IDs (for this work)
- `tile_hop` — ascending pitch per tile
- `form_ignite` — word form activation
- `artisan_trigger` — artisan cascade
- `slam_impact` — final damage hit

Additional SFX IDs can be added later without changing the interface.

---

## 6. Monster Hitstop & Screen Shake

### Screen shake utility

Extract inline shake from `CombatScreen._projectile_to_monster()` into reusable:

```gdscript
# scripts/components/ScreenShake.gd (static utility)
static func shake(node: Node, magnitude: float, duration: float) -> void
```

Called with `%MonsterDisplayArea`, `6.0`, `0.2` during Phase D impact.

### Monster hitstop sequence (during Phase D impact)

1. `monster_sprite.modulate = Color(5, 5, 5, 1)` (0.06s flash)
2. `monster_sprite.position.y += 6` (0.1s knockback)
3. `monster_sprite.position.y` returns to 0 (0.15s settle, TRANS_BACK)
4. `ScreenShake.shake(%MonsterDisplayArea, 6.0, 0.2)`
5. `PixelHPBar` smooth drain via tween (0.35s)
6. Damage float text near HP bar

---

## Files Changed

| File | Change |
|------|--------|
| `scripts/autoload/CombatService.gd` | Rewrite `calculate_word()` to emit trace; add `_trace_event()` helper |
| `scripts/screens/CombatScreen.gd` | Rewrite `_play_score_animation()` to drive from trace; add state machine, skip, Artisan cascade anim, monster hitstop |
| `scripts/autoload/AudioManager.gd` | **New** — minimal SFX autoload |
| `scripts/components/ArtisanSlot.gd` | **New** — single artisan slot display |
| `scenes/components/ArtisanSlot.tscn` | **New** — artisan slot scene |
| `scripts/components/ArtisanRailDisplay.gd` | **New** — 5-slot rail display |
| `scenes/components/ArtisanRailDisplay.tscn` | **New** — rail display scene |
| `scripts/components/ScreenShake.gd` | **New** — static screen shake utility |
| `scenes/CombatScreen.tscn` | Add ArtisanRailDisplay node |
| `project.godot` | Add `AudioManager` autoload entry |

---

## Edge Cases

- **Zero active artisans**: Phase C produces no events, skips immediately
- **1-2 letter words**: no form detection, Phase B produces `form_ignite` with delta_chips=0, delta_mult=0, x_mult=1.0 (length_mult=1.0, no form)
- **Skip during Phase A**: totals accumulate silently, jump to Phase D
- **All tiles silenced (boss modifier)**: tile_hop events with 0 delta_chips, animation still plays (shows "0" hop)
- **No AudioManager singleton**: all `AudioManager.play()` calls guarded with `if Engine.has_singleton("AudioManager")`
