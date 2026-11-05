# Architecture

omagnet gives Omarchy's floating workspaces what Magnet gives a Mac: snap a window to a half, third, quarter or the
whole screen, by keyboard or by dragging to a screen edge. This page says how it is built, which other ways were
considered, and why these were chosen. Evidence for each choice is in [research/](research/) and
[gotchas.md](gotchas.md); what is done and what is left is in [ROADMAP.md](ROADMAP.md).

## Rules the design must keep

1. **Floating workspaces only.** Windows on tiled or scrolling workspaces are never touched; a key pressed in such a
   window goes on to the app.
2. **Nothing on the Omarchy bar by default.** The bar icon is an option in the settings app.
3. **No native code.** Pure Lua on Hyprland's own Lua API, so a Hyprland update cannot break a compiled module.
4. **Own settings app**, built the way Omarchy's own plugins are built, following the Omarchy theme.
5. **Public repo:** nothing private (`tests/scrub.sh` checks before every push).

## The parts

```
                    ~/.config/omagnet/config.toml            (one flat file, the single source of settings)
                      ^ writes                 | reads
                      |                        v
  Settings app  --------------------->  Lua module in Hyprland          <--- keyboard shortcuts, SUPER + drag
  (Quickshell plugin)   hyprctl eval    lua/omagnet-snap.lua           (Hyprland binds)
   panel + service      reload_config() geometry.lua, config.lua                    |
   + optional bar icon                      |                                       v
        ^                                   | writes 3 small files in           moves and resizes the window
        | opens                             v $XDG_RUNTIME_DIR                  (resize first, then move)
   bar icon (off by default)          Overlay process: qs -p lua/preview.qml
                                      draws the outline and the zone strips (starts and stops with a drag)
```

| Part | Where | Job | Needs Hyprland to test? |
|------|-------|-----|-------------------------|
| Geometry | `lua/geometry.lua` | Positions as fractions, rounding so neighbours tile exactly, margins, drag zones, slide to two thirds, portrait screens, zone strips, moving between monitors. No `hl` calls. | No |
| Config | `lua/config.lua` | Reads the flat TOML subset, defaults, a bad value falls back, custom positions, ignore list. No `hl` calls. | No |
| Glue | `lua/omagnet-snap.lua` | Binds, the floating-workspace guard, restore, drag handling, the timers, the overlay process. | Mostly with a fake `hl`; the rest live |
| Overlay | `lua/preview.qml` | A click-through layer window that draws where the window will land. | Live (screenshot) |
| Settings app | the repo root | A Quickshell plugin: panel, service (launcher entry), optional bar widget, a JavaScript reader and writer of the same config file. | Unit tests in Node; the rest in the real shell |
| Tests | `tests/` | Runner, live tests with a virtual keyboard, mouse and monitor, a scrub of private details. | See [testing](#testing) |

The two sides never share code, only the config file and the agreed meaning of each key. `ConfigIO.js` and
`lua/config.lua` are checked against each other on the same inputs.

## How the main behaviours work

- **Which windows are ours.** Omarchy tags every window on a floating workspace with `omarchy-floating-workspace`.
  Every action checks that tag. A maximized window loses the tag, so for those the workspace's saved mode (the same
  file Omarchy's own `layout current` reads) decides.
- **Keyboard.** One bind per command, with the `auto_consuming` flag: the handler returns `{ ok = false }` for a window
  that is not ours, so the key reaches the app.
- **Drag.** Hyprland sends no event for a drag, so the glue adds three non-consuming binds next to Omarchy's
  `SUPER + mouse:272` ("Move window"): one on press, one on release after a drag, one on a plain click. From the press
  it polls the pointer every 30 ms (chained one-shot timers) and keeps the target; the release applies it. The shared
  key is never unbound.
- **Outline.** A small Quickshell program started on demand (it costs about 230 MB, so it exists only during a drag
  near an edge, or from the press if the zone highlight is on). It reads three small files the Lua side writes; the outline takes the colour of the theme's active window border, read live from Hyprland.
- **Restore.** The size and place from before the first snap live in a window tag (`omagnet-orig=x,y,w,h`), so they die
  with the window and survive a config reload. Dragging a snapped window away ends Hyprland's own drag and moves the
  window from a fast timer, because Hyprland computes a drag from the window's start position.
- **Exact sizes.** A resize from an odd position can come out one pixel off; the size is checked after 40 ms and set
  again at most twice.
- **Displays.** Next and previous display keep the window's relative place and size, and only move into a monitor
  whose workspace is floating.
- **Settings.** The app writes the file and runs `hyprctl eval "_G.omagnet.reload_config()"`. Spacing, zones, switches,
  ignore list, appearance and custom rectangles apply to the next snap; a changed shortcut needs a Hyprland reload and
  the app says so.

## Approaches considered

| Question | Chosen | Other options and why not |
|----------|--------|---------------------------|
| Build, or use an existing plugin? | Build, as a separate project | Two community plugins (Gridnet, Zones) do edge snapping and add a bar icon and a native module that must be rebuilt after each Hyprland update. omagnet is pure Lua, keyboard first, and keeps the bar clean. Ideas can still go upstream. See [research/omarchy-upstream-community.md](research/omarchy-upstream-community.md). |
| Pure Lua or a native Hyprland plugin? | Pure Lua | Native gives per-motion hooks and title-bar drags, but breaks on Hyprland updates. The price is that a drag started from an app's own title bar is not seen. |
| How to know a drag ended? | A bind flag (`drag`, `click`) beside Omarchy's drag bind, plus a timer for the pointer | A Quickshell global shortcut (unproven), a native plugin (rule 3). |
| Settings app: Qt app or Quickshell plugin? | Quickshell plugin (panel, service, widget) | A Qt app needs packaging and cannot be listed in the plugin marketplace. A TUI would not follow the theme. See [research/omarchy-app-stack.md](research/omarchy-app-stack.md). |
| Bar icon: how to stay off the bar? | One plugin whose widget hides itself (no size, no gap) | Two plugins (one for the icon) is cleaner in `shell.json` but needs a second folder. Checked on the real bar: identical with the icon off. |
| Where the old window size lives | A window tag | A Lua table (lost on reload), a file (needs cleaning). |
| Where the outline is drawn | A separate short-lived `qs` process | A resident overlay (about 230 MB for nothing), a Hyprland plugin (rule 3), a floating window (steals focus). |
| Config format | Flat TOML subset | JSON (awkward to edit), full TOML (heavy for both sides). One 15 line parser per side, with cross-checked tests. |
| Drag-away restore | End Hyprland's drag, follow from a timer | Restart the drag from Lua (does not work: a second dispatch does nothing). |

## Folder layout

```
manifest.json, SettingsPanel.qml, SettingsStore.qml, Service.qml, BarWidget.qml, ConfigIO.js, Paths.js, omagnet.desktop
                     the settings plugin; the repo root is the plugin, because `omarchy plugin add <git-url>` clones the
                     repo into the plugins folder and the marketplace wants manifest.json at the root
lua/                 the snapping module: geometry.lua, config.lua, omagnet-snap.lua, preview.qml, and the unit tests
tests/               run-all.sh, live.py, live_displays.py, live_overlay.py, uinput_kbd.py, scrub.sh, config_io.test.mjs
docs/                ROADMAP.md (every function and its gates), architecture.md (this page), config.md (settings),
                     gotchas.md (traps found), batch-log.md (history), validation-checklist.md (hand checks),
                     magnet-reference/ (what Magnet does), research/ (what already exists, what Hyprland can do)
```

Before 2026-11-05 evening the Lua module lived in `prototype/` and the plugin in `plugin/`; [batch-log.md](batch-log.md)
uses those names for the work done then.

## Testing

1. **Pure** (`lua lua/test_*.lua`, Lua 5.5 like Hyprland): geometry and config, no Hyprland. Fast and exact.
2. **Glue with a fake `hl`** (`lua/test_glue.lua`): the module loads, every setting and bind exists, and the safety
   rules hold (nothing for a window that is not ours, no move into a tiled workspace, a refused size is not retried
   forever). Checked to fail when a setting is removed.
3. **Live** (`python3 tests/live.py`): a throwaway window, real key and mouse events through `/dev/uinput`, exact
   rectangles, restore, maximize, drag zones, drag-away, two windows, the config re-read. `live_displays.py` adds a
   temporary virtual monitor. `live_overlay.py` checks the overlay settings with a screenshot.
4. **The settings app** is loaded into the real shell and looked at; its JavaScript is tested with Node.
5. **Scrub** (`tests/scrub.sh`): no private details in a public repo.

The live tests drive your real keyboard and mouse and refuse to send a key unless the test window has focus.

## Known limits and risks

- A drag started from an app's own title bar (Chrome, VS Code) is not seen: no bind fires. Not fixable without a native
  plugin. (Roadmap D11.)
- Hyprland's Lua API is new and may change; the glue is small and covered by tests so a change shows quickly.
- The maximized-window path and the next-display check read Omarchy's saved workspace modes
  (`~/.local/state/omarchy/workspace-layouts/`), the same files its own command reads. A change there would need a
  matching change here.
- Omarchy's theme picker opens whenever its shell reloads and takes keyboard focus; unrelated to omagnet but it
  disturbs tests ([gotchas.md](gotchas.md)).
- Tested on one laptop screen at scale 2 and on a virtual monitor at scales 2, 1.5 and 1.25 and rotated. Real second and
  vertical monitors are untested.

## Packaging

One repo. `omarchy plugin add <git-url>` clones the repo into `~/.config/omarchy/plugins/<id>/`, so the Lua module
(`lua/`) arrives together with the settings plugin, and other Omarchy plugins also keep `docs`, `tests` and similar folders
next to their manifest. The marketplace needs one public repo with `manifest.json`, a README with install and removal, and a
license at its root, which is what this repo has.

What an install does not do is load the Lua module: a plugin cannot edit `~/.config/hypr/hyprland.lua` by itself. For now the
README gives the user one guarded line to add. Option for later: a button in the settings app that adds that line after
asking, with a backup and a way back. It is not built, because it would write to the user's Hyprland config.
