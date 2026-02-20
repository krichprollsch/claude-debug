# Lightpanda Browser Debugging Environment

An isolated debugging environment for Claude to identify and fix
behavioral differences between [Lightpanda
Browser](https://github.com/lightpanda-io/browser) and Chrome on real websites.

We use Docker to create a container including tools to build and debug.

Volumes are used to link the container with a local clone of Lightpanda,
instructions, Claude's files ~/.claude and ~/.claude.json and output.

Claude will not make any git commit. You are the reviewer and the committer of Claude's generated code.

Lightpanda is an open-source headless browser written in Zig, compatible with
Playwright, Puppeteer, and chromedp through the Chrome DevTools Protocol (CDP).

## How to use

### Build the docker image

```
$ make build
```

### Create the wdebug container

`BROWSER_DIR` env var is used to link the volume to an existing Lightpanda local clone.
It's recommended to create a dedicated git clone for Claude debug.

```
$ make create
```

Other shared volumes are:
* ./tools
* ./notes
* ./CLAUDE.md
* ./output
* $(HOME)/.claude.json
* $(HOME)/.claude

### Start a debugging session

```
$ make run
```

Once connected, run Claude bypassing permissions:

```
$ claude --allow-dangerously-skip-permissions --dangerously-skip-permissions
```

Now you can prompt Claude asking to debug a website by comparing results between Lightpanda and Chrome.
```
debug https://european-union.europa.eu/ compare Lightpanda output with chrome's
and try to understand why the analytics wt wt-analytics class div and
wt-unselected wt-globan--center are missing from Lightpanda output. Also first
cleanup the site/ cache for the proxy.
```

Claude has the instruction to generate files in `output` by domain and date.
It will generate a plan.md of the debugging session fix to implement.

### Delete wdebug container

```
$ make delete
```


## License

Apache 2.0 — see [LICENSE](./LICENSE).
