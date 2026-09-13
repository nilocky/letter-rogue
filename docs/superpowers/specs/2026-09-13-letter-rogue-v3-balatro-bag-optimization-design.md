# Letter Rogue V3 — Balatro-Style Mechanics & Bag Optimization

> Design document for adapting Balatro systems into Letter Rogue's mechanical keyboard dungeon rune universe, with play-and-refill bag mechanics, Word Form engine, 4-phase scoring pipeline, Artisan Keycap rail, consumables, and Depth progression.

---

## 1. Overview

Transform Letter Rogue's core loop from a simple "draw→spell→score→return tiles" model into a rich Balatro-inspired system where:

- **Bag is persistent** — tiles consumed on play go to a discard pile, unused tiles stay in hand
- **Word Forms** replace poker hands — Trio/Quartet/Palindrome/Double-Tap detection with per-form base damage and multipliers
- **Artisan Keycaps** replace Jokers — a 5-slot macro rail above the word strip with left-to-right cascade triggers
- **Consumables** replace Tarot/Spectral cards — Modder's Toolkit and Cursed Hardware for bag sculpting
- **Dungeon Depths** replace Blinds/Antes — 3-stage encounters with skip-for-Tags mechanics

---

## 2. As-Is vs To-Be Gap Matrix

| Subsystem | As-Is (Current) | To-Be (V3) | Breaking? |
|---|---|---|---|
| **Bag/Draw** | Tiles return to bag at turn end; no discard; 8-tile bag; no vowel guard | Play-and-refill (used tiles consumed); discard cooldown tray; 14-16 tile bag; vowel safeguard (≥2 vowels/wildcards); Altar Rune socket | **YES** |
| **Scoring** | `round(sum(letter) * length_mult) + flat` — single phase | 4-phase pipeline: Tile Hops → Word Form → Artisan Cascade → Runic Blast | **YES** |
| **Word Forms** | Only length multiplier | Trio/Quartet/Quintet/Hexagram + Double-Tap + Mirror Word + Consonant Core detection; per-form base+mult | **YES** |
| **Packs** | 5 Cherry MX with simple draw/score modifiers | 5 thematic Switch Packs with conditional passives | **YES** |
| **Artisan Keycaps** | None; EffectPipeline exists but unused | 5-slot macro rail; 4 archetypes (+Mult, ×Mult, synergy, economy); left-to-right cascade | **NEW** |
| **Consumables** | None | Modder's Toolkit (4 Tarot), Cursed Hardware (3 Spectral), Lexicon Grimoires (Word Form leveling) | **NEW** |
| **Depths** | Simple round progression; no skip | 3-stage Vanguard/Sentry/Boss + Firmware Tags for skipping | **MODERATE** |
| **Blueprints** | 3 simple upgrades (draw/turns/redraws) | Workshop Blueprints (N-Key Rollover, Silicone Dampener, Group-Buy Pass) | **MODERATE** |
| **Visuals** | Single embedded mode; squash/stretch keycap sprite | Dual-perspective (45° iso setup / 2.5D ortho combat); rigid 2-3px plunge; dual-stage audio | **MODERATE** |

---

## 3. Data Architecture — New `Resource` Schemas

All new data types defined as Godot `Resource` scripts under `scripts/data/`:

### `SwitchPackData.gd`
```
id: String              # "clicky", "linear", "tactile", "heavy_tactile", "silent"
name: String
description: String
stem_visual: String     # atlas key for stem texture
sound_profile: String   # "click", "clack", "thock", "silent"
conditionals: Array[Dictionary]
  # [{condition: "rare_consonant", bonus: 0.5}, {condition: "short_word", penalty: -0.2}]
```

### `WordFormData.gd`
```
id: String              # "trio", "quartet", "quintet", "hexagram", "double_tap", "mirror", "consonant_core"
min_length: int
pattern_type: String    # "length", "adjacent_dup", "palindrome", "consonant_rich"
base_damage: int
base_multiplier: float
```

### `ArtisanData.gd`
```
id: String
name: String
archetype: String       # "flat_power", "x_mult", "synergy", "economy"
trigger_condition: Dictionary
  # {type: "word_length", min: 4} or {type: "rare_consonant", per: true}
effect: Dictionary
  # {type: "add_flat", value: 8} or {type: "multiply", value: 1.5}
rarity: String
price: int
```

### `ConsumableData.gd`
```
id: String
name: String
type: String            # "tarot", "spectral", "grimoire"
description: String
effect_type: String     # "remove_tile", "duplicate_tile", "wildcard_tile", "destroy_random", "overclock", "ghost_wire"
effect_params: Dictionary
price: int
```

### `BlueprintData.gd`
```
id: String
name: String
description: String
effect_type: String     # "draw_bonus", "silence_immunity", "shop_discount"
effect_value: float
base_price: int
```

### `FirmwareTagData.gd`
```
id: String
name: String
effect_type: String     # "free_grab_bag", "bonus_turns", "double_interest"
duration: String        # "instant", "this_shop"
```

---

## 4. New & Modified Singletons

### New Autoloads

| Singleton | Responsibility | Autoload Position |
|---|---|---|
| `WordFormService` | Pattern detection, form lookup, grimoire level tracking | After `WordService` |
| `ArtisanRailManager` | 5-slot rail state, equip/unequip, cascade dispatch | After `KeyCapService` |
| `DepthService` | 3-stage encounter generation, Tag rewards, skip logic | After `CombatService` |
| `ConsumableService` | Apply tarot/spectral/grimoire effects, bag mutations | After `ArtisanRailManager` |

### Modified Singletons

**`GameState.gd`** — new fields:
```gdscript
var discard_pile: Array = []       # played tiles awaiting reshuffle
var altar_rune: Dictionary = {}     # communal tile (persists across turns)
var word_form_levels: Dictionary = {}  # {form_id: level}
var artisan_rail: Array = []        # 5 slots, null or ArtisanData
var active_blueprints: Dictionary = {}  # {blueprint_id: true}
var skip_tags: Array = []           # accumulated Firmware Tags
var depth_stage: int = 0           # 0=vanguard, 1=sentry, 2=boss
```

**`KeyCapService.gd`** — rewritten draw logic:
- `draw_hand()` — play-and-refill: used tiles → discard, unused stay
- `_vowel_safeguard()` — guarantee ≥2 vowels/wildcards
- `reshuffle_from_discard()` — move discard → bag, shuffle, emit `bag_reshuffled`

**`CombatService.gd`** — rewritten scoring:
- `calculate_word()` → 4-phase pipeline runner
- `_phase_tile_hops(slots)` → existing letter score logic extracted
- `_phase_word_form_ignition(slots, scores)` → WordFormService + grimoire levels
- `_phase_artisan_cascade(word, scores, form_data)` → ArtisanRailManager triggers
- `_phase_runic_blast(accumulated)` → final damage

**`ShopService.gd`** — expanded:
- Blueprint purchase column
- Grab Bag pack generation (3-pick-1 / 5-pick-2)
- Grimoire shop items

### Modified `EffectPipeline.gd` — new hooks:
```gdscript
signal on_word_form_evaluated(form_id: String, base: int, mult: float)
signal on_artisan_triggered(artisan_id: String, slot: int, effect: Dictionary)
signal on_shop_opened
signal on_bag_mutated(mutation_type: String, affected_tiles: Array)
```

---

## 5. EventBus — New Signals

```gdscript
# Bag/Draw
signal tiles_consumed(used: Array, discarded: Array)
signal bag_reshuffled
signal hand_refilled(hand: Array)

# Scoring Pipeline
signal phase_tile_hop_ready(letter_scores: Array)
signal phase_word_form_ignited(form_id: String, form_base: int, form_mult: float)
signal phase_artisan_cascade_started(artisan_ids: Array)
signal phase_runic_blast_ready(final_damage: int)

# Artisan Rail
signal artisan_equipped(slot: int, artisan_id: String)
signal artisan_unequipped(slot: int)

# Depth/Shop
signal depth_stage_changed(stage: int)
signal tag_awarded(tag_id: String)
signal blueprint_purchased(blueprint_id: String)
signal consumable_applied(consumable_id: String)
signal grab_bag_opened(pack_type: String, choices: Array)
```

---

## 6. Scoring Pipeline — Detailed Formula

```
Phase 1: Tile Hops
  for each letter in word:
    base = letter_base_score(letter)
    + pack_score_modifier
    + ability_score
    × ability_mult (double_score = ×2)
    + finish_bonus (foil=+3, holo=+1)
    × finish_mult (polychrome=×1.5)
    × sticker_mult (red=×2)
    × condition_mult (glass=×2)
  letter_scores[i] = final_letter_value

Phase 2: Word Form Ignition
  form_id = WordFormService.detect(word, slots)
  form_base = WordFormService.base_damage(form_id) + grimoire_bonus(form_id)
  form_mult = WordFormService.base_multiplier(form_id) + grimoire_mult_bonus(form_id)
  length_mult = length_multiplier(len(word))
  total_base = Σ letter_scores + form_base
  total_after_form = total_base × length_mult × form_mult

Phase 3: Artisan Cascade
  artisan_flat = 0
  artisan_xmult = 1.0
  for artisan in rail (slot 0→4):
    if artisan.trigger_condition matches (word, letter_scores, form_id):
      if artisan.archetype == "flat_power": artisan_flat += effect.value
      if artisan.archetype == "x_mult":     artisan_xmult *= effect.value
      if artisan.archetype == "synergy":    evaluate synergy trigger
      if artisan.archetype == "economy":    evaluate economy trigger
  total_after_artisans = (total_after_form + artisan_flat) × artisan_xmult

Phase 4: Runic Blast
  final_damage = round(total_after_artisans) + flat_bonus_damage
```

---

## 7. Switch Packs — Rewrite

| Pack ID | Name | Conditional Passives |
|---|---|---|
| `clicky` | Clicky Pack (Kailh BOX White) | Rare consonants (V,K,X,J,Q,Z) deal +50% damage; -1 redraw token |
| `linear` | Linear Pack (TTC Gold Pink) | +1 Hand per turn; short words (≤3) suffer -20% damage |
| `tactile` | Tactile Pack (Holy Panda) | 5-letter words trigger ×1.5 X-Mult; first 3 key presses double base power |
| `heavy_tactile` | Heavy Tactile Pack (Kailh BOX Navy) | Min 4-letter words; 6+ letter words trigger ×2.5 X-Mult |
| `silent` | Silent Pack (Cherry Silent Red) | -10% base word points; immune to Boss Silence debuffs |

---

## 8. Implementation Roadmap — 6 Milestones

### Milestone 1: Bag & Draw Overhaul
- Play-and-refill: only used tiles consumed; unused stay in hand
- Discard pile + reshuffle on empty
- Bag expansion to 14-16 tiles (add D, L, C, M, P)
- Vowel safeguard: guarantee ≥2 vowels/wildcards per draw
- Altar Rune socket deferred to M5
- Update CombatScreen `_refresh_hand()` for new lifecycle
- **Acceptance:** Headless test — draw hand, spell word, verify consumed tiles enter discard, unused stay, refill maintains vowel guard.

### Milestone 2: Word Form Engine
- `WordFormService.detect(slots)` → form_id
- `WordFormService.base()`, `WordFormService.mult()` — per-form stats
- Grimoire level tracking in GameState
- `data/word_forms.json` — form definitions
- **Acceptance:** `detect(["B","O","O","K"])` → `"double_tap"`; `detect(["L","E","V","E","L"])` → `"mirror"`.

### Milestone 3: 4-Phase Scoring Pipeline
- New `calculate_word()` delegates to 4-phase pipeline
- Phase 1: Tile Hops (extract existing letter scoring)
- Phase 2: Word Form Ignition (calls WordFormService)
- Phase 3: Artisan Cascade (stub — passes through)
- Phase 4: Runic Blast (final damage)
- Update CombatScreen animation for 4 phases
- **Acceptance:** Scoring "CAT" produces same damage as before (no Artisans → transparent pipeline).

### Milestone 4: Artisan Keycap Rail System
- `ArtisanRailManager` — 5-slot array, equip/unequip/trigger dispatch
- 20+ artisan definitions across 4 archetypes
- `ArtisanSlot.tscn` — UI component for macro rail
- Rail cascade in Phase 3
- **Acceptance:** Equip "Caps Lock"; playing 4-letter word triggers +8 flat damage.

### Milestone 5: Switch Packs Rewrite
- Rewrite `data/packs.json` — 5 thematic packs with conditional passives
- Rewrite `PackService.gd` — conditional evaluation
- Update RunSetupScreen for new pack display

### Milestone 5a: KeyCapElement Rigid Plunge & Dual Perspective
- Remove squash/stretch sprite; rigid 2-3px tween-based translation
- Standalone mode for RunSetup (45° isometric)
- Embedded mode for Combat (2.5D orthographic)
- Dual-stage audio hooks (click/thock press, clack release) — AudioManager stub

### Milestone 6: Consumables, Depths & Shop Expansion
- `DepthService` — 3-stage Vanguard/Sentry/Boss + Tags
- `ConsumableService` — Modder's Toolkit (4 Tarot), Cursed Hardware (3 Spectral)
- Lexicon Grimoires shop items
- Workshop Blueprints (3 upgrades)
- Grab Bags (3-pick-1 / 5-pick-2)
- **Acceptance:** Use Keycap Puller → tile removed. Skip Vanguard → Tag awarded.

---

## 9. Key Design Decisions

- **No player HP** — remains unchanged. Turn budget is still the only loss condition.
- **Artisan cascade is left-to-right** — position on rail matters. Balatro-style order dependency.
- **Discard pile is a cooldown tray, not a strategic resource** — no "play from discard" mechanics (yet). Keeps scope contained.
- **Word Forms are detected, not selected** — the game identifies the pattern automatically (like poker hands), no player choice needed.
- **Altar Rune is M5** — small feature, not blocking core loop changes.
- **AudioManager is a stub** — hook points are defined, actual audio files are out of scope.
- **EffectPipeline remains the hook system** — Artisan triggers, consumable effects, and form bonuses all register through it.
