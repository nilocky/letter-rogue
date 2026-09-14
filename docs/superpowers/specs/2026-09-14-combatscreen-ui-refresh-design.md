# CombatScreen UI Refresh & New Systems Design

**Date:** 2026-09-14
**Status:** Approved in chat; implementation ready

---

## 1. Overview

This redesign refactors CombatScreen to match the mockup layout (`idea_combat_1.jpg`) using the new background `bg_combat_3.jpg`. It adds:

- Fixed 2×5 keyboard grid with unlockable slots
- Persistent BASE/MULT display (always visible below monster)
- HINT button with gradated hint system
- DECK button (enhanced bag modal showing bag + discard pile)
- Top HUD bar with depth info, clickable grimoire icons, settings, and draggable/sellable artisan status icons

---

## 2. Background Zones

Viewport: **540×960** (`display/window/size/viewport_width/height`)

`bg_combat_3.jpg` zones (vertical):

| Range | Visual | UI Placement |
|-------|--------|--------------|
| ~0-12% | Dark rune pillars | HUD bar (depth, grimoires, settings, money) |
| ~12-45% | Floating stone altar | Monster sprite + name + HP bar + persistent BASE/MULT |
| ~45-65% | Arch/torch transition | Word rack (spelled letters) |
| ~65-100% | Stone floor + rubble | Fixed 2×5 keyboard + action buttons |

Margins kept similar to existing: ~46px horizontal; vertical redistributed.

---

## 3. New Data Model (GameState Additions)

```gdscript
# scripts/autoload/GameState.gd — new fields

var unlocked_key_slots: int = 8        # 10 total; start with 8 usable
var active_grimoires: Array = []       # {"id", "name", "description", "price_paid", "sellable"}
var hint_quality: int = 1              # 1=basic, 2=improved, 3=optimal
var hints_remaining: int = 3           # per-round budget, like redraws
var upgrade_hints: int = 0              # hint count upgrades across run
```

Per-round hint budget computation (mirrors `round_redraw_budget()`):

```gdscript
func round_hint_budget() -> int:
    return BASE_HINTS + upgrade_hints
```

`BASE_HINTS = 3` constant added alongside `BASE_REDRAWS`, `BASE_TURNS`.

---

## 4. Fixed 2×5 Keyboard Layout

**Scene node:** `%FixedKeyboardGrid` (GridContainer, columns=5)

Slots numbered 0-9, arranged:
```
row 0: 0 1 2 3 4
row 1: 5 6 7 8 9
```

**Slot states:**
1. **Unlocked + filled**: shows keycap tile from hand, interactive
2. **Unlocked + empty**: shows empty slot visual, no interaction
3. **Locked**: shows padlock icon, dimmed, non-interactive

**Logic:**
- `draw_size()` determines how many tiles we actually draw
- `unlocked_key_slots` determines how many of the 10 slots are usable
- Actually rendered tiles = `min(draw_size(), unlocked_key_slots)`
- Hand container code in `CombatScreen.gd` migrates from `_setup_hand_container_geometry()` + dynamic HBox/VBox construction → instead populates the fixed grid

**Unlocks in shop:** later task will add shop items that increase `unlocked_key_slots`. Data model ready now.

---

## 5. Persistent BASE/MULT Display

Currently `%ScoringBannerOverlay` only appears during word-play animation.

**New persistent node:** `%PersistentScoringRow` (HBox):

- `%PersistBasePanel` → shows running letter score sum
- `%PersistMultLabel` → "×"
- `%PersistMultPanel` → shows multiplier

**Update rules:**
- When tiles are added/removed from word rack (`_refresh_word()` / `_update_word_ui()`):
  - Compute:
    - `base_preview` = sum of `_letter_base_score()` for selected letters
    - `length_mult` = `WordService.length_multiplier(selected_count)`
  - Set labels:
    - `persist_base_score.text = "%d" % roundi(base_preview)`
    - `persist_mult_score.text = "×%.1f" % length_mult`
- Artisan bonus preview is **not** included in persistent display (too complex, keeps UI simple)

**During animation:**
- `ScoringBannerOverlay` still runs and draws on top (z-index > persistent row)
- Persistent row can optionally be hidden during animation; simplest: let overlay occlude it.

---

## 6. DECK Button = Enhanced BagModal

**Current BagModal:**
- Shows `GameState.bag` letter counts + vowel/consonant ratio

**Enhanced for DECK:**
- Add `GameState.discard_pile` display
- Two views/tabs: "In Bag" and "Discarded"
- Keep single-scene structure; add a segment control or simple button toggle

**Files:**
- `scripts/components/BagModal.gd`
- `scenes/components/BagModal.tscn`

**DECK button replaces... actually mockup shows 4 buttons: HINT / REDRAW / PLAY / DECK. Current is 2 buttons: REDRAW / PLAY. So we're adding two buttons.**

Action bar becomes: `[HINT] [REDRAW] [PLAY] [DECK]`

---

## 7. HINT Button + Gradated Hint System

New autoload: `HintService.gd`

**Algorithm — Tier 1 (basic):**

Given letters in hand, find **any** valid 3+ letter word:

```gdscript
func find_any_word(letters: Array[String]) -> String:
    # Generate all sorted 3..len combinations
    # For each combination:
    #   If WordService.is_word(combo), return it
    # Fallback: return ""
```

Combinations approach:
- Hand size ≤10, so max checks = 10C3 + 10C4 + ... + 10C8 = ~968 worst case, but short-circuit on first hit.
- "sorted" because dictionary words are checked in canonical order; if hand has [C,A,T], combination "ACT" checks `is_word("ACT")` which may be false while "CAT" is true. We actually need to generate **permutations** or sort+anagram-lookup.

**Better — anagram map lookup:**

Precompute once in `WordService`: map from `sorted_letters` → `[actual_word1, actual_word2, ...]`

e.g., `"ACT"` → `["ACT", "CAT"]`

At hint time:
1. Take multiset of available letters
2. For subset sizes 3..N:
   - Generate all unique sorted letter combinations respecting counts
   - Look up in anagram map
   - If found, return any word from the result list

`WordService` doesn't currently expose this, so `HintService` builds its own index on ready.

**Tier 2 and Tier 3 (deferred):**

- Tier 2: among valid words, prefer above-median total letter score
- Tier 3: full damage evaluation including word forms

Marked with `ponytail: hint tiers 2+ deferred; add when users ask for better hints`

---

## 8. HUD Top Bar

### Structure

```
%HUDContainer (VBox)
├── %DepthRow (HBox)
│   ├── %DepthPanel: "DEPTH 2-1"
│   ├── %DepthInfoButton: info icon
│   ├── (spring spacer)
│   ├── %GrimoireRow (HBox): draggable grimoire icons
│   ├── (spring spacer)
│   ├── %MoneyLabel: display-only (currently in TopStatusBar)
│   └── %SettingsButton: gear icon
└── %ArtisanRow: enhanced ArtisanRailDisplay (draggable, tooltips, sellable)
         plus %SellDropZone: small "SELL" area at far right
```

### Depth Info Popup

`%DepthInfoButton` opens `DepthInfoPopup.tscn`:

- Shows:
  - Depth stage: `GameState.depth_stage` → "Stage 1", "Stage 2", etc.
  - Round within stage: `GameState.round_number`
  - Pool preview: from `DepthService.get_stage_pool()` — list monster names in this depth

Uses existing `DepthService` which reads `data/depths.json`.

### Grimoire Icons

Data source: `GameState.active_grimoires` (new array).

When a grimoire consumable is purchased and used:
- Increment `word_form_levels` per its `effect_params`
- Also push to `active_grimoires`: `{"id", "name", "description", "icon_texture"}`

**Icon behaviour:**
- Hover/touch long-press → show tooltip: name + description
- Drag: pick up and reorder within `%GrimoireRow`
- Drag to `%SellDropZone`: attempt sell

**Sell rules (starting simple):**
- Grimoires have permanent effect. Can't be undone.
- So `sellable = false` after use.
- If user drags to sell: show "Cannot sell permanent upgrades" toast.

**Later** may introduce *temporary* grimoires; but data model has `sellable` flag ready.

### Artisan Rail Enhancement

Existing `ArtisanRailDisplay` (5 slots) becomes draggable.

Changes to `ArtisanSlot.gd` / `ArtisanRailDisplay.gd`:

- Add `_gui_input` for drag-start detection
- On drag begin: set drag preview using `Control.set_drag_preview()`
- Add `_can_drop_data()` / `_drop_data()` in the rail container to accept reordering
- Hover/touch: show tooltip with artisan `name` + `description`
- Drag to `%SellDropZone`: unequip and refund

**Unequip rules:**
- Artisans are **equipped** (not permanently consumed).
- Selling unequips the artisan, returns it to shop inventory? Or simpler: returns `price_paid * 0.5` money and `rail[slot] = null`.

Add to `ArtisanRailManager.equip()`: also store `price_paid` in the artisan dict if provided.

### Settings Button

For now:
- Check if existing settings scene exists. If not:
- Button prints `push_error("Settings menu not yet implemented")`

Money display moves from `TopStatusBar` into the new HUD.

---

## 9. Node Tree Changes (CombatScreen.tscn)

**Before (simplified):**
```
CombatScreen
├── Background (bg_combat_2.jpg)
├── CombatRootMargin (margins: 46,79,46,60)
│   └── CombatVerticalStack (VBox)
│       ├── TopZone_Red
│       │   ├── TopStatusBar (BagButton / TurnRoundLabel / MoneyLabel)
│       │   └── MonsterDisplayArea (sprite, name, HP)
│       ├── MidZone_Blue (HintLabel, WordRackContainer)
│       ├── BottomZone_Green (HandEmptyWarning)
│       └── ActionZone_Orange (RedrawButton, PlayButton)
├── HandTileContainer (positioned absolute)
├── ArtisanRail (absolute positioned)
├── ScoringBannerOverlay (absolute)
└── WildcardPopup
```

**After:**
```
CombatScreen
├── Background (bg_combat_3.jpg)
├── CombatHUDBar (NEW: top HUD VBox)
│   ├── DepthRow
│   │   ├── DepthPanel, DepthInfoButton
│   │   ├── GrimoireRow
│   │   ├── MoneyLabel
│   │   └── SettingsButton
│   └── ArtisanRow (enhanced ArtisanRailDisplay + SellDropZone)
├── MonsterZone (repositioned VBox, middle altar area)
│   ├── MonsterSprite
│   ├── MonsterNameLabel
│   ├── MonsterHPBar
│   └── HpLabel
├── PersistentScoringRow (NEW HBox: BASE / × / MULT)
├── WordRackZone (VBox: HintLabel, WordRackContainer)
├── FixedKeyboardGrid (NEW GridContainer, cols=5)
├── ActionButtonsRow (HBox: HINT, REDRAW, PLAY, DECK)
├── HandEmptyWarning (moved under keyboard grid)
├── ScoringBannerOverlay (kept, z-index above)
├── WildcardPopup
├── DepthInfoPopup (NEW modal)
└── BagModal (enhanced with discard tab; already exists as prefab)
```

TopStatusBar's `BagButton` is functionally replaced by `DECK` button (which opens the enhanced BagModal). The turn/round display moves into monster area or hint area.

---

## 10. Files Inventory

### Modified

| File | Change |
|------|--------|
| `scripts/autoload/GameState.gd` | New fields: `unlocked_key_slots`, `active_grimoires`, `hint_quality`, `hints_remaining`, `upgrade_hints`. New `round_hint_budget()`. `reset()` clears new fields. |
| `scripts/autoload/CombatService.gd` | No changes needed (unless we add preview helpers; try to avoid) |
| `scripts/autoload/WordService.gd` | Optional: expose anagram map; if not, `HintService` builds own index |
| `scripts/autoload/ArtisanRailManager.gd` | Add optional `price_paid` tracking in equip data; no change to existing callers |
| `scripts/screens/CombatScreen.gd` | Major rewrite of hand rendering → fixed grid, persistent scoring updates, HINT/DECK button wiring, HUD hookup |
| `scenes/CombatScreen.tscn` | Restructure node tree, background swap to `bg_combat_3.jpg` |
| `scripts/components/BagModal.gd` | Add discard pile view + toggle |
| `scenes/components/BagModal.tscn` | UI for tab/view toggle |
| `scripts/components/ArtisanSlot.gd` | Drag start, hover tooltip |
| `scripts/components/ArtisanRailDisplay.gd` | `_can_drop_data`/`_drop_data` for reordering |

### Created

| File | Purpose |
|------|---------|
| `scripts/autoload/HintService.gd` | Word suggestion logic (Tier 1) |
| `scripts/components/GrimoireIcon.gd` | Draggable grimoire icon control |
| `scripts/components/GrimoireRow.gd` | Container with drop handling for reorder |
| `scenes/components/DepthInfoPopup.tscn` | Depth info modal scene |
| `scripts/components/DepthInfoPopup.gd` | Depth info modal logic |
| `assets/textures/backgrounds/bg_combat_3.jpg` | Copied/moved from `examples/bg_combat_3.jpg` |
| `tests/test_hint_service.gd` | Hint correctness tests |
| `tests/test_fixed_keyboard.gd` | Slot unlock/hand population tests |

### Moved

| From | To |
|------|-----|
| `examples/bg_combat_3.jpg` | `assets/textures/backgrounds/bg_combat_3.jpg` |
| (import file regenerated) | |

---

## 11. Deferred / ponytail Markers

| Location | Item | When to revisit |
|----------|------|-----------------|
| `HintService.gd` | Tier 2/3 hints (scored preference, optimal) | When users ask for "better hints" |
| Grimoire sell | Selling permanent upgrades currently disabled | If temporary consumables added later |
| Settings button | Full settings menu implementation | When there are actual settings to change |
| BASE/MULT preview | Artisan contribution not included in persistent preview | If users want full live preview complexity |

---

## 12. Testing Strategy

- `test_hint_service.gd`: given known letters, verify it returns a valid `WordService.is_word()` word of length ≥3
- `test_fixed_keyboard.gd`: verify `unlocked_key_slots` clamping, hand population into slots
- No new test framework; use existing GUT pattern from `tests/test_*.gd`

---

## 13. Spec Self-Check

1. **Spec coverage**: All approved items covered: bg swap, zone repositioning, fixed 2×5 keyboard with slot unlocks, persistent BASE/MULT, HINT+gradated, DECK, HUD depth+grimoire+artisan drag-drop-sell-tooltips.

2. **No placeholders**: All sections have concrete data model and node structure. Deferred items explicitly marked.

3. **Types consistent**: New `GameState` fields have clear types; scene node references use `%UniqueName` convention per project style.
