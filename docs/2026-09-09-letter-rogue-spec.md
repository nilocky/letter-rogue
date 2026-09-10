# Letter Rogue — Game Design Spec (V2: Spell Your Own Words)

> A word-spelling roguelite where you build real dictionary words from random letter tiles to damage monsters before your turn budget runs out.

## Overview

Letter Rogue is a 2D roguelite built in Godot. Each round pits you against a monster with a fixed HP pool and a **turn budget**. On every turn you draw a random hand of letter tiles from your bag and spell **one English word**; longer words and rarer letters deal more damage. Spend the monster's HP to zero before your turns run out to win the round, earn money, and shop for better tiles and upgrades. There is **no player HP** — running out of turns while the monster still lives is the only way to lose.

Delivered as a single Godot **Web (HTML5) export**, self-hosted via Docker, and re-used as the game surface inside thin iOS/Android WebView shells.

## Tech Stack

- **Engine:** Godot 4.x (GDScript)
- **Rendering:** 2D (CanvasLayer-based)
- **Resolution:** Dynamic / responsive — Desktop landscape (1920x1080 target), Mobile portrait (1080x1920 target), plus arbitrary browser/WebView aspect ratios

## Delivery Platform

One Godot **Web export** is the single artifact; every client loads that same build.

| Client | How it runs |
|---|---|
| Desktop browser | HTML5 export in a browser tab |
| Mobile browser | Same HTML5 export, responsive layout |
| iOS shell | Thin native app embedding the hosted URL in a `WKWebView` |
| Android shell | Thin native app embedding the hosted URL in a `WebView` |
| Hosting | Self-hosted static web server via Docker (`deploy/web/`) |

Web constraints that shape implementation:

- All game data ships inside the exported pck (`res://data/*.json`, `res://data/words.json`). No runtime file access, no external fetches.
- UI is 100% `Container`/anchor based so it reflows for any viewport the WebView/window reports.
- Input: touch and mouse both supported (Godot "Emulate Touch From Mouse" stays on for desktop testing).
- iOS/Android shells are out of scope for the core game tasks (store WebView-policy risk flagged separately); the web build must simply work when hosted and loaded in a WebView.

## Architecture

### Service-based with Event Bus

**Autoloads (7 singletons):**

| Service | Responsibility |
|---|---|
| `EventBus` | Signal definitions only |
| `GameState` | Runtime state: money, round, bag (tile collection), hand, current monster, turn budget, redraw budget, draw size, upgrades, active pack |
| `KeyCapService` | Draw hand from bag, return letters to bag, resolve ability effects, buy/sell tiles |
| `WordService` | **NEW** — dictionary loading, word validation, word length multiplier |
| `CombatService` | Round setup, per-turn damage application, win/lose from turn budget |
| `ShopService` | Shop inventory + buy/sell/reroll + upgrade purchases |
| `PackService` | Active Cherry MX pack modifier |

**Scenes:**

| Scene | Purpose |
|---|---|
| `MainMenuScreen` | New Run button + pack selection |
| `CombatScreen` | Word builder: hand tiles, current word, damage preview, turn + redraw counters |
| `ShopScreen` | Buyable tiles, tile bag view, reroll, upgrade shop |
| `GameOverScreen` | Round reached, restart |

**GameRoot** runs a state machine that shows/hides screens and listens to EventBus for transitions.

### Responsive Layout

All UI uses Godot `Container` nodes with anchors — no fixed positions. The layout is a **word-spelling bar** rather than fixed monster-word slots, so it must reflow cleanly from landscape to portrait:

- **Landscape:** monster name/HP + counters top-left, spelled-word strip center-top, hand tiles bottom-center, damage preview + confirm bottom-right
- **Portrait:** monster + counters top, word strip + controls middle, hand tiles bottom (wrap)
- **ShopScreen:** buyable tiles grid + bag grid + an upgrade column; grids adapt columns to aspect
- **KeyCap elements:** `Control` with `min_size` + expand flags; letter and ability text scale with container

Godot window stretch mode uses `canvas_items` with `expand`.

## Core Loop

```
MainMenu → Combat → (monster dead?) → Shop → Combat → ... → GameOver
                ↑                          │
                └ (turns exhausted) ────────┘
```

### Round

- Each round: one monster with `hp`/`max_hp` plus a **turn budget**.
- Default turn budget per round: **3**. Shop upgrade items raise it permanently for later rounds.
- **Lose condition:** the turn budget is exhausted while the monster is still alive → Game Over. There is no player HP, shield, or healing anywhere in the game.

### Turn loop

1. **Draw** — fill the hand to the current **draw size** (default 5, raised by bag-size upgrades / pack) by drawing random tiles from the bag. Letter tiles are *not* consumed by a round; they return to the bag when the turn ends.
2. **Spell** — build exactly **one word** from hand tiles. Click a tile to add it to the word; click it again (or backspace) to remove/deselect it. Word-strip tiles can be **dragged to reorder** (drag-and-drop), and each used hand tile shows its 1-based position badge.
3. **Confirm** — allowed only when the word is:
   - length ≥ 3 and ≤ draw size,
   - present in the bundled dictionary (`WordService.is_word`),
   - buildable from the current hand.
4. **Damage** — each word-strip tile plays a **sequential letter-hop animation** (per-tile power floats up and fades) before damage is dealt to the monster (see Scoring). If the monster reaches 0 HP → round won → Shop.
5. **End turn** — tiles (except broken Glass) return to the bag; hand clears; decrement turns remaining; next turn begins.

If the hand cannot form any valid word the player has two non-soft-lock escapes:

- **Redraw (targeted swap)** — spend **1 redraw token** to put a chosen hand tile back into the bag and draw a replacement from the bag. Default redraw tokens per round: **3**; shop items raise the per-round cap.
- **Skip turn** — end the turn dealing no damage (still consumes a turn).

> Design decision: redraw swaps a *specific chosen tile*, and redraw tokens are a separate per-round budget (default 3) that shop upgrades increase. Wildcards are assigned: click a wildcard tile, then pick the letter it represents.

## Data Model

```
Rarity enum: Normal, Rare, Epic, Legendary

KeyCap:
  letter: String            (single uppercase A-Z **or a wildcard symbol**)
  ability_id: String        ("bonus_points", "double_score",
                             "money_bonus", "bonus_damage")
  rarity: Rarity
  ability_strength: int
  is_symbol: bool            (true only for wildcard tiles)
  finish: String?           (null, "foil", "holographic", "polychrome")
  sticker: String?          (null, "gold", "red", "blue")
  condition: String?        (null, "glass", "lucky", "eternal")

Monster:
  name: String
  hp: int
  max_hp: int
  is_boss: bool
  boss_modifier: String?    (null, "vowel_lock", "consonant_lock", "no_repeats", "silence")

GameState:
  money, round: int
  bag: Array[KeyCap]        (permanent tile collection)
  hand: Array[KeyCap]       (current turn's tiles)
  current_monster: Monster
  turns_left: int            (reset to round_turn_budget() each round)
  redraws_left: int          (reset to round_redraw_budget() each round)
  upgrade_draw: int          (bag-size upgrade bonus to letters drawn)
  upgrade_turns: int         (per-round turn bonus from shop)
  upgrade_redraws: int       (per-round redraw bonus from shop)
  next_draw_bonus: int       (one-time extra draw, e.g. Blue sticker)
  active_pack_id: String
  shop_inventory: Array[KeyCap]

  Derived (no stored copy):
  round_turn_budget()   = BASE_TURNS(3)  + upgrade_turns
  round_redraw_budget() = BASE_REDRAWS(3) + upgrade_redraws
  draw_size()           = pack_draw_base() + upgrade_draw + next_draw_bonus
```

### Letter values (power tiers)

The tile's base power, independent of which word it sits in:

| Tier | Letters | Power |
|---|---|---|
| Common | E T A O I N S R | 1 |
| Uncommon | H L D C U M F P G W Y B | 2 |
| Rare | V K X J Q Z | 4 |

Wildcard tiles contribute **0 base power** but still count toward word length.

## Scoring

```
word_damage = round( sum(player_base_power) × length_multiplier(length) ) + flat_bonus_damage
```

`sum(player_base_power)` = total base power of the letter tiles used, plus per-tile ability/finish/sticker/condition effects where they make sense. `flat_bonus_damage` = flat `bonus_damage` ability contributions, added after the multiplier. The per-letter contributions are also surfaced individually so the combat screen can animate each tile's power as it scores.

Length multiplier (one tunable function):

| Word length | Multiplier |
|---|---|
| 3 | 1.0 |
| 4 | 1.3 |
| 5 | 1.6 |
| 6 | 2.0 |
| 7+ | 2.5 |

Example: spelling `QUIZ` with Q(4)+U(2)+I(1)+Z(4) = 11 power × 1.3 = 14 damage (rounded). Rewarding longer words is intentional — a bigger bag and wildcards let you reach 6+ letter words.

Boss modifiers re-scope to constrain the *spelled* word's scoring (see Bosses).

## Wildcards

Wildcard tiles represent a letter the player picks. Clicking a wildcard tile opens a **popup letter picker** (a grid of the allowed letters with a Cancel button); the chosen letter is what the word is validated and scored as. The picker also re-assigns a wildcard already placed in the word when you click it in the word strip.

| Symbol | Meaning | Rarity |
|---|---|---|
| `*` | Full wild — any A–Z | Epic |
| `~` | Vowel wild — any of A E I O U | Rare |
| `#` | Consonant wild — any consonant | Rare |

Wildcards add 0 base power, count toward word length, and unlock otherwise impossible words. A vowel wild in the hand makes a valid word far more likely.

## Shop

After every won round the player visits the shop. Money is earned from round rewards (see Progression). The shop has two parts:

### 1. Tile inventory (existing cap buy/sell/reroll)

- 5 tiles offered, weighted by rarity; buy into the bag. Each offer tile shows a **price badge**; buying opens a **confirmation dialog** (OK disabled when you can't afford it).
- Sell any owned tile for 50% of its price (Eternal tiles cannot be sold — the sell dialog disables OK for them); bag tiles show their **sell-value badge**.
- Reroll the offer for $3.

### 2. Upgrade shop (new — persistent run upgrades)

| Upgrade | Effect | Base price | Escalation |
|---|---|---|---|
| **Bigger Bag** | +1 letter drawn per turn (draw_size) | $6 | ×2 each purchase |
| **Extra Turn** | +1 turn to the per-round budget | $8 | ×2 each purchase |
| **Extra Redraw** | +1 redraw token per round | $5 | ×2 each purchase |

Upgrades are permanent for the run and stack. Prices are tuning defaults.

A word is spelled from the **letter faces** of your tiles, so only two tile kinds exist:

- **Letter tiles** — a real A–Z face that may also carry an ability, finish, sticker, or condition.
- **Wildcard tiles** — symbol-faced tiles (`*`, `~`, `#`) that stand in for a letter you choose.

Value symbols from V1 (`$`, `+`, `!`, `%`, `@`, `#`-as-shield, …) had *slot-matching* semantics and cannot be a face inside a dictionary word, so their effects now live as **abilities on letter tiles**.

### Abilities (on letter tiles)

| Ability | Effect | Rarity |
|---|---|---|
| `bonus_points` | Flat power bonus added to this tile's contribution | Normal+ |
| `double_score` | Doubles this tile's power contribution | Rare |
| `money_bonus` | +$ when this tile is used in a word | Rare |
| `bonus_damage` | Flat bonus damage added to the whole word | Rare |

Ability effects apply on top of the letter's base power.

### Finishes (visual, independent of ability)

| Finish | Effect | Price Modifier |
|---|---|---|
| **Foil** | +3 flat to this tile's power when used | +$2 |
| **Holographic** | +1 per-letter power when used | +$3 |
| **Polychrome** | 1.5× this tile's power when used | +$5 |

Dropped: `double_shot` (slot matching gone), `neon` (adjacency gone).

### Stickers

| Sticker | Effect |
|---|---|
| **Gold** | Earn +$2 when this tile is used in a word |
| **Red** | Retrigger — this tile's contribution counts twice |
| **Blue** | Draw +1 extra tile next turn |

Dropped: `glow` (tiles return to the bag anyway), `rainbow` (superseded by wildcards).

### Conditions

| Condition | Effect |
|---|---|
| **Glass** | 2× power; 1-in-4 chance to break — removed from the bag permanently |
| **Lucky** | 1-in-5 chance +10 power, 1-in-15 chance +$10 |
| **Eternal** | Cannot be sold |

Dropped: `steel`, `gold_held`, `rental` (all keyed to player HP / held-hand economy that V2 removed).

### Modifier stacking

```
KeyCap = letter + ability + rarity     (base)
       + finish?                       (foil, holographic, polychrome)
       + sticker?                      (gold, red, blue)
       + condition?                    (glass, lucky, eternal)
```

All modifiers are independent and stack multiplicatively/additively per the V2 scoring rules.

## Cherry MX Switch Packs

Chosen before a run. Packs modify core draw/scoring mechanics:

| Pack | Mechanic |
|---|---|
| **MX Red** | +1 draw per turn, no scoring bonus |
| **MX Blue** | +2 power per tile used in a word |
| **MX Brown** | +1 power per tile used; start the run with +$5 |
| **MX Black** | +3 power per tile used, -1 draw per turn |
| **MX Speed** | Draw 6 instead of 5 tiles per turn |

`PackService` applies pack modifiers during `KeyCapService.draw_hand()` and `WordService`/`CombatService` scoring.

## Bosses

A boss appears every 3 rounds. Bosses have more HP and a **modifier** that constrains the words you can spell or how they score:

| ID | Effect |
|---|---|
| `vowel_lock` | Only the vowel tiles in your word contribute power |
| `consonant_lock` | Only the consonant tiles in your word contribute power |
| `no_repeats` | The same letter cannot appear twice in one word |
| `silence` | Tile abilities, finishes, stickers, and conditions are disabled |

Dropped from V1: `mirror_words`, `tight_grip` (both depended on monster-word slot matching).

## Word Dictionary

- Bundled as `data/words.json`: a JSON array of valid uppercase words, **length ≥ 3** (upper bound enforced by draw size, not the file).
- Loaded once by `WordService` into a `Dictionary` (hash lookup by word, keyed by length then word) at startup.
- Ships inside the exported pck; must be included in the Web export (no runtime fetch).
- Source: a public-domain English word list (e.g. dwyl/english-words or an OS dictionary) filtered to `^[A-Z]{3,}$` and deduplicated. Expected size is tens of thousands of words — a lookup `Dictionary`, never a linear scan.

## Progression

- Monster HP scale: `max_hp * (1.0 + (round-1) * 0.15)` — kept from V1 as a tuning default.
- Money reward per won round: `5 + round * 2`, plus in-word `money_bonus`-ability / Gold-sticker / Lucky gains.
- Starter bag: 8 common tiles (E, T, A, O, I, N, S, R) — enough to spell many 3–5 letter words from the default 5-tile hand.
- Boss every 3 rounds.
- Round loss (turn budget exhausted) → Game Over screen showing round reached and money.

## Constraints

- Godot 4.x, GDScript only
- All data in JSON files under `data/`; word dictionary in `data/words.json`
- Single-player
- Responsive: desktop landscape (1920x1080), mobile/WebView portrait (1080x1920) and arbitrary browser aspect
- No audio in vertical slice
- Deliverable runs as a Web (HTML5) export served from a Docker static host and inside iOS/Android WebViews
- KeyCap letter is A-Z (letter tiles that may carry abilities/modifiers) or a wildcard symbol (`*`, `~`, `#`)
- Cherry MX Switch pack selected before run
