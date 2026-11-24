# Upstream integration plan: omagnet snapping in Omarchy core

Status (2026-11-10): **proposed, waiting on maintainers.** Nothing is built yet. Do not start the port until a
maintainer answers in [omacom/omarchy#17754](https://github.com/omacom/omarchy/discussions/17754).

## Where this stands

- 2026-11-05: we asked in #17754 whether snapping on floating workspaces belongs in a plugin or in core.
- 2026-11-08: another contributor answered with a core stack written from scratch: overview #18145, snapping #18141,
  #18142 and #18143 on top, the dock change #18140, and drag events in omacom/omarchy-hyprland-titlebars#15. About
  4,500 lines in total, and it moves `Super + Arrow`. No omagnet code is in it.
- 2026-11-10: [our reply](https://github.com/omacom/omarchy/discussions/17754#discussioncomment-19514040) suggests
  integrating omagnet's snapping module instead, with zones and the layout editor staying in the plugin, and offers a
  PR in whatever scope the maintainers choose.

## What to do for each answer

| Maintainer answer | What we do |
|-------------------|-----------|
| Integrate omagnet | Full port below, in the scope they name |
| Keyboard only first | Port steps 1, 2, 4 to 6 only; no drag, no outline (skip step 3) |
| Merge #18145 instead | No port. Check omagnet still works beside it: both bind on floating workspaces, so the shortcut and drag binds must not collide. Help review #18145 if asked |
| Keep core lean, plugins only | No port. omagnet stays the marketplace plugin; close the item in `docs/contributions.md` |
| No answer | Do nothing. Check the thread every few days; don't open an unrequested PR |

## The port: omagnet module to Omarchy layout

The source is `lua/` (about 1,400 lines). The target layout comes from the files #18141 touches, which show where
Omarchy keeps this kind of code.

| omagnet today | In Omarchy | Change needed |
|---------------|-----------|---------------|
| `lua/geometry.lua` (pure math) | `default/hypr/window-snapping-geometry.lua` | Almost none: it has no Hyprland calls |
| `lua/omagnet-snap.lua` (binds, drag, restore) | `default/hypr/window-snapping.lua`, loaded from `default/hypr/omarchy.lua` | Drop zones and the cell-stepping keys. Read the floating mode from `workspace-modes.lua` rather than Omarchy's state files (our `on_floating_workspace` reads them directly today) |
| `lua/config.lua` + `~/.config/omagnet/config.toml` | Fixed defaults in Lua; people override in their own Hyprland Lua | Drop the TOML parser. Core has no per-feature config file |
| Keybinds made in Lua | `default/hypr/bindings/` | Keep `Ctrl + Alt`, so no existing hotkey moves (Omarchy's AGENTS.md asks for that). Add each bind to `default/i18n/en/keybindings.json` so the keybindings menu shows it |
| `lua/preview.qml`, started with `qs -p` on each drag | A first-party shell plugin under `shell/plugins/` | The outline runs inside the existing shell; Lua sends it the box as a Hyprland custom event. Parse only a bounded, exact message, because any client on the socket can send one |
| `lua/test_*.lua`, `tests/live*.py` | `test/shell.d/<name>-test.sh` | Rewrite the geometry and glue checks in their shell test style. The live uinput tests stay in omagnet; they need a real session |
| README "What it does" | `manual/04-navigation.md`, `manual/07-hotkeys.md` | Short entries in the manual's voice |

## Steps

1. Work in the Omarchy clone at `~/omarchy`, never in the workspace. Branch from their current `quattro`.
2. Move geometry and behaviour over, with zones removed, and hook the module into `default/hypr/omarchy.lua`.
3. Port the drag outline to a shell plugin (skip for keyboard only).
4. Binds, keybindings menu entries, manual pages.
5. Tests in `test/shell.d/`. Run only the new test files with their stubs. `./test/all` and `./test/shell` read the live session, so never run them on the dev machine's desktop.
6. Try it in a nested Hyprland, not on the dev machine's own displays, and never with virtual monitors.
7. Open the PR with what was tried by hand and what wasn't, and link #17754.

## After the port, the plugin

If core takes the basics, omagnet becomes the extras: grid zones, the layout editor, thirds and custom positions if
core leaves them out. It must then detect the core module and not register the same binds twice. Plan that change only
once the core PR's final shape is known.

## Open questions for the maintainers

- Scope: keyboard only, or keyboard and drag?
- Thirds in core, or halves and quarters only?
- Is `Ctrl + Alt` acceptable, or do they want `Super + Arrow` like #18141?
