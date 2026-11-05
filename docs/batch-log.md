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
