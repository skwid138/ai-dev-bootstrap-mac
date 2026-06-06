---
description: >-
  Open a site or local web app in Chrome and check for page-load problems,
  console errors, failed requests, broken images, and broken links. Argument is
  the URL or page to inspect.
---
The user invoked `/check-my-site` with this target:

`{{$arguments}}`

Use the `check-my-site` skill. The Chrome helper `--check` must pass before any
`chrome-devtools_*` MCP tool call. If the helper cannot prove it owns the Chrome
debugging profile, do not call Chrome DevTools MCP; explain the blocker plainly.
