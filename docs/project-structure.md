# Letter Rogue — Project Structure

Annotated layout of the repository as of 2026-09-16.

```
letter-rogue/
│
├── project.godot              Godot project config: 540x960 viewport, 441x784 window override,
│                               canvas_items stretch, portrait locked, 19 autoloads, custom theme
│
├── AGENTS.md                  Agent instructions (Godot MCP, Outline wiki, code conventions)
├── README.md
├── shell.html                 Custom Web export HTML shell (export_presets custom_html_shell)
├── @icons picker.html         Dev tool: icon asset browser (not shipped, excluded from export)
│
├── data/                      # Gameplay data as JSON, ships in exported pck
│   ├── words.json             Word dictionary (~370k words, 3+ letters, POS+def enriched)
│   ├── key_caps.json          Shop pool: letter tiles with abilities/finishes/stickers/conditions
│   ├── monsters.json          Normal + boss monster definitions with unified `modifier` + `drop_table_id`
│   ├── packs.json             5 Switch Packs with conditional passives (Clicky/Linear/Tactile/Heavy Tactile/Silent)
│   ├── starter_bags.json      4 starter bag loadouts (Standard 14 tiles, Vowel Explorer, Consonant Heavy, Minimalist)
│   ├── word_forms.json        Word Form definitions (Trio/Quartet/Quintet/Hexagram/Double-Tap/Mirror/Consonant Core)
│   ├── artisans.json          Artisan Keycap definitions (4 archetypes, trigger+effect)
│   ├── consumables.json       Toolkit (tarot) + Cursed Hardware (spectral) + Grimoire definitions
│   ├── blueprints.json        Workshop Blueprint definitions
│   ├── firmware_tags.json     Firmware Tag definitions
│   ├── depths.json            Depth encounter tables (8 stages: Vanguard/Sentry/Boss
│   │                           Gate/Catacombs/Fungal/Crystal/Void/Abyssal pools)
│   ├── secret_words.json      Rare words flagged `is_secret: true` (gameplay effect pending)
│   └── drop_tables.json       Weighted loot tables keyed by monster `drop_table_id`
│
├── examples/                  # Reference/concept art (bg_*, idea_*, ss_* jpgs), packed into export
│
├── scripts/
│   ├── game_root.gd           Top-level state machine: MENU → RUN_SETUP → COMBAT → SHOP → GAME_OVER.
│   │                           Instantiates/destroys screen scenes via SceneTransition.
│   │                           F1 debug shortcut.
│   │
│   ├── autoload/              # Singletons (registered in project.godot, in this order)
│   │   ├── EventBus.gd        Signal definitions: navigation, combat, shop, upgrades, bag/draw,
│   │   │                       scoring pipeline, artisan rail, depth/shop
│   │   ├── GameState.gd       Runtime state: money, round, bag, discard_pile, hand, monster,
│   │   │                       turn/redraw/hint budgets, upgrades, word_form_levels, artisan_rail,
│   │   │                       active_blueprints, active_grimoires, unlocked_key_slots, skip_tags,
│   │   │                       depth_stage
│   │   ├── PackService.gd     Active Switch Pack modifier lookups + evaluate_conditionals() passives
│   │   ├── KeyCapService.gd   Play-and-refill draw from bag, vowel safeguard, discard reshuffle,
│   │   │                       resolve_ability, starter bag loaders
│   │   ├── KeyCapSkinService.gd  Atlas-based skin system: loads keycap_kit_6.png slices via AtlasTexture,
│   │   │                       supports cap_unpressed/overlays states + switch atlas per pack id
│   │   ├── ShopService.gd     Tile buy/sell/reroll, 3 run upgrades (Bigger Bag, Extra Turn, Extra Redraw),
│   │   │                       Blueprint purchases, Grab Bag generation
│   │   ├── WordService.gd     Dictionary load/lookup, word length multiplier, get_word_meta()
│   │   ├── CombatService.gd   Round setup, word validation, 4-phase scoring pipeline (trace-driven),
│   │   │                       damage application, win/lose, EffectPipeline hooks, unified _current_modifier()
│   │   ├── ArtisanRailManager.gd 5-slot Artisan rail, equip/unequip, left-to-right cascade trigger eval
│   │   ├── WordFormService.gd Word Form detection (Trio/Quartet/Mirror/Double-Tap/Consonant Core),
│   │   │                       per-form base+mult, grimoire level tracking
│   │   ├── DepthService.gd    8-stage encounter generation (Vanguard/Sentry/Boss Gate/Catacombs/
│   │   │                       Fungal Depths/Crystal Caverns/Void Threshold/Abyssal Crown),
│   │   │                       milestone modifiers, stage pools, depth-6 banned letter
│   │   ├── ConsumableService.gd  Apply tarot/spectral/grimoire effects, bag mutations
│   │   ├── ResolutionManager.gd  (registered autoload from scripts/services/) Cross-platform window
│   │   │                       sizing: 82% desktop height cap, 9:16 aspect, mobile fullscreen
│   │   ├── MCPRuntimeProbe.gd (*uid://bsg12huaf1u5i — from addons/godot_mcp/, dev-only, excluded
│   │   │                       from Web export)
│   │   ├── DebugManager.gd    Debug hotkeys (F1 overlay, F12 screenshot), scene routing, state injection
│   │   ├── EffectPipeline.gd  Hook registry: 11 combat lifecycle events (on_draw..on_turn_end,
│   │   │                       on_word_form_evaluated, on_artisan_triggered, on_shop_opened, on_bag_mutated)
│   │   ├── LootService.gd     Rolls loot drops from monster drop_table_id on defeat
│   │   ├── AudioManager.gd    Minimal SFX player: cached stream playback, .ogg/.wav fallback,
│   │   │                       no-op on missing files (no assets/audio/* shipped yet)
│   │   └── HintService.gd     Tier 1 brute-force word finder (find_basic_word, combos→perms);
│   │                           drives the CombatScreen HINT button
│   │
│   ├── services/
│   │   └── ResolutionManager.gd  Registered autoload (home of ResolutionManager). Cross-platform
│   │                               window sizing: 82% desktop height cap, 9:16 aspect, mobile fullscreen
│   │
│   ├── screens/               # One script per screen, wired to .tscn via %UniqueName
│   │   ├── MainMenuScreen.gd  Title + Start Run (emits run_setup_requested)
│   │   ├── RunSetupScreen.gd  Pack cycler (5 Switch Packs, switch icon from skin atlas) + bag selector (4 bags) with preview
│   │   ├── CombatScreen.gd    Word builder: hand tiles (latched deep-travel) → WordRuneSlot magical rune
│   │   │                       display strip, Artisan rail display + SellDropZone, GrimoireRow, persistent
│   │   │                       inline scoring row (BASE/MULTI scale-punch start), projectile to monster,
│   │   │                       smooth HP drop, wildcard picker, HINT + DECK action buttons,
│   │   │                       BagModal (bag/discard tabs), DepthInfoPopup, VictoryModal.
│   │   │                       Tap-to-skip animation, drag-drop reorder via WordRackDropZone.
│   │   │                       Word metadata subtitle (WORD · POS · "def" · Vn/Cn). DepthPanel header text.
│   │   │                       HintService wired via _hint_pressed().
│   │   ├── ShopScreen.gd      Tile buy/sell/reroll grids, run upgrade column, Workshop Blueprint section,
│   │   │                       confirmation dialogs
│   │   ├── GameOverScreen.gd  Shows reached round + money, restart button
│   │   ├── DebugOverlay.gd    Debug overlay panel (route buttons, state readout, time-scale, screenshot)
│   │   └── UISandbox.gd       UI gallery: safe-area overlay, touch-target grid, mouse-filter demo boxes
│   │
│   └── components/
│       ├── KeyCapElement.gd   Hand tile widget: letter, power badge, skin atlas textures (cap_unpressed),
│       │                        overlay (foil/holographic/glass/gold), latched state with 2px rigid plunge
│       │                        animation (no squash/stretch), redraw-marked state. Not used in word strip.
│       ├── WordRuneSlot.gd    Word-strip rune tile: letter label (cyan), power badge (amber), obsidian-style
│       │                        StyleBoxFlat panel with cyan border. Tap-to-dismiss removes letter from word.
│       ├── WordRackDropZone.gd Extends HBoxContainer. Drag-drop reorder zone with magnetic InsertionSpacer
│       │                        (spring-physics width, Hermite smoothstep proximity, cyan glow). On drop:
│       │                        queue_free()s spacer, emits item_dropped(from_slot, to_pure_index). Rebuilds
│       │                        _slots from live tree — zero manual array surgery.
│       ├── ParticleBurst.gd   Static class: one-shot CPUParticles2D burst with cached 6×6 pixel texture.
│       │                        Used for score bursts, button presses, projectile impact, victory confetti.
│       ├── PixelHPBar.gd      TextureProgressBar subclass: custom _draw() segmented retro HP bar with
│       │                        color transitions (green→yellow→red) and top highlight line.
│       ├── ScreenShake.gd     Static class: tween-based screen shake utility.
│       │                        `shake(node, magnitude, duration)` — jitter + restore
│       ├── ArtisanSlot.gd     Artisan rail slot widget (40×40): icon-only, borderless, hidden when empty,
│       │                        glow/shake trigger animations
│       ├── ArtisanRailDisplay.gd 5-slot HBoxContainer: refresh() from ArtisanRailManager,
│       │                        trigger_slot(index) for glow+shake, drop-to-swap maps position to visible-slot index
│       ├── SceneTransition.gd Static Node: two-phase screen transition via CanvasLayer 128 + ShaderMaterial.
│       │                        5 shader styles (bayer dither, pixelate, diamond grid, scanline, radial wipe).
│       │                        No-flash guarantee, stutter protection via 1-frame await.
│       ├── BagModal.gd        Bag inspector overlay: per-letter frequency counts, vowel/consonant ratio;
│       │                        two tabs — In Bag + Discarded (GameState.discard_pile)
│       ├── VictoryModal.gd    Itemized reward receipt with counting-up total animation, loot drops display,
│       │                        particle burst confetti, Continue button
│       ├── GrimoireIcon.gd    Grimoire row tile (40×40): first-letter label + name/desc tooltip, drag payload
│       │                        {type:"grimoire", from_index, data}
│       ├── GrimoireRow.gd     HBox: refresh() rebuilds icons from GameState.active_grimoires; accepts grimoire
│       │                        drops and reorders via _child_index_at_pos()
│       ├── SellDropZone.gd    Artisan drag target: 50% refund + floating +$N; grimoires rejected ("Cannot sell
│       │                        permanent upgrades")
│       ├── DepthInfoPopup.gd  Depth modal: depth/round, milestone modifier + description, depth-6 banned letter,
│       │                        stage monster pool rows (name, HP, modifier)
│       └── OverlayHint.gd     Reusable labeled translucent rect for UI sandbox annotations
│
├── scenes/
│   ├── GameRoot.tscn          Empty by design — runtime-only Node, screens instantiated dynamically
│   ├── MainMenuScreen.tscn    Background (bg_main_menu_2.jpg) + SettingsButton + StartButton +
│   │                           AchievementsButton + CollectionButton. Hover scale+tint effects.
│   ├── RunSetupScreen.tscn    Pack cards, bag buttons grid, bag preview, Start/Back
│   ├── CombatScreen.tscn      TopStatusBar (DepthPanel + DepthInfo + GrimoireRow + Settings) + ArtisanRow
│   │                           (ArtisanRail + SellDropZone + MoneyLabel) + MonsterDisplayArea (HP bar + sprite +
│   │                           turns) + PersistentScoringRow (BASE/MULTI inline scoring) + WordShelf
│   │                           (wraps WordRackContainer) + ActionZone (Hint/Redraw/Play/Deck) +
│   │                           HandTileContainer (absolute child of root) + WildcardPopup overlay
│   ├── ShopScreen.tscn        InventoryGrid + BagGrid + UpgradeBox + money/reroll/fight buttons
│   ├── GameOverScreen.tscn    BodyLabel + RestartButton
│   ├── UISandbox.tscn         UI gallery: safe-area overlays, touch-target grid, mouse-filter demo boxes
│   │
│   ├── debug/
│   │   └── DebugOverlay.tscn  Debug panel: route buttons, state readout, time-scale, screenshot, inject
│   │
│   └── components/
│       ├── KeyCapElement.tscn   Tile visual: SocketShadow (ColorRect 38×3 at (5,46), dark socket slit, visible
│       │                         only in embedded mode), SwitchBase (TextureRect direct child of root, standalone
│       │                         (5,22) 38×28 full atlas vs embedded (5,26) 38×22 cropped duplicate atlas ~21%),
│       │                         CapLayer (Control 48×40 at (0,0), wraps CapTexture, OverlayTexture,
│       │                         LegendContainer, MarkFrame, PowerLabel as movable unit, rigid 2px plunge on press),
│       │                         LetterLabel, PowerLabel. embedded_mode flag: combat-embedded vs shop-standalone.
│       ├── WordRuneSlot.tscn    Rune slot: LetterLabel, PowerLabel (BadgeLabel variant). Draggable PanelContainer.
│       ├── ArtisanSlot.tscn     Artisan rail slot: IconRect (28×28), borderless, root hidden when empty
│       ├── ArtisanRailDisplay.tscn 5-slot HBoxContainer (dead scene — live node is CombatScreen ArtisanRow/ArtisanRail)
│       ├── BagModal.tscn        Overlay + Panel + scrollable LetterGrid (bag/discard tabs) + VowelRatio + CloseButton
│       ├── DepthInfoPopup.tscn  Depth info modal (runtime-instantiated by CombatScreen)
│       └── VictoryModal.tscn    Overlay + Panel + Title + Receipt + TotalLabel + ContinueButton
│
├── ui/
│   └── theme/
│       └── default_theme.tres  MSDF font theme with type variations:
│                                HeaderLabel, MetricLabel, KeyCapFaceLabel, BodyLabel,
│                                BadgeLabel, MicroLabel
│
├── assets/
│   ├── fonts/                 Kenney Blocks/Pixel/Mini/High/Future + monogram + m5x7
│   ├── shaders/
│   │   └── transitions/       5 transition shader styles (bayer_dither, pixelate_darken,
│   │                            diamond_grid, scanline_shutter, radial_wipe)
│   └── textures/
│       └── backgrounds/       bg_main_menu.jpg, bg_main_menu_low.jpg, bg_main_menu_2.jpg,
│                              bg_combat_2.jpg, bg_combat_2_keyboard_safe.jpg (safe-area mask reference),
│                              bg_combat_3.jpg (current combat background)
│
├── tests/                     # Test suite
│   ├── run_tests.gd           Test runner (shells out to godot per suite; 16 suites wired, all passing)
│   ├── lexicon_test.gd        WordService.get_word_meta assertions
│   ├── word_test.gd           is_word, length_multiplier, word_count
│   ├── monster_modifier_test.gd  silence/vowel_lock/consonant_lock/no_repeats modifier rules
│   ├── scenario_test.gd       Full combat flow with "CAT" word
│   ├── test_bag_expansion.gd  V3: standard starter bag = 14 tiles w/ correct letters
│   ├── test_play_refill.gd    V3: play-and-refill, discard, vowel safeguard
│   ├── test_word_form_detection.gd  V3: form detection + pattern priority
│   ├── test_scoring_pipeline.gd     V3: 4-phase pipeline (CAT=7, LEVEL=80)
│   ├── test_artisan_rail.gd   V3: artisan cascade (Caps Lock flat, Rotary Knob xmult)
│   ├── test_switch_packs.gd   V3: conditional passive evaluation
│   ├── test_consumables_depths.gd   V3: consumables apply + depth encounter gen
│   ├── test_scoring_trace.gd   V3.5: trace schema verification (4 phases, 9-field events, annotation match)
│   ├── verify_banner_layout.gd  V3.6: %PersistentScoringRow layout across viewports
│   ├── verify_hp_bar.gd       PixelHPBar segment/color assertions
│   ├── verify_main_menu.gd    MainMenuScreen scene loads + node refs resolve
│   └── test_hint_service.gd   HintService Tier 1: find_basic_word finds a valid word ("CAT")
│
├── tools/
│   ├── build_words.py         One-off Python generator: wordlist → data/words.json (POS+def enriched)
│   ├── deploy-web.ps1         Export Web release + copy build/web/* to T:\letter-rogue
│   └── debug/
│       └── sync_outline.py    Utility to push docs/*.md to the Outline wiki via API
│
├── deploy/
│   └── web/                   Docker deployment for Web export
│       ├── Dockerfile         nginx:alpine serving build/web
│       └── nginx.conf         gzip + immutable cache for wasm/pck/js
│
├── build/
│   └── web/                   (gitignored) Godot Web export output
│
├── docs/
│   ├── spec.md                [THIS] Comprehensive game & technical specification
│   ├── plan.md                [THIS] Implementation status & roadmap
│   ├── project-structure.md   [THIS] Directory & architecture tree
│   ├── web-delivery.md        Export / Docker / WebView embed guide
│   └── archive/               Superseded historical docs (dated spec, plan, structure, superpowers/)
│
├── addons/
│   ├── godot_mcp/             Godot MCP plugin (enabled; dev-only, excluded from Web export)
│   ├── at-icons/              Icon browser addon (installed, unused by game code; dev-only)
│   └── dialogue_manager/      Dialogue editor addon (installed, unused by game code; dev-only)
│
├── export_presets.cfg         Web export preset (canvas_items, emulate touch, keep_height,
│                               exclude addons/*,docs/*,tests/*,tools/*,*.wav,*.zip; PWA enabled)
└── .gitignore
```

## Data Flow Notes

- **Autoload order matters (19):** `EventBus → GameState → PackService → KeyCapService → KeyCapSkinService → ShopService → WordService → CombatService → ArtisanRailManager → WordFormService → DepthService → ConsumableService → ResolutionManager → MCPRuntimeProbe → DebugManager → EffectPipeline → LootService → AudioManager → HintService`. Services reference each other via autoload names at call time, not in `_ready()` cross-dependencies.

- **Scoring flow — 4-phase pipeline:** `CombatService.calculate_word()` runs Phase 1 Tile Hops (per-tile letter score + abilities/finishes/stickers/conditions + pack passives → `letter_scores`), Phase 2 Word Form Ignition (`(Σ + form_base) × length_mult × form_mult`), Phase 3 Artisan Cascade (`(total_after_form + artisan_flat) × artisan_xmult`, from `ArtisanRailManager.cascade()`), Phase 4 Runic Blast (`roundi(total) + flat_bonus`). Returns `letter_scores`, `form_data`, `flat_bonus` driving the banner animation. `WordService` supplies only `is_word()` and `length_multiplier()`.

- **Bag/hand lifecycle — play-and-refill:** `GameState.bag` is the permanent tile collection, `GameState.discard_pile` holds consumed tiles. `KeyCapService.draw_hand()` refills `GameState.hand` to `draw_size()` keeping unused tiles; played tiles move to discard on commit; `_vowel_safeguard()` keeps 2+ vowels/wildcards in hand; when bag empties, discard reshuffles back into bag.

- **Victory money timing:** On monster defeat, money is NOT added immediately. VictoryModal shows the computed total; money is added to `GameState.money` only on Continue button press. Non-victory turn ability money is still added immediately.

- **Shop in two parts:** `ShopScreen` shows tile inventory (buy/sell/reroll) AND the run-upgrade column. Both draw from `ShopService`, which owns `UPGRADES` metadata + pricing with ×2 escalation per level.
