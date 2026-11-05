# Batch log

One entry per batch: what changed, which tests ran and their result, what the maintainer checked.
Plan and status live in [ROADMAP.md](ROADMAP.md).

## Before the batches (2026-11-05)

- Research done (see README). Prototype built: drag with `SUPER` to an edge, outline, snap (D1 to D3, Q1, Q6, Q7).
- D1 validated by the maintainer with a real Chrome window. D2 and D3 tested by script only.

## B1 Keyboard core (2026-11-05)

Built: `geometry.lua` (positions, rounding, centre, usable area, restore tag), `config.lua` (flat TOML,
defaults, safe merge), keyboard binds in `omagnet-snap.lua`, restore, centre, maximize handling.
Covers K1 to K11 (K8 has no default key), S1, parts of Q2 and Q5.

Tests, all green on 2026-11-05:
- `lua prototype/test_geometry.lua`: every position, tiling with no gap or overlap for 8 awkward widths,
  centre, drag rectangles, usable area (scale and rotation), restore tag round trip.
- `lua prototype/test_config.lua`: values, comments, bad lines, wrong types ignored, defaults not shared,
  no duplicate default shortcuts, workspace-mode parsing.
- `python3 tests/live.py` (real key events through a virtual keyboard): 14 positions with exact rectangles,
  restore after many snaps, second restore does nothing, centre, snapping a maximized window, an untagged
  window untouched with the key passed to the app, a key with nothing to do consumed on a floating
  workspace, scripted drag (outline state file, hide, release snap, overlay process gone).

Bugs found by the tests and fixed: tag pattern escape; Lua 5.5 read-only loop variable (only visible in
Hyprland); modifier keys joined with `+`; maximized window loses the floating tag; un-maximize needs a delay.

Maintainer check (pending): press the shortcuts on a floating workspace with a real app window. Keys:
`CTRL + ALT` with arrows, U I J K, D F G, E T, Return (maximize), C (centre), Backspace (restore).

## B2 Spacing (2026-11-05)

Built: `margin` (default 8, Magnet's default), `edge_tight` (default true), `reserve_*` (space kept free).
Each side of a shared edge gives half the margin, so neighbours end exactly `margin` apart for odd margins
and odd sizes. Covers S2, S3, S11 (K10 centre was done in B1).

Tests green on 2026-11-05: unit tests for gaps between halves, quarters and thirds (margins 1, 3, 7, 8, 11;
widths 1280, 1281, 999), tight and not tight, tiny windows, negative margin, reserved space; live checks with
real keys for margin 8, middle third, maximize staying tight, not tight, and 60 px kept free at the bottom.
Not tested: fractional scale (only scale 2 here), a second monitor.

Maintainer check (pending): with a floating workspace, snap two windows side by side and confirm an 8 px gap
and no gap to the screen border.

Review: the first independent review attempt failed because that agent type had no file tools, so it was
redone with a general agent plus a second read by the orchestrator (see "Review fixes" below).

## Review fixes for B1 and B2 (2026-11-05)

Two independent reads of the code agreed on these, each traced in the source and now covered by a test:
- **A failing snap could block the next drag** (state stayed "dragging"). Now wrapped in `pcall`, cleanup always
  runs, and a new press starts clean. Live check: a snap that throws, then `pressed` is false.
- **Restore on a maximized window** sent a move that is refused and then dropped the saved size. Now it does nothing
  on a maximized window. Live check, including that the saved size survives a maximize.
- **Center from a maximized window** used the maximized size. Now the size is read after un-maximizing.
- **Binds:** one bad or duplicated shortcut no longer stops the others; the global table is set before any bind;
  duplicates are resolved in a fixed order and listed in `bind_errors`.
- **Fractional sizes** crashed the saved-size tag. Rounded, with unit tests.
- **Config:** `keys = true` followed by `[keys]` crashed the parser; `0x10` and `1e999` were accepted as numbers.
- **Drag-snap saved the dropped spot** as the old rectangle. Now the rectangle from the start of the drag is saved.
- **The outline process started on every `SUPER` + drag** on any workspace. Now it starts only for a floating
  workspace window with the cursor within 150 px of an edge. After 20 s the outline stops but the release still snaps.
- **Quoted the overlay path** so a folder with a space works.

Left for later batches (already in the roadmap): corners and thirds by drag (B3), restore after the window was moved
by hand or its monitor changed, and snapping near the border between two monitors (B4).
Not checked: fractional scale and a second monitor (one display only); the drag snaps the focused window, so a
two-window drag with focus not following the mouse still needs a hand test.

## Audit fixes (2026-11-05)

- The live test now refuses to send any key unless the test window has focus (it could have typed into a real
  window). Checked that the guard fires.
- README status corrected; generated `.pyc` untracked and ignored; `run-all.sh` requires Lua 5.5, because 5.4
  accepts code Hyprland rejects; the temp folder of the live test is removed.

## B3 Drag zones (2026-11-05)

Built (Magnet's website drawings): corner gives a quarter, left or right edge a half, top edge maximize, bottom
edge a third, and sliding along the bottom edge to the next third gives two thirds. Settings: `edge_width`
(default 12, Magnet's default) and `corner_size` (default 64, our pick). The outline overlay starts near any edge,
now including the bottom.

Tests, green: unit tests for every zone, the boundaries (one pixel inside or outside a strip), all four slide
directions, a jump across the screen, and a sweep of every pixel of a small area (no error, only known positions).
Live (scripted cursor): the outline for each of 13 cursor positions, hides when the cursor leaves the strip, and a
release in a corner snaps a quarter.

Not done on purpose: top and bottom halves by drag (Magnet's drawings do not show where those zones sit; keyboard
only) and highlighting every zone while dragging (needs a different overlay; later).

Maintainer check (pending): drag a floating window to each corner, to the bottom edge, and slide along the bottom
edge. The outline shows the target; let go to snap.

## B4 groundwork (2026-11-05)

- **Real mouse in the live test.** A virtual mouse through `/dev/uinput` now drives real `SUPER` + drag runs: left,
  right, top, bottom (middle third), both tested corners, restore back to the start after each, a short drag that
  must not snap, and two overlapping windows (dragging the unfocused one snaps that one). All pass.
- **Bug found by it and fixed:** a snap from a window partly off the screen ended one pixel too tall or wide.
  `put` now checks the size after 40 ms and sets it again, at most twice. Live check added, plus the real top-left
  corner drag that first showed it.
- The live test now warns that it uses the real keyboard and mouse, and waits 4 seconds.

## B4a Restore on drag away, D7 (2026-11-05)

Dragging a snapped window (`SUPER` + drag) gives it its old size back once the pointer has moved 12 px. The pointer
stays at the same relative spot on the window, the window follows the pointer, and letting go at an edge snaps it
again (the new "old size" is then the restored size). Pure grab-offset function with unit tests; live real-mouse
checks: size back, pointer inside the window, window follows (moved about 80 px for an 80 px drag), snapped again at
an edge, restore gives the old size.

How it works, and why: see the gotcha about Hyprland computing a drag from its starting position
([gotchas.md](gotchas.md)). shortcut: the window follows at about 60 steps a second, a little less smooth than
Hyprland's own drag, only for a drag that starts on a snapped window.

Maintainer check (pending): snap a window with a key, then `SUPER` + drag it away. It should shrink to its old size
under the pointer and follow it smoothly enough. Tell me if the follow feels laggy.

## B7a Custom positions and ignore list (2026-11-05)

Built: `[cmd_<name>]` sections in the config (x, y, w, h as fractions, optional key) become positions with their own
shortcut; `ignore = "class, class"` makes omagnet leave those apps alone (the key reaches the app). Invalid or
incomplete custom positions are skipped whole. Also: the "tight to the screen edge" test now uses a tolerance, because
a custom position such as 0.1 + 0.9 is not exactly 1 in floating point (the audit had flagged the fragile `==`).
New document: [config.md](config.md) lists every setting and shortcut.

Tests green: unit tests for valid and invalid custom sections, key registration, ignore matching (case, spaces,
exact names), tolerance at the edge; live: an ignored app does not move and gets the key, a custom position snaps to
its rectangle, an unknown command does nothing.
Not done: the visual grid editor (C1, C3), which belongs to the settings app (Batch 5).

## B4b Next and previous display, several monitors (2026-11-05)

Built: `next_display` and `prev_display` (default `SUPER + CTRL + ALT + RIGHT / LEFT`, our picks) send the active
window to the next monitor, left to right, wrapping, keeping its relative place and size (pure functions `transfer`
and `next_monitor` with unit tests). Zones, margins and snap keys already used the monitor under the pointer or the
window, so they follow the window to the other monitor.

Tested with a temporary virtual monitor (`tests/live_displays.py`, about 30 s, never touches your windows and puts
them back): omagnet's monitor lookup and usable area match Hyprland's on a second monitor at scale 2; next display,
previous display (back within one pixel), right half, middle third and maximize on the other monitor. Your
windows on normal workspaces were unchanged afterwards. One hidden special-workspace window was laid out again by
Hyprland; omagnet does not touch it.

Not tested: a real second monitor with a different scale or rotation (the virtual one was 1920 by 1080 at scale 2),
the shortcut keys for the display commands (focus cannot be given to the test window while a second monitor exists;
the same binding code is covered by the single-monitor test), and a drag that crosses between monitors.

## Review fixes for B3 to B7a, and B5 groundwork (2026-11-05)

A review with the middle-size model found these; each is traced in the code and now covered:
- A window followed during a drag-away that closes mid-drag could make the move hit the active window instead.
  Now following stops when the window is gone.
- The size retry resent a stale position during a drag-away. Now that move does not retry.
- The 20 s cap counted ticks, which is 10 s at the follow rate, and left the follow frozen. Now it counts seconds and
  clears the follow.
- Drag-away could resize the focused window when an unfocused one was being dragged. Now it arms only when the pointer
  is on the active window.
- `next_display` could push a window into a tiled or scrolling workspace. Now the target monitor's workspace must be
  floating (read from Omarchy's saved modes), otherwise nothing happens. The saved size is carried to the new monitor.
- Geometry: no zero-size rectangle without a margin; mirrored monitors order by name; a corner never swallows a whole
  edge on a small area.
- New `prototype/test_glue.lua` loads the module with a fake `hl`, checks every setting and bind, and the rules above.
  Checked by deleting a setting and by removing the floating check: both make it fail.
- `reload_config()` (for the settings app) re-reads the config without a Hyprland reload and reports whether a shortcut
  changed from the bound ones.

My own mistake, fixed: the virtual-monitor test opened Omarchy's theme picker each time and left it open on screen
(see gotchas). The test now closes it and checks no overlay is left.

Left as shortcuts, written in the code: a window moved by hand after a snap still counts as snapped for the drag-away
restore; a `#` inside a quoted config string is cut; a release snaps the active window even if the dragged one closed.

Settings app (B5): the first version of the plugin (panel, service, JavaScript config reader and writer) is in
`plugin/`. It validates and its JavaScript tests pass; it has not been loaded into the shell yet.

## B5 Settings app, A1 and A4 (2026-11-05)

The settings app is a Quickshell plugin in `plugin/` with a panel and a service, and no bar widget (nothing is added to
the bar). It was written by a mid-size agent from the research and the working plugins on this machine, then checked
here: its JavaScript config reader and writer agree with `config.lua` on 9 shared inputs, the validator passes, and
the scripts it runs take their values as arguments and only touch its own launcher file and the config file.

Loaded into the real shell and rendered: the panel shows switches, spacing, drag zones, the ignore list and shortcuts,
in the Omarchy theme. A click on "No margin at the screen border" wrote `edge_tight = false` to
`~/.config/omagnet/config.toml`, and the running Lua module applied it at once with no Hyprland reload. Switched back,
and the test config file was removed.

Problems found only by loading it, now fixed and written in the gotchas: a property named `baseline` collides with a
built-in of `Item`; the shell caches a failed compile, and a new plugin needs a shell restart once.

State on this machine: the plugin is installed (a copy in `~/.config/omarchy/plugins/io.github.felipecpaiva.omagnet`)
and enabled, a launcher entry `omagnet` exists, and `~/.config/omagnet/config.toml` does not exist (defaults apply).
To remove it: `omarchy plugin disable io.github.felipecpaiva.omagnet`, then `omarchy plugin remove` for the folder.

Maintainer check (pending): open "omagnet" from the launcher, change a setting, see it apply; scroll to the shortcuts.
Not done: the optional bar icon (Batch 6), a visual editor for custom positions, and marketplace listing.

## B8a Portrait screens, D9 (2026-11-05)

On a vertical screen (taller than wide) the side edges give row thirds (top, middle, bottom) with the same slide to
two thirds, the corners give quarters, the top edge maximizes, and the bottom edge gives the left and right halves,
following the Magnet drawings. New positions `third_top`, `third_middle`, `third_bottom`, `two_thirds_top`,
`two_thirds_bottom` (rows tile exactly, with margins). Unit tests for every zone, the slide, and the rectangles.
The landscape live test still passes. Not tried on a real vertical monitor (none here); Magnet's text is not clear
about where top and bottom halves sit on a vertical screen, so those stay on the keyboard.

## B6 Optional bar icon, A2 (2026-11-05)

`plugin/BarWidget.qml`, written by a mid-size agent and checked here. One plugin with kinds panel, service and
bar-widget. The widget is invisible and has no size unless `bar_icon = true` is in the config; a new switch "Show an
icon in the bar" in the settings window turns it on. Because the plugin also has a panel, the shell opens it through the
normal panel path, so the settings window opens from the launcher even while the icon is hidden.

Real bar, compared by picture: with the plugin enabled and the icon off the bar is the same as before (only the clock
differs); with the icon on a grid icon appears at the right; clicking it opens the settings window; switching it off
removes it again within 2 seconds. Found and fixed: the first version never saw a config file created after the shell
started (a watcher on a missing file); the widget now also re-reads the file every 2 seconds.

Left as is: the bar layout in `shell.json` lists the plugin's id (invisible) after enabling. A3, a menu on the icon, is
only a click that opens the settings window; Magnet's menu bar menu is not known.

Maintainer check (pending): open the settings window, turn on "Show an icon in the bar", look at the bar, click the icon.

## B3b Drag appearance and zone highlight, S6, S7, D10 (2026-11-05)

Settings `target_outline`, `target_color`, `target_fill`, `highlight`, `highlight_outline` (config.md). The overlay
reads two more small files (style, zone strips) next to the state file, so the existing state file and its tests did not
change. `highlight` draws a faint strip for each drag zone (corners, sides, top, bottom thirds; on a vertical screen the
side thirds and bottom halves) from the start of the drag; it is off by default because it starts the 230 MB overlay at
every drag. Pure `zone_pills` with unit tests (every pill is inside the area and inside a zone). `tests/live_overlay.py`
checks the files and takes a screenshot: a red 6 px outline with a stronger fill and all 14 zone strips were visible.

A bug found by the settings agent and fixed: the config parser cut comments at the first `#`, even inside quotes, so a
colour could not be saved in the file. Both parsers now ignore `#` inside quoted strings; shown end to end: a colour
typed in the settings window was written as `target_color = "#ff0000"` and read by the running Lua. The live test did
not catch it (it set the value directly); the file round trip is now in `live.py` and in both unit suites.

The settings window has a new "Drag outline" section for these. The fill is shown as a percent because Omarchy's number
field is integer only.

## End of day state (2026-11-05)

Tests, all passing: `lua` unit tests (geometry, config, glue), `tests/scrub.sh`, `node plugin/tests/config_io.test.mjs`,
`omarchy plugin validate plugin`, and the live tests `live.py`, `live_displays.py`, `live_overlay.py`.
Architecture: [architecture.md](architecture.md). Hand checks still to do: [validation-checklist.md](validation-checklist.md).
Left: C1 and C3 (a visual grid editor), A5 (marketplace, needs a packaging decision), D6 (blocked on unclear Magnet
drawings). Documented limits: D11 (drags from an app's own title bar), K13 (not in Magnet).
