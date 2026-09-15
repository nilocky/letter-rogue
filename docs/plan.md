# Letter Rogue — Implementation Plan & Status

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement tasks. Steps use `- [ ]` syntax.

## Completed Milestones

### Core Architecture
- [x] Autoload singletons: EventBus, GameState, PackService, KeyCapService, ShopService, WordService, CombatService, ResolutionManager
- [x] DebugManager autoload (F1 overlay, F12 screenshot, scene routing, state injection, time-scale, mechanic triggers)
- [x] EffectPipeline autoload (hook registry: 11 combat lifecycle events)
- [x] LootService autoload (drop table rolls from monster drop_table_id)
- [x] WordFormService autoload (Word Form detection + grimoire level tracking)
- [x] ArtisanRailManager autoload (5-slot Artisan rail, cascade dispatch)
- [x] DepthService autoload (8-stage encounter generation: Vanguard/Sentry/Boss Gate/Catacombs/Fungal Depths/Crystal Caverns/Void Threshold/Abyssal Crown)
- [x] ConsumableService autoload (tarot/spectral/grimoire effects, bag mutations)
- [x] GameRoot state machine: MENU → RUN_SETUP → COMBAT → SHOP → GAME_OVER
- [x] GameRoot routing hooks: route_to(), inject_state(), trigger_mechanic(), jump_boss_round()
- [x] EventBus signal-driven screen transitions
- [x] ResolutionManager: cross-platform desktop/mobile window sizing
- [x] Custom theme with font scale variations (`default_theme.tres`)

### Data Layer
- [x] `data/words.json` — word dictionary (~370k words, enriched with POS bitmask + definition)
- [x] `data/secret_words.json` — rare secret words (gameplay effect pending)
- [x] `data/drop_tables.json` — weighted loot tables keyed by drop_table_id
- [x] `data/monsters.json` — unified `modifier` field + `drop_table_id`, added Shielded Goblin + Raging Orcs
- [x] `data/key_caps.json` — shop pool letter tiles with abilities, finishes, stickers, conditions
- [x] `data/packs.json` — 5 Switch Packs with conditional passives (Clicky/Linear/Tactile/Heavy Tactile/Silent)
- [x] `data/starter_bags.json` — 4 starter bag loadouts (Standard 14 tiles, Vowel Explorer, Consonant Heavy, Minimalist)
- [x] `data/word_forms.json` — Word Form definitions (Trio/Quartet/Quintet/Hexagram/Double-Tap/Mirror/Consonant Core)
- [x] `data/artisans.json` — 12 Artisan Keycap definitions across 4 archetypes (flat_power/x_mult/synergy/economy)
- [x] `data/consumables.json` — Modder's Toolkit (4 tarot), Cursed Hardware (3 spectral), Lexicon Grimoires (4)
- [x] `data/blueprints.json` — 3 Workshop Blueprints (Anti-Ghosting, Silicone Dampener, Group-Buy Pass)
- [x] `data/firmware_tags.json` — 3 Firmware Tags (Free Grab Bag, Bonus Turns, Double Interest)
- [x] `data/depths.json` — Depth encounter tables (Vanguard/Sentry/Boss pools)

### Services
- [x] `WordService` — dictionary load/lookup, word length multiplier, `get_word_meta()` with POS/definition/vowel/consonant counts
- [x] `CombatService` — round setup, validate_word, 4-phase calculate_word, commit_word (tiles → discard), monster damage/win-lose, EffectPipeline hook integration, unified `_current_modifier()` dispatch
- [x] `ShopService` — tile buy/sell/reroll, run upgrades (Bigger Bag, Extra Turn, Extra Redraw), Blueprint purchases, Grab Bag generation
- [x] `PackService` — pack lookup for draw/score modifiers, `evaluate_conditionals()` for Switch Pack passives
- [x] `KeyCapService` — play-and-refill draw_hand(), vowel safeguard, discard reshuffle, resolve_ability, starter bag loaders

### Screens
- [x] `MainMenuScreen` — title + Start Run button (simplified, no pack list)
- [x] `RunSetupScreen` — Switch Pack cycler (5 Switch Packs) + bag selector (4 starter bags) with preview
- [x] `CombatScreen` — word builder: hand tiles, word strip (drag-drop reorder), hint label, HINT + DECK action buttons, wildcard letter picker popup
- [x] `ShopScreen` — buy/sell/reroll tiles, run upgrade column
- [x] `GameOverScreen` — round reached + money

### Components & Modals
- [x] `KeyCapElement` — reusable tile widget: letter, rarity bg, ability label, finish/sticker/condition badges, position index, drag-drop support, selection state, used state, latched state with 5px deep-travel animation
- [x] `WordRuneSlot` — magical rune display slot: amber letter label, amber power badge, walnut/amber StyleBoxFlat panel, tap-to-dismiss
- [x] `BagModal` — bag inspector: per-letter frequency counts, vowel/consonant ratio
- [x] `VictoryModal` — itemized reward receipt with counting-up total animation, loot drops display, Continue button
- [x] `ScoringBannerOverlay` → `PersistentScoringRow` — Balatro-style scoring HUD relocated inline into `TopZone_Red` (BASE/MULTI panels, scale-punch start animation instead of banner fade), `TotalDamageShelf` reveals total damage

### Combat Mechanics
- [x] Turn budget system (default 3 turns/round)
- [x] Redraw tokens (default 3/round), toggle mode with tile marking
- [x] 1-2 letter valid plays (no skip turn button)
- [x] 3+ letter dictionary validation
- [x] Boss modifiers: vowel_lock, consonant_lock, no_repeats, silence (unified `modifier` field, works on normal monsters too)
- [x] Wildcard tile popup letter picker
- [x] Scoring animation with skip-on-click
- [x] Ability/finish/sticker/condition stacking in scoring
- [x] Hand tile deep-travel latch: tapping a tile drops it 5px with pressed skin, tapping again springs it back up
- [x] Magical rune display strip: WordRuneSlot replaces KeyCapElement in mid zone — glowing cyan/obsidian runic terminal aesthetic

### Display & Layout
- [x] UISandbox gallery scene (safe-area overlay, touch-target grid, mouse-filter demo boxes)
- [x] 540x960 viewport, 9:16 portrait orientation
- [x] `canvas_items` stretch mode
- [x] Desktop window sizing (82% height cap)
- [x] MSDF font rendering with theme variations
- [x] Safe area margins (top 96, bottom 64-80)

### V3 Milestone — Balatro-Style Mechanics & Bag Optimization (2026-09-13)

Design doc: `docs/superpowers/specs/2026-09-13-letter-rogue-v3-balatro-bag-optimization-design.md`

- [x] **M1 Bag & Draw Overhaul** — play-and-refill (used tiles → discard, unused stay in hand), discard reshuffle on empty bag, standard bag expanded 8→14 tiles (added D, L, C, M, P, H), vowel safeguard (≥2 vowels/wildcards per hand)
- [x] **M2 Word Form Engine** — `WordFormService.detect()` pattern priority Mirror > Double-Tap > Consonant Core > length; per-form base damage + multiplier; grimoire levels tracked in `GameState.word_form_levels`
- [x] **M3 4-Phase Scoring Pipeline** — `calculate_word()` = Tile Hops → Word Form Ignition → Artisan Cascade → Runic Blast; `length_mult × form_mult` applied in Phase 2; flat bonus in Phase 4; CombatScreen banner animates all 4 phases
- [x] **M4 Artisan Keycap Rail** — 5-slot rail, left-to-right cascade, 12 artisan definitions across 4 archetypes, trigger evaluation (word_length/no_redraws_used/rare_consonant/unused_redraws/more_vowels/word_form/leftover_turns)
- [x] **M5 Switch Packs Rewrite** — 5 thematic packs with conditional passives (Clicky/Linear/Tactile/Heavy Tactile/Silent), `PackService.evaluate_conditionals()`, switch atlas mappings for new pack ids
- [x] **M5a KeyCapElement Rigid Plunge & Dual Perspective** — removed squash/stretch sprite, rigid 2px tweened plunge, dual-perspective embedded/standalone modes
- [x] **M6 Consumables, Depths & Shop Expansion** — Modder's Toolkit (4 tarot), Cursed Hardware (3 spectral), Lexicon Grimoires (4), Workshop Blueprints (3), Grab Bags, Firmware Tags, 3-stage Depth progression, Blueprint shop section
- [x] **Banner display fix** — scoring banner shows full pipeline result: BASE = Σ letter scores + form base, MULT = length_mult × form_mult, TOTAL = pipeline damage (fixes HUME=25 display mismatch)
- [x] **Web export + deploy** — `./tools/deploy-web.ps1` (fixed `$ProjectRoot` double-Split-Path bug + artifact-check guard), deployed to `T:\letter-rogue`

## Current Active Tasks

### Layout & Responsiveness
- [x] **Adaptive hand tile layout** — single row ≤5, dual rows 6–10+, fixed keycap size 48×54px and font 20
- [x] **Fix hand tile centering over stone altar** — HandTileContainer must be horizontally centered (SIZE_SHRINK_CENTER), rows must center, not left-align
- [x] **Unify keycap press physics** — mouse-down press must use same cap_pressed sprite + 5px offset as latched state
- [x] **Fix keycap release jitter** — don't pop up on release, let CombatScreen decide latched state seamlessly

### V3.5 Milestone — Scoring Trace & Animation Overhaul (2026-09-14)

Design doc: `docs/superpowers/specs/2026-09-14-scoring-trace-animation-overhaul-design.md`

- [x] **T1 ScoringTrace pipeline** — `CombatService.calculate_word()` emits trace events for all 4 phases (tile_hop, tile_retrigger, form_ignite, artisan_trigger, clash_resolve); `_trace_event()` static helper with 9-field schema
- [x] **T2 AudioManager autoload** — minimal SFX player with `.ogg`/`.wav` caching, no-op on missing files; wired into CombatScreen animation steps
- [x] **T3 ScreenShake utility** — `scripts/components/ScreenShake.gd` static `shake(node, magnitude, duration)` tween-based jitter
- [x] **T4 Artisan rail visual display** — `ArtisanSlot.gd`/`.tscn` (40×40px icon-only slot, borderless, hidden when empty, glow/shake animations), `ArtisanRailDisplay.gd` (5-slot HBoxContainer, drop-to-swap maps to visible-slot index), wired into CombatScreen `TopZone_Red/ArtisanRow`
- [x] **T5 CombatScreen animation overhaul** — trace-driven animation with per-step methods (`_animate_tile_hop`, `_animate_tile_retrigger`, `_animate_form_ignite`, `_animate_artisan_trigger`, `_animate_clash`), `_monster_hitstop()` with HP drain, simplified projectile, audio/rail wiring, skip-on-click
- [x] **Test coverage** — `tests/test_scoring_trace.gd` verifies trace schema, all 4 phases, final annotation
- [x] **Scoring banner positioning** — offset_top=540 to clear word strip; verified at 540×960 viewport
- [x] **Web export + deploy** — `./tools/deploy-web.ps1` after final commit

### Polish & Juice
- [x] **KeyCap 3-layer sandwich (SwitchBase + CapLayer + CapTexture/OverlayTexture)** — Mount Cherry MX switch housing beneath every keycap, driven by `GameState.active_pack_id`. CapLayer wraps textures as movable unit, plunges 6px onto fixed SwitchBase.
- [x] **Shift hand tiles down onto stone slab** — HandTileContainer Y anchor moved to 745–830px, tiles rest directly on stone altar surface. MidZone_Blue min height 210.
- [x] **Fix keycap elevation over switch** — SwitchBase fixed at (5,24) on slab surface; CapLayer (48×44) plunges 5px on press, SwitchBase (38×28) stays planted.
- [x] **Calibrate hand keyboard to stone altar safe zone** — HandTileContainer anchored absolutely at Position (106,704), Size (324,110) (measured white-mask safe box, 540×960 viewport); realistic keycap pitch (8px H separation, 6px V separation); fixed keycap size 48×56; 5px keycap plunge travel.
- [x] **Shift hand keyboard up 10px & reconstruct keycap-to-switch stacking (image-2/image-3 match)** — HandTileContainer position.y 714→704, size (324,110); KeyCapElement root 48×56, SwitchBase (38×28) at (5,24) extending below the cap skirt (stretch_mode KEEP_ASPECT_CENTERED), CapLayer (48×44) floats at UNPRESSED_CAP_Y 0.0 and plunges to PRESSED_CAP_Y 5.0 on press/latch, tint (0.85,0.88,0.95).
- [x] **Plate-mounted socket masking for Cherry MX switch (image.jpg black-mask match)** — SwitchSocketContainer (`clip_contents = true`, 38×22 at (5,14)) clips the bottom 6px (~19%) of the SwitchBase (38×28, STRETCH_KEEP native top-left) so the switch appears socketed/embedded into the stone altar plate; StoneSocketSlot ColorRect (40×6 at (4,30), dark `Color(0.1,0.12,0.16,0.9)`) adds the recessed slot shadow/bevel line at the base.
- [x] **Restore visible switch base underneath keycaps (image-2/image-3 match)** — previous socket container (Y=14..36) was fully covered by the opaque 44px cap; flattened hierarchy: root 48×54 mouse_filter PASS, CapLayer (0,0) 48×40, SwitchBase direct child standalone (5,22) 38×28 full atlas extending ~10px below cap skirt (5px projection when cap plunges to PRESSED_CAP_Y 5.0); CombatScreen `_refresh_hand()` tile_size (48,54) so runtime tiles match the root.
- [x] **Context-aware keycap switch embedding (Combat embedded vs Shop standalone)** — `@export embedded_mode: bool = false`; `set_embedded_mode(enabled)` re-applies skin; CombatScreen `_instantiate_tile()` sets `embedded_mode = true`. Embedded: `SocketShadow` ColorRect (38×3 at (5,46), `Color(0.08,0.10,0.14,0.95)`) visible, SwitchBase (5,26) 38×22 with **cropped duplicate** atlas (`region.size.y *= 0.79`, proportional ~21% because the switch slice is 262×258 source px — literal `-= 6.0` would crop only ~0.7 display px). Standalone (ShopScreen/RunSetupScreen): SocketShadow hidden, full uncropped switch (5,22) 38×28. Crop applied on `duplicate()` so the shared cached atlas is never mutated.
- [x] **Scene transition system** — `SceneTransition.gd` static Node, 5 shader styles (bayer dither, pixelate, diamond grid, scanline shutter, radial wipe), two-phase play_out/play_in, no-flash guarantee, stutter protection via 1-frame await
- [x] **ParticleBurst system** — `ParticleBurst.gd` static class, CPUParticles2D one-shot bursts, cached 6×6 pixel texture, used for score bursts, button presses, projectile impact, victory confetti
- [x] **PixelHPBar** — custom `_draw()` segmented retro HP bar with color transitions (green→yellow→red) and top highlight line
- [x] **MainMenuScreen overhaul** — added Achievements/Collection/Settings buttons, hover scale+tint effects, particle burst on press, new bg_main_menu_2.jpg background
- [x] **SFX Audio Manager** — AudioManager autoload (`res://scripts/autoload/AudioManager.gd`) with cached stream playback, ogg/wav fallback, no-op on missing
- [x] **Particle effects** — tile score bursts, damage impact, victory celebration (existing ParticleBurst system already covers these)
- [x] **Redraw animation polish** — smooth in/out tweens for swapped tiles
- [x] **Scoring banner positioning** — offset_top=540 to clear word strip; verified at 540×960 viewport
- [x] **Web export + deploy** — `./tools/deploy-web.ps1` after final commit

### V3.6 Milestone — HUD Reflow & Artisan Rail Icon-Only (2026-09-14)

- [x] **Persistent inline scoring row** — replaced floating `ScoringBannerOverlay` with `%PersistentScoringRow` inside `TopZone_Red` (PersistBasePanel + PersistMultPanel + `×` separator); `_score_start()` scale-punch (0.95→1.0 TRANS_BACK) replaces banner fade; `%TotalDamageShelf` + `%WordMetaLabel` moved under the row
- [x] **Top status bar reflow** — added `DepthPanel` ("DEPTH 1-1"), DepthInfoButton, spacer pair around GrimoireRow; TurnRoundLabel + HP bar moved into MonsterDisplayArea; MonsterSprite shrunk 192→128
- [x] **Artisan rail relocated to TopZone_Red** — `ArtisanRow` (HBox, min 40px) with `%ArtisanRail` (size_flags_horizontal=3) + `SellDropZone` + `MoneyLabel`; removed old absolute-positioned rail at offset_top=575
- [x] **WordShelf panel** — `%WordShelf` PanelContainer (WordShelfStyle brown StyleBoxFlat) wraps `%WordRackContainer` in MidZone_Blue
- [x] **Action row resize** — Hint/Redraw/Play/Deck buttons all 100×60 (was 120/148/148), DeckButton moved into ActionZone_Orange
- [x] **WordRuneSlot brown/amber theme** — rune slot restyled from cyan/obsidian to amber/walnut (`Color(0.26,0.16,0.09)` bg, amber border/text)
- [x] **Artisan slot icon-only 40×40** — removed border, NameLabel, and EmptyPlaceholder; empty slots `visible=false`; only purchased artisans show; `_slot_index_at_position()` maps drop to visible-slot index; `verify_banner_layout.gd` updated to `%PersistentScoringRow`
- [x] **Data cleanup** — removed stale `sprite` ref from vowel_witch boss; Golem sprite asset updated
- [x] **examples/ reference art added** — concept/reference jpgs (bg_*, idea_*, ss_*) packed into export
- [x] **Web export + deploy** — `./tools/deploy-web.ps1` (21 files → T:\letter-rogue)

### V3.7 Milestone — Dungeon Depths Expansion (2026-09-15)

- [x] **8 Depth Stages** — Extended from 3 to 8 depths: Vanguard → Sentry → Boss Gate → Catacombs → Fungal Depths → Crystal Caverns → Void Threshold → Abyssal Crown
- [x] **Milestone Modifiers** — 4 unique depth modifiers: Curse (depth 3), Spore Cloud (depth 4), Reflection (depth 5), Void Corruption (depth 6), Abyssal Power (depth 7+)
- [x] **New Monster Pools** — 15 new monsters across 5 new depth pools with unique modifiers (cursed, spore_cloud, reflective, void_touch, abyssal)
- [x] **Unique Milestone Loot** — 5 new drop tables (catacombs_loot, fungal_depths_loot, crystal_caverns_loot, void_threshold_loot, abyssal_crown_loot) with exclusive rewards
- [x] **Endless Mode** — Depth 7+ loops Abyssal Crown with +25% HP scaling per cycle
- [x] **UI Updates** — DepthInfoPopup shows depth name, modifier, and banned letter; CombatScreen depth panel shows depth name
- [x] **Web export + deploy** — `./tools/deploy-web.ps1` (21 files → T:\letter-rogue)

### CombatScreen UI Refresh & New Systems (2026-09-16)

Design doc: `docs/superpowers/specs/2026-09-14-combatscreen-ui-refresh-design.md`

- [x] **HintService Tier 1 + HINT action** — `HintService` autoload (brute-force combination/permutation word finder); `%HintButton` (100×60, "HINT (N)") consumes from `round_hint_budget()` = 3 + `upgrade_hints`, disabled at 0
- [x] **DECK button + BagModal bag/discard tabs** — `%DeckButton` opens BagModal with two views: In Bag (`GameState.bag`) + Discarded (`GameState.discard_pile`)
- [x] **GrimoireRow + active_grimoires** — top status bar row renders 40×40 `GrimoireIcon` per `GameState.active_grimoires`; drag-to-reorder reindexes the array; grimoires permanent (unsellable)
- [x] **SellDropZone** — artisan drag refunds `roundi(price_paid × 0.5)` + floating `+$N`; grimoire drops rejected with toast
- [x] **DepthInfoPopup** — depth name/round, milestone modifier + description, depth-6 banned letter, stage monster pool (`DepthService.get_stage_pool`)
- [x] **bg_combat_3.jpg** — new combat background (CombatScreen `Background` TextureRect)
- [x] **Fixed 100×60 action row** — HINT / REDRAW / PLAY / DECK buttons uniform size; DeckButton moved into ActionZone_Orange
- [x] **Fix GrimoireRow script attach** — `%GrimoireRow` in CombatScreen.tscn was a bare HBoxContainer (missing `scripts/components/GrimoireRow.gd`); attached ext_resource + `script =`, verified scene loads with 56 nodes
- [ ] **Fixed 2×5 unlockable keyboard — NOT built (design divergence)** — design proposed a fixed 2×5 grid with padlock slots; shipped code uses a dynamic adaptive 2-row layout (`_refresh_hand`, ≤5 tiles/row). `GameState.unlocked_key_slots`/`hint_quality`/`upgrade_hints` fields are dormant — no locking/purchase path reads them. Build when slot-lock progression is specced.

### Polish & Juice (remaining)
- [ ] **Shop upgrade pricing display** — ensure upgrade cost button updates dynamically after purchase
- [ ] **HP bar styling** — add gradient/color transitions for damage

### Testing & Quality
- [x] Test suite: run_tests.gd runner + 16 suites, all wired and passing headless
- [x] Core suites: lexicon_test, word_test, monster_modifier_test, scenario_test
- [x] V3 suites: test_bag_expansion, test_play_refill, test_word_form_detection, test_scoring_pipeline, test_artisan_rail, test_switch_packs, test_consumables_depths
- [x] V3.5+ suites: test_scoring_trace, verify_banner_layout, verify_hp_bar, test_hint_service, verify_main_menu
- [x] All 16 test suites passing
- [ ] **Edge cases** — empty bag, empty hand, zero turns left boundary, wildcard with no letters in picker
- [ ] **Bag overflow** — bag larger than hand draw size (already handled via `mini()`)

## Upcoming Backlog

### Content Expansion
- [ ] **More boss variations** — additional boss modifiers beyond the current 7
- [ ] **More shop items** — additional upgrades, consumables, special tiles
- [ ] **Additional Switch Packs** — more pack variety
- [ ] **Altar Rune socket** — communal tile persisting across turns (deferred from M1)
- [ ] **Pack unlock progression** — stake/difficulty system (Balatro-style)
- [x] **Endless mode** — continue past boss rounds with escalating difficulty (implemented at Depth 7+ Abyssal Crown)
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
