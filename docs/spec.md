# Letter Rogue — Game & Technical Specification

> A word-spelling roguelite where you build real dictionary words from random letter tiles to damage monsters before your turn budget runs out.

## Overview

Letter Rogue is a 2D roguelite built in Godot 4.7.x (GDScript). Each round pits you against a monster with a fixed HP pool and a **turn budget**. On every turn you draw a random hand of letter tiles from your bag and spell **one English word**; longer words and rarer letters deal more damage. Spend the monster's HP to zero before your turns run out to win the round, earn money, and shop for better tiles and upgrades. There is **no player HP** — running out of turns while the monster still lives is the only way to lose.

Delivered as a single Godot **Web (HTML5) export**, self-hosted via Docker, and reused as the game surface inside thin iOS/Android WebView shells.

## Tech Stack

- **Engine:** Godot 4.7.x (GDScript typed)
- **Rendering:** 2D, Container-based responsive UI
- **Resolution:** 540x960 logical viewport, 9:16 aspect ratio, `canvas_items` stretch mode, `keep` aspect
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
- Exclude filter: `addons/godot_mcp/*` never ships.

## Architecture

### Service-based with Event Bus

**Autoloads (8 singletons, registered in `project.godot`):**

| Singleton | Responsibility |
|---|---|
| `EventBus` | Signal definitions only — no logic |
| `GameState` | Runtime state: money, round, bag, hand, current monster, turn/redraw budgets, upgrades, active pack/bag ids |
| `PackService` | Active Cherry MX pack modifier lookups |
| `KeyCapService` | Draw hand from bag, targeted redraw swaps, resolve ability effects, starter bag loaders |
| `ShopService` | Shop inventory generation, buy/sell/reroll, persistent run upgrade purchases |
| `WordService` | Dictionary loading (`data/words.json`), word validation, word length multiplier |
| `CombatService` | Round setup, per-turn word validation & scoring, damage application, win/lose from turn budget |
| `ResolutionManager` | Cross-platform desktop window sizing (82% height cap, 9:16 aspect preservation) and mobile fullscreen |

**Autoload order matters:** `EventBus`, `GameState`, `PackService`, `KeyCapService`, `ShopService`, `WordService`, `CombatService`, `ResolutionManager`.

### Screens

| Scene | Purpose |
|---|---|---|
| `MainMenuScreen` | Title + Start Run button |
| `RunSetupScreen` | Cherry MX Pack (5) + Starter Bag (4) selection |
| `CombatScreen` | Word builder: hand tiles with deep-travel latched state, WordRuneSlot magical rune display strip, damage preview, scoring banner, BagModal, VictoryModal |
| `ShopScreen` | Buyable tiles grid, sell/reroll, upgrade column |
| `GameOverScreen` | Round reached + money display, restart |

### GameRoot State Machine

```
MENU → RUN_SETUP → COMBAT ←→ SHOP → GAME_OVER
                     ↑            │
                     └── shop ─────┘
```

`GameRoot` (`scripts/game_root.gd`) is a `Node` that instantiates/destroys screen scenes as children. Transitions driven entirely by `EventBus` signals.

### Scoring Animation (CombatScreen)

Balatro-style sequential animation with deliberate timing:
1. **Banner entrance** (0.25s fade + scale)
2. **Phase A: Sequential letter hop** — each tile hops up (0.15s), lands with bounce (0.18s), floating score label fades up, 0.2s pause between tiles
3. **Phase B: Multiplier ignition** — mult panel pulses, ramps from 1.0 to final mult over 0.35s (words ≥3 only)
4. **Phase C: Final resolution** — total damage label appears with scale pulse, projectile flies from banner to monster (0.35s), HP bar drops smoothly (0.4s), damage float text, banner fades out (0.25s)
5. **Phase D: Commit** — `CombatService.commit_word()` called

Player can click during animation to skip remaining animation.

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

1. **Draw** — fill hand to current draw size (default 5) by sampling random tiles from bag. Tiles are NOT consumed — they return to bag at turn end. No discard pile.
2. **Spell** — build exactly one word from hand tiles. Tap tile to add to word strip; tap word strip tile to remove it. Drag-and-drop reorder within word strip. Wildcard tiles open a letter picker popup.
3. **Play** — any length ≥1 is valid. 1-2 letter plays deal flat base power (no multiplier). 3+ letter plays must be in the dictionary.
4. **Score** — sequential Balatro-style animation, then damage applied.
5. **End turn** — tiles return to bag; decrement turns; next turn begins.

### Redraw (Targeted Swap)

- Toggle redraw mode: tap tiles in hand to mark for swap.
- Costs **1 redraw token** per redraw action (any number of tiles at once).
- Default redraw tokens per round: **3**. Shop raises cap.
- Marked tiles animate out, replacements animate in.

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
boss_modifier: String?    (null, "vowel_lock", "consonant_lock", "no_repeats", "silence")
```

### GameState Fields

```
money: int
round_number: int
bag: Array[Dictionary]        (permanent tile collection)
hand: Array[Dictionary]       (current turn's tiles)
current_monster: Dictionary
shop_inventory: Array[Dictionary]
active_pack_id: String
active_starter_bag_id: String
turns_left: int               (reset to round_turn_budget each round)
redraws_left: int             (reset to round_redraw_budget each round)
upgrade_draw: int             (bag-size upgrade bonus)
upgrade_turns: int            (per-round turn bonus)
upgrade_redraws: int          (per-round redraw bonus)
next_draw_bonus: int          (one-time extra draw, e.g. Blue sticker)

round_turn_budget()   = BASE_TURNS(3) + upgrade_turns
round_redraw_budget() = BASE_REDRAWS(3) + upgrade_redraws
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

## Scoring Formula

```
word_damage = round(sum(letter_base + abilities) * length_multiplier) + flat_bonus_damage
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

## Cherry MX Switch Packs

| Pack | Effect |
|---|---|
| MX Red | +1 draw per turn |
| MX Blue | +2 power per tile used |
| MX Brown | +1 power per tile used, start with +$5 |
| MX Black | +3 power per tile used, -1 draw per turn |
| MX Speed | Draw 6 tiles per turn (overrides base) |

## Starter Bags

| Bag | Tiles | Start Money |
|---|---|---|
| Standard | E T A O I N S R (8) | 0 |
| Vowel Explorer | E E A A I O U ~ (8) | 0 |
| Consonant Heavy | T N S R V K X J Q Z (10) | 0 |
| Minimalist | E T A O I R (6) | 15 |

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
|---|---|
| `data/words.json` | Word dictionary (~370k words, 3+ letters) |
| `data/key_caps.json` | Shop pool tiles (letter + abilities + modifiers) |
| `data/monsters.json` | Normal + boss monster definitions |
| `data/packs.json` | Cherry MX pack modifiers |
| `data/starter_bags.json` | Starting bag loadouts |

## Key Design Decisions

- 1-2 letter plays are valid (no skip turn) — deal base power only, no multiplier
- Redraw costs 1 token per action (any number of tiles), not per tile
- Victory money held back until Continue button pressed
- No player HP, no shield, no healing
- No discard pile — tiles return to bag at turn end
- All UI responsive via Containers — no fixed positions

## KeyCap 3-Layer Mechanical Sandwich Architecture

Each `KeyCapElement` tile is a context-aware stack rendering from back to front. One scene, two rendering modes:

- **Embedded mode** (`embedded_mode = true`, set by `CombatScreen` hand tiles): the switch is cropped to its upper housing and a dark socket shadow sits at its base — the switch is socketed into the stone altar plate (image.jpg black-mask match).
- **Standalone mode** (default; ShopScreen/RunSetupScreen previews): the full switch with complete bottom skirt is shown — the keycap as a full product.

| Layer | Node | Source | Description |
|---|---|---|---|
| **Root** | `Control` (48×54) | — | KeycapButton root bounding box, `mouse_filter = PASS`. Holds SocketShadow (embedded only) + SwitchBase (bottom) + CapLayer (top). |
| **SocketShadow** | `ColorRect` (38×3 at 5,46) | — | Dark recessed socket slit `Color(0.08, 0.10, 0.14, 0.95)`, `visible` only in embedded mode. Reads as the carved slot the switch plugs into. |
| **SwitchBase** | `TextureRect` | `keycap_kit_6.png` Row 3 (switches) | Cherry MX transparent housing + colored cross-stem. Standalone: position (5,22), size 38×28, full uncropped atlas. Embedded: position (5,26), size 38×22, cropped **duplicate** of the atlas (`region.size.y *= 0.79`). Atlas key = `"switches"` + `GameState.active_pack_id` (mx_red/mx_blue/mx_brown/mx_black/mx_speed). Always visible, fixed position — never moves. |
| **CapLayer** | `Control` (48×40 at 0,0) | — | Wraps CapTexture, OverlayTexture, LegendContainer, MarkFrame, and PowerLabel as a single movable unit. `position.y` is animated for press/release. |
| **CapTexture** | `TextureRect` (full rect, child of CapLayer) | `keycap_kit_6.png` Row 1/2 | The movable keycap. `cap_unpressed` (Y=0) or `cap_pressed` (Y=5px, squashed sprite). |
| **OverlayTexture** | `TextureRect` (full rect, child of CapLayer) | `keycap_kit_6.png` Row 4 | Finish/condition/sticker overlays (foil, holographic, glass, sticker_gold). |

**Layer ordering** (back to front): `SocketShadow → SwitchBase → CapLayer (CapTexture → OverlayTexture → LegendContainer → MarkFrame → PowerLabel)`.

**Embedding logic** (`@export var embedded_mode: bool = false`, setter `set_embedded_mode(enabled)`): `_apply_switch_base()` branches on the flag. Embedded: `SocketShadow.visible = true`; the switch atlas is **duplicated** (`base_atlas.duplicate()`) and `cropped.region.size.y *= 0.79` before assignment — the crop is proportional (~21%) because the switch slice is 262×258 source px (a literal 6px crop would remove only ~0.7 display px). The duplicate guarantees the shared cached atlas used by standalone/Shop tiles is never mutated. Embedded geometry: SwitchBase `position (5,26)`, `size (38,22)`. Standalone: `SocketShadow.visible = false`, full atlas, `position (5,22)`, `size (38,28)`. `SwitchBase` uses `mouse_filter = 2` (ignore) so it never intercepts clicks, `expand_mode = 1` (EXPAND_IGNORE_SIZE), and `stretch_mode = 5` (STRETCH_KEEP_ASPECT_CENTERED). The switch housing is always at the same Y position — only the CapLayer moves on press/release.

**CapLayer** is a `Control` (48×40 at (0,0)) that wraps CapTexture, OverlayTexture, LegendContainer, MarkFrame, and PowerLabel as a single movable unit. On press/release, `CapLayer.position.y` is animated from `UNPRESSED_CAP_Y` (0.0, floating high as in image-2) to `PRESSED_CAP_Y` (5.0, squashed as in image-3), plunging the entire keycap down to rest solidly on the fixed switch base and cover the top of the stem.

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

Bottom action buttons (REDRAW / PLAY) sit below the slab on the stone floor at Y≈845–900px.

## Unified Keycap Physics

Both real-time mouse-down press and latched (word-strip) state share identical visual behavior:

| Aspect | Behavior |
|---|---|
| **Sprite** | `cap_pressed` atlas texture (squashed perspective) |
| **Vertical offset** | 5px downward (`PRESSED_CAP_Y` from `UNPRESSED_CAP_Y` 0.0) |
| **Color tint** | `Color(0.85, 0.88, 0.95, 1.0)` — slight tactile shading |
| **CapLayer offset** | Entire CapLayer shifts 5px down, plunging keycap flush onto fixed SwitchBase |

On mouse-button release, the keycap **never pops up** — it remains in the pressed position. CombatScreen then either calls `set_latched(true)` (seamless stay-down) or the next interaction pops it up. This eliminates the 1-frame jitter where the keycap would bounce up before being latched back down.
