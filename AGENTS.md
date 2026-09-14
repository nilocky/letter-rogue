# Agent Instructions

## Workflow Protocol (Lightweight & Batch Sync)

### 1. In-Session Tasks (Build Mode)
- **Code First / Fast Iteration**: When receiving tactical bug fixes or UI adjustment prompts, proceed directly with code changes and Godot verification.
- **Do NOT** perform full Phase 1 doc reconciliation or call Outline MCP on every single micro-task. Keep sessions lean and token-efficient.

### 1.5. Web Export (every session)
- **Every session** (after code changes, before finalization): re-export the Web build and deploy:
  ```powershell
  godot --headless --export-release "Web" build/web/index.html
  ```
- Then copy to NAS target:
  ```powershell
  Copy-Item -Path "build\web\*" -Destination "T:\letter-rogue" -Recurse -Force
  ```
- Or run the combined script: `.\tools\deploy-web.ps1`

### 2. Session Finalization (`/session-sync`)
- When the user signals the end of the session or runs `/session-sync`:
  1. Review all code changes across the session.
  2. Batch update `docs/spec.md`, `docs/plan.md` and `docs/project-structure.md`.
  3. Push updated spec to Outline Wiki (`4f19f637-60dd-4ed1-ae88-b991dfa10a6a`) via `outline-mcp`.
  4. Perform atomic `git add`, `git commit`, and `git push`.

## Mandatory Task Lifecycle: The "Doc-First & Outline Sync" Gate

---

## Tool Usage & MCP Constraints

1. **Available MCP Tools**:
   - `outline-mcp`: Use this tool directly for querying specs, plans, and doc updates. Do NOT fetch Outline API via curl or bash.
   - `godot-mcp`: Use this tool directly for checking scene trees, node status, and Godot engine inspections.

2. **Strict Boundary Rules**:
   - **NEVER** attempt to read user home directories (`~/.config/opencode`, `~/.bashrc`, etc.) or OS temp folders (`/tmp`). All configuration, tokens, and endpoints are already injected into the MCP server environment.
   - **NEVER** ask for external directory permissions to inspect configuration files. If an MCP call fails, report the error directly instead of searching the filesystem for credentials.
   - Always prefer MCP tool calls over manual CLI file searches for Outline wiki documentation and Godot runtime inspection.


## OS & Terminal Constraints

- **Host Operating System**: Windows 11 (Non-POSIX).
- **Default Shell**: PowerShell (pwsh).
- **Prohibited Commands**: NEVER execute Linux/Bash-specific commands:
  - DO NOT USE: `ls`, `cat`, `grep`, `touch`, `rm -rf`, `find`, `export`, `source`, `which`
- **Mandatory Equivalents**:
  - `cat <file>` ➔ `Get-Content <file>`
  - `grep <pattern>` ➔ `Select-String -Pattern "<pattern>"`
  - `rm -rf <path>` ➔ `Remove-Item -Recurse -Force <path>`
  - `touch <file>` ➔ `New-Item -ItemType File -Force <file>`
  - `export VAR=val` ➔ `$env:VAR = "val"`
  - `which <tool>` ➔ `Get-Command <tool>`
- **Path Separators**: Always format file paths with Windows compatibility (e.g. `.\scripts\autoload\DebugManager.gd` or Godot's `res://...`).
- **Chaining Commands**: Use `;` in PowerShell instead of `&&` when running consecutive commands on older PowerShell versions.


## Outline wiki uploads (UTF-8 encoding)

When uploading docs to the Outline wiki by **outline-mcp** MCP server (instance `https://outline.nas.thinksdesign.com`, collection `OpenCode`), non-ASCII characters (`→`, `—`, box-drawing `├──`, etc.) will be silently corrupted into mojibake (`â†'`, `â€”`, `â”œâ€`...) unless you follow this procedure. PowerShell 5.1 defaults corrupt UTF-8 in two places:

1. **Reading** — never read the source markdown with `Get-Content` (defaults to Windows-1252). Read it as UTF-8 explicitly:
   ```powershell
   [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
   ```
2. **The API request** — build the JSON payload as a string, write it to a temp file with UTF-8 (no BOM), and POST with `curl.exe --data-binary @file` (never `Invoke-RestMethod -Body <string>` for large multiline bodies):
   ```powershell
   [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
   & curl.exe -s -X POST "$base/api/documents.update" -H "Authorization: Bearer $key" -H "Content-Type: application/json" --data-binary "@$tmp"
   ```
3. **Verifying** — parse the API response via a file, not curl stdout. `curl -o resp.json`, then decode with `[System.IO.File]::ReadAllText($resp, [Text.Encoding]::UTF8)`. PowerShell mis-decodes curl's console output, which produces false "still corrupted" readings.

Notes:
- `documents.info`/`documents.update` take an `id` (UUID), not a `url` slug. Find a doc's UUID with `documents.search` if you only have its URL.
- Verify a doc is clean by checking the stored text contains no characters in range U+0080–U+00FF (legit content chars like `→`/`—`/`├` are all above U+00FF).

## Code Conventions
- Use Godot 4.x typed GDScript (`var count: int = 0`, `func get_name() -> String:`).
- Node naming in scripts: Use `%UniqueName` syntax for UI scene nodes referenced by scripts.
- Signal naming: Use past-tense descriptive verbs (e.g., `word_committed`, `round_won`, `turn_ended`).
- Do not add comments explaining basic language syntax; keep code concise and domain-focused.

## Debug Tools

Debug hotkeys live in `scripts/autoload/DebugManager.gd` (`_unhandled_input`) and are gated behind `OS.is_debug_build()` — they no-op in release builds.

- **F1**: toggles the `DebugOverlay` panel (`scenes/debug/DebugOverlay.tscn`).
- **F12**: saves a screenshot to `user://screenshots/debug_<timestamp>.png`.

The overlay buttons route through `DebugManager`, which delegates to `/root/GameRoot` methods:
- **Menu / Combat / Shop** → `route_to(state)` (menu/run_setup/combat/shop).
- **Jump Boss Round** → `jump_boss_round()`.
- **x0.5 / x1 / x2** → `set_time_scale(v)` (clamps `Engine.time_scale` to 0.0–4.0).
- **Screenshot** → `screenshot()`.
- **+$50** → `inject_state(cfg)` (injects money).
- **Trigger: silence** → `trigger_mechanic(id)` (sets current monster's `modifier` to `silence`).

**F1 was removed.** It previously jumped straight to the shop with the mx_red pack + $50; that routing is now handled by the overlay buttons instead.

## Editing scenes in the Godot 2D editor

`GameRoot.tscn` is **empty by design** — it is a runtime-only `Node` state machine that dynamically instantiates screens from `scripts/game_root.gd`. Opening it in the 2D editor shows nothing; do not treat that as corruption.

- Edit each screen **standalone** by double-clicking its scene file: `scenes/MainMenuScreen.tscn`, `scenes/CombatScreen.tscn`, `scenes/ShopScreen.tscn`, `scenes/GameOverScreen.tscn`, and components under `scenes/components/`.
- Every screen root is a `Control` with full-rect anchors, so it fills the 768x1376 viewport in the editor and edits/manipulates normally.

## Strict Project Sandbox & Debugging Boundaries

### 1. Zero External Filesystem Pollution (STRICT RULE)
- **Do NOT navigate outside the project root (`letter-rogue/`).** 
- **Do NOT create, write, or execute files in `/tmp`, `/var/tmp`, `~`, or parent directories (`../`).**
- Every script, test runner, scratchpad, or temporary verification file MUST be contained strictly inside the project tree.

### 2. Designated Debugging & Verification Workspace
- Any temporary repro scripts or automated tests MUST live under one of these dedicated in-project directories:
  - `tests/` (for persistent unit/integration tests).
  - `tools/debug/` (for throwaway reproduction scripts, isolated data parsers, or slice testers).
- Use `git status` awareness: Any throwaway debug script created in `tools/debug/` must be cleaned up and removed before marking a task as complete, OR added to `.gitignore`.