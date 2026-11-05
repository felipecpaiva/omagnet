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
