# Comparing Lightpanda and Chrome Output

## Quick Workflow

```bash
DOMAIN="example.com"
DATE=$(date +%Y%m%d)
mkdir -p output/$DOMAIN/$DATE
```

### 1. Start proxy (cache resources)
```bash
# run_in_background: true
./tools/proxy
```

### 2. Start Lightpanda
```bash
# run_in_background: true
cd ./browser && zig build run -- serve --log_level warn \
  --http_proxy http://127.0.0.1:3000 \
  --insecure_disable_tls_host_verification \
  2>&1 | tee "./output/$DOMAIN/$DATE/lightpanda.log"
```
Wait for "server running" message before proceeding.
Zig compile takes ~2–3 minutes on first build; near-instant if cached.

### 3. Dump with Lightpanda
```bash
./tools/cdpcli --sleep 5 dump https://$DOMAIN/ 2> output/$DOMAIN/$DATE/lightpanda.html
```
HTML goes to **stderr**. Stats (run count, duration) go to stdout — ignore them.

### 4. Start Chrome
```bash
# run_in_background: true
./tools/chrome.sh 2>&1 | tee "output/$DOMAIN/$DATE/chrome.log"
```
Wait for a line containing `DevTools listening on ws://...`.

### 5. Extract Chrome WebSocket URL
```bash
WS_URL=$(grep -oP 'ws://[^\s]+' "output/$DOMAIN/$DATE/chrome.log" | head -1)
echo $WS_URL
```

### 6. Dump with Chrome
```bash
./tools/cdpcli --cdp "$WS_URL" --sleep 5 dump https://$DOMAIN/ \
  2> output/$DOMAIN/$DATE/chrome.html
```

### 7. Compare
```bash
diff -u output/$DOMAIN/$DATE/chrome.html output/$DOMAIN/$DATE/lightpanda.html | head -100
```

Or count specific patterns:
```bash
grep -c 'filter:blur(10px)' output/$DOMAIN/$DATE/lightpanda.html
grep -c 'opacity:0'         output/$DOMAIN/$DATE/lightpanda.html
```

---

## Key Gotchas

- **Proxy must be running first** — both browsers use `http://127.0.0.1:3000` as HTTP proxy.
  Chrome picks it up automatically via the script; Lightpanda needs the `--http_proxy` flag.
- **HTML dump is on stderr**, not stdout. Always redirect with `2>`.
- **`--sleep N`** is seconds to wait *after* page load before capturing DOM. Use 5 for most
  sites; increase if JS is slow (scroll-triggered animations, lazy loads, etc.).
- **`--log_level warn`** for Lightpanda keeps output clean (only `console.warn` debug traces
  and actual warnings). Use `--log_level debug` when diagnosing network/script issues.
- **Stop old processes** before restarting: `pkill -f lightpanda; pkill -f chrome`.
  The proxy binds port 3000 — if it's already running, the new one exits with code 1.
- **Zig build is cached** — if no `.zig` source files changed, `zig build run` starts
  instantly (output will say "ninja: no work to do" and skip straight to "server running").

---

## Adding Debug Traces

Edit cached JS in `sites/<domain>/`:
- Use `console.warn(...)` — visible in Lightpanda stderr output.
- **Never modify original behavior** — only add trace calls alongside existing code.
- Revert all traces before final comparison.

Example trace pattern for tracking style updates:
```javascript
// Before a style assignment:
console.warn("[LP-DEBUG] before assign", "el=", e.tagName, "opacity=", t.opacity);
Object.assign(e.style, t, ...);
console.warn("[LP-DEBUG] after assign", "style.opacity=", e.style.opacity);
```

---

## Interpreting Results

Common Lightpanda vs Chrome differences:

| Symptom | Likely cause |
|---------|-------------|
| Elements stuck at `opacity:0` or `filter:blur(Npx)` | `Animation.onfinish` not implemented / CSS named setter missing |
| `element.style.opacity` returns `undefined` | `isKnownCSSProperty` list incomplete |
| `element.style['filter'] = value` silently no-ops | `CSSStyleProperties.setNamed` was null |
| Subscriber callbacks not firing after `motionValue.set()` | Check if `requestAnimationFrame` or scheduler interaction is involved |
