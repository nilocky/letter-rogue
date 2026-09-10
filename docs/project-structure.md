# Letter Rogue — Project Structure

Annotated layout of the repo. Tags mark each entry's status for the **V2 "Spell Your Own Words"** rework (V1 = match key caps to monster words → V2 = spell your own dictionary word each turn):

- **[keep]** — reused as-is in V2
- **[rework]** — exists in V1; modified/extended for V2
- **[delete]** — removed in V2 (slot-match mechanic is gone)
- **[new]** — added by the V2 plan

```
letter-rogue/
│
├── project.godot                      [rework] Godot project + autoload registrations
│                                              (+ WordService), Web export preset,
│                                              "Emulate Touch From Mouse"
│
├── AGENTS.md                          [keep]   agent instructions (MCP/godot notes)
├── README.md                          [keep]
├── .gitignore                         [rework] + data/raw/, build/, .godot/
├── .dockerignore                      [new]    excludes raw wordlists / build cache
│
├── .opencode/                         [keep]   opencode config (untracked, not in git)
│   ├── package.json / package-lock.json
│   └── .gitignore
│
├── data/                              # all gameplay data as JSON, ships in pck
│   ├── key_caps.json                  [rework] starter bag + shop pool: letter tiles
│   │                                          with abilities; wildcard symbols (* ~ #)
│   ├── monsters.json                  [rework] normal + boss monsters; drops word_pool
│   │                                          & attack_pattern; adds is_boss/boss_modifier
│   ├── packs.json                     [rework] Cherry MX packs → draw/score/start-money
│   │                                          modifiers
│   ├── words.json                     [new]    bundled English dictionary ({"words": [...]})
│   └── raw/                           [new]    (gitignored) source wordlists for generator
│
├── tools/
│   └── build_words.py                 [new]    one-off generator: wordlist → data/words.json
│
├── scripts/                           # all GDScript
│   ├── game_root.gd                   [rework] screen state machine; round/shop/boss
│   │                                          cadence; run start (pack money, starter bag)
│   │
│   ├── autoload/                      # singletons (registered in project.godot)
│   │   ├── EventBus.gd                [rework] V2 signal set (drops player_hit, caps_played,
│   │   │                                       score_calculated, combat_word_generated)
│   │   ├── GameState.gd               [rework] money/round/bag/hand/monster + turn &
│   │   │                                       redraw budgets + upgrade_* + next_draw_bonus
│   │   ├── KeyCapService.gd           [rework] draw_hand from bag, targeted redraw_tiles,
│   │   │                                       resolve_ability; drops play_caps/discard/heal
│   │   ├── WordService.gd             [new]    dictionary load/lookup, word length multiplier
│   │   ├── CombatService.gd           [rework] turn-budget rounds: start_round, validate_word,
│   │   │                                       calculate_word, commit_word, skip_turn
│   │   ├── ShopService.gd             [rework] tile buy/sell/reroll + persistent run
│   │   │                                       upgrades (bigger bag / extra turn / redraw)
│   │   └── PackService.gd             [keep]   active-pack lookups (draw base, score/tile)
│   │
│   ├── components/
│   │   ├── KeyCapElement.gd           [rework] reusable tile widget (letter + badges +
│   │   │                                       position index; drag-drop for word reorder)
│   │   └── WordSlot.gd                [delete] monster-word slot (V1 only)
│   │
│   └── screens/                       # one script per screen, wired to .tscn
│       ├── MainMenuScreen.gd          [keep]   title + new run + pack select
│       ├── CombatScreen.gd            [rework] word-builder UI: hand, word strip, damage
│       │                                       preview, wildcard picker, redraw/skip/confirm
│       ├── ShopScreen.gd              [rework] tile grids + sell/reroll + upgrade column
│       └── GameOverScreen.gd          [rework] shows round reached + money
│
├── scenes/
│   ├── components/
│   │   ├── KeyCapElement.tscn         [rework] scene for KeyCapElement.gd (+IndexLabel)
│   │   └── WordSlot.tscn              [delete] scene for WordSlot.gd
│   │
│   ├── CombatScreen.tscn              [rework] word-builder layout (unique-name nodes)
│   ├── GameOverScreen.tscn            [rework] copy/labels for V2
│   ├── GameRoot.tscn                  [keep]   boots autoload flow / first screen
│   ├── MainMenuScreen.tscn            [keep]
│   └── ShopScreen.tscn                [rework] adds upgrade section (UpgradeBox)
│
├── deploy/
│   └── web/                           [new]    self-hosted static host for the Web export
│       ├── Dockerfile                          nginx:alpine serving build/web
│       └── nginx.conf                         gzip + immutable cache for wasm/pck/js
│
├── build/
│   └── web/                           [new]    (gitignored) Godot Web export output
│
└── docs/
    ├── project-structure.md           [new]    this file
    ├── web-delivery.md                [new]    export / Docker / WebView embed guide
    ├── 2026-09-09-letter-rogue-spec.md [new]   V2 game design spec
    └── 2026-09-09-letter-rogue-plan.md [new]   V1→V2 implementation plan
```

## Data flow notes

- **Autoload order matters** (in `project.godot`): `EventBus`, `GameState`, `PackService`, `KeyCapService`, `ShopService`, `WordService`, `CombatService` — services reference each other via autoload names at call time, not in `_ready()` cross-dependencies.
- **Scoring** lives in `CombatService.calculate_word` (per-tile abilities/finishes/stickers/conditions, boss modifiers, pack `score_modifier`); it returns `letter_scores` (per-slot contributions, driving CombatScreen's score animation) and an optional `log` flag prints a `[score]` breakdown. `WordService` supplies only the dictionary (`is_word`) and the length multiplier. This mirrors the V1 boundary where `CombatService` owned scoring.
- **Bag/hand lifecycle**: `GameState.bag` is the permanent tile collection. `KeyCapService.draw_hand()` samples tiles from the bag into `GameState.hand` each turn; tiles are not consumed (return at turn end), so there is **no discard pile** in V2.
- **Two shops in one**: `ShopScreen` shows tile inventory (buy/sell/reroll) **and** the run-upgrade column; both draw from `ShopService`, which owns `UPGRADES` metadata + pricing.
