# Letter Rogue — Implementation Plan & Status

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement tasks. Steps use `- [ ]` syntax.

## Completed Milestones

### Core Architecture
- [x] Autoload singletons: EventBus, GameState, PackService, KeyCapService, ShopService, WordService, CombatService, ResolutionManager
- [x] GameRoot state machine: MENU → RUN_SETUP → COMBAT → SHOP → GAME_OVER
- [x] EventBus signal-driven screen transitions
- [x] ResolutionManager: cross-platform desktop/mobile window sizing
- [x] Custom theme with font scale variations (`default_theme.tres`)

### Data Layer
- [x] `data/words.json` — word dictionary (~370k words, 3+ letters)
- [x] `data/key_caps.json` — shop pool letter tiles with abilities, finishes, stickers, conditions
- [x] `data/monsters.json` — normal + boss monsters with modifiers
- [x] `data/packs.json` — 5 Cherry MX packs with draw/score/start-money modifiers
- [x] `data/starter_bags.json` — 4 starter bag loadouts (Standard, Vowel Explorer, Consonant Heavy, Minimalist)

### Services
- [x] `WordService` — dictionary load/lookup, word length multiplier (1-2 = 1.0, 3 = 1.0, 4 = 1.3, 5 = 1.6, 6 = 2.0, 7+ = 2.5)
- [x] `KeyCapService` — draw hand from bag, targeted redraw swaps, resolve_ability, starter bag loaders
- [x] `CombatService` — round setup, validate_word (1-2 letter valid, 3+ needs dictionary), calculate_word, commit_word, monster damage/win-lose
- [x] `ShopService` — tile buy/sell/reroll, run upgrades (Bigger Bag, Extra Turn, Extra Redraw)
- [x] `PackService` — pack lookup for draw/score modifiers

### Screens
- [x] `MainMenuScreen` — title + Start Run button (simplified, no pack list)
- [x] `RunSetupScreen` — pack cycler (5 Cherry MX) + bag selector (4 starter bags) with preview
- [x] `CombatScreen` — word builder: hand tiles, word strip (drag-drop reorder), hint label, scoring banner, wildcard letter picker popup
- [x] `ShopScreen` — buy/sell/reroll tiles, run upgrade column
- [x] `GameOverScreen` — round reached + money

### Components & Modals
- [x] `KeyCapElement` — reusable tile widget: letter, rarity bg, ability label, finish/sticker/condition badges, position index, drag-drop support, selection state, used state, latched state with 5px deep-travel animation
- [x] `WordRuneSlot` — magical rune display slot: cyan letter label, amber power badge, obsidian/cyan StyleBoxFlat panel, tap-to-dismiss
- [x] `BagModal` — bag inspector: per-letter frequency counts, vowel/consonant ratio
- [x] `VictoryModal` — itemized reward receipt with counting-up total animation, Continue button
- [x] `ScoringBannerOverlay` — Balatro-style scoring HUD with sequential per-tile hop animation, multiplier ramp, total damage reveal, projectile to monster

### Combat Mechanics
- [x] Turn budget system (default 3 turns/round)
- [x] Redraw tokens (default 3/round), toggle mode with tile marking
- [x] 1-2 letter valid plays (no skip turn button)
- [x] 3+ letter dictionary validation
- [x] Boss modifiers: vowel_lock, consonant_lock, no_repeats, silence
- [x] Wildcard tile popup letter picker
- [x] Scoring animation with skip-on-click
- [x] Ability/finish/sticker/condition stacking in scoring
- [x] Hand tile deep-travel latch: tapping a tile drops it 5px with pressed skin, tapping again springs it back up
- [x] Magical rune display strip: WordRuneSlot replaces KeyCapElement in mid zone — glowing cyan/obsidian runic terminal aesthetic

### Display & Layout
- [x] 540x960 viewport, 9:16 portrait orientation
- [x] `canvas_items` stretch mode
- [x] Desktop window sizing (82% height cap)
- [x] MSDF font rendering with theme variations
- [x] Safe area margins (top 96, bottom 64-80)

## Current Active Tasks

### Layout & Responsiveness
- [x] **Adaptive hand tile layout** — single row ≤5, dual rows 6–10+, fixed keycap size 48×54px and font 20
- [x] **Fix hand tile centering over stone altar** — HandTileContainer must be horizontally centered (SIZE_SHRINK_CENTER), rows must center, not left-align
- [x] **Unify keycap press physics** — mouse-down press must use same cap_pressed sprite + 5px offset as latched state
- [x] **Fix keycap release jitter** — don't pop up on release, let CombatScreen decide latched state seamlessly

### Polish & Juice
- [x] **KeyCap 3-layer sandwich (SwitchBase + CapLayer + CapTexture/OverlayTexture)** — Mount Cherry MX switch housing beneath every keycap, driven by `GameState.active_pack_id`. CapLayer wraps textures as movable unit, plunges 6px onto fixed SwitchBase.
- [x] **Shift hand tiles down onto stone slab** — HandTileContainer Y anchor moved to 745–830px, tiles rest directly on stone altar surface. MidZone_Blue min height 210.
- [x] **Fix keycap elevation over switch** — SwitchBase fixed at (5,24) on slab surface; CapLayer (48×44) plunges 5px on press, SwitchBase (38×28) stays planted.
- [x] **Calibrate hand keyboard to stone altar safe zone** — HandTileContainer anchored absolutely at Position (106,704), Size (324,110) (measured white-mask safe box, 540×960 viewport); realistic keycap pitch (8px H separation, 6px V separation); fixed keycap size 48×56; 5px keycap plunge travel.
- [x] **Shift hand keyboard up 10px & reconstruct keycap-to-switch stacking (image-2/image-3 match)** — HandTileContainer position.y 714→704, size (324,110); KeyCapElement root 48×56, SwitchBase (38×28) at (5,24) extending below the cap skirt (stretch_mode KEEP_ASPECT_CENTERED), CapLayer (48×44) floats at UNPRESSED_CAP_Y 0.0 and plunges to PRESSED_CAP_Y 5.0 on press/latch, tint (0.85,0.88,0.95).
- [x] **Plate-mounted socket masking for Cherry MX switch (image.jpg black-mask match)** — SwitchSocketContainer (`clip_contents = true`, 38×22 at (5,14)) clips the bottom 6px (~19%) of the SwitchBase (38×28, STRETCH_KEEP native top-left) so the switch appears socketed/embedded into the stone altar plate; StoneSocketSlot ColorRect (40×6 at (4,30), dark `Color(0.1,0.12,0.16,0.9)`) adds the recessed slot shadow/bevel line at the base.
- [x] **Restore visible switch base underneath keycaps (image-2/image-3 match)** — previous socket container (Y=14..36) was fully covered by the opaque 44px cap; flattened hierarchy: root 48×54 mouse_filter PASS, CapLayer (0,0) 48×40, SwitchBase direct child standalone (5,22) 38×28 full atlas extending ~10px below cap skirt (5px projection when cap plunges to PRESSED_CAP_Y 5.0); CombatScreen `_refresh_hand()` tile_size (48,54) so runtime tiles match the root.
- [x] **Context-aware keycap switch embedding (Combat embedded vs Shop standalone)** — `@export embedded_mode: bool = false`; `set_embedded_mode(enabled)` re-applies skin; CombatScreen `_instantiate_tile()` sets `embedded_mode = true`. Embedded: `SocketShadow` ColorRect (38×3 at (5,46), `Color(0.08,0.10,0.14,0.95)`) visible, SwitchBase (5,26) 38×22 with **cropped duplicate** atlas (`region.size.y *= 0.79`, proportional ~21% because the switch slice is 262×258 source px — literal `-= 6.0` would crop only ~0.7 display px). Standalone (ShopScreen/RunSetupScreen): SocketShadow hidden, full uncropped switch (5,22) 38×28. Crop applied on `duplicate()` so the shared cached atlas is never mutated.
- [ ] **SFX Audio Manager** — hook audio calls (commented-out `AudioManager.play()` calls in CombatScreen) with a simple autoload AudioManager that plays from `res://assets/audio/`
- [ ] **Particle effects** — add particle emitters for tile score bursts, damage impact, victory celebration
- [ ] **Redraw animation polish** — ensure smooth in/out tweens for swapped tiles
- [ ] **Scoring banner positioning** — verify banner fits all viewport sizes without overflow
- [ ] **Shop upgrade pricing display** — ensure upgrade cost button updates dynamically after purchase
- [ ] **HP bar styling** — add gradient/color transitions for damage

### Testing & Quality
- [ ] **Headless verify harness** — create `_verify.gd`/`_verify.tscn` for automated regression
- [ ] **Edge cases** — empty bag, empty hand, zero turns left boundary, wildcard with no letters in picker
- [ ] **Bag overflow** — bag larger than hand draw size (already handled via `mini()`)

## Upcoming Backlog

### Content Expansion
- [ ] **More boss variations** — additional boss modifiers beyond the current 4
- [ ] **More shop items** — additional upgrades, consumables, special tiles
- [ ] **Additional Cherry MX packs** — more pack variety
- [ ] **Pack unlock progression** — stake/difficulty system (Balatro-style)
- [ ] **Endless mode** — continue past boss rounds with escalating difficulty
- [ ] **Achievements** — track milestones, word stats, longest word

### Mobile & Deployment
- [ ] **WebView build pipeline** — automate Godot Web export
- [ ] **iOS/Android shell apps** — thin WebView wrappers
- [ ] **Docker deployment** — nginx serving Web export with gzip/cache headers
- [ ] **PWA support** — service worker for offline play

### Future Features
- [ ] **Animation skip** — tap to skip scoring animation (placeholder logic exists, needs completion)
- [ ] **Tooltips** — long-press tile info showing ability/finish/sticker/condition details
- [ ] **Sound effects** — tile click, word commit, damage, victory jingle
- [ ] **Background music** — menu and combat tracks
- [ ] **Tutorial overlay** — first-run explanation of mechanics
- [ ] **Statistics screen** — end-of-run stats (words spelled, longest word, total damage, etc.)
- [ ] **Save/load** — persist run state across sessions
