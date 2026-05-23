# TUI plugin development

OpenCode TUI plugins customize terminal UI slots. This repo ships local plugins
under `opencode/plugins/`; module 09 copies them to the user's OpenCode config
and enables them from `tui.json`.

## Slot system

Plugins register slot renderers through the TUI API:

```tsx
api.slots.register({
  slots: {
    home_logo() {
      return <box>{/* OpenTUI/Solid elements */}</box>
    },
  },
})
```

`home_logo` replaces the logo shown on the OpenCode home screen. The current
JustVibes logo renders one row per `<box flexDirection="row">`, with separate
`<text>` segments for each brand color.

## Path resolution

Plugin paths in `tui.json` are resolved relative to the directory containing
that `tui.json`. In the installed config, this means:

```json
{
  "plugin": [["./plugins/justvibes-logo.tsx", {}]]
}
```

points at `~/.config/opencode/plugins/justvibes-logo.tsx`.

## Visual preview

Use the isolated preview helper while developing:

```bash
scripts/tui-preview.sh
```

It creates a temporary workspace, copies `opencode/plugins/*.tsx` into
`.opencode/plugins/`, writes a temporary `.opencode/tui.json`, and launches
OpenCode there so your normal config is not changed.

## Editing the ASCII art

The logo source comments link to the TAAG generator with the Big Mono 9 font.
The URL in the plugin comment encodes `t=Vibes` as an example; to regenerate
`Just`, change the `t=` parameter. Paste the generated rows into the JSX
strings. Keep row widths aligned so the two word segments line up in the
terminal.

## Brand color split

Use the existing two-color split consistently:

- `Just`: teal `#5DBDB3`
- `Vibes`: pink `#F8B4C4`

Each row should keep the teal segment first and the pink segment second.
