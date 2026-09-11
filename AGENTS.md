# Agent Instructions

## MCP Servers

This project can use the **godot-mcp** MCP server for debugging Godot code. If you have it configured in your MCP client, use it to connect to a running Godot editor instance for inspecting scenes, running scripts, and debugging.

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

## Editing scenes in the Godot 2D editor

`GameRoot.tscn` is **empty by design** — it is a runtime-only `Node` state machine that dynamically instantiates screens from `scripts/game_root.gd`. Opening it in the 2D editor shows nothing; do not treat that as corruption.

- Edit each screen **standalone** by double-clicking its scene file: `scenes/MainMenuScreen.tscn`, `scenes/CombatScreen.tscn`, `scenes/ShopScreen.tscn`, `scenes/GameOverScreen.tscn`, and components under `scenes/components/`.
- Every screen root is a `Control` with full-rect anchors, so it fills the 768x1376 viewport in the editor and edits/manipulates normally.
- Verify a scene is healthy headlessly with the `_verify.gd` harness below instead of relying on what the editor shows.

## Headless verification (temp `_verify.gd` + `_verify.tscn`)

These pitfalls caused repeated hangs/no-output runs — internalize them:

1. **This project treats GDScript warnings as ERRORS** (e.g. `inference_on_variant`: *"The variable type is being inferred from a Variant value, so it will be typed as Variant. (Warning treated as error.)"*). NEVER use `:=` on a Variant-returning call like `JSON.parse_string(...)`, `load(...)`, `get_node(...)`. Use explicit annotations: `var data: Variant = JSON.parse_string(...)`. Also `var hand_w := 0` then `hand_w += c.size.x` (float→int) is a compile error; use `var hand_w: float = 0`.
2. **A compile error in the verify script is SILENT on the CLI**: the script doesn't attach, so `_ready` never runs → no `quit()` → the headless run hangs printing only the Godot banner, no errors. The parse errors ARE visible in the connected Godot editor's debug output (use godot-mcp `get_debug_output`). To confirm a script compiled, probe it: `load("res://_verify.gd").can_instantiate()` (false = compile error).
3. **When diagnosing a hang, run with `--quit-after N`** (e.g. `--quit-after 30`) so Godot force-exits after N frames instead of hanging forever; then run without it once fixed.
4. **Root Controls added directly to the tree get size 0 in headless** — full-rect anchors never size them. Before measuring layout, force it with `get_window().size = Vector2i(768, 1376)` (the project viewport size) and `await get_tree().process_frame` once or twice. The window's `get_visible_rect().size` is a reliable 768x1376 even when the root Control is 0.
5. Always end the verify with `get_tree().quit(0)` (or `quit(1)` on assert failure) and keep asserts side-effect-free. Delete `_verify.gd`/`_verify.tscn` (and any `.uid` sidecars) afterwards.

## Strict Project Sandbox & Debugging Boundaries

### 1. Zero External Filesystem Pollution (STRICT RULE)
- **Do NOT navigate outside the project root (`letter-rogue/`).** 
- **Do NOT create, write, or execute files in `/tmp`, `/var/tmp`, `~`, or parent directories (`../`).**
- Every script, test runner, scratchpad, or temporary verification file MUST be contained strictly inside the project tree.

### 2. Designated Debugging & Verification Workspace
- Any headless verification scripts, temporary repro scripts, or automated tests MUST live under one of these dedicated in-project directories:
  - `tests/` (for persistent unit/integration tests and headless verification harnesses).
  - `tools/debug/` (for throwaway reproduction scripts, isolated data parsers, or slice testers).
- Use `git status` awareness: Any throwaway debug script created in `tools/debug/` must be cleaned up and removed before marking a task as complete, OR added to `.gitignore`.

### 3. In-Project Godot Headless Execution Standard
- Always execute Godot verification commands from the project root using relative `res://` paths:
  ```bash
  # CORRECT:
  godot --headless --script res://tests/verify_scoring.gd
  godot --headless --script res://tools/debug/test_atlas_slices.gd

  # FORBIDDEN:
  godot --headless -s /tmp/test.gd
  python3 ../temp_verify.py
  ```
- Running inside the project guarantees that:
  - All 8 Autoload singletons (`EventBus`, `GameState`, etc.) initialize cleanly.
  - Slices from `res://assets/ui/keycap_kit_6.png` resolve without path errors.
  - Project-wide Theme resources (`res://ui/theme/default_theme.tres`) load properly.