# Running Web Platform Tests (WPT)

Lightpanda is tested against the standardized [Web Platform Tests](https://web-platform-tests.org/) using a custom Go-based runner.

## Prerequisites

In this environment, everything is already set up:

- **WPT repository**: `/debug/wpt` (fork branch, with `MANIFEST.json` generated and hosts installed)
- **WPT runner**: `/debug/tools/wptrunner` (precompiled Go binary)
- **Lightpanda browser**: `/debug/browser` (build with `zig build run`)

## Step-by-step

### 1. Start the WPT HTTP server

Use `run_in_background: true`:

```bash
cd /debug/wpt && python3 wpt serve
```

Wait until you see the server is listening (check with `TaskOutput block: false`). The default address is `http://web-platform.test:8000`.

### 2a. Run a single test directly (recommended for debugging)

No CDP server needed — the browser runs, fetches the page, executes JS, and exits:

```bash
cd /debug/browser && zig build run -- fetch --dump wpt "http://web-platform.test:8000/dom/nodes/CharacterData-appendChild.html"
```

- **stdout**: JSON output with summary and per-subtest `name`/`status`/`message`
- **stderr**: internal browser logs (INFO, WARN, errors)

To see only the JSON result:
```bash
cd /debug/browser && zig build run -- fetch --dump wpt "http://web-platform.test:8000/xhr/responsetext-decoding.htm" 2>/dev/null
```

This is the fastest way to check a single test while fixing a bug — no background processes to manage.

### 2b. Start Lightpanda as a CDP server (needed for wptrunner)

Use `run_in_background: true`:

```bash
cd /debug/browser && zig build run -- serve --insecure_disable_tls_host_verification
```

Wait until you see `server running` before proceeding.

### 3. Run tests with wptrunner

**Run the full suite** (takes a long time):

```bash
/debug/tools/wptrunner
```

**Run a specific test file:**

```bash
/debug/tools/wptrunner Node-childNodes.html
```

**Run with summary output:**

```bash
/debug/tools/wptrunner -summary
```

**Run with JSON output:**

```bash
/debug/tools/wptrunner -json
```

**List test cases without running:**

```bash
/debug/tools/wptrunner -list
```

### 4. Stop services

```bash
pkill -f "wpt serve"
pkill lightpanda
```

## wptrunner Options

| Flag | Description | Default |
|------|-------------|---------|
| `-cdp` | CDP WebSocket address | `ws://127.0.0.1:9222` |
| `-concurrency` | Number of concurrent tests | `10` |
| `-json` | Output results in JSON format | off |
| `-summary` | Display a summary | off |
| `-list` | Only list test cases, don't run | off |
| `-verbose` | Enable debug log level | off |
| `-lpd-path` | Lightpanda binary path (enables auto-restart) | none |
| `-wpt-addr` | WPT server address | `http://web-platform.test:8000` |

Environment variables `WPT_ADDR`, `CDP_WS`, and `LPD_PATH` can also be used.

## Tips

- **Single test debugging**: prefer `zig build run -- fetch --dump wpt "URL"` over wptrunner — no CDP server needed, JSON output directly in stdout, much faster iteration.
- Use `-lpd-path` to let wptrunner auto-restart Lightpanda if it crashes during the suite.
- You can browse any WPT test case interactively at [wpt.live](https://wpt.live).
- The WPT fork includes a custom [`testharnessreport.js`](https://github.com/lightpanda-io/wpt/commit/01a3115c076a3ad0c84849dbbf77a6e3d199c56f) for Lightpanda integration.
