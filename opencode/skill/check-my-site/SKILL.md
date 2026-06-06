---
name: check-my-site
description: >-
  Inspect a website or local web app in Chrome and report plain-language loading
  problems. Use when the user asks to "check my site", "open the page", "look
  for browser errors", "inspect my app", "why is this page broken", or wants a
  browser-based check of a URL.
---

# Check My Site

Use Chrome to look at a page the way a visitor would and report what worked,
what failed, and what was not checked.

This skill can load pages in a real browser. Loading a page runs whatever that
page runs on open, just like visiting it yourself. The dedicated Chrome profile
at `/tmp/chrome-devtools-mcp-auth` keeps its logins and cookies across runs, so a
future check may still be signed in to sites used before.

## Hard browser ownership rule

Before any `chrome-devtools_*` MCP tool call, the Chrome helper `--check` must
pass. If `--check` does not pass, do not call any `chrome-devtools_*` tool.

Repeat: the helper `--check` must pass before every first browser MCP call in a
workflow and before retrying after any connection failure. If the helper refuses,
invoke no Chrome DevTools MCP tool and explain the blocker plainly.

Use the deployed workspace helper with a subcommand, for example:

```text
<workspace>/scripts/agent/chrome_mcp.sh --check
<workspace>/scripts/agent/chrome_mcp.sh --url <URL>
```

The helper owns a dedicated Chrome instance on `127.0.0.1:9222` with profile
`/tmp/chrome-devtools-mcp-auth`. It refuses to proceed if that port is not owned
by the matching helper-launched Chrome profile.

## What to check by default

For each requested page:

1. Confirm the page loads or say it was unreachable.
2. Check browser console errors.
3. Check failed network requests.
4. Check broken images.
5. Check obvious broken links on the page.

Classify normal noise separately so the user is not scared by harmless details:

- Blocked trackers or ad scripts.
- Missing source maps.
- Flaky websocket reconnect messages.
- Browser extension messages from the isolated profile.

Lighthouse can be run if the user asks, but it is rarely needed for local apps;
mention it only as an optional deeper check.

## Login and private pages

If the page needs a login, launch the helper first, then tell Gandalf to ask the
user to sign in inside the dedicated Chrome window and say when ready. Do not ask
for passwords, one-time codes, or private tokens in chat.

## Coverage contract

Every report must include:

- Pages reached.
- Pages unreachable.
- What was looked at: console, network, images, links, or other checks.
- What was not looked at.
- Whether any failures looked expected or harmless.

A clean result applies only to the pages actually reached and checked. Never say
the whole site is fine if only one page was inspected.

## When not to use

- Reading static files in the project.
- API-only checks that do not need a real browser.
- Pages the user has not authorized us to open.
- Any browser workflow when the helper `--check` refuses or cannot prove it owns
  the debugging Chrome instance.
