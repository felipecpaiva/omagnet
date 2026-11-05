# omagnet: Hyprland capabilities study

Scope: can Magnet-style snapping (halves, thirds, quarters, maximize, next display, restore,
drag-to-edge zones with preview, gaps) be built for Omarchy floating workspaces only?

Environment: Hyprland 0.56.2 (Lua config), Omarchy 4.5 floating mode, Quickshell-based Omarchy
shell, one internal display (scale 2, 2560x1600 physical, 1280x800 logical).

Evidence labels: **tested** (ran it here, reversible, throwaway window closed afterwards),
**source** (read from Omarchy source under /usr/share/omarchy), **docs** (wiki.hypr.land only,
not exercised here). `hyprctl eval '<lua>'` prints only `ok`, so results were written to a file
from inside the Lua and read back.

## Summary

Everything except the drag-to-edge gesture is pure Lua through Hyprland dispatchers, driven by
keybinds. Drag-to-edge needs a way to learn "drag started / pointer position / drag ended", and
Hyprland 0.56 exposes no drag event and no mouse-button state to Lua. A Lua timer polling the
cursor plus a release-flag bind is the cheapest path (docs only, needs a real mouse to verify).
A native C++ plugin is only needed if titlebar drags (hyprbars) must also snap, or if the
polling approach proves flaky. The preview overlay is a Quickshell layer-shell window in a user
plugin (kind `overlay`), which Omarchy already supports for third-party plugins.

## 1. Moving, resizing, monitor geometry

### Dispatchers (tested)

`hl.dsp.window` contains: alter_zorder, bring_to_top, center, clear_tags, close, cycle_next,
drag, float, fullscreen, fullscreen_state, kill, move, pin, pseudo, resize, set_prop, signal,
swap, tag, toggle_swallow. Listed with `pairs(hl.dsp.window)` through `hyprctl eval`.

Experiments on a throwaway floating kitty window (class `omagnet-test`):

| Call | Result |
|---|---|
| `resize({x=640,y=387,relative=false,window=W})` then `move({x=0,y=26,relative=false,window=W})` | window at [0,26], size [640,387]. Exact. |
| `resize({x="50%",y="50%",...})` | error `hl.focus: unrecognized arguments`. Percent strings rejected. |
| `move({x="50%",y="0",...})` | error `hl.window.move: unrecognized arguments`. |
| `resize({x="monitor_w*0.5",...})` | rejected. Expressions only work in window rules, not in dispatchers. |
| `resize({x=100.7,y=200.2,...})` | accepted, size became 100x201 (kitty snaps to its cell grid, so apps can round). |
| `move({x=-300,y=-300,...})`, `resize({x=5000,y=5000,...})` | accepted with no clamping. The caller must clamp. |

Findings:

- Numbers only, in logical (scaled) pixels, global layout coordinates. Compute the rectangle in
  Lua and pass integers (tested).
- **Resize is center-anchored on a floating window.** Resizing 640x387 at [0,26] to 100x201
  moved the window to [270,119], the same center (tested). Always `resize` first, then `move`.
  Omarchy's own `place()` does the same order (workspace-modes.lua:112-121, source).
- `relative=true` makes move and resize deltas. Omarchy uses it for its cascade step
  (workspace-modes.lua:121, source).
- Moving a maximized window is refused: `warning: Window is fullscreen` and the window did not
  move (tested). Unset maximize first.
- `hl.dsp.window.move({monitor=...})` moves to another monitor and `move({workspace=...})` to a
  workspace (docs: dispatchers page).

### Monitor geometry (tested, source)

Fields read from `hl.get_active_monitor()`: id, name, width, height, x, y, scale (2.0),
transform (0), `reserved` ({left=0, top=26, right=0, bottom=0}), position, size, refresh_rate,
active_workspace. `hyprctl monitors -j` gives the same as `"reserved": [0,26,0,0]`.

- Logical size is `width / scale`, swapped when `transform % 2 == 1` (vertical monitors), then
  minus `reserved`. Omarchy computes exactly this in `place()` (workspace-modes.lua:101-110,
  source), so the formula is the house convention.
- The usable origin is `monitor.x + reserved.left`, `monitor.y + reserved.top`. Here that is
  (0, 26): the top bar reserves 26 px (tested).
- Maximizing a floating window (`fullscreen({mode="maximized", action="set"})`) produced
  at [0,26] size [1280,774], i.e. it respects the bar reservation, and `action="unset"` restored
  the previous [200,200] 600x401 (tested). That is a free "maximize and restore" pair.
- **The dock does not reserve space.** The layer surface list shows `omarchy-bar` plus
  `omarchy-dock`, but monitor.reserved only has the 26 px top. DockWindow.qml sets
  `exclusiveZone: 0` (DockWindow.qml:199-200, source) and can auto-hide (DockWindow.qml:44-47).
  Snap rectangles that should avoid the dock must subtract it themselves, or accept overlap.
  `omarchy dock position` printed `bottom` (tested). Reading its thickness from Lua needs
  `shell.json` (`dock` key) or a fixed config value. Decide: ignore the dock (it is an overlay,
  usually auto-hidden) or add a user setting.
- Only one monitor was available, so multi-monitor and vertical behaviour is **from source and
  docs only**. Fractional scale: only scale 2 exists here. Logical size for 1.25 or 1.5 may be
  non-integer, so use `math.floor` as `place()` does.
  Available APIs for multi-monitor: `hl.get_monitors()`, `hl.get_monitor_at({x=,y=})`,
  `hl.get_monitor_at_cursor()` (the last one tested, the others listed in the Lua utilities
  page, docs).
- Gaps: this machine sets `general.float_gaps`, `gaps_in`, `gaps_out` to 0 (user config). The
  config key `float_gaps` exists. Hyprland does not apply gaps to floating windows placed by
  dispatchers, so Magnet-style gaps are an omagnet setting subtracted from each rectangle (easy).

## 2. Detecting a drag

### What does not exist (tested, docs)

- `hl.on` events (wiki "Lua events", fetched): config.*, hyprland.*, input.keyboard.key,
  keybinds.submap, layer.*, monitor.*, screenshare.state, window.active, window.bell,
  window.class, window.close, window.destroy, window.fullscreen, window.kill, window.minimize,
  window.move_to_workspace, window.open, window.open_early, window.pin, window.title,
  window.update_rules, window.update_state, window.urgent, workspace.*. **No drag, resize,
  move or mouse-button event.** `input.keyboard.key` is keyboard only.
- socket2 (event socket) captured while moving, resizing and maximizing the test window
  (tested): only `fullscreen>>1` and `fullscreen>>0` arrived. Geometry changes emit nothing.
  Socket2 `movewindow` means a workspace change, not a drag (docs: IPC page).
- `hl.is_key_down(name)` works only for keyboard keysyms: `Super_L`, `Control_L`, `Shift_L`,
  `Escape` returned booleans, while `mouse:272`, `mouse_left`, `BTN_LEFT`, `272` returned
  `Unknown keysym` errors or nil (tested). **Mouse button state is not readable from Lua.**

### What does exist

- `hl.get_cursor_pos()` returns `{x, y}` in global logical coordinates (tested:
  `500.97, 421.31`).
- `hl.timer(fn, {type="repeat", timeout=16})` works. 20 ticks at 16 ms, each calling
  `get_cursor_pos()`, used about 2 ms of CPU in total (tested). Polling is cheap. Handlers
  must not block (wiki Binds page warning, docs).
- Existing drag binds: Omarchy binds `SUPER + mouse:272` to `hl.dsp.window.drag()` with
  `{ mouse = true }` (bindings/tiling.lua:83, source). `hyprctl binds -j` shows it as a
  Lua-dispatched bind (tested).
- Bind flags (wiki flags page, docs): `release` (fires on release), `click` (release without
  leaving `binds:drag_threshold`), `drag` (release after moving beyond the threshold). The
  wiki's own mouse example pairs `ALT + mouse:272` with `mouse = true` and again with
  `click = true`, so two binds on one button with different flags coexist. `drag_threshold`
  is currently 0 here (tested, `set: false`, so default).
- A Quickshell `GlobalShortcut` receives press and release events. The shell registers many
  under appid `omarchy` (shell.qml:1646-1655, source; listed by `hyprctl globalshortcuts`,
  tested), reached through `hl.dsp.global("omarchy:...")`. Binding a mouse key to a global
  shortcut would hand press and release to the shell. Untested.

### Recommended mechanism

1. Keep Omarchy's `SUPER + mouse:272` drag bind untouched (so normal drag still works).
2. Add one extra Lua bind on the same key with `{ drag = true }` (or `release = true`) that
   runs on release and applies the snap decided by the last cursor position. This is the
   "drag ended" signal. **Docs only, needs a real mouse to verify**: I had no way to inject
   pointer input here (no ydotool; `wtype` is keyboard only).
3. "Drag in progress and where is the pointer": start a `repeat` timer on `window.active` or a
   press-side bind, poll `hl.get_cursor_pos()` at 16 to 33 ms, hit-test against the edge zones
   of `hl.get_monitor_at_cursor()`, and tell the overlay (next section). Stop the timer on the
   release bind, with a hard cap (about 30 s) as a safety net.
4. Fallback if Lua-only proves flaky: a Quickshell `GlobalShortcut` bound to the mouse key gives
   press and release as real signals.

Native plugin needed? Not for the SUPER+drag path. **Yes** for dragging by a hyprbars titlebar
(the plugin starts that drag internally, no bind or event is involved) and for a guaranteed
per-motion hook. This user hides bars with `hyprbars:no_bar` (user hyprland.lua:33, read), so
the titlebar case can be deferred.

## 3. Preview overlay

- Quickshell layer-shell is the right tool. OverlayWindow.qml is a `PanelWindow` anchored to all
  four edges, transparent, `exclusionMode: Ignore`, layer `WlrLayer.Overlay`, keyboard focus
  `Exclusive` by default (OverlayWindow.qml:10-17, 75-81, source). It also waits for the
  monitor scale before revealing, to avoid a blurry first frame (OverlayWindow.qml:27-42).
  For a preview, a **new** window is better than reusing OverlayWindow: set
  `WlrLayershell.keyboardFocus: WlrKeyboardFocus.None` (exclusive focus would steal keys and
  break the drag), use `WlrLayer.Top`, and a click-through input region (`mask: Region {}`).
  Source can be copied, not edited (read only).
- User plugins can add overlays and services: `~/.config/omarchy/plugins/<id>/manifest.json`
  with `"kinds": ["overlay", "service"]` and `entryPoints` is the contract the installed
  gaming-console plugin uses (its manifest, read). The first-party README confirms user plugins
  live in that directory and share the manifest contract (plugins/README.md, source).
  `keepLoaded: true` keeps the surface alive between uses.
- The shell already runs `Quickshell.Hyprland`, so a plugin can read monitor and window state;
  it can receive commands from Lua through `hyprctl`/exec_cmd to an `omarchy-shell` IPC target
  (shell.qml IPC socket, source) or via a `GlobalShortcut`.
- Alternatives: a Hyprland plugin (heavy, native, breaks on every upgrade) or no preview (snap
  on release only, trivial). A cheap middle path: draw the preview as a small floating
  borderless Hyprland window. It is a real window, steals focus risk, and animates, so not
  recommended.
- Preview cost: one transparent rectangle with a border, repositioned on zone change. Easy.

## 4. Restricting to floating workspaces

Source of truth: `workspace-modes.lua`.

- Every window on a floating workspace carries the tag `omarchy-floating-workspace`
  (workspace-modes.lua:13-15, 22, 47-49, source). The tag is set on window open, on move to a
  workspace, and on fullscreen exit via `arrange()` (lines 465-540), and removed when the mode
  ends or the window is carried to a tiled workspace (`tile_for_mode`, lines 150-158).
  `hl.get_windows({tag="omarchy-floating-workspace"})` returned the window after I added the
  tag by dispatch and none after removal (tested; I removed the tag again afterwards).
- Rule-applied tags show with a trailing `*` in `window.tags` (e.g. `terminal*` in
  `hyprctl activewindow`, tested). The Omarchy tag is applied with a dispatcher, so it appears
  without the star.
- The mode logic (`floating_workspace(id)`, `modes`) is local to that module, not exported, so
  omagnet cannot call it. The tag is the public interface. The CLI form
  `omarchy hyprland workspace layout current` prints `dwindle` on the current (tiled)
  workspace here (tested).
- Guard on every action, statelessly: `window.tags` contains `omarchy-floating-workspace` and
  `window.floating` and `window.fullscreen == 0` (after unmaximizing). Nothing is cached, so a
  layout toggle just changes what the next check sees.
- Timing hazards (source): after `window.move_to_workspace` Omarchy waits 1 s before
  re-arranging because a move is still being committed (workspace-modes.lua:524-529), and does
  the same on `window.fullscreen` (lines 533-537). omagnet should not snap within about 1 s of
  those events, and must not hold a stale decision across them. Right after a toggle, windows
  are floated and centred by `place()` with a 24 px cascade (lines 95-122), so remembered
  "original" geometry from before a toggle is not reliable.
- Pinned and "popped out" windows (`SUPER + O`) float on their own and are not claimed. They
  still get the workspace tag when on a floating workspace, so they are snappable, which is
  usually what a user wants.
- A tiled workspace window never gets the tag, so snap binds on tiled workspaces can fall
  through to Omarchy's own binding via `return { ok = false }` with the `auto_consuming` flag
  (wiki Binds page, docs; not tested).

## 5. Restore to previous size

Options:

| Store | Survives reload | Survives window death | Notes |
|---|---|---|---|
| Lua table keyed by window address | no, Lua state is torn down on `config.unload` (docs) | n/a | Simple, loses state on any reload, including monitor hotplug (source comment, workspace-modes.lua:9-11) |
| State file (JSON) | yes | needs pruning | Needs IO in Lua, `io.open` works (used above) but must stay non-blocking |
| **Window tag** | yes | dies with window, correct | Omarchy itself relies on this property (workspace-modes.lua:5-11) |

Recommended: encode the pre-snap rectangle in a window tag. Tested: tag
`omagnet-orig=100,100,500,300` was added with `hl.dsp.window.tag`, read back from `window.tags`
unchanged, and removed with `clear_tags` (tested; tags are free-form strings). Parse on restore,
re-apply `resize` then `move`, clear the tag. Save only when the window is not already snapped
(so repeated snaps keep the first geometry). Caveat: `clear_tags` clears all tags, so remove
just the one tag with `"-omagnet-orig=..."` in real code (the `-` form is what Omarchy uses,
workspace-modes.lua:43-49).

Maximize and restore can instead use Hyprland's own maximized state, which remembers geometry
(tested above), but only for that one feature.

## 6. Keybinding conflicts

Source: `omarchy menu keybindings --print` and `hyprctl binds -j` (tested). Modmask: SHIFT=1,
CTRL=4, ALT=8, SUPER=64.

Taken arrow combinations (all with an arrow key):

| Modifiers | Default action |
|---|---|
| SUPER | focus left/right/up/down |
| SUPER SHIFT | swap window |
| SUPER ALT | move window to group |
| SUPER CTRL | move grouped window focus (left, right only) |
| SUPER SHIFT CTRL | move window to other monitor |
| SUPER SHIFT ALT | move workspace to other monitor |

Also taken: SUPER+F fullscreen, SUPER ALT+F full width, SUPER CTRL+F tiled full screen,
SUPER CTRL ALT+F full screen desktop, SUPER+T float toggle, SUPER+J split, SUPER+O pop out,
SUPER+minus/equal (+SHIFT/ALT/CTRL variants) resize, SUPER+mouse:272/273 move/resize,
SUPER+0..9 (+SHIFT, +SHIFT ALT) workspaces, SUPER+TAB workspace cycling, SUPER+K, SUPER+W/Q.

Free in the default set and this machine's live binds (checked for arrows, return, letters):
- **CTRL ALT + arrows** (halves), no match found; CTRL ALT only has DELETE (close all windows).
- **SUPER CTRL ALT + arrows**: only F, C, T, D, E are used under that modifier set.
- Letter and digit keys under SUPER CTRL ALT (except F, C, T, D, E) and CTRL ALT.

Suggested default scheme (Rectangle and Magnet style, avoids the above):

| Keys | Action |
|---|---|
| CTRL ALT + Left / Right / Up / Down | left / right / top / bottom half |
| CTRL ALT + U / I / J / K | quarters (top-left, top-right, bottom-left, bottom-right) |
| CTRL ALT + D / F / G | first / center / last third |
| CTRL ALT + Return | maximize (toggle) |
| CTRL ALT + Backspace | restore |
| CTRL ALT SUPER + Left / Right | move to previous / next display |

Verify at install with `hyprctl binds -j`, since `omarchy menu keybindings` only lists Omarchy's
own and the user's file adds more. Bindings should be registered with `o.bind(...)`-style
descriptions so they show in the keybindings menu (bindings/tiling.lua uses `o.bind(keys,
description, dispatcher)`, source). Make the modifier configurable.

## 7. Risks

- **Lua API churn.** The Lua config API is new in 0.56 and the wiki page was last updated
  2026-11-03. This machine's `hl.get_window` returns userdata objects (`HL.Window(0x...)`)
  accessed by field, `hl.dsp.*` dispatchers must be wrapped in `hl.dispatch`, and `hl.on`
  event names are strings. Any of these could be renamed in a minor release. Mitigation: one
  adapter module (`geometry.lua`) holding every `hl.*` call, pcall wrappers, and a startup
  self-check that the functions exist (`hl.dsp.window.move`, `resize`, `get_cursor_pos`).
  Omarchy's own `workspace-modes.lua` is itself a user of the same API and is updated with
  Omarchy, so reading it after each Omarchy upgrade shows where the API moved.
- **Fullscreen and maximized.** Moves on a maximized window are refused (tested). Snap must
  `fullscreen({action="unset"})` first and, for true fullscreen (mode 2), skip the window.
  Omarchy un-maximizes a maximized window when another opens on a floating workspace
  (`unmaximize_others`, workspace-modes.lua:322-333, source), which would silently change
  state under a stored "restore" rectangle.
- **Min and max size hints.** Apps may refuse a half-width request. The test window rounded to
  its cell grid (100.7 to 100, 200.2 to 201, tested). Expect terminals to snap by cell size
  and some apps to enforce a minimum. Mitigation: after `resize`, read back `window.size`, and
  `move` using the size actually granted (top and left edges stay aligned, right and bottom
  edges may leave a small gap). Hyprland window rules `min_size`/`max_size` exist (docs) but
  are not needed.
- **Resize anchoring.** Resize is center-anchored (tested): always resize before move.
- **Unclamped values.** Hyprland accepted a -300 position and a 5000x5000 size (tested). Clamp
  to the usable rectangle.
- **Dock.** No reservation (source), so tiles can sit under a visible dock.
- **Timers and blocking.** Binds and timers run on the compositor event loop. A slow handler
  freezes input (wiki warning, docs). Keep the poll tiny, never call `io.popen` from the poll.
- **Reload.** Lua state is torn down on reload. Store everything that matters in tags, and
  rebuild bind and timer state on `config.reloaded` or simply at config load.
- **Floating-workspace tag timing.** Windows moved across workspaces lose or gain the tag
  after about 1 s (source), so a snap issued immediately after a move can hit a window that is
  about to be tiled again.
- **Drag path unverified.** The release-flag bind and the poll are docs and source only. This
  is the single biggest unknown and should be the first thing a prototype proves with a real
  mouse.

## Feasibility table

| Magnet feature | Difficulty | Mechanism | Evidence |
|---|---|---|---|
| Left/right/top/bottom halves | easy | Lua keybind, compute rect from monitor minus reserved, `resize` then `move` | tested |
| Thirds, two-thirds | easy | same, different fractions | tested |
| Quarters | easy | same | tested |
| Maximize / center | easy | `fullscreen maximized` toggle (respects reserved area) or explicit rect; `center` exists | tested |
| Restore | easy | pre-snap geometry in a window tag | tested |
| Gaps | easy | omagnet setting subtracted from each rect | source (float_gaps is 0 here) |
| Respect top bar | easy | `monitor.reserved` | tested |
| Respect dock | medium | dock does not reserve; subtract from `shell.json` dock settings or ignore | source |
| Move to next display | easy to medium | `move({monitor=...})` then re-snap with that monitor's rect; needs two monitors to verify | docs only |
| Vertical or fractional-scale monitors | easy | `width/scale`, swap on `transform % 2 == 1`, floor | source (Omarchy `place()`), scale 2 only tested |
| Floating-only guard | easy | tag `omarchy-floating-workspace`, checked per action | tested |
| Drag-to-edge snap on release (SUPER + drag) | medium | extra bind with `drag`/`release` flag plus cursor read | docs only, unverified |
| Live zone detection during drag | medium | 16 ms `hl.timer` polling `get_cursor_pos` | tested (timer, cursor), drag itself unverified |
| Preview overlay | medium | Quickshell user plugin, layer-shell, no keyboard focus, click-through | source |
| Snap by dragging a hyprbars titlebar | hard, needs native plugin | drag starts inside the plugin, no event or bind | docs only |
| Zone/edge hover with no modifier key | hard, needs native plugin or global input capture | Hyprland exposes no pointer-motion or button events to Lua | tested (absence) |

## Recommended architecture

1. **Lua module in the user Hyprland config** (about 150 lines): rect math, snap binds, tag-based
   guard and restore, adapter around every `hl.*` call.
2. **Quickshell plugin** (`overlay` + `service`) in `~/.config/omarchy/plugins/`: draws the
   preview rectangle, driven by exec or IPC from the Lua poll.
3. **Drag**: SUPER+drag only, using a release-flag bind plus a polling timer. Prove this first.
4. Defer titlebar-drag snapping and anything needing a native plugin.
