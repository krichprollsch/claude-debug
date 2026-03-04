# Puppeteer Scripts for Complex Scenarios

For scenarios beyond what `cdpcli` supports — waiting on network idle, filling forms, clicking links, multi-page navigation — use Node.js scripts with `puppeteer-core`.

## Setup

Create an npm project in the relevant output subdirectory (e.g. `output/<domain>/<YYYYMMDD>/`):

```bash
mkdir -p output/<domain>/<YYYYMMDD>
cd output/<domain>/<YYYYMMDD>
npm init -y
npm install puppeteer-core
```

Add `"type": "module"` to `package.json` to use ES module syntax (`import`).

## Connecting to the Browser

Always use `puppeteer.connect()` — never `puppeteer.launch()` — since you are attaching to an already-running browser instance.

Use the `BROWSER_ADDRESS` environment variable for the WebSocket endpoint so the same script can be run against Lightpanda or Chrome without code changes:

```js
import puppeteer from 'puppeteer-core';

// Default points to Lightpanda. Override with BROWSER_ADDRESS env var to target Chrome.
const browser = await puppeteer.connect({
    browserWSEndpoint: process.env.BROWSER_ADDRESS ?? 'ws://127.0.0.1:9222',
});

const context = await browser.createBrowserContext();
const page = await context.newPage();

// ... your scenario ...

await page.close();
await context.close();
await browser.disconnect();
```

Run against Lightpanda (default):

```bash
node script.js
# or explicitly:
BROWSER_ADDRESS=ws://127.0.0.1:9222 node script.js
```

## Testing the Same Scenario with Chrome

Because the script reads `BROWSER_ADDRESS` from the environment, you can replay the exact same scenario against Chrome with no code changes. This is the primary way to isolate Lightpanda-specific bugs.

1. Start Chrome with CDP enabled (in background):

```bash
./tools/chrome.sh
```

2. Extract the WebSocket URL from its output (the line starting with `DevTools listening on`):

```bash
WS_URL=$(grep -oP 'ws://[^\s]+' output/<domain>/<YYYYMMDD>/chrome.log | head -1)
```

3. Run the same script pointing at Chrome:

```bash
BROWSER_ADDRESS="$WS_URL" node script.js
```

Both runs go through the same proxy cache (`http://127.0.0.1:3000`), so any difference in output is caused by the browser, not the network.

## Recommended: Wait for networkidle0

Prefer `waitUntil: 'networkidle0'` over a fixed sleep — it waits until there are no in-flight network requests for 500ms, giving a reliable signal that the page has finished loading:

```js
await page.goto('https://example.com', { waitUntil: 'networkidle0', timeout: 10000 });
```

## Common Patterns

### Dump page HTML

```js
await page.goto(url, { waitUntil: 'networkidle0', timeout: 10000 });
const html = await page.content();
console.log(html);
```

### Fill and submit a form

```js
await page.goto(url, { waitUntil: 'networkidle0', timeout: 10000 });
await page.type('#username', 'myuser');
await page.type('#password', 'mypassword');
await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle0' }),
    page.click('button[type=submit]'),
]);
const html = await page.content();
```

### Click a link and navigate to a second page

```js
await page.goto(url, { waitUntil: 'networkidle0', timeout: 10000 });
await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle0' }),
    page.click('a.some-link'),
]);
const html = await page.content();
```

### Wait for a specific element to appear

```js
await page.goto(url, { waitUntil: 'networkidle0', timeout: 10000 });
await page.waitForSelector('.results', { timeout: 5000 });
const html = await page.content();
```

### Extract structured data from the page

```js
const items = await page.evaluate(() => {
    return Array.from(document.querySelectorAll('.item')).map(el => ({
        title: el.querySelector('h2')?.textContent.trim(),
        href: el.querySelector('a')?.href,
    }));
});
console.log(JSON.stringify(items, null, 2));
```

### Search form (type + submit)

```js
await page.goto(url, { waitUntil: 'networkidle0', timeout: 10000 });
await page.type('input[name=q]', 'search query');
await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle0' }),
    page.keyboard.press('Enter'),
]);
```

## Saving Output

Save HTML dumps to the standard output directory so they can be compared with Chrome:

```js
import { writeFileSync } from 'fs';

const html = await page.content();
writeFileSync('lightpanda.html', html);
```

Run the script and redirect logs:

```bash
node script.js 2>&1 | tee lightpanda.log
```

## Example References

See the Lightpanda demo repository for ready-to-use examples:
- https://github.com/lightpanda-io/demo/tree/main/puppeteer — basic navigation, form submission, link clicking, network wait, cookies, frames, request interception
- https://github.com/lightpanda-io/demo/tree/main/integration — real-world site scenarios (Hacker News, DuckDuckGo, GitHub, Wikipedia, etc.)

## Sending Raw CDP Commands

Use `page._client()` to get the underlying CDP session and send raw commands:

```js
const client = page._client();
await client.send('Network.enable');

client.on('Network.responseReceived', (event) => {
    console.log(event.response.url, event.response.status);
});

const { body } = await client.send('Network.getResponseBody', { requestId });
```

Alternatively, create a dedicated CDP session with `page.createCDPSession()`:

```js
const cdp = await page.createCDPSession();
await cdp.send('Network.enable');
```

## Tips

- Always `await browser.disconnect()` at the end — do not call `browser.close()` since you are connected to an external process.
- Use `console.warn()` for debug output — it shows up in Lightpanda's stderr log alongside internal browser logs.
- If `networkidle0` times out, the page likely has persistent background polling; fall back to `waitForSelector` or `waitForNetworkIdle({ idleRequestsCount: 2 })`.
- Scripts can be run against both Lightpanda and Chrome (by changing `browserWSEndpoint`) to isolate browser-specific bugs.
