# Lightpanda Project Notes & How to Contribute

## Project Overview

Lightpanda is an open-source headless browser written in **Zig**, designed for
web automation, scraping, AI agents, and testing. It is CDP-compatible
(Playwright, Puppeteer, chromedp). The browser embeds **V8** as its JS engine.

Source: `browser/` directory in this repo.

---

## Codebase Layout

```
browser/
  src/
    browser/
      webapi/           ← Web API implementations (DOM, CSS, events, …)
        css/
          CSSStyleDeclaration.zig
          CSSStyleProperties.zig   ← style.opacity, style['filter'], etc.
        animation/
          Animation.zig            ← Web Animations API (element.animate())
        Element.zig
        Window.zig
        …
      js/
        js.zig          ← JS bridge (V8 bindings)
        Local.zig       ← JS value / local scope helpers
        Caller.zig      ← named getter/setter bridge dispatch
      Page.zig
      …
    testing.zig         ← test runner helpers
    log.zig
  src/browser/tests/    ← HTML-based integration tests
    element/
      css_style_properties.html
    animation/
      animation.html
    …
```

---

## Build & Test

### Build and run the browser
```bash
cd browser
zig build run -- serve --log_level debug \
  --http_proxy http://127.0.0.1:3000 \
  --insecure_disable_tls_host_verification
```
First build compiles V8 (ninja) + Zig; subsequent builds are cached and fast.

### Run all tests
```bash
cd browser
zig build test
```

### Run a single test file
```bash
cd browser
zig build test -- tests/element/css_style_properties.html
```
Output: green pass list or red failures with expected vs actual.

---

## How the JS Bridge Works

### Exposing a Zig type to JS

Every Web API type has a `JsApi` inner struct:

```zig
pub const JsApi = struct {
    pub const bridge = js.Bridge(MyType);

    pub const Meta = struct {
        pub const name = "MyType";
        pub const prototype_chain = bridge.prototypeChain();
        pub var class_id: bridge.ClassId = undefined;
    };

    // Expose a function
    pub const myMethod = bridge.function(MyType.myMethod, .{});

    // Expose a getter/setter pair
    pub const myProp = bridge.accessor(MyType.getMyProp, MyType.setMyProp, .{});

    // Expose a read-only property with a static value
    pub const pending = bridge.property(false, .{ .template = false });

    // Named + indexed interceptor (e.g. element.style['opacity'])
    pub const @"[]" = bridge.namedIndexed(MyType.getNamed, MyType.setNamed, null, .{});
};
```

### Named interceptor signatures (Caller.zig)

```zig
// Getter — return error.NotHandled to yield to JS prototype chain (→ undefined)
pub fn getNamed(self: *T, name: []const u8, page: *Page) ![]const u8

// Setter — return error.NotHandled to ignore the assignment
pub fn setNamed(self: *T, name: []const u8, value: []const u8, page: *Page) !void
```

`value` is **already converted** from JS (numbers coerced to string via
`jsValueToZig([]const u8, …)` → `.toStringSlice()`).

### Scheduler (async tasks from Zig)

To fire a callback asynchronously from Zig code:

```zig
try page.js.scheduler.add(
    self,                        // context pointer (cast to *anyopaque)
    struct {
        fn run(ctx: *anyopaque) anyerror!?u32 {
            const self: *MyType = @ptrCast(@alignCast(ctx));

            // MUST create a local scope when calling JS outside a Caller context
            var ls: js.Local.Scope = undefined;
            self._page.js.localScope(&ls);
            defer ls.deinit();

            ls.toLocal(self._callback).call(void, .{}) catch |err| {
                log.warn(.browser, "my callback", .{ .err = err });
            };
            return null;   // null = don't reschedule; return u32 to reschedule in Nms
        }
    }.run,
    delay_ms,
    .{ .name = "my.callback" },
);
```

**Critical:** Zig inner struct functions **cannot capture runtime variables**
from the outer scope. Store everything you need in the context struct (e.g.
`_page: *Page = undefined` as a field on the type).

---

## Common Patterns When Fixing Missing Web APIs

1. **Identify the JS API call** failing in the site JS (via debug traces or
   error logs). Cross-reference with MDN.

2. **Find or create the Zig file** under `src/browser/webapi/`.

3. **Implement the method/property** following the bridge patterns above.

4. **Add to `isKnownCSSProperty`** if adding a CSS property that should return
   `''` (empty string) instead of `undefined` when not set.

5. **Write a test** in `src/browser/tests/<category>/<feature>.html`:
   ```html
   <script id="myTest">
   {
     const el = document.createElement('div');
     el.style.setProperty('my-prop', 'value');
     testing.expectEqual('value', el.style.myProp);
   }
   </script>
   ```
   Add `testing.htmlRunner("category/feature.html", .{})` in the Zig file.

6. **Run tests** and verify all pass before considering the fix complete.

---

## Lessons Learned from the lightpanda.io Debug Session

### Bug 1: `Animation.onfinish` not implemented
- **Symptom:** Framer Motion entrance animations never complete → elements
  remain at `opacity:0` / `filter:blur(10px)` (their initial keyframe state).
- **Fix:** Implement `setOnfinish` in `Animation.zig` using the scheduler to
  fire the callback with a configurable delay.
- **Gotcha:** The scheduler callback runs *outside* any JS Caller context, so
  `page.js.local` is `null`. Must use `page.js.localScope(&ls)` to create a
  fresh local scope before calling any JS function.
- **Gotcha 2:** The `_page` pointer must be stored as a **field** on the struct
  (`_page: *Page = undefined`). Zig closures in inner structs cannot capture
  outer-scope runtime variables.

### Bug 2: `CSSStyleProperties` named setter was `null`
- **Symptom:** `element.style.opacity = '1'` and
  `Object.assign(element.style, {filter: 'blur(0px)'})` silently did nothing.
- **Fix:** Implement `setNamed` in `CSSStyleProperties.zig` and wire it into
  the `JsApi @"[]"` bridge:
  ```zig
  pub const @"[]" = bridge.namedIndexed(getNamed, setNamed, null, .{});
  ```
- **Root cause identified via:** debug trace on `renderDOM` function in cached
  Framer Motion bundle — confirmed style was set in JS but DOM not updated.

### Bug 3: Animation cycling (ongoing)
- **Symptom:** Even with onfinish + setter fixed, elements cycle between
  `blur(10px)` and `blur(0px)` repeatedly.
- **Root cause hypothesis:** `onfinish` fires at delay=0ms (immediately), but
  Framer Motion's WAAPI integration checks `animation.startTime` and
  `animation.currentTime` to decide when to re-drive/restart the animation.
  Since LP returns `startTime = null` and never advances `currentTime`, FM
  keeps restarting.
- **Next step:** Implement proper `startTime` tracking in `element.animate()`:
  store `options.duration`, set `startTime` on first `play()`, advance
  `currentTime`, and schedule `onfinish` after the actual duration instead of
  0ms.

---

## Debugging Tips Specific to Lightpanda

- `console.warn` traces appear in LP stderr; `console.log` may be suppressed
  depending on log level.
- Use `--log_level warn` for clean output (only warnings + your traces).
- Use `--log_level debug` to trace script loading, scheduler ticks, CDP events.
- The scheduler fires at 250ms intervals for `page.messageLoop`. Tasks with
  `delay_ms = 0` fire on the next available tick.
- `zig build test -- tests/path/to/test.html` only runs HTML tests whose file
  path **contains** the given string — useful for targeted runs.
