# Letter Rogue — Game & Technical Specification

> A word-spelling roguelite where you build real dictionary words from random letter tiles to damage monsters before your turn budget runs out.

## Overview

Letter Rogue is a 2D roguelite built in Godot 4.7.x (GDScript). Each round pits you against a monster with a fixed HP pool and a **turn budget**. On every turn you draw a random hand of letter tiles from your bag and spell **one English word**; longer words and rarer letters deal more damage. Spend the monster's HP to zero before your turns run out to win the round, earn money, and shop for better tiles and upgrades. There is **no player HP** — running out of turns while the monster still lives is the only way to lose.

Delivered as a single Godot **Web (HTML5) export**, self-hosted via Docker, and reused as the game surface inside thin iOS/Android WebView shells.

## Tech Stack

- **Engine:** Godot 4.7.x (GDScript typed)
- **Rendering:** 2D, Container-based responsive UI
- **Resolution:** 540x960 logical viewport, 9:16 aspect ratio, `canvas_items` stretch mode, `keep_height` aspect
- **Window overrides:** Desktop 441x784 (82% screen height cap, 9:16 preservation via ResolutionManager)
- **Orientation:** Locked portrait (handheld/orientation=1)
- **Input:** `Emulate Touch From Mouse` enabled
- **Fonts:** MSDF font rendering via `res://ui/theme/default_theme.tres` with logical scale variations
- **No external dependencies** — Godot stdlib only

### Theme Type Variations

| Variation | Usage |
|---|---|
| `HeaderLabel` | Screen titles, section headers |
| `MetricLabel` | HP, money, turn counters |
| `KeyCapFaceLabel` | Tile letter display |
| `BodyLabel` | Descriptions, body text |
| `BadgeLabel` | Price tags, dots indicators |
| `MicroLabel` | Subdued info, footnotes |

Minimum touch targets: 120x120 logical pixels. No label below 24px.

## Delivery Platform

One Godot **Web export** is the single artifact; every client loads that same build.

| Client | How it runs |
|---|---|
| Desktop browser | HTML5 export in a browser tab |
| Mobile browser | Same HTML5 export, responsive layout |
| iOS shell | Thin native app embedding the hosted URL in a WKWebView |
| Android shell | Thin native app embedding the hosted URL in a WebView |
| Hosting | Self-hosted static web server via Docker (`deploy/web/`) |

Web constraints:
- All game data ships inside the exported pck (`res://data/*.json`). No runtime file access, no external fetches.
- UI is 100% Container/anchor based — reflows for any viewport.
- Exclude filter: all `addons/*` (godot_mcp, at-icons, dialogue_manager) never ship, plus docs/examples/backups/tests/tools/* and `.wav`/`.zip`.

## Architecture

### Service-based with Event Bus

**Autoloads (19 singletons, registered in `project.godot`):**

| Singleton | Responsibility |
|---|---|
| `EventBus` | Signal definitions only — no logic |
| `GameState` | Runtime state: money, round, bag, discard pile, hand, current monster, turn/redraw/hint budgets, upgrades, active pack/bag ids, word form levels, artisan rail, active blueprints, skip tags, depth stage, active grimoires, unlocked key slots |
| `PackService` | Active Switch Pack modifier lookups + conditional passive evaluation (`evaluate_conditionals`) |
| `KeyCapService` | Play-and-refill draw from bag (used tiles → discard, unused stay), vowel safeguard, discard reshuffle, resolve ability effects, starter bag loaders |
| `KeyCapSkinService` | Atlas-based skin system for keycap textures |
| `ShopService` | Shop inventory generation, buy/sell/reroll, persistent run upgrade purchases, Blueprint purchases, Grab Bag generation |
| `WordService` | Dictionary loading (`data/words.json`), word validation, word length multiplier, `get_word_meta()` for POS/definition/letter counts |
| `CombatService` | Round setup, per-turn word validation & 4-phase scoring, damage application, win/lose from turn budget. Hooks into `EffectPipeline` for cap effect lifecycle. |
| `ArtisanRailManager` | 5-slot Artisan rail state, equip/unequip, left-to-right cascade trigger evaluation |
| `WordFormService` | Word Form pattern detection (Trio/Quartet/Mirror/Double-Tap/Consonant Core), per-form base damage & multiplier, grimoire level tracking |
| `DepthService` | 8-stage encounter generation (Vanguard/Sentry/Boss Gate/Catacombs/Fungal Depths/Crystal Caverns/Void Threshold/Abyssal Crown), milestone modifiers, stage pools, depth-6 banned letter |
| `ConsumableService` | Apply tarot/spectral/grimoire effects, bag mutations |
| `ResolutionManager` | Cross-platform desktop window sizing (82% height cap, 9:16 aspect preservation) and mobile fullscreen |
| `MCPRuntimeProbe` | Godot MCP runtime probe (`res://addons/godot_mcp/`), dev-only, never ships in Web export |
| `DebugManager` | Debug-only hotkeys (F1 overlay toggle, F12 screenshot), scene routing, state injection, time-scale |
| `EffectPipeline` | Hook registry: caps register `{hook, apply}` callbacks triggered on combat lifecycle events |
| `LootService` | Rolls loot drops from monster's `drop_table_id` on defeat |
| `AudioManager` | Minimal SFX player: cached stream playback from `res://assets/audio/`, `.ogg`/`.wav` fallback, no-op on missing files. **No audio assets shipped yet** — all plays no-op. |
| `HintService` | Tier 1 brute-force word finder: `find_basic_word(letters)` enumerates combinations/permutations (length 3..hand size) and returns the first valid dictionary word |

**Autoload order matters** (registration order in `project.godot`): `EventBus`, `GameState`, `PackService`, `KeyCapService`, `KeyCapSkinService`, `ShopService`, `WordService`, `CombatService`, `ArtisanRailManager`, `WordFormService`, `DepthService`, `ConsumableService`, `ResolutionManager`, `MCPRuntimeProbe`, `DebugManager`, `EffectPipeline`, `LootService`, `AudioManager`, `HintService`. Services reference each other via autoload names at call time, not in `_ready()` cross-dependencies.

### Screens

| Scene | Purpose |
|---|---|---|
| `MainMenuScreen` | Title + Start/Achievements/Collection/Settings buttons, hover scale+tint effects, particle burst on press |
| `RunSetupScreen` | Switch Pack (5) + Starter Bag (4) selection |
| `CombatScreen` | Word builder: hand tiles with deep-travel latched state, WordRuneSlot magical rune display strip, Artisan rail display + SellDropZone, persistent scoring row (BASE/MULTI inline HUD), HINT + DECK action buttons, BagModal (bag + discard tabs), VictoryModal, ParticleBurst score bursts, PixelHPBar monster HP, DepthInfoPopup |
| `ShopScreen` | Buyable tiles grid, sell/reroll, upgrade column, Workshop Blueprints |
| `GameOverScreen` | Round reached + money display, restart |

### GameRoot State Machine

```
MENU → RUN_SETUP → COMBAT ←→ SHOP → GAME_OVER
                     ↑            │
                     └── shop ─────┘
```

`GameRoot` (`scripts/game_root.gd`) is a `Node` that instantiates/destroys screen scenes as children. Transitions driven entirely by `EventBus` signals.

### Scoring Animation (CombatScreen)

Balatro-style sequential animation driven by trace events from `CombatService.calculate_word().trace`. Each trace event carries `{step_type, source_index, label, delta_chips, delta_mult, x_mult, running_chips, running_mult, annotation}` and drives one animation step. Scores render **inline** in the persistent scoring row (`%PersistentScoringRow` in `TopZone_Red`), not a floating banner:

1. **Scoring start** — `%PersistentScoringRow` scales 0.95→1.0 (0.15s TRANS_BACK), `%TotalDamageShelf` hides, BASE/MULT panels reset
2. **tile_hop events** — each tile hops up (0.15s), lands (0.18s), floating `+N` label fades up, `ParticleBurst` at tile position, BASE label updates to running_chips with scale punch. Audio: `AudioManager.play("score_chip")`. 0.2s pause between tiles.
3. **tile_retrigger events** (red sticker / lubed condition) — tile pulses scale 1.3→1.0, floating "RE-TRIGGER!" text, BASE updates again
4. **form_ignite event** — Word Form base damage lands into BASE label (scale punch, floating "+N [FormName]"), mult panel pulses, multiplier ramps from ×1.0 to running_mult over 0.35s. Audio: `AudioManager.play("mult_ignite")`.
5. **artisan_trigger event** — `ArtisanRailDisplay.trigger_slot()` fires for each triggered artisan, floating text shows artisan bonus (+N Mult / ×N), mult display updates with pulse. Audio: `AudioManager.play("mult_ignite", 1.15)`.
6. **clash_resolve event** — `%TotalDamageShelf` shows `= N DMG` with scale pulse, BASE+MULT labels pulse in sync. Projectile label flies from the scoring row to monster (0.35s), `ParticleBurst` at impact, `ScreenShake.shake()`, `_squash_hit()`. Audio: `AudioManager.play("slam_impact")`.
7. **Word metadata:** after trace iteration, `%WordMetaLabel` shows `WORD · POS · "def" · Vn/Cn`
8. **Hitstop:** HP bar drops smoothly (0.4s), damage float text (`-N`)
9. **Score reset** (`_score_reset()`), then `CombatService.commit_word()`

Player can click during animation to skip remaining steps (sets `_skip_requested = true`).

## Core Loop

```
MainMenu → RunSetup → Combat → (win) → VictoryModal → Shop → Combat → ... → GameOver
                            ↑                                       │
                            └──── (turns exhausted) ─────────────────┘
```

### Round

- Each round: one monster with HP plus a **turn budget** (default 3).
- Shop upgrades raise turn budget, draw size, and redraw budget permanently.
- **Lose condition:** turn budget exhausted while monster alive → Game Over. No player HP anywhere.

### Turn Loop

1. **Draw (play-and-refill)** — fill hand to current draw size (default 5) by sampling random tiles from bag. On turn start, **unused tiles stay in hand**; only tiles played on the previous turn are missing and get refilled. A vowel safeguard swaps in vowels/wildcards to guarantee ≥2 per hand. When the bag empties, the discard pile reshuffles back into the bag.
2. **Spell** — build exactly one word from hand tiles. Tap tile to add to word strip; tap word strip tile to remove it. Drag-and-drop reorder within word strip. Wildcard tiles open a letter picker popup.
3. **Play** — any length ≥1 is valid. 1-2 letter plays deal flat base power (no multiplier). 3+ letter plays must be in the dictionary.
4. **Score** — 4-phase Balatro-style animation (Tile Hops → Word Form → Artisan Cascade → Runic Blast), then damage applied.
5. **End turn** — **played tiles move to the discard pile** (not back to bag); decrement turns; unused hand tiles persist into the next turn, missing tiles refilled.

### Redraw (Targeted Swap)

- Toggle redraw mode: tap tiles in hand to mark for swap.
- Costs **1 redraw token** per redraw action (any number of tiles at once).
- Default redraw tokens per round: **3**. Shop raises cap.
- Marked tiles animate out, replacements animate in.

### HINT (HintService Tier 1)

CombatScreen action row has a `%HintButton` (100×60, "HINT (N)"). Pressing it consumes one hint (`GameState.hints_remaining`, budget = `round_hint_budget()` = 3 + `upgrade_hints`) and asks `HintService.find_basic_word(hand_letters)` for a valid word suggestion. Tier 1 is brute-force: enumerate all combinations (length 3..hand size) then permutations, return the first that `WordService.is_word()`. No anagram map yet. Button disabled at 0 hints. Higher tiers (`hint_quality` = 2/3) are deferred.

### DECK (Bag / Discard Inspector)

`%DeckButton` (100×60) opens the BagModal, which now has two views: **In Bag** (live `GameState.bag` letter inventory) and **Discarded** (`GameState.discard_pile` — tiles consumed this run, awaiting bag reshuffle). Tabs switch between the two piles.

### Grimoire Row

The top status bar holds a `GrimoireRow` (HBox) rendering every `GameState.active_grimoires` entry as a 40×40 `GrimoireIcon` (first letter, tooltip = name + description). Each icon is draggable; dropping it on the row reorders `active_grimoires` (used for Word Form leveling priority). Grimoires are permanent upgrades and **cannot be sold** via the Sell Drop Zone.

### Sell Drop Zone

`SellDropZone` (inside `ArtisanRow`) accepts artisan keycap drags. Dropping an artisan refunds **half its purchase price** (`roundi(price_paid × 0.5)`) into `GameState.money`, unequips it from the rail, and shows a floating `+$N` label. Grimoire drops are rejected with a toast ("Cannot sell permanent upgrades").

### Depth Info Popup

`%DepthInfoButton` ("?") opens a modal (`DepthInfoPopup` scene, runtime-instantiated) showing `Depth %s / Round %d`, the current depth milestone modifier name + description (and the void-banned letter at depth 6), plus the monster pool for that stage (`DepthService.get_stage_pool`). Pool rows show name, HP, and modifier.

## Data Model

### KeyCap (Tile)

```
letter: String            (A-Z or wildcard symbol: *, ~, #)
ability_id: String        ("bonus_points", "double_score", "money_bonus", "bonus_damage", "wild", "vowel_wild", "consonant_wild")
rarity: String            ("Normal", "Rare", "Epic", "Legendary")
ability_strength: int
is_symbol: bool           (true only for wildcards *, ~, #)
finish: String?           (null, "foil", "holographic", "polychrome")
sticker: String?          (null, "gold", "red", "blue")
condition: String?        (null, "glass", "lucky", "eternal")
price: int                (shop price, computed by ShopService)
```

### Monster

```
name: String
hp: int
max_hp: int
is_boss: bool
modifier: String          (unified: "", "vowel_lock", "consonant_lock", "no_repeats", "silence", "shielded", "enraged")
sprite: String            (texture path, may be empty)
drop_table_id: String     (loot table id for LootService, empty = no drops)
```

### GameState Fields

```
money: int
round_number: int
bag: Array[Dictionary]        (permanent tile collection)
discard_pile: Array           (played tiles awaiting reshuffle)
hand: Array[Dictionary]       (current turn's tiles, unused persist between turns)
current_monster: Dictionary
shop_inventory: Array[Dictionary]
active_pack_id: String
active_starter_bag_id: String
turns_left: int               (reset to round_turn_budget each round)
redraws_left: int             (reset to round_redraw_budget each round)
upgrade_draw: int             (bag-size upgrade bonus)
upgrade_turns: int            (per-round turn bonus)
upgrade_redraws: int          (per-round redraw bonus)
upgrade_hints: int            (per-round hint bonus, via future shop items)
next_draw_bonus: int          (one-time extra draw, e.g. Blue sticker; reserved, unused)
altar_rune: Dictionary        (communal tile socket, persists across turns)
word_form_levels: Dictionary  ({form_id: level}, raised by Grimoires)
artisan_rail: Array           (5 slots, null or artisan Dictionary)
active_blueprints: Dictionary ({blueprint_id: true})
active_grimoires: Array       (purchased Lexicon Grimoire items, reorderable via GrimoireRow drag)
unlocked_key_slots: int       (reserved fixed-keyboard slot unlock, =8 of 10; dormant — adaptive hand layout renders min(draw_size(), 10))
hint_quality: int             (1 = Tier 1 brute-force; tiers 2/3 deferred)
hints_remaining: int          (reset to round_hint_budget each round)
skip_tags: Array              (accumulated Firmware Tags)
depth_stage: int              (0=vanguard, 1=sentry, 2=boss_gate, 3=catacombs, 4=fungal_depths, 5=crystal_caverns, 6=void_threshold, 7=abyssal_crown)

round_turn_budget()   = BASE_TURNS(3) + upgrade_turns
round_redraw_budget() = BASE_REDRAWS(3) + upgrade_redraws
round_hint_budget()   = BASE_HINTS(3) + upgrade_hints
draw_size()           = pack_base + upgrade_draw + next_draw_bonus (min 3)
monster_hp_scaled()   = round(base_hp * (1.0 + (round - 1) * 0.15))
round_reward()        = 5 + round_number * 2
```

## Letter Values (Power Tiers)

| Tier | Letters | Base Power |
|---|---|---|
| Common | E T A O I N S R | 1 |
| Uncommon | H L D C U M F P G W Y B | 2 |
| Rare | V K X J Q Z | 4 |

Wildcard tiles contribute **0 base power** but count toward word length.

## Scoring — 4-Phase Pipeline

`CombatService.calculate_word()` runs four phases (Balatro-style):

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
    (boss modifier zeroing: vowel_lock/consonant_lock)
  letter_scores[i] = final_letter_value

Phase 2: Word Form Ignition
  form_id = WordFormService.detect(slots)
  form_base = form.base_damage + grimoire_level × 2
  form_mult = form.base_multiplier + grimoire_level × 0.1
  length_mult = length_multiplier(len(word))
  total_after_form = (Σ letter_scores + form_base) × length_mult × form_mult

Phase 3: Artisan Cascade
  artisan_flat = 0, artisan_xmult = 1.0
  for artisan in rail (slot 0→4), left-to-right:
    if trigger matches (word, slots, letter_scores, form_data, pack):
      flat_power: artisan_flat += effect.value
      x_mult:     artisan_xmult *= effect.value
  total_after_artisans = (total_after_form + artisan_flat) × artisan_xmult

Phase 4: Runic Blast
  damage = roundi(total_after_artisans) + flat_bonus_damage
```

### Length Multiplier

| Length | Multiplier |
|---|---|
| 1, 2 | 1.0 |
| 3 | 1.0 |
| 4 | 1.3 |
| 5 | 1.6 |
| 6 | 2.0 |
| 7+ | 2.5 |

### Word Forms

Word Forms are detected automatically (like poker hands) — no player selection. Pattern priority: Mirror (palindrome) > Double-Tap (adjacent duplicate) > Consonant Core (3+ of V/K/X/J/Q/Z) > length-based. Special patterns win over length forms at the same length.

| Form | Pattern | Base Damage | Base Mult |
|---|---|---|---|
| Trio | 3 letters, any | 0 | ×1.0 |
| Quartet | 4 letters, any | 4 | ×1.3 |
| Quintet | 5 letters, any | 8 | ×1.6 |
| Hexagram | 6+ letters, any | 12 | ×2.0 |
| Double-Tap | 3+ letters with adjacent duplicate | 6 | ×1.5 |
| Mirror Word | 3+ letters palindrome | 10 | ×2.0 |
| Consonant Core | 3+ of V K X J Q Z | 5 | ×1.5 |

Grimoires raise a form's level: each level adds `+2 base damage` and `+0.1 multiplier`. Levels stored in `GameState.word_form_levels`.

### Ability Contributions (per tile)

- `bonus_points`: +N score
- `double_score`: ×2 score multiplier
- `money_bonus`: +$N when played
- `bonus_damage`: +N flat damage (added after multiplier)

### Finishes

| Finish | Effect | Price + |
|---|---|---|
| Foil | +3 score | +$2 |
| Holographic | +1 score | +$3 |
| Polychrome | ×1.5 score | +$5 |

### Stickers

| Sticker | Effect |
|---|---|
| Gold | +$2 when played |
| Red | ×2 score |
| Blue | +1 draw next turn |

### Conditions

| Condition | Effect |
|---|---|
| Glass | ×2 score, 25% chance to break (removed from bag permanently) |
| Lucky | 20% chance +10 damage, 6.67% chance +$10 |
| Eternal | Cannot be sold |

All modifiers are independent and stack multiplicatively/additively.

## Wildcards

| Symbol | Meaning | Rarity |
|---|---|---|
| `*` | Full wild — any A-Z | Epic |
| `~` | Vowel wild — A E I O U | Rare |
| `#` | Consonant wild | Rare |

Wildcards: 0 base power, count toward word length, letter chosen via popup picker on click.

## Boss Modifiers

Every 3rd round a boss appears with extra HP and a modifier:

| Modifier | Effect |
|---|---|
| `vowel_lock` | Only vowel tiles contribute power |
| `consonant_lock` | Only consonant tiles contribute power |
| `no_repeats` | Same letter cannot appear twice in one word |
| `silence` | Abilities, finishes, stickers, conditions disabled |

## Depth Modifiers (Milestone Modifiers)

Active at specific depths, applying to all encounters in that depth:

| Depth | Modifier | Effect |
|---|---|---|
| 3 (Catacombs) | `cursed` | 25% chance/turn: random tile in hand becomes Cursed (0 score, cannot be redrawn) |
| 4 (Fungal Depths) | `spore_cloud` | Vowels worth -1 score; Consonants worth +1 score (swaps each round) |
| 5 (Crystal Caverns) | `reflective` | Mirror words (palindromes) gain +50% damage |
| 6 (Void Threshold) | `void_touch` | One random letter banned per encounter |
| 7+ (Abyssal Crown) | `abyssal` | Boss gains +25% HP each cycle, all modifiers active |

## Switch Packs

Five thematic Switch Packs replace the old Cherry MX packs. Each carries conditional passives evaluated via `PackService.evaluate_conditionals()`:

| Pack | Effect |
|---|---|
| Clicky | Rare consonants (V,K,X,J,Q,Z) deal +50% damage; -1 redraw token |
| Linear | +1 draw per turn; short words (≤3) deal -20% damage |
| Tactile | 5-letter words trigger ×1.5 X-Mult; first 3 key presses double base power |
| Heavy Tactile | Min 4-letter words; 6+ letter words trigger ×2.5 X-Mult |
| Silent | -10% base word points; immune to Boss Silence debuffs |

## Starter Bags

| Bag | Tiles | Start Money |
|---|---|---|
| Standard | E T A O I N S R D L C M P H (14) | 0 |
| Vowel Explorer | E E A A I O U ~ (8) | 0 |
| Consonant Heavy | T N S R V K X J Q Z (10) | 0 |
| Minimalist | E T A O I R (6) | 15 |

Starting money = **10 base** (`GameState.money := 10`) + `pack.start_money` (all current packs: 0) + bag `start_money` (`KeyCapService.starter_bag_money(id)`).

## Shop

### Tile Inventory
- 5 tiles offered per shop visit, weighted by rarity
- Buy into bag; sell for 50% price (Eternal cannot be sold)
- Reroll for $3

### Run Upgrades (persistent)

| Upgrade | Effect | Base Price | Escalation |
|---|---|---|---|
| Bigger Bag | +1 draw per turn | $6 | ×2 each level |
| Extra Turn | +1 turn per round | $8 | ×2 each level |
| Extra Redraw | +1 redraw per round | $5 | ×2 each level |

### Workshop Blueprints

| Blueprint | Effect | Price |
|---|---|---|
| Anti-Ghosting Matrix | +1 tile drawn per turn permanently | $10 |
| Silicone Dampener | Immune to Boss Silence debuffs | $12 |
| Group-Buy Pass | 20% discount on all shop items | $8 |

Blueprints are one-shot permanent run upgrades stored in `GameState.active_blueprints`. Each is purchasable once.

### Grab Bags

Random packs of pick-N items offered in the shop, generated by `ShopService.generate_grab_bag(pack_type, choices, pick)`:
- **Artisan Grab Bag** — 3-pick-1 from artisan pool
- **Toolkit** — tarot consumables
- **Black Box** — spectral consumables
- **Grimoire** — word-form leveling items

## Artisan Keycap Rail

A 5-slot macro rail (Balatro-style Joker row) in the top HUD row (`ArtisanRow` inside `TopZone_Red`). Artisans equip into fixed slots and trigger left-to-right each word played — position on the rail matters.

**Visual:** each `ArtisanSlot` is a **40×40px icon-only panel** (borderless, no name label, no empty placeholder). Empty slots are **hidden entirely** — only purchased/equipped artisans display in the rail. Drop-to-swap maps the drop position to the real slot index among the currently visible slots (`ArtisanRailDisplay._slot_index_at_position()`), preserving left-to-right cascade order. Slots render blank when filled until `data/artisans.json` gains an `icon` texture field.

| Archetype | Behavior |
|---|---|
| Flat Power | +N flat damage when triggered |
| X-Mult | ×N multiplier when triggered |
| Synergy | Trigger off word properties (form, vowels, letter patterns) |
| Economy | Money / bag-scaling triggers |

Trigger types: `word_length` (min/max), `no_redraws_used`, `rare_consonant`, `unused_redraws`, `more_vowels_than_consonants`, `word_form`, `leftover_turns`, `consecutive_start_letter`. Equip/unequip via `ArtisanRailManager.equip(slot, artisan)` / `unequip(slot)`; the cascade runs in `CombatService` Phase 3.

## Consumables

Three classes of one-shot consumables, applied via `ConsumableService.apply(item)`:

### Modder's Toolkit (Tarot — bag sculpting)

| Item | Effect |
|---|---|
| Keycap Puller | Remove 1 selected tile from the bag |
| Hot-Swap Tool | Duplicate 1 target letter tile |
| Laser Engraver | Convert 1 tile into a full wildcard |
| Lube Pen | Lubed status: tile scores twice |

### Cursed Hardware (Spectral — high risk/reward)

| Item | Effect |
|---|---|
| Short Circuit | Destroy 3 random tiles, gain $25 |
| Overclock | Polychrome 1 random tile, -1 max redraw |
| Ghost Wire | Transform 2 hand tiles into full wildcards |

### Lexicon Grimoires (Word Form leveling)

| Item | Effect |
|---|---|
| Trio Codex | Trio: +5 base damage, +1 mult |
| Quartet Scroll | Quartet: +5 base damage, +1 mult |
| Mirror Tome | Mirror: +10 base damage, +2 mult |
| Double-Tap Tome | Double-Tap: +10 base damage, +2 mult |

All consumable bag mutations emit `on_bag_mutated` through EffectPipeline.

## Depths Progression

Eight-stage encounter scaling with milestone modifiers and unique rewards:

| Stage | Depth Name | Pool | Milestone Modifier | Unique Rewards |
|---|---|---|---|---|
| 0 | VANGUARD | Vanguard | — | — |
| 1 | SENTRY | Sentry | — | — |
| 2 | BOSS GATE | Bosses | — | — |
| 3 | CATACOMBS | Catacombs | **Curse** — 25% chance/turn: random tile becomes Cursed (0 score, no redraw) | Cursed artifacts, Grimoire fragments |
| 4 | FUNGAL DEPTHS | Fungal Depths | **Spore Cloud** — Vowels -1 / Consonants +1 (swaps each round) | Spore-infused tiles, Consumables |
| 5 | CRYSTAL CAVERNS | Crystal Caverns | **Reflection** — Mirror words (palindromes) +50% damage | Crystal finishes, Mirror artisans, Blueprint |
| 6 | VOID THRESHOLD | Void Threshold | **Void Corruption** — One random letter banned per encounter | Void-touched wildcards, Spectral consumables |
| 7+ | ABYSSAL CROWN | Abyssal Crown | **Abyssal Power** — Boss +25% HP/cycle, all modifiers | Unique blueprints, Cosmetic keycaps |

`DepthService.generate_encounter(stage)` picks from the stage pool. Every 3rd round is a boss round and advances `depth_stage`. Milestone rewards granted at depths 3, 5, 7 via `LootService` with dedicated drop tables. Firmware Tags (e.g. Free Grab Bag, Bonus Turns, Double Interest) can be earned by skipping encounters — stored in `GameState.skip_tags`. Endless mode at depth 7+ loops `abyssal_crown` pool with escalating HP.

## Victory & Economy

- On monster defeat: VictoryModal shows itemized receipt (Base Reward + Leftover Turns at $1 each + Ability Money)
- Money added to `GameState.money` only on Continue button press
- Boss completion → "GAME COMPLETE" → back to main menu
- Round loss → GameOver screen showing reached round and money

## Display & Safe Areas

- 540x960 logical baseline, 9:16 aspect ratio
- Safe area insets: top 48px, bottom 32px (logical coordinates)
- Desktop: 82% of usable screen height, centered, 9:16 ratio preserved
- Mobile: fullscreen

## Data Files

All JSON under `data/`, ships inside exported pck:

| File | Purpose |
|---|---|---|
| `data/words.json` | Word dictionary (~370k words, 3+ letters, enriched with POS bitmask + definition) |
| `data/key_caps.json` | Shop pool tiles (letter + abilities + modifiers) |
| `data/monsters.json` | Normal + boss monster definitions (unified `modifier` field, `drop_table_id`) |
| `data/packs.json` | Switch Pack modifiers + conditional passives |
| `data/starter_bags.json` | Starting bag loadouts |
| `data/word_forms.json` | Word Form definitions (base damage, multiplier per form) |
| `data/artisans.json` | Artisan Keycap definitions (4 archetypes, trigger + effect) |
| `data/consumables.json` | Toolkit (tarot), Cursed Hardware (spectral), Grimoire definitions |
| `data/blueprints.json` | Workshop Blueprint definitions |
| `data/firmware_tags.json` | Firmware Tag definitions |
| `data/depths.json` | Depth encounter tables (Vanguard/Sentry/Boss pools) |
| `data/secret_words.json` | Rare words flagged `is_secret: true` in metadata (future: scoring bonus) |
| `data/drop_tables.json` | Weighted loot tables keyed by `drop_table_id` on monsters |

## Key Design Decisions

- 1-2 letter plays are valid (no skip turn) — deal base power only, no multiplier
- Redraw costs 1 token per action (any number of tiles), not per tile
- Victory money held back until Continue button pressed
- No player HP, no shield, no healing
- **Play-and-refill bag** — played tiles go to the discard pile (a cooldown tray, not a strategic resource); unused tiles persist in hand across turns; discard reshuffles into bag when the bag empties
- All UI responsive via Containers — no fixed positions
- Debug hotkeys gated behind `OS.is_debug_build()`: F1 toggles DebugOverlay, F12 saves screenshot to `res://screenshots/`
- `EffectPipeline` provides 11 hook points: on_draw, on_letter_slotted, on_word_validated, on_score_calculated, on_monster_damaged, on_monster_defeated, on_turn_end, on_word_form_evaluated, on_artisan_triggered, on_shop_opened, on_bag_mutated
- Monster modifiers unified under single `modifier` field (replaces separate `boss_modifier`)
- Secret words from `data/secret_words.json` flagged in metadata; gameplay effects pending
- Word Forms are detected, not selected — pattern identification is automatic (like poker hands)
- Artisan cascade is strictly left-to-right — rail position orders trigger resolution
- Altar Rune socket deferred; AudioManager built (autoload with cached stream playback) — no `assets/audio/` files shipped yet, so all plays no-op

## KeyCap 3-Layer Mechanical Sandwich Architecture

Each `KeyCapElement` tile is a context-aware stack rendering from back to front. One scene, two rendering modes:

- **Embedded mode** (`embedded_mode = true`, set by `CombatScreen` hand tiles): the switch is cropped to its upper housing and a dark socket shadow sits at its base — the switch is socketed into the stone altar plate (image.jpg black-mask match).
- **Standalone mode** (default; ShopScreen/RunSetupScreen previews): the full switch with complete bottom skirt is shown — the keycap as a full product.

| Layer | Node | Source | Description |
|---|---|---|---|
| **Root** | `Control` (48×54) | — | KeycapButton root bounding box, `mouse_filter = PASS`. Holds SocketShadow (embedded only) + SwitchBase (bottom) + CapLayer (top). |
| **SocketShadow** | `ColorRect` (38×3 at 5,46) | — | Dark recessed socket slit `Color(0.08, 0.10, 0.14, 0.95)`, `visible` only in embedded mode. Reads as the carved slot the switch plugs into. |
| **SwitchBase** | `TextureRect` | `keycap_kit_6.png` Row 3 (switches) | Cherry MX transparent housing + colored cross-stem. Standalone: position (5,22), size 38×28, full uncropped atlas. Embedded: position (5,26), size 38×22, cropped **duplicate** of the atlas (`region.size.y *= 0.79`). Atlas key = `"switches"` + `GameState.active_pack_id` (clicky/linear/tactile/heavy_tactile/silent). Always visible, fixed position — never moves. |
| **CapLayer** | `Control` (48×40 at 0,0) | — | Wraps CapTexture, OverlayTexture, LegendContainer, MarkFrame, and PowerLabel as a single movable unit. `position.y` is animated for press/release. |
| **CapTexture** | `TextureRect` (full rect, child of CapLayer) | `keycap_kit_6.png` Row 1/2 | The movable keycap. Only `cap_unpressed` is used — press is a rigid 2px translate, no squashed sprite swap. |
| **OverlayTexture** | `TextureRect` (full rect, child of CapLayer) | `keycap_kit_6.png` Row 4 | Finish/condition/sticker overlays (foil, holographic, glass, sticker_gold). |

**Layer ordering** (back to front): `SocketShadow → SwitchBase → CapLayer (CapTexture → OverlayTexture → LegendContainer → MarkFrame → PowerLabel)`.

**Embedding logic** (`@export var embedded_mode: bool = false`, setter `set_embedded_mode(enabled)`): `_apply_switch_base()` branches on the flag. Embedded: `SocketShadow.visible = true`; the switch atlas is **duplicated** (`base_atlas.duplicate()`) and `cropped.region.size.y *= 0.79` before assignment — the crop is proportional (~21%) because the switch slice is 262×258 source px (a literal 6px crop would remove only ~0.7 display px). The duplicate guarantees the shared cached atlas used by standalone/Shop tiles is never mutated. Embedded geometry: SwitchBase `position (5,26)`, `size (38,22)`. Standalone: `SocketShadow.visible = false`, full atlas, `position (5,22)`, `size (38,28)`. `SwitchBase` uses `mouse_filter = 2` (ignore) so it never intercepts clicks, `expand_mode = 1` (EXPAND_IGNORE_SIZE), and `stretch_mode = 5` (STRETCH_KEEP_ASPECT_CENTERED). The switch housing is always at the same Y position — only the CapLayer moves on press/release.

**CapLayer** is a `Control` (48×40 at (0,0)) that wraps CapTexture, OverlayTexture, LegendContainer, MarkFrame, and PowerLabel as a single movable unit. On press/release, `CapLayer.position.y` is animated from `UNPRESSED_CAP_Y` (0.0, floating high as in image-2) to `PRESSED_CAP_Y` (2.0, rigid 2-3px plunge as in image-3), plunging the entire keycap down to rest solidly on the fixed switch base and cover the top of the stem. The 2px plunge replaces the old 5px squash/stretch — no `cap_pressed` sprite swap, translation only.

## Stone Altar Safe Area & Hand Keyboard Calibration

Pixel analysis of the combat background's stone altar white-mask marked the exact safe bounding box (540×960 viewport space):

| Item | Value |
|---|---|
| Container Rect | Position (106, 704), Size (324, 110) |
| Center | (268, 759) |
| Bezel margin | Top 4px, Bottom 5px, Left 12px, Right 12px |
| Row separation | VBox 6px |
| Key separation | HBox 8px |
| Keycap size | 48×54 px |

`HandTileContainer` is a `CenterContainer` anchored absolutely at `position (106, 704)` with `size`/`custom_minimum_size` `(324, 110)` and `mouse_filter = PASS`. It is a direct child of the `CombatScreen` root (outside the VBox layout) so container layout never overrides its geometry.

| Hand Size | Layout | Tile Size | Font Size | Gap |
|---|---|---|---|---|
| 1–5 | Single centered row | 48×54px | 20 | 8px |
| 6–10 | Two rows (split ceil(n/2) top / floor(n/2) bottom) | 48×54px | 20 | 8px horizontal / 6px vertical |

At max 10 tiles (2 rows × 54px + 6px gap = 114px), the keyboard block is vertically centered in the 110px container with the switch housings extending below each cap skirt. Max 5 keys per row = 5×48 + 4×8 = 272px ≤ 324px container width, centered with ~26px side bezels. Each row `HBoxContainer` uses `alignment = ALIGNMENT_CENTER` + `SIZE_SHRINK_CENTER`; rows sit inside a `VBoxContainer` with 6px separation.

> **Design divergence:** the 2026-09-14 design doc proposed a fixed 2×5 grid keyboard with padlock-locked unlockable slots. The shipped implementation instead uses a **dynamic adaptive layout** (`CombatScreen._refresh_hand()`, tile size 62×58, font 30): a VBox (3px sep for ≥5 tiles, 6px below) with an HBox of up to 5 tiles on row 1 and the remainder on row 2, centered inside `%HandTileContainer` (324×130). `GameState.unlocked_key_slots`/`hint_quality`/`upgrade_hints` fields exist but are dormant — no slot-lock rendering or purchase path reads them yet. If the fixed-2×5 spec is wanted, it's an open build task.

Bottom action buttons (REDRAW / PLAY) sit below the slab on the stone floor at Y≈845–900px.

## Unified Keycap Physics

Both real-time mouse-down press and latched (word-strip) state share identical visual behavior:

| Aspect | Behavior |
|---|---|
| **Sprite** | `cap_unpressed` atlas texture always (no squashed sprite on press) |
| **Vertical offset** | 2px downward (`PRESSED_CAP_Y` from `UNPRESSED_CAP_Y` 0.0), tweened rigid — no squash/stretch |
| **Color tint** | `Color(0.85, 0.88, 0.95, 1.0)` — slight tactile shading |
| **CapLayer offset** | Entire CapLayer shifts 2px down, plunging keycap flush onto fixed SwitchBase |

On mouse-button release, the keycap **never pops up** — it remains in the pressed position. CombatScreen then either calls `set_latched(true)` (seamless stay-down) or the next interaction pops it up. This eliminates the 1-frame jitter where the keycap would bounce up before being latched back down.

## Scene Transitions (Pixel-Art Retro)

`SceneTransition` (`scripts/components/SceneTransition.gd`) is a static Node providing two-phase screen transitions via CanvasLayer 128 with a ShaderMaterial overlay:

- **play_out(screen)** — fades out the current screen using a randomly chosen shader style (0.45s)
- **play_in(screen)** — reveals the new screen by unwinding the same shader pattern (0.45s)
- **No-flash guarantee** — at progress 1.0 the overlay is fully opaque; the old screen is freed / new screen added while progress stays at 1.0
- **Stutter protection** — `play_in` awaits one frame so the new screen's heavy `_ready()` finishes before the reveal tween starts

5 shader styles, preloaded at script load time:

| Shader | Effect |
|---|---|
| `bayer_dither.gdshader` | Ordered dither dissolve (4x4 Bayer matrix), pixel clusters dissolve to black |
| `pixelate_darken.gdshader` | Pixelate & darken: block sizes step 1→2→4→8→16→32 while each block fills from center |
| `diamond_grid.gdshader` | Diamond grid tile wipe, Manhattan distance metric, chunky retro edges |
| `scanline_shutter.gdshader` | Interlaced shutter bands, random vertical/horizontal orientation |
| `radial_wipe.gdshader` | Stepped radial iris wipe, chunky pixelated edge (cell_size=8) |

All shaders share `progress` uniform (0.0 = fully transparent, 1.0 = fully opaque) and `transition_color` uniform (default black).

`GameRoot._show()` wraps screen instantiation in `SceneTransition.play_out(old) → old.queue_free() → current_screen = scene.instantiate() → add_child() → SceneTransition.play_in(current_screen)`. `_transitioning` flag prevents re-entrance.

## Particle System

`ParticleBurst` (`scripts/components/ParticleBurst.gd`) is a static class using `CPUParticles2D` for one-shot effects:

- `ParticleBurst.burst(parent, global_pos, color, amount, opts)` — creates, emits, and self-frees a CPU particle burst
- Uses a cached 6×6 pixel texture with edge lightening for a chunky retro look
- Opacity: `lifetime`, `vel_min/max`, `gravity`, `spread`, `scale_min/max`
- Used for: tile score bursts (CombatScreen), button press effects (MainMenuScreen), damage projectile impact, victory confetti (VictoryModal)

## Custom HP Bar

`PixelHPBar` (`scripts/components/PixelHPBar.gd`) is a `TextureProgressBar` subclass with custom `_draw()` for segmented retro HP display:

- `segments` (default 20): number of HP segments
- `gap` (default 2): pixel gap between segments
- `fill_color` / `warn_color` / `crit_color`: color transitions at 55% / 25% thresholds
- `empty_color` / `border_color`: empty segment and border colors
- Segmented bar draws filled segments with a top highlight line for retro depth
- Connected to `changed` signal for auto-redraw
