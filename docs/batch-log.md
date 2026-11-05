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

Review: the first independent review attempt failed because that agent type had no file tools; it is being
redone (see B1 and B2 review below).
