# Web Delivery

Letter Rogue ships as a self-hosted HTML5 (WebAssembly) build served by nginx in Docker, intended for embedding in iOS/Android WebViews.

## Re-exporting the Web build

Requires the Godot 4.7.2 export templates (installed via Editor → Manage Export Templates, or by unzipping `Godot_v4.7.2-stable_export_templates.tpz` into `%APPDATA%\Godot\export_templates\4.7.2.stable\`).

The Web preset is defined in `export_presets.cfg`:

- Export path: `build/web/index.html`
- `Emulate Touch From Mouse` is enabled (`input_devices/pointing/emulate_touch_from_mouse=true`)
- `window/stretch/mode="canvas_items"` with `aspect="expand"` so the layout reflows to any viewport
- Exclude filter: `addons/godot_mcp/*` — the dev-only MCP plugin never ships

Re-export from the repo root:

```bash
godot --headless --export-release "Web" build/web/index.html
```

Expected output in `build/web/`: `index.html`, `index.js`, `index.wasm`, `index.pck`. The `.pck` embeds `data/words.json` (the 369k-word dictionary); the pck is ~4.6 MB.

## Building and serving the Docker image

The Dockerfile copies from the repo root, so build with context = repo root:

```bash
docker build -f deploy/web/Dockerfile -t letter-rogue-web .
docker run --rm -p 8080:80 letter-rogue-web
```

Open `http://localhost:8080/` in a browser or an embedded WebView. nginx serves `index.html`, gzip-compresses wasm/js/json, and sets long-lived immutable cache headers on `*.wasm|*.pck|*.js`.

## Embedding in a WebView

- Android: load the URL in a `WebView` with JavaScript enabled.
- iOS: load it in a `WKWebView`.
- Ports/CORS: serve the game over HTTP (or HTTPS on device); nginx binds port 80 inside the container and maps to the host port of your choice (`-p <host>:80`). No cross-origin requests are made by the game itself, so CORS is only relevant if you embed a page from a different origin than the game URL.

## iOS App Store policy risk

Apple's App Store Review Guidelines (section 4.7 on HTML5 games / embedded webviews) restrict apps whose primary content is a webview-hosted game. Shipping Letter Rogue inside a WKWebView risks rejection unless the app adds meaningful native functionality. Plan for either an App Store wrapper with native extras, or sideload/enterprise distribution for iOS.

## Portability notes

- The word dictionary is baked into the `.pck` at export time; any change to `data/words.json` requires a re-export.
- `.dockerignore` excludes `.godot`, `addons`, `docs`, and `data/raw` so the build context stays small while still shipping `build/web`.