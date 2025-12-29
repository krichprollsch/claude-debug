# Lightpanda Browser Architecture Reference

This document describes the architecture of the Lightpanda browser (located in `browser/` directory), which is helpful context when debugging issues.

## Core Components

**Browser Engine (`src/browser/`)**
- `browser.zig` - Main browser entry point
- `page.zig` - Page navigation and lifecycle management (arena-based memory)
- `session.zig` - Browser session management
- `netsurf.zig` - HTML parser integration (Netsurf libs)
- `ScriptManager.zig` - JavaScript execution coordination
- `Scheduler.zig` - Task scheduling
- `SlotChangeMonitor.zig` - Shadow DOM slot change tracking

**DOM & HTML (`src/browser/dom/`, `src/browser/html/`)**
- DOM tree manipulation and traversal
- HTML element implementations
- `window.zig` - JavaScript global window object

**CDP Implementation (`src/cdp/`)**
- `cdp.zig` - CDP protocol handler
- `domains/` - Individual CDP domain implementations (Page, DOM, Network, Runtime, etc.)
- Provides Playwright/Puppeteer compatibility

**HTTP & Networking (`src/http/`)**
- Built on libcurl with custom configuration
- Supports HTTP/2 (nghttp2), Brotli, TLS (BoringSSL)
- Proxy support with bearer token authentication

**JavaScript Integration (`src/browser/js/`)**
- V8 engine integration
- WebAPI bindings

**Web APIs**
- `fetch/` - Fetch API
- `xhr/` - XMLHttpRequest
- `storage/` - Web Storage (cookies, localStorage)
- `events/` - Event system
- `console/` - Console API
- `crypto/` - Web Crypto API
- `canvas/` - Canvas API
- `streams/` - Streams API
- `encoding/` - Text encoding
- `cssom/` - CSS Object Model

**Application Layer**
- `main.zig` - CLI entry point and argument parsing
- `server.zig` - CDP WebSocket server
- `app.zig` - Application state management

## Memory Management

- Uses arena allocators extensively, especially in `Page`
- Page arena is reset on navigation (`end()` method)
- Debug builds use `std.heap.DebugAllocator` for leak detection
- Release builds use C allocator (actually Mimalloc)

## Build Configuration

The `build.zig` file:
- Defines multiple build targets (main browser, tests, WPT runner, shell)
- Manages complex C/C++ dependency compilation (curl, brotli, nghttp2, etc.)
- Uses LLVM backend (required for V8 compatibility)
- Configures extensive curl feature flags (many protocols disabled)
- Links BoringSSL for TLS

## Development Workflow

1. **Initial setup:**
   ```bash
   make install-dev
   make build-dev
   ```

2. **Development cycle:**
   ```bash
   make test F="your_test"  # Run specific tests
   make build-dev           # Rebuild
   ```

3. **WPT tests** (Web Platform Tests) are in `tests/wpt/` - these are standardized web platform tests. Keep the directory structure when adding new tests.

4. **End-to-end tests** require the `demo` repository cloned to `../demo`:
   ```bash
   make end2end
   ```

## Running the Browser

**Fetch a URL:**
```bash
./zig-out/bin/lightpanda fetch --dump https://example.com
```

**Start CDP server:**
```bash
./zig-out/bin/lightpanda serve --host 127.0.0.1 --port 9222
```

Then connect with Puppeteer/Playwright using `browserWSEndpoint: "ws://127.0.0.1:9222"`.

## Testing

- Unit tests are co-located with source files using Zig's built-in test system
- Custom test runner in `src/test_runner.zig`
- Test filter via `TEST_FILTER` environment variable or `F=` make parameter
- WPT tests validate Web API compliance
