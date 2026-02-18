# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Environment

This project runs inside a Docker container. You have full access to run Linux commands (apt-get, curl, wget, etc.) as needed.

## Project Overview

This repository (website-debugging) is used to debug Lightpanda Browser behavior on websites.

Lightpanda Browser is an open-source headless browser written in Zig, designed for web automation, scraping, AI agents, and testing. It's compatible with Playwright, Puppeteer, and chromedp through the Chrome DevTools Protocol (CDP).

The Lightpanda browser codebase is located in the `browser/` directory. This debugging repository also includes a `proxy` binary (a precompiled Go executable) and `cdpcli` tool at the root level.

## Focus and Approach

Your primary goal is to **fix the Lightpanda browser** so it runs correctly with the target website. Follow these principles:

1. **Make small, incremental changes** — Fix one thing at a time. Do not bundle multiple fixes into a single change.
2. **Plan before coding** — Before making any fix, write a plan into the corresponding `output/<domain>/<YYYYMMDD>/` directory (e.g. `plan.md`) describing what you found, what you intend to change, and why. **Ask the user for validation before implementing.**
3. **Add missing tests** — When fixing a bug in `browser/`, add or update tests to cover the fixed behavior. Tests ensure regressions are caught early.
4. **Fixes go in `browser/` only** — Never fix issues by modifying cached site files. The proxy cache must remain faithful to the original website.
5. **Web API reference** — Use https://developer.mozilla.org/en-US/docs/Web/API as the authoritative reference for web API specifications when implementing or fixing browser features.

## Debugging Workflow

The typical debugging process:
1. Start the proxy to cache website resources locally
2. Start Lightpanda browser with proxy configuration
3. Dump the website using cdpcli
4. Analyze cached files in `sites/` directory
5. Modify cached HTML/JS files to add debug traces
6. Re-run to see modified behavior

You can dump a website using `cdpcli` and `proxy` with Lightpanda, then understand and debug how Lightpanda behaves by altering the html and js files cached by `proxy`. Use `console.warn` to introduce debug traces you will be able to view in Lightpanda output.

## File Locations

- `tools/proxy` - Proxy server binary (root directory)
- `tools/cdpcli` - CDP client tool for dumping websites (root directory)
- `tools/chrome.sh` - Script to start Chrome with debugging enabled (root directory)
- `browser/` - Lightpanda browser source code
- `notes/` - Your notes - Update / Add your own notes into this dir
- `sites/` - Cached website resources (created by proxy)
  - Organized by domain subdirectories
  - Contains HTML, JS, CSS, and other assets
- `output/` - Test outputs organized by domain and date
  - Structure: `output/<domain>/<YYYYMMDD>/`
  - Contains HTML dumps, logs, and comparison results

## Output Organization

All test outputs should be stored in the `output/` directory with the following structure:

```
output/
  └── <domain>/
      └── <YYYYMMDD>/
          ├── lightpanda.html
          ├── chrome.html
          ├── lightpanda.log
          └── chrome.log
```

Example for testing `blg.tch.re` on December 24, 2025:
```bash
mkdir -p output/blg.tch.re/20251224
```

This organization allows:
- Easy comparison of outputs across different dates
- Tracking behavior changes over time
- Keeping test artifacts organized by website

## Run a Test

### Start the proxy

Start the proxy in the background listening on `http://127.0.0.1:3000`:
```bash
./proxy &
```

Or use the Bash tool with `run_in_background: true` when working with Claude Code.

The proxy will cache all remote data into `sites/`.
Resources are stored in subdirectories organized by domain.

You can edit these cached files to debug the results.

### Start Lightpanda browser

To start the browser, go to `browser/` directory and then run:
```bash
zig build -Dprebuilt_v8_path=v8/libc_v8.a run -- serve --log_level debug --http_proxy http://127.0.0.1:3000 --insecure_disable_tls_host_verification
```

To save logs to the output directory:
```bash
# Set up output directory
DOMAIN="example.com"
DATE=$(date +%Y%m%d)
mkdir -p "../output/$DOMAIN/$DATE"

# Start browser and save logs
cd browser && zig build -Dprebuilt_v8_path=v8/libc_v8.a run -- serve --log_level debug --http_proxy http://127.0.0.1:3000 --insecure_disable_tls_host_verification 2>&1 | tee "../output/$DOMAIN/$DATE/lightpanda.log" &
cd ..
```

The stderr will display internal logs but also the console.log and console.warn messages you added to JavaScript files for debugging.

Use background task to let the browser running while starting other commands.

### Dump a website with cdpcli

Use the command `./cdpcli` to connect to Lightpanda browser through CDP protocol, fetch a website and dump the final HTML:

```bash
./cdpcli --sleep 5 dump https://example.com
```

Use the `--sleep` option to wait for page loading/JS execution (increase for slow-loading pages).

**Important:** The HTML dump is output to **stderr**, not stdout. Stdout contains statistics (run count, duration, errors) that can be ignored.

To save the HTML output to the organized output directory:
```bash
# Create output directory
DOMAIN="example.com"
DATE=$(date +%Y%m%d)
mkdir -p "output/$DOMAIN/$DATE"

# Dump and save output
./cdpcli --sleep 5 dump https://example.com 2> "output/$DOMAIN/$DATE/lightpanda.html"
```

To view just the HTML (ignore statistics):
```bash
./cdpcli --sleep 5 dump https://example.com 2>&1 1>/dev/null
```

### Stopping services

To stop background processes:
```bash
pkill proxy
pkill lightpanda
pkill chrome
```

Or use the KillShell tool when working with Claude Code.

## Comparing with Chrome

To debug behavioral differences between Lightpanda and Chrome, you can run the same tests on both browsers using the same cached resources.

### Start Chrome with debugging

Start Chrome in the background with CDP enabled:
```bash
./chrome.sh &
```

To save Chrome logs to the output directory:
```bash
# Set up output directory
DOMAIN="example.com"
DATE=$(date +%Y%m%d)
mkdir -p "output/$DOMAIN/$DATE"

# Start Chrome and save logs
./chrome.sh 2>&1 | tee "output/$DOMAIN/$DATE/chrome.log" &
```

Chrome will output to stderr a line containing the WebSocket address:
```
DevTools listening on ws://127.0.0.1:9222/devtools/browser/abc123...
```

To capture the WebSocket address, you can:

**Option 1: Extract manually from output**
Look for the line starting with "DevTools listening on" in the stderr output and copy the full `ws://...` URL.

**Option 2: Capture automatically**
```bash
WS_URL=$(./chrome.sh 2>&1 | grep -oP 'ws://[^\s]+' | head -1)
echo $WS_URL
```

**Option 3: Extract from saved log file**
```bash
WS_URL=$(grep -oP 'ws://[^\s]+' "output/$DOMAIN/$DATE/chrome.log" | head -1)
echo $WS_URL
```

Then use the captured address with cdpcli:
```bash
./cdpcli --cdp "$WS_URL" --sleep 5 dump https://example.com
```

Chrome will use the same proxy (`http://127.0.0.1:3000`) as Lightpanda, ensuring both browsers access identical cached resources.

### Dump a website with Chrome

Use cdpcli with the `--cdp` option to connect to Chrome instead of Lightpanda:

```bash
# Using the captured WebSocket URL
./cdpcli --cdp "$WS_URL" --sleep 5 dump https://example.com

# Or with a specific URL (replace with actual address from Chrome output)
./cdpcli --cdp "ws://127.0.0.1:9222/devtools/browser/abc123..." --sleep 5 dump https://example.com
```

Remember: HTML output goes to stderr. To save it to the organized output directory:
```bash
# Ensure output directory exists
DOMAIN="example.com"
DATE=$(date +%Y%m%d)
mkdir -p "output/$DOMAIN/$DATE"

# Dump and save
./cdpcli --cdp "$WS_URL" --sleep 5 dump https://example.com 2> "output/$DOMAIN/$DATE/chrome.html"
```

### Comparison workflow

Complete workflow for comparing Lightpanda and Chrome behavior:

```bash
# 1. Set up output directory
DOMAIN="example.com"
DATE=$(date +%Y%m%d)
mkdir -p "output/$DOMAIN/$DATE"

# 2. Start the proxy (if not already running)
./proxy &

# 3. Start Lightpanda and save logs
cd browser && zig build -Dprebuilt_v8_path=v8/libc_v8.a run -- serve --log_level debug --http_proxy http://127.0.0.1:3000 --insecure_disable_tls_host_verification 2>&1 | tee "../output/$DOMAIN/$DATE/lightpanda.log" &
cd ..

# 4. Dump with Lightpanda
./cdpcli --sleep 5 dump https://example.com 2> "output/$DOMAIN/$DATE/lightpanda.html"

# 5. Start Chrome and save logs
./chrome.sh 2>&1 | tee "output/$DOMAIN/$DATE/chrome.log" &

# 6. Extract WebSocket URL from Chrome logs
sleep 2
WS_URL=$(grep -oP 'ws://[^\s]+' "output/$DOMAIN/$DATE/chrome.log" | head -1)
echo "Chrome WebSocket: $WS_URL"

# 7. Dump with Chrome
./cdpcli --cdp "$WS_URL" --sleep 5 dump https://example.com 2> "output/$DOMAIN/$DATE/chrome.html"

# 8. Compare HTML outputs
diff -u "output/$DOMAIN/$DATE/chrome.html" "output/$DOMAIN/$DATE/lightpanda.html"

# 9. Review logs for differences
echo "Lightpanda log: output/$DOMAIN/$DATE/lightpanda.log"
echo "Chrome log: output/$DOMAIN/$DATE/chrome.log"
```

Additional steps:
- Modify cached files in `sites/` to add debug traces and investigate discrepancies
- Both browsers use the same cached resources from the proxy, making it easier to isolate Lightpanda-specific issues
- All artifacts are saved in `output/$DOMAIN/$DATE/` for later analysis

## Important: Do Not Change JS Behavior in Proxy Cache

Cached files in `sites/` must **never** have their original behavior modified. You may only edit them to add debug traces (e.g. `console.warn`) for understanding and investigation purposes. If you discover a bug or behavioral issue, the fix must be made in the **Lightpanda browser source code** (`browser/`), not by altering the cached website JS/HTML. The proxy cache must remain a faithful representation of the original website.

## Debugging Tips

- Use `console.warn()` instead of `console.log()` for debug traces - they're more visible in Lightpanda output
- Check `sites/[domain]/` to find cached files you can modify
- The `--sleep` parameter in cdpcli allows JavaScript to execute - increase it for slow-loading pages
- Browser logs go to stderr, including your console.warn messages
- Use `--log_level debug` to see detailed internal browser logs
- Modified cached files take effect immediately on the next run
- Store all outputs in `output/<domain>/<YYYYMMDD>/` for easy tracking and comparison across test runs

## Troubleshooting

- **Proxy not caching**: Ensure the proxy is running before starting Lightpanda
- **Changes not reflected**: Clear the `sites/` cache or verify you're modifying the correct domain subdirectory
- **Connection refused**: Check that both proxy (port 3000) and Lightpanda are running
- **TLS errors**: The `--insecure_disable_tls_host_verification` flag disables certificate verification for debugging
- **Page not fully loaded**: Increase the `--sleep` value in cdpcli to allow more time for JavaScript execution

## Lightpanda Browser Architecture

For detailed information about Lightpanda's internal architecture, components, and development workflow, see [LIGHTPANDA_ARCHITECTURE.md](./LIGHTPANDA_ARCHITECTURE.md).
