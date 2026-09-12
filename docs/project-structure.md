# Letter Rogue — Project Structure

Annotated layout of the repository as of 2026-09-12.

```
letter-rogue/
│
├── project.godot              Godot project config: 540x960 viewport, 441x784 window override,
│                               canvas_items stretch, portrait locked, 12 autoloads, custom theme
│
├── AGENTS.md                  Agent instructions (Godot MCP, Outline wiki, code conventions,
│                               headless verification harness procedure)
├── README.md
│
├── data/                      # Gameplay data as JSON, ships in exported pck
│   ├── words.json             Word dictionary (~370k words, 3+ letters, POS+def enriched)
│   ├── key_caps.json          Shop pool: letter tiles with abilities/finishes/stickers/conditions
│   ├── monsters.json          Normal + boss monster definitions with unified `modifier` + `drop_table_id`
│   ├── packs.json             5 Cherry MX packs: draw/score/start-money modifiers
│   ├── starter_bags.json      4 starter bag loadouts (Standard, Vowel Explorer, Consonant Heavy, Minimalist)
│   ├── secret_words.json      Rare words flagged `is_secret: true` (gameplay effect pending)
│   └── drop_tables.json       Weighted loot tables keyed by monster `drop_table_id`
│
├── scripts/
│   ├── game_root.gd           Top-level state machine: MENU → RUN_SETUP → COMBAT → SHOP → GAME_OVER.
│   │                           Instantiates/destroys screen scenes. F1 debug shortcut.
│   │
│   ├── autoload/              # Singletons (registered in project.godot)
│   │   ├── EventBus.gd        Signal definitions: navigation, combat, shop, upgrades
│   │   ├── GameState.gd       Runtime state: money, round, bag, hand, monster, budgets, upgrades
│   │   ├── PackService.gd     Active Cherry MX pack modifier lookups
│   │   ├── KeyCapService.gd   Draw hand from bag, targeted redraw swaps, resolve_ability,
│   │   │                       starter bag loaders
│   │   ├── KeyCapSkinService.gd  Atlas-based skin system: loads keycap_kit_6.png slices via AtlasTexture,
│   │   │                       supports cap_unpressed/cap_pressed/overlays states by skin_id (slate, etc.)
│   │   ├── ShopService.gd     Tile buy/sell/reroll, 3 run upgrades (Bigger Bag, Extra Turn, Extra Redraw)
│   │   ├── WordService.gd     Dictionary load/lookup, word length multiplier, get_word_meta()
│   │   ├── CombatService.gd   Round setup, word validation & scoring, damage application, win/lose,
│   │   │                       EffectPipeline hooks, unified _current_modifier()
│   │   ├── DebugManager.gd    Debug hotkeys (F1 overlay, F12 screenshot), scene routing, state injection
│   │   ├── EffectPipeline.gd  Hook registry: 7 combat lifecycle events (on_draw..on_turn_end)
│   │   └── LootService.gd     Rolls loot drops from monster drop_table_id on defeat
│   │
│   ├── services/
│   │   └── ResolutionManager.gd  Cross-platform window sizing: 82% desktop height cap, 9:16 aspect,
│   │                               mobile fullscreen
│   │
│   ├── screens/               # One script per screen, wired to .tscn via %UniqueName
│   │   ├── MainMenuScreen.gd  Title + Start Run (emits run_setup_requested)
│   │   ├── RunSetupScreen.gd  Pack cycler (5 MX switches, switch icon from skin atlas) + bag selector (4 bags) with preview
│   │   ├── CombatScreen.gd    Word builder: hand tiles (latched deep-travel) → WordRuneSlot magical rune
│   │   │                       display strip, scoring banner (Balatro-style sequential letter scores, multiplier
│   │   │                       ramp, projectile to monster, smooth HP drop), wildcard picker, BagModal, VictoryModal.
│   │   │                       Tap-to-skip animation, drag-drop reorder via WordRackDropZone.
│   │   │                       Word metadata subtitle (WORD · POS · "def" · Vn/Cn).
│   │   ├── ShopScreen.gd      Tile buy/sell/reroll grids, run upgrade column, confirmation dialogs
│   │   ├── GameOverScreen.gd  Shows reached round + money, restart button
│   │   ├── DebugOverlay.gd    Debug overlay panel (route buttons, state readout, time-scale, screenshot)
│   │   └── UISandbox.gd       UI gallery: safe-area overlay, touch-target grid, mouse-filter demo boxes
│   │
│   └── components/
│       ├── KeyCapElement.gd   Hand tile widget: letter, power badge, skin atlas textures (cap_unpressed/pressed),
│       │                        overlay (foil/holographic/glass/gold), latched state with 5px deep-travel animation,
│       │                        redraw-marked state. Not used in word strip.
│       ├── WordRuneSlot.gd    Word-strip rune tile: letter label (cyan), power badge (amber), obsidian-style
│       │                        StyleBoxFlat panel with cyan border. Tap-to-dismiss removes letter from word.
│       ├── WordRackDropZone.gd Extends HBoxContainer. Drag-drop reorder zone with magnetic InsertionSpacer
│       │                        (spring-physics width, Hermite smoothstep proximity, cyan glow). On drop:
│       │                        queue_free()s spacer, emits item_dropped(from_slot, to_pure_index). Rebuilds
│       │                        _slots from live tree — zero manual array surgery.
│       ├── BagModal.gd        Bag inspector overlay: per-letter frequency counts, vowel/consonant ratio
│       ├── VictoryModal.gd    Itemized reward receipt with counting-up total animation, loot drops display, Continue button
│       └── OverlayHint.gd     Reusable labeled translucent rect for UI sandbox annotations
│
├── scenes/
│   ├── GameRoot.tscn          Empty by design — runtime-only Node, screens instantiated dynamically
│   ├── MainMenuScreen.tscn    Background + SafeArea + Title + StartButton
│   ├── RunSetupScreen.tscn    Pack cards, bag buttons grid, bag preview, Start/Back
│   ├── CombatScreen.tscn      TopBar (monster/HP/turns/bag/money) + MidZone (word strip) +
│   │                           BottomZone (Redraw/Play buttons) + HandTileContainer (absolute child of
│   │                           root) + WildcardPopup overlay + WordMetaLabel in scoring banner
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
│       │                         LegendContainer, MarkFrame, PowerLabel as movable unit, plunges 5px on press),
│       │                         LetterLabel, PowerLabel. embedded_mode flag: combat-embedded vs shop-standalone.
│       ├── WordRuneSlot.tscn    Rune slot: LetterLabel, PowerLabel (BadgeLabel variant). Draggable PanelContainer.
│       ├── BagModal.tscn        Overlay + Panel + scrollable LetterGrid + VowelRatio + CloseButton
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
│   └── textures/
│       └── backgrounds/       bg_main_menu.jpg, bg_main_menu_low.jpg, bg_combat_2.jpg,
│                              bg_combat_2_keyboard_safe.jpg (safe-area mask reference)
│
├── tests/                     # Headless test suite (extends SceneTree)
│   ├── run_tests.gd           Test runner (shells out to godot per suite)
│   ├── lexicon_test.gd        WordService.get_word_meta assertions
│   ├── word_test.gd           is_word, length_multiplier, word_count
│   ├── monster_modifier_test.gd  silence/vowel_lock/consonant_lock/no_repeats modifier rules
│   └── scenario_test.gd       Full combat flow with "CAT" word
│
├── tools/
│   ├── build_words.py         One-off Python generator: wordlist → data/words.json (POS+def enriched)
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
│   └── godot_mcp/             Godot MCP plugin (dev only, excluded from Web export)
│
├── export_presets.cfg         Web export preset (canvas_items, emulate touch, exclude MCP)
└── .gitignore
```

## Data Flow Notes

- **Autoload order matters:** `EventBus → GameState → PackService → KeyCapService → KeyCapSkinService → ShopService → WordService → CombatService → ResolutionManager → DebugManager → EffectPipeline → LootService`. Services reference each other via autoload names at call time, not in `_ready()` cross-dependencies.

- **Scoring flow:** `CombatService.calculate_word()` applies per-tile abilities, finishes, stickers, conditions, boss modifiers, and pack score_modifier. Returns `letter_scores` array driving the scoring animation. `WordService` supplies only `is_word()` and `length_multiplier()`. Flat `bonus_damage` is added after multiplier.

- **Bag/hand lifecycle:** `GameState.bag` is the permanent tile collection. `KeyCapService.draw_hand()` samples tiles from bag into `GameState.hand` each turn. Tiles are not consumed — they return to bag at turn end. No discard pile exists.

- **Victory money timing:** On monster defeat, money is NOT added immediately. VictoryModal shows the computed total; money is added to `GameState.money` only on Continue button press. Non-victory turn ability money is still added immediately.

- **Shop in two parts:** `ShopScreen` shows tile inventory (buy/sell/reroll) AND the run-upgrade column. Both draw from `ShopService`, which owns `UPGRADES` metadata + pricing with ×2 escalation per level.
