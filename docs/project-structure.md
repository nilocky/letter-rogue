# Letter Rogue — Project Structure

Annotated layout of the repository as of 2026-09-11.

```
letter-rogue/
│
├── project.godot              Godot project config: 540x960 viewport, 441x784 window override,
│                               canvas_items stretch, portrait locked, 8 autoloads, custom theme
│
├── AGENTS.md                  Agent instructions (Godot MCP, Outline wiki, code conventions,
│                               headless verification harness procedure)
├── README.md
│
├── data/                      # Gameplay data as JSON, ships in exported pck
│   ├── words.json             Word dictionary (~370k words, 3+ letters)
│   ├── key_caps.json          Shop pool: letter tiles with abilities/finishes/stickers/conditions
│   ├── monsters.json          Normal + boss monster definitions with boss_modifier
│   ├── packs.json             5 Cherry MX packs: draw/score/start-money modifiers
│   └── starter_bags.json      4 starter bag loadouts (Standard, Vowel Explorer, Consonant Heavy, Minimalist)
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
│   │   ├── ShopService.gd     Tile buy/sell/reroll, 3 run upgrades (Bigger Bag, Extra Turn, Extra Redraw)
│   │   ├── WordService.gd     Dictionary load/lookup, word length multiplier
│   │   └── CombatService.gd   Round setup, word validation & scoring, damage application, win/lose
│   │
│   ├── services/
│   │   └── ResolutionManager.gd  Cross-platform window sizing: 82% desktop height cap, 9:16 aspect,
│   │                               mobile fullscreen
│   │
│   ├── screens/               # One script per screen, wired to .tscn via %UniqueName
│   │   ├── MainMenuScreen.gd  Title + Start Run (emits run_setup_requested)
│   │   ├── RunSetupScreen.gd  Pack cycler (5 MX switches) + bag selector (4 bags) with preview
│   │   ├── CombatScreen.gd    Word builder: hand tiles, word strip, scoring banner, wildcard picker,
│   │   │                       BagModal, VictoryModal. Balatro-style sequential scoring animation.
│   │   ├── ShopScreen.gd      Tile buy/sell/reroll grids, run upgrade column, confirmation dialogs
│   │   └── GameOverScreen.gd  Shows reached round + money, restart button
│   │
│   └── components/
│       ├── KeyCapElement.gd   Reusable tile widget: letter, rarity bg, ability label, modifier badges,
│       │                        position index, drag-drop reorder, selected/used/redraw-marked states
│       ├── BagModal.gd        Bag inspector overlay: per-letter frequency counts, vowel/consonant ratio
│       └── VictoryModal.gd    Itemized reward receipt with counting-up total animation, Continue button
│
├── scenes/
│   ├── GameRoot.tscn          Empty by design — runtime-only Node, screens instantiated dynamically
│   ├── MainMenuScreen.tscn    Background + SafeArea + Title + StartButton
│   ├── RunSetupScreen.tscn    Pack cards, bag buttons grid, bag preview, Start/Back
│   ├── CombatScreen.tscn      TopBar (monster/HP/turns/bag/money) + MidZone (word strip) +
│   │                           BottomZone (hand + Redraw/Play buttons) + WildcardPopup overlay
│   ├── ShopScreen.tscn        InventoryGrid + BagGrid + UpgradeBox + money/reroll/fight buttons
│   ├── GameOverScreen.tscn    BodyLabel + RestartButton
│   │
│   └── components/
│       ├── KeyCapElement.tscn   Tile visual: Label, RarityBg, FinishLabel, StickerLabel,
│       │                         ConditionLabel, IndexLabel, MarkFrame
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
│       └── backgrounds/       bg_main_menu.jpg, bg_main_menu_low.jpg
│
├── tools/
│   └── build_words.py         One-off Python generator: wordlist → data/words.json
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

- **Autoload order matters:** `EventBus → GameState → PackService → KeyCapService → ShopService → WordService → CombatService → ResolutionManager`. Services reference each other via autoload names at call time, not in `_ready()` cross-dependencies.

- **Scoring flow:** `CombatService.calculate_word()` applies per-tile abilities, finishes, stickers, conditions, boss modifiers, and pack score_modifier. Returns `letter_scores` array driving the scoring animation. `WordService` supplies only `is_word()` and `length_multiplier()`. Flat `bonus_damage` is added after multiplier.

- **Bag/hand lifecycle:** `GameState.bag` is the permanent tile collection. `KeyCapService.draw_hand()` samples tiles from bag into `GameState.hand` each turn. Tiles are not consumed — they return to bag at turn end. No discard pile exists.

- **Victory money timing:** On monster defeat, money is NOT added immediately. VictoryModal shows the computed total; money is added to `GameState.money` only on Continue button press. Non-victory turn ability money is still added immediately.

- **Shop in two parts:** `ShopScreen` shows tile inventory (buy/sell/reroll) AND the run-upgrade column. Both draw from `ShopService`, which owns `UPGRADES` metadata + pricing with ×2 escalation per level.
