# Reference code review: omarchy-smart-windows and Mouse-First

Date: 2026-11-05. Method: shallow clones, files read only, nothing run or installed. Every claim below is "read from code" unless marked otherwise. Line numbers refer to the default branch at clone time.

Repos:
- OSW = hugorolimf/omarchy-smart-windows (pure Lua, `windowing/*.lua`).
- MF = DjaboDev/Mouse-First (Lua module `src/lua/mousefirst.lua` + QML shell + pure JS geometry `src/js/geometry.js`).
- hyprfloat = yz778/hyprfloat (skimmed `src/commands/snap.lua` only).

## (a) Drag start/end and pointer position

OSW (read from code):
- No timers during the drag. Two binds per button, `mouse:272` and `mouse:273`, one press and one `release = true`, all with `non_consuming = true, ignore_mods = true` (`snap.lua:266-269`).
- Press handler records the window under the cursor and its frame in a `pressed` table (`snap.lua:185-199`). Release handler compares `w.at`/`w.size` against that record to decide moved, resized or plain click (`snap.lua:238-264`).
- The pointer is read once, at release: `hl.get_cursor_pos()` and `hl.get_monitor_at_cursor()` inside `snap()` (`snap.lua:83-84`).
- It finds the dragged window itself with `window_at_cursor()` (`snap.lua:130-146`), because focus only follows clicks in their setup. Active window first, else the lowest `focus_history_id` under the pointer.
- Super state is read with `hl.is_key_down("Super_L")` (`snap.lua:186`).

MF (read from code):
- Same two non-consuming binds on `mouse:272` (press and release), registered once per Lua state (`mousefirst.lua:106-119`), plus `transparent = true`.
- A `hl.timer(M.tick, { timeout = 16, type = "repeat" })` (`mousefirst.lua:281`) runs `watch_native_move()` (`mousefirst.lua:129-160`). Drag start is inferred: button is down, the active floating window moved at least 2 px, and its size is unchanged (or it was fullscreen).
- On detection it calls `hl.dispatch(hl.dsp.window.drag())` to end Hyprland's own drag, then continues the move itself and emits cursor positions as custom IPC events only when x or y changed (`mousefirst.lua:135-141,152-156`). The event bridge is `hl.dsp.event("mousefirst>>...")` (`mousefirst.lua:35`).
- Press and release also emit the cursor position (`mousefirst.lua:94-95,102-103`).

Difference from our prototype: both use the same bind pair. OSW needs no polling because it only snaps on release. MF polls at 16 ms but only to hand the drag to a shell overlay for a live preview.

## (b) Target rectangles, usable area, gaps, scale, multi-monitor

OSW (read from code):
- Zones are cursor-based, not window-edge based: cursor within `ZONE` px (36) of a monitor border, `SHARED` (4) on a border shared with another monitor, and `CORNER` (0.22) as the share of a side that counts as a corner (`snap.lua:62-79,89-102`; defaults `settings.lua:3-6`).
- Resulting layouts: side + row top/bottom = quarter, side only = full-height half, top only = maximize (`snap.lua:95-114`). No thirds, no bottom-only or top-half zone.
- Quarter height is `(ah - GAP*3) / 2`, so gaps are GAP at the screen border and GAP between tiles (`snap.lua:93,106-107`).
- Side width is adaptive: half, or whatever the windows already snapped on the other side leave free, clamped to 20-80% of the width (`side_span`, `snap.lua:38-57`).
- Usable area is `monitor_size` (width/height divided by `m.scale`, swapped when `transform` is odd) minus `m.reserved` and extra covers read from files published by the author's dock and notch plugins (`core.lua:249-264` in numbering of the file, i.e. `W.monitor_size` and `W.work_area`).
- Multi-monitor: `zones(m)` thins the snap zone on any border that touches another monitor, so a drag across does not snap (`snap.lua:62-79`). `monitor_of(frame)` picks the monitor under a frame centre (`snap.lua:203-211`). `placement.lua` rescales remembered geometry between screens by work-area ratio (`placement.lua:343-356`, file-local lines 75-87).
- Window frames include a title bar height from a global `TITLEBAR_HEIGHT` (`core.lua` function `W.bar`/`W.frame`). Not relevant to us unless we draw bars.
- Move and resize are two dispatches, resize first then move, with `math.floor` (`core.lua` `W.place_raw`).

MF (read from code, pure functions in `geometry.js`):
- `usableArea(monitor, reserved, gap)` subtracts reserved left/top/right/bottom and insets by `gap` (`geometry.js:61-69`).
- `zoneRect(zone, area, gap)` returns nine zones: maximize, four halves, four quarters (`geometry.js:72-92`). Halves are `round((w - gap)/2)`, the right side takes the remainder so the tiles always meet the far edge exactly (`geometry.js:74-79`).
- `snapZone(raw, area, monitor, cursor)` arms on either the window touching a usable edge (`EDGE_TOUCH` 6) or the cursor within `CURSOR_EDGE` 16 px of the screen edge, corners via `CURSOR_CORNER` 32 px squares (`geometry.js:132-169`). It resolves the "window as wide as the area touches both sides" case by cursor half (`geometry.js:142-153`).
- `isBreaking` disables snapping and clamping once the window is pushed 45 px past the usable edge or the cursor leaves the monitor (`geometry.js:113-119`).
- Monitor lookup falls back to the nearest monitor when the cursor sits between outputs (`geometry.js:45-57`).
- The Lua side reports logical monitor size using the same scale and transform logic (`mousefirst.lua:59-72`).

hyprfloat (read from code): fractions are `x0 x1 y0 y1` of the "effective area", each position `floor(area.x + area.w * frac)` and size `floor(area.w * (x1 - x0))` (`snap.lua:24-27`). Issues the four dispatches as one hyprctl batch including `fullscreenstate 0` (a maximized or fullscreen window is un-fullscreened before moving) and `alterzorder top` (`snap.lua:29-34`). Silently ignores tiled windows (`snap.lua:18-21`).

## (c) Pre-snap size storage and drag-away restore

OSW (read from code):
- Two tables keyed by window address: `restore[addr] = {w, h}` (size only, used for drag-away) and `saved[addr] = frame` (full frame, used for un-maximize) (`core.lua` `W.remember`). First snap wins: both are only set if empty, so a chain of snaps keeps the original size.
- Drag-away: on release, if the window is outside any zone and has a `restore` entry, it is resized to the old size and positioned so the grab point keeps its relative fraction under the cursor: `fx = clamp((c.x - w.at.x) / w.size.x, 0, 1)` then `x = c.x - fx * r.w` (`snap.lua:115-124`). This happens at release, not mid-drag.
- A resize clears both records (`snap.lua:254-257`). Window close clears them (`placement.lua:411-416`).
- Un-maximize with no record falls back to 70% of the work area, centred (`snap.lua:23-24`).
- Everything is in memory, lost on config reload, except per-class geometry and minimized frames which are persisted to `~/.local/state/omarchy/` as tab-separated text (`placement.lua:285-308`).

MF (read from code, QML):
- Snapped or maximized window is restored the moment the drag starts, with the grabbed point kept under the cursor (CHANGELOG 0.2.0, "Fixed"; `DragController.qml:11-12`). Math in `restoreSize` (remembered size, clamped to area, default 60% x 65% of usable area, `geometry.js:171-183`) and `restoreUnderCursor` (horizontal grab ratio clamped to 0.1-0.9, vertical offset kept in pixels from the top, result clamped to the area, `geometry.js:185-195`).
- Its reason for taking over the drag: Hyprland positions a native drag at "start position + pointer delta", so a window restored mid-drag drifts from the cursor (`mousefirst.lua:121-128`). Relevant to us: restore on release (OSW) avoids this problem, restore mid-drag needs the drag hand-over trick.

## (d) Limiting to floating workspaces or windows

OSW (read from code): it does not limit itself. It floats everything (`o.window(".*", { float = true })`, `windowing.lua:385-389` in file numbering) and also force-floats already-open tiled windows at load and on `config.reloaded` (`windowing.lua` `float_existing`). Within that, every action filters by `w.floating and w.fullscreen == 0` (`snap.lua:18,192,247`), and `windows_on` additionally excludes unmapped, hidden, pinned (`core.lua` `W.windows_on`). Dialogs tagged `floating-window` are skipped for placement (`core.lua` `W.is_dialog`).

MF (read from code): `watch_native_move` returns unless the active window is floating (`mousefirst.lua:132`). Optional window rule floats every window (`mousefirst.lua:185-194`). No workspace-level restriction.

For omagnet: neither project has a "floating workspace only" concept. The floating-window test is `w.floating`, and the workspace test would be ours to write (compare `w.workspace.id`/name to our set).

## (e) Config format and where settings live

OSW (read from code and README): a Lua table returned from `windowing/settings.lua` (`settings.lua:1-26` in file numbering), edited by hand, applied with `hyprctl reload`. Installed under `~/.config/omarchy-smart-windows/` with a one-line loader dropped in Omarchy's toggles folder (`loader/hugorolimf-windows.lua:5-7`). The loader checks the file exists before `dofile`, so uninstalling cannot break the config (comment at `loader/...:2-3`). Key bindings are strings like `"SUPER + Q"`, `false` disables (`settings.lua`, KEYS block). State files go in `~/.local/state/omarchy/`.

MF (read from code and README): JSON at `~/.config/omarchy/mouse-first.json`, written from a QML settings panel, hot-reloaded; options listed in README lines 94-114. Plugin installed via `omarchy plugin add`. Not a model for us (needs Quickshell).

## (f) Keyboard shortcuts and cycling

OSW (read from code): binds are registered with `hl.unbind(KEYS.x)` immediately followed by `hl.bind(KEYS.x, fn, { description = ... })` (`minimize.lua:116-130`, also `picker.lua`, `swap.lua`). Shortcuts: minimize, quit, arrange, maximize (off by default), Super+Shift+arrows swap. A layout picker accepts digit keys 1-9, Enter, 0 for undo (bind description at `picker.lua`, line ~164 in grep output). No cycling of snap positions.

MF (read from code): four optional shortcuts `SUPER+CTRL+SHIFT+arrow`, each calls `emit("shortcut", action)` and the QML side decides (`mousefirst.lua:198-220`). Left/right arrows snap to half, up = maximize/restore, down = restore or minimize. Cycling (README) means cycling an app's windows from a bar icon, not cycling snap sizes. No Magnet-style repeated-press cycling through half, third, two-thirds in either project.

Lesson for omagnet (inference, not read from code): Magnet-style cycling would need our own per-window state (last zone, last time), neither project has it.

## (g) Tests

OSW: none. No test directory, no CI, no workflows in the tree (read from file listing). It offers `windowing_snap_test(address)` and `windowing_bury_test(ws)` as hand-run globals via `hyprctl eval` (`snap.lua:153,176,232-233`), manual only.

MF: `tests/geometry.test.mjs` (154 lines) runs `geometry.js` under `node:test` via `vm.runInNewContext` after stripping the QML `.pragma library` line (`geometry.test.mjs:7-13`). Covered: usable area with reserved space and gap, zone rects tile without overlap, offset monitor, nearest-monitor lookup, clamping, break-out margin, snap zones for edges/corners/free space, full-width windows, restore sizing, grab-point restore, fit-inside, rect tolerance, split-view `followEdge` (`geometry.test.mjs:20-154`). `tests/i18n.test.mjs` checks translations complete. CI (`.github/workflows/ci.yml:16-30`) runs the node tests, manifest key check, `luac5.4 -p` syntax check of the Lua module, `qmllint`, `shellcheck`. Not tested: anything that calls `hl.*`, the drag hand-over, the binds.

For omagnet: MF's pattern (pure geometry in a module with no `hl` calls, tested with a plain interpreter) is the one to copy. In Lua that is a `geometry.lua` run by `lua` or `luajit` outside Hyprland.

## (h) Hazards and gotchas, documented or visible

1. Hyprland 0.56 crash on stale keybind handles (documented, MF README line 121 and `mousefirst.lua:82-88`): calling any method on an `HL.Keybind` whose bind no longer exists crashes the compositor (null check on an optional instead of the pointer). `remove()` on a handle also drops every bind with the same key and modifiers, killing the sibling press/release pair. MF's workaround: never call methods on keybind handles, register the mouse binds once per Lua state (`M.binds_installed` guard) and turn them off with an `enabled` flag, remove shortcuts with `hl.unbind(keys)` by key name inside `pcall`. Applies directly to our SUPER+mouse:272 setup.
2. OSW calls `hl.unbind(key)` by name before every `hl.bind` (`minimize.lua:120-129`, `swap.lua:47`), the by-name form MF also uses. Neither guards against the key not being bound; MF wraps in `pcall` (`mousefirst.lua:208,217`), OSW does not.
3. Maximized or fullscreen windows refuse moves (OSW comment, `windowing.lua` float_existing: "a tiled window filling the screen can't grow"; hyprfloat issues `fullscreenstate 0` before moving, `snap.lua:30`). MF handles drags that begin on a fullscreen window specially (`d.fs ~= 0`, `mousefirst.lua:151`).
4. Minimum sizes: OSW notes "apps with a minimum size can't shrink" (`minimize.lua:73-74`) and keeps `MIN_W/MIN_H` for arranging (`settings.lua`). MF clamps restore size to at least `min(320, area.w)` x `min(240, area.h)` (`geometry.js:177-183`). Neither re-reads the window size after placing to detect a refused resize. For snapping, a window with a larger minimum will overflow its tile.
5. Timing: Hyprland applies its own rules after open, so OSW waits 40 ms (placement) and 120 ms (fit) in oneshot timers (`placement.lua:402-409`), and 40 ms after a release before correcting position "once the moves above have landed" (`snap.lua:260-263`). Dispatches are not synchronous with state.
6. Workspace change pulls a window back on screen; OSW sets `no_anim` first (`minimize.lua:81-84`).
7. A stub environment hazard (documented, `core.lua` `W.windows_on` comment): omarchy-menu-keybindings runs config against a stub where every `hl.*` returns an endless proxy, so `ipairs` over results never ends. OSW uses counted `for i = 1, #t` loops everywhere and guards `hl.get_windows() or {}`. MF uses `ipairs` (`mousefirst.lua:61,231`), so it would hang under that stub. Worth copying the counted loop if we load under that menu.
8. Config reload semantics: a reload starts a fresh Lua state, so binds re-register, but module-level state (OSW `restore`, `saved`, `maxed`) is wiped. OSW persists minimized frames to disk for this reason (`minimize.lua:23-27`). MF re-evaluation guard: disables the old timer before creating a new one (`mousefirst.lua:13-15`).
9. Window address is the only stable key but is reused? Not verified. Both clear per-address tables on `window.close` (OSW `placement.lua:411-416`).
10. A drag started by Hyprland keeps running even after you want to cancel it; MF ends it with `hl.dsp.window.drag()` called outside a press (comment `mousefirst.lua:123-127`). Read from code, not tested by us.

## (i) Code quality, one honest paragraph

OSW is compact, heavily commented in plain language, and has good defensive habits: `pcall` around timer callbacks (`placement.lua:405,408`), counted loops, a loader that cannot break the config, nil checks on every `hl.*` return, `math.floor` before dispatch. But it is a single shared mutable table `W` into which modules inject functions at load time ("looked up on it when called", `core.lua` header), plus real globals (`windowing_maximize`, `windowing_minimize`, ... defined with no `local`) used as a public API over `hyprctl eval`. Module load order matters implicitly. It has no tests at all, depends on private sibling plugins (dock, notch, island) through files in `~/.local/state`, rewrites the user's window rules to float everything, writes several state files with no atomicity, and `snap()` is a 40-line decision tree of nested booleans (`snap.lua:82-125`) that is hard to reason about and impossible to unit test since it calls `hl.*` inline. Do not copy the globals, the injected-function `W` table, the cross-plugin file protocol, or the geometry logic mixed with dispatch calls. MF is better engineered where it matters: tiny Lua surface that only emits events, all math in pure functions with real tests, a documented crash workaround, generation guards, `pcall` on bind/unbind, CI with `luac -p`. Its weaknesses are a global `MOUSE_FIRST`, a 16 ms repeating timer that builds a string of every window and monitor property every tick (`mousefirst.lua:42-72,166-180`, constant allocation), `ipairs` over `hl.*` results, and heavy coupling to Quickshell (most logic is QML we cannot reuse). The hand-over of a native drag is clever but fragile and unverified on versions other than 0.55-0.56.

## (j) License and attribution

- OSW: MIT, copyright 2026 Hugo Rolim Filho (`LICENSE`). Copying substantial portions requires keeping the copyright notice and permission text.
- MF: MIT, copyright 2026 DjaboDev (`LICENSE`). Same condition.
- hyprfloat: MIT, copyright 2025 yz778 (`LICENSE`, only the first lines read).
- Plan is to write our own code and borrow ideas only: ideas, algorithms and constants do not require attribution, but a "Prior art" note in the README crediting both projects is a courtesy. If any lines are copied verbatim, keep a short comment naming the source and add its MIT notice to a `THIRD_PARTY_LICENSES` section.

Snippets worth copying verbatim (all small, MIT, would need the notice):
- MF `mousefirst.lua:82-88` comment block explaining the 0.56 keybind crash, as documentation only (better to paraphrase).
- MF `geometry.js:72-92` `zoneRect` tiling math (remainder-to-far-edge rounding). Port to Lua rather than copy; it is 20 lines of arithmetic.
- MF `geometry.js:185-195` `restoreUnderCursor` (clamp ratio 0.1-0.9, keep pixel offset). Port.
- MF `geometry.test.mjs:26-39` the "zones tile the area without overlap" assertion shape. Port the idea.
- OSW `snap.lua:119-123` grab-fraction restore (4 lines). Trivial, rewrite.
- OSW loader `loader/hugorolimf-windows.lua:5-7` (io.open check then dofile). Rewrite.
Nothing here justifies verbatim copying; everything is small enough to reimplement.

## Ideas to borrow (summary, ordered by value)

1. Never call methods on keybind handles on Hyprland 0.56.x: register the press and release binds once per Lua state, gate with an `enabled` flag, remove by key name inside `pcall` (MF `mousefirst.lua:82-119`).
2. Keep all geometry in a pure Lua module with no `hl.*` calls and test it with a plain interpreter, with tests like "zones tile the usable area with no overlap" and offset-monitor cases (MF `geometry.js`, `geometry.test.mjs`).
3. Usable area = logical size (`width/scale`, swap on odd `transform`) minus `m.reserved`, inset by gap; make the far-side tile take the remainder so tiles meet the edge exactly (MF `geometry.js:61-92`, OSW `core.lua` `W.monitor_size`).
4. Restore by remembering size only at first snap, and on drag-away keep the grab point under the cursor via a clamped ratio; clear the record on resize and close (OSW `snap.lua:115-124`, MF `geometry.js:185-195`).
5. Run an un-maximize (hyprfloat dispatches `fullscreenstate 0`) before moving, wait 40 ms in a oneshot timer before post-move correction, thin the snap zone on borders shared with another monitor, and use counted loops with `or {}` guards (hyprfloat `snap.lua:30`, OSW `snap.lua:62-79,260-263`, `core.lua` `windows_on`).
