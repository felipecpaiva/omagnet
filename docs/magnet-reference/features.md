# Magnet-style window snapping for Omarchy floating workspaces

Status: **research, no code yet** (started 2026-11-05).
Goal: port every function of Magnet (macOS, https://magnet.crowdcafe.com/) to Omarchy's floating
workspace mode, so a floating window can be snapped to a part of the screen.
Rule from the maintainer: Magnet is the quality bar. Every function is listed here before any code.

## Where it would live

Floating mode is Omarchy 4.5: `Super + L` cycles dwindle, scrolling, floating
(`omarchy hyprland workspace layout toggle`). Windows get the tag `omarchy-floating-workspace`.
Hyprland is 0.56.2 with Lua config. Likely parts: Lua binds using `hl.dsp.window.move` and
`hl.dsp.window.resize`; maybe a drag watcher for snap zones. Not decided.

## Upstream check (2026-11-05, partial: GitHub rate limit hit mid-search)

- No issue or discussion about snapping, Magnet or Rectangle in `omacom/omarchy` (searched: magnet,
  snap, snapping, rectangle, edge, half screen, floating layout, floating workspace).
- Closest: PR #11503 (move floating windows with the keyboard, 25px steps, open), PR #16340 (cap
  floating window size to the monitor), PR #17626 (keep a floating window on screen across monitors),
  PR #13569 (floating bar option). The maintainer's own PR #9113 (2/3 - 1/3 split) is for tiled mode.
- Not yet searched: "tile", "maximize", "move window keyboard", "window management", "grid".

## Magnet functions: from official sources (verified)

Sources: magnet.crowdcafe.com (home, FAQ), Mac App Store listing id441258766.

| Area | What Magnet does |
|------|------------------|
| Positions | Fullscreen (maximize, not macOS full screen), halves, quarters, thirds, two-thirds |
| Drag: top edge | Maximize |
| Drag: bottom edge | Thirds; sliding along the edge expands to two-thirds |
| Drag: side edges | Left/right and top/bottom halves |
| Drag: corners | Quarters |
| Drag: vertical (portrait) display | Thirds along the sides; quarters and halves on the corners and bottom edge |
| Restore | Grab the title bar of a snapped window again and it returns to its old size (user reviews) |
| Activation | Trigger areas (drag), keyboard shortcuts, green window button menu, menu bar icon; each optional and customizable |
| Custom commands | "An infinite number of custom commands" (App Store text, no detail) |
| Displays | Up to six external displays; vertical displays; moving windows between monitors |
| Spaces | Works on windows in the active Space only, not across Spaces (FAQ) |
| Settings | Custom shortcuts, optional menu bar icon, optional iCloud sync, launch at login (reviews) |
| Limits (FAQ) | Only standard resizable windows; some apps keep a minimum width, so they stay wider than half |

## Magnet functions: from third-party pages (weaker, confirm in the app)

- Thirds: Ctrl + Option + D / F / G. Quarters: Ctrl + Option + U / I / J / K.
- Next/previous display: Ctrl + Option + Cmd + Left / Right.
- Multi-zone drag: dragging across several zones quickly sizes the window to the combined area.
- A user reported ultrawide (21:9) works.

## NOT FOUND in any source (must come from the app itself)

Full default shortcut list, sixths and eighths, center, restore shortcut, undo, gap or padding setting,
ignored apps list, snap-zone count and size, drag preview overlay, hot corners.

## Next step

The maintainer has Magnet on a Mac. To close the gaps, screenshot: (1) the menu bar icon menu, (2) every
Settings tab (shortcuts, trigger areas, general). Put them in this folder, then finish the table above.
Then write the Omarchy design (binds first, drag zones second) and file an upstream discussion.
