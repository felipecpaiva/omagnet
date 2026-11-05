# Existing window snapping solutions

Date: 2026-11-05. Goal: find what already exists before building omagnet (Magnet-style snapping for
Omarchy's floating workspace mode, Hyprland 0.56 with Lua config).

Evidence tags used on every claim:

- **[read]** read from the project's README, source tree, docs page or GitHub API metadata (license,
  last push, language, stars) during this research.
- **[search]** search result snippet only, not verified against the source page.

Dates are the last push to the default branch (GitHub API, read 2026-11-05) unless stated.

## Verdict first

**Something very close to omagnet already exists and shipped three weeks ago:**
`austinwilkerson/omarchy-zones` ("Floating Snap Zones"), MIT, active (v0.4.4 on 2026-11-04). It
already does drag-to-snap for Omarchy's floating workspace mode only, with edge gestures, zone
presets, a landing preview, per-monitor and per-workspace layouts. Read it, test it, and decide
whether to contribute to it rather than rebuild it. What it lacks (see the table) is the keyboard
half of Magnet, restore-on-unsnap and cycling. Details below.

## 1. Omarchy and Hyprland (the ones that matter)

| Name | Link | License | Last push | Language | Reuse? |
|------|------|---------|-----------|----------|--------|
| Floating Snap Zones (omarchy-zones) | https://github.com/austinwilkerson/omarchy-zones | MIT | 2026-11-04 | Python + QML + small C++ helper | **Adopt, fork or contribute** |
| Mouse-First | https://github.com/DjaboDev/Mouse-First | MIT | 2026-09-28 | QML + Lua + JS | Learn from, geometry code reusable |
| omarchy-smart-windows | https://github.com/hugorolimf/omarchy-smart-windows | MIT | 2026-11-03 | Lua | Learn from, possibly reuse |
| omarchy-x-mode | https://github.com/timurguseynov/omarchy-x-mode | NOASSERTION (no clear license) | 2026-11-01 | Shell | Learn only (license unclear, whole-desktop bundle) |
| omarchy-snap-layouts (JeoCrypto) | https://github.com/JeoCrypto/omarchy-snap-layouts | MIT | 2026-10-16 | QML | Learn from (keyboard picker) |
| omarchy-snap-layouts (n0rthstar88) | https://github.com/n0rthstar88/omarchy-snap-layouts | MIT | 2026-10-31 | QML | Learn from (drag to top picker, snap assist) |
| omarchy-to-windows | https://github.com/flaviomartil/omarchy-to-windows | MIT | 2026-11-02 | Python + modified Hyprbars | Learn only (whole-desktop bundle) |
| omarchy-windows-like | https://github.com/focuswts/omarchy-windows-like | MIT | 2026-08-29 | Shell | Learn only |
| omarchy-caption-buttons | https://github.com/Zarrock77/omarchy-caption-buttons | MIT | 2026-10-19 | QML | Learn only (drop on edge to snap) |
| omarchy-workspace-layout | https://github.com/bjarneo/omarchy-workspace-layout | MIT | 2026-10-28 | JS + generated Lua | Learn only (tiling layouts, not floating) |
| hyprtoggle | https://github.com/din-grogu/hyprtoggle | MIT | 2026-10-08 | C++ | Learn from (8-zone drag plugin) |
| hyprwinsnap | https://github.com/sitiyou/hyprwinsnap | none stated | 2026-10-31 | C++ | Learn only (snaps size to presets) |
| hyprfloat | https://github.com/yz778/hyprfloat | MIT | 2026-08-20 | Lua | Learn from (keyboard fractional snap) |
| windowized-hyprland | https://github.com/naolmideksa/windowized-hyprland | MIT | 2026-11-02 | QML + C++ plugin | Learn only (full dotfiles) |
| Hyprland built-in snap | https://wiki.hypr.land (general snap block) | BSD-3-Clause | active | C++ | Not a solution, see below |

### Floating Snap Zones (omarchy-zones) [read]

- Targets exactly our scope: "Zone snapping for Omarchy's Floating workspace mode". Does nothing in
  tiling or scrolling workspaces. Verified on Omarchy 4.5.0-1 RC, Hyprland 0.56.2.
- Install: `omarchy plugin add <repo> --enable`. Created 2026-10-15, 7 commits visible, releases
  v0.4.2 to v0.4.4, 0 stars (very new, nobody has validated it).
- Eight layout presets (50/50, 50/50 vertical, thirds, 25/50/25, four columns, four-square grid,
  four plus overlapping centre). Overlapping zones resolved by closest centre.
- Edge gestures with every preset: left edge = left half, right edge = right half, top edge =
  maximize to usable area. Snap happens on release; a translucent landing preview shows the frame.
- Padding between zones and screen edges (shared gaps not doubled), preview colour and opacity,
  per-monitor and per-workspace layout override, handles scale, rotation, bars and dock.
- Architecture: Quickshell bar widget plus a Python daemon using Hyprland IPC, plus a small C++
  helper loaded into Hyprland that reports mouse-button state over the IPC socket (needed because
  Omarchy titlebars consume the events). The helper is compiled locally on first start against the
  installed Hyprland headers.
- Weaknesses (from its own docs): README lists no keyboard shortcuts (only 2 mentions of
  keyboard/shortcut words, none documenting binds); no mention of restore-on-unsnap, cycling
  repeated commands, thirds by drag along the bottom edge, or corner quarters by gesture (quarters
  only via the grid preset). Needs a C++ toolchain and Hyprland dev headers, and breaks when the
  Hyprland ABI changes (it rebuilds automatically). Touchscreen drags and other compositors not
  validated. Single author, no stars.

### Mouse-First [read]

- Quickshell plugin for Omarchy 4, Hyprland 0.55+. Half on side edge, quarter on corner, optional
  top edge maximize, un-snap restores previous size under the cursor, resize two snapped windows
  together by dragging the shared border, optional `Super+Ctrl+Shift+arrows` snap shortcuts, respects
  bar, dock and gaps.
- How it works: a Lua module loaded with `hyprctl eval` reports events; two non-consuming binds track
  the left mouse button (the Lua API cannot read it); when Hyprland starts a floating drag the module
  ends it and the shell drag controller continues it. Pure geometry functions in JS with tests.
- Useful gotcha in its docs: in Hyprland 0.56.2, calling a method on an `HL.Keybind` whose bind no
  longer exists crashes the compositor, and `:remove()` drops every bind with the same key and mods.
- Weakness: it is also a window-controls, dock and bar-icons bundle, so snapping is one feature among
  many. Not restricted to floating workspace mode (it can make everything float).

### omarchy-smart-windows [read, README only]

- Lua module under the user config dir, does not edit `hyprland.lua`. Drop on top edge = maximize,
  side = half, corner = quarter, drag away restores the old size, `Super+A` arranges the screen,
  `Super+Shift+arrows` swap neighbours. Created recently (pushed 2026-11-03), 0 stars. Not verified
  beyond the README; check its source for how it detects drag release without the C++ helper.

### omarchy-x-mode [read, README only]

- Mac-like bundle: titlebar with tabs, dock, Command-Tab, and "Rectangle-style snapping": drag to a
  side for half, corner for quarter, top for maximize; `Super+Alt+Left/Right` cycles half, two thirds,
  one third. Adds its own `xmode` workspace layout beside Omarchy 4.5's three. Licence is unclear
  (GitHub reports NOASSERTION), so do not copy code. The cycle idea is the one worth copying.

### Snap layout pickers [read, README only]

- JeoCrypto: pop a Windows 11 style picker with a key (`SUPER + Z`), choose layout and zone by
  keyboard. n0rthstar88: drag a window to the top to get the picker, then snap assist offers live
  thumbnails for the remaining zones. Both are QML Quickshell plugins. Good UX references for the
  "zones" half; neither is Magnet-like edge snapping.

### Hyprland plugins and scripts [read]

- hyprtoggle: native C++ plugin, 8 drag zones (top, bottom, sides, 4 corners) with configurable
  action per zone (snap geometry, fullscreen, any dispatcher), threshold 20 px and corner 60 px,
  animated preview, hyprpm install, Lua config. Created 2026-10-08, 2 stars, 0 issues. Closest
  example of in-compositor zone detection. Weakness: C++ plugin must track Hyprland ABI; the
  actions are fixed per zone, no thirds.
- hyprwinsnap: snaps the size to preset WxH while you drag-resize (threshold and hysteresis). Not
  position snapping. No licence in repo metadata.
- hyprfloat: Lua script (lua-cjson, lgi, posix, grim-hyprland). `snap x0 x1 y0 y1` takes fractions of
  the screen, so bind one key per position. Also togglefloat, movemon, alt-tab, overview. 74 stars,
  MIT. No drag snapping, no restore, no cycle. Best prior art for keyboard-only fractional snapping.
- hyprland-plugins (official): contains hyprbars, hyprfocus, borders-plus-plus, csgo-vulkan-fix
  (directory listing read). No snapping plugin there. hyprscrolling and hyprexpo are not a snapping
  tool (hyprscrolling is a scrolling tiler; not opened). hyprgrass (touch gestures, BSD-3, 604 stars)
  is touch input, not zones.
- Hyprland built-in snap [search]: added in 0.45; options `snap:enabled`, `window_gap` (default 10),
  `monitor_gap`, `border_overlap`, `respect_gaps` under `general`. It snaps edges of floating
  windows to other windows and to the monitor edge while dragging. It is edge magnetism, not
  half, quarter or third placement. I could not open the wiki page itself (404 on the URLs tried),
  so treat the option list as search result only.

## 2. Other Linux desktops

| Name | Link | License | Last push | Language | Reuse? |
|------|------|---------|-----------|----------|--------|
| Tiling Assistant (GNOME) | https://github.com/ubuntu/Tiling-Assistant | GPL-2.0 | 2026-10-08 | JavaScript | Learn only |
| Tiling Shell (GNOME) | https://github.com/domferr/tilingshell | GPL-3.0 | 2026-10-17 | TypeScript | Learn only |
| Pop Shell (GNOME) | https://github.com/pop-os/shell | GPL-3.0 | 2026-08-20 | TypeScript | Learn only |
| Polonium (KWin tiler) | https://github.com/zeroxoneafour/polonium | MIT | 2026-11-03 | TypeScript | Learn only |
| Magnetile (KWin script) | https://github.com/jcearnal/magnetile | GPL-3.0 | 2026-05-24 | QML | Learn only |
| KWin Quick Tile and custom tiles | KDE Plasma built in | GPL | active | C++ | Learn only |
| canoe (River) | https://github.com/roblillack/canoe | MIT | 2026-06-10 | Rust | Learn only |

- Tiling Assistant [read]: Windows-like snap assist plus an expanded two-column tiling for GNOME.
  Newest GNOME release only. Weakness: bound to GNOME Shell internals and breaks per release.
- Tiling Shell [read]: layout editor, Windows 11 style snap assist while dragging, edge tiling,
  window suggestions to fill remaining tiles, Super+arrows move between tiles, JSON import/export,
  GNOME 42 to 51. Weakness: no gaps mentioned; cannot hook the maximize button hover.
- Pop Shell, Polonium [search/metadata only]: auto-tilers, not Magnet-like; stars and dates only.
- KWin [search only]: Quick Tile edge snapping (left/right, corners) and a custom tile editor;
  reported weakness is that tiles persist as linked regions and are hard to reset, and top/bottom
  edge tiling was a feature request (bug 490198). Magnetile adds zone snapping as a KWin script.
- canoe [search + metadata]: stacking WM for River, `Super+Left` snaps to left half and restores when
  snapped right. A whole WM, not a tool.
- Sway, niri, River [search only]: no dedicated snap-to-half tool found. niri has floating windows
  since 25.01, no half-screen snap noted. sway has none in the results.

## 3. macOS (the quality bar)

| Name | Link | License and price | Language | Status |
|------|------|-------------------|----------|--------|
| Magnet | https://magnet.crowdcafe.com/ | Proprietary, Mac App Store (about 4.99 USD, search only) | n/a | Reference |
| Rectangle | https://github.com/rxhanson/Rectangle | MIT, free (Pro is paid) | Swift | pushed 2026-11-03, 30k stars |
| Loop | https://github.com/MrKai77/Loop | GPL-3.0, free | Swift | pushed 2026-10-18 |
| Moom | https://manytricks.com/moom/ | Proprietary, 15 USD [read] | n/a | n/a |
| Swish | https://highlyopinionated.co/swish/ | Proprietary, 16 USD or Setapp [read] | n/a | n/a |
| BetterSnapTool | https://folivora.ai/bettersnaptool | Proprietary, paid (price not shown) | n/a | n/a |
| Amethyst | https://github.com/ianyh/Amethyst | MIT | Swift | pushed 2026-11-04, auto-tiler [metadata] |
| AeroSpace | https://github.com/nikitabobko/AeroSpace | MIT | Swift | pushed 2026-11-05, i3-like tiler [metadata] |
| Hammerspoon | https://github.com/Hammerspoon/hammerspoon | MIT | Objective-C | scripting, not a snapper [metadata] |

Comparison against Magnet (Magnet column from `docs/magnet-reference/features.md`):

| Feature | Magnet | Rectangle [read] | Loop [read] | Moom [read] | Swish [read] | BetterSnapTool [read] |
|---------|--------|------------------|-------------|-------------|--------------|-----------------------|
| Drag to edge: halves | yes | yes | yes | yes, per zone | via titlebar swipe | yes |
| Corners: quarters | yes | yes | yes | yes | grids 2x2, 3x2, 3x3 | yes |
| Top edge: maximize | yes | yes | not detailed | configurable | gestures | yes |
| Thirds | yes (bottom edge, drag slide gives two thirds) | yes, plus sixths, eighths, ninths | yes | via grid | via grids | not listed |
| Keyboard shortcuts | yes | yes, per action | yes, trigger key + key | yes | yes | yes, custom |
| Repeat shortcut cycles sizes | not documented | yes (thirds, tiling grids) | yes (chains actions) | chained actions | n/a | n/a |
| Custom zones | no | no | no | yes (layouts as drop targets) | no | yes (custom snap areas) |
| Multi display | up to 6 | next/prev display | screen switching | yes | yes | yes |
| Restore on drag away | yes | yes (not detailed on page) | not stated | yes | n/a | n/a |
| Scripting hook | no | URL scheme and shell | `loop://` URL scheme | no | no | no |
| Saved layouts / window sets | no | no | no | yes | no | no |
| Gap setting | not found | yes (in app settings, not on page) | padding yes | no | no | no |
| Distinctive | simple, cheap | free, huge layout set, cycling | radial menu, theming, stash | grid and layouts | trackpad gestures | custom areas |
| Biggest weakness | no gap or custom zones found | minimum-size apps overlap, cannot cross Spaces | no trackpad gestures or workspaces | price, older UX | needs low-level access, paid, off App Store | paid, dated |

Notes: Rectangle's "cannot move windows to other Spaces" limit and the minimum-window-size overlap
issue are stated on its page [read] and map directly to Hyprland (apps with minimum sizes will
refuse a half). Loop's page marks its own comparison table as possibly outdated and lacks a
known-issues section [read]. The cross-product table comes from Loop's own comparison page, which
returned HTTP 410 when fetched, so competitor cells beyond what each vendor page states are
**[search]**.

## 4. Windows

| Name | Link | License | Language | Notes |
|------|------|---------|----------|-------|
| FancyZones (PowerToys) | https://github.com/microsoft/PowerToys | MIT, last push 2026-11-05 | C++/C# | Learn only |
| Snap Layouts / Snap Assist | built into Windows 11 | proprietary | n/a | Learn only [search] |
| AquaSnap | https://nurgo-software.com/pricing/aquasnap | proprietary, free personal tier, about 30 USD pro [search] | n/a | Learn only |

FancyZones [read, full docs page]: hold Shift while dragging to show zones; hovering the shared edge
of two zones selects both (merged rectangle); Ctrl adds zones; mouse wheel while dragging switches
layout (off by default); grid and canvas layout editor with split/merge, space-around-zones margin,
Win+arrow override to move between zones (by zone index or relative position), `Win+Ctrl+Alt+number`
quick layouts, move new windows to last known zone, restore original size on unsnap, exclude apps
list, CLI (`set-layout`, `get-layouts`, hotkey assignment), JSON layouts. Weaknesses on its own page:
a long list of apps that cannot be zoned, elevated windows need admin, DPI mismatch gaps.
Windows 11 Snap Layouts [search]: hover maximize button, pick layout, Snap Assist fills remaining
zones; third-party reports of problems with legacy apps and remote windows.
AquaSnap [search]: freemium; personal edition lacks mouse shortcuts, tiling, move-together and
multi-monitor.

## 5. Gaps no existing tool fills (as of 2026-11-05)

1. Magnet's third-by-drag along the bottom edge (slide for two thirds): not found in any Omarchy or
   Hyprland tool; omarchy-zones does thirds only via a layout preset.
2. Repeat the same shortcut to cycle half, two thirds, one third: only omarchy-x-mode (license
   unclear) and Rectangle/Loop on macOS.
3. A documented full keyboard map (halves, quarters, thirds, centre, next monitor, restore) that
   works only in floating workspace mode: hyprfloat has the fractional primitive, nothing wraps it.
4. Restore on unsnap plus an undo shortcut, in a floating-mode-only tool: Mouse-First and smart-windows
   claim unsnap restore, omarchy-zones does not document it.
5. Tests, upstream-friendly packaging: only omarchy-zones and Mouse-First ship tests.

## 6. Verdict

**Do not start from scratch.** Install `austinwilkerson/omarchy-zones` first and judge it against the
Magnet function table. It covers the drag half for floating mode with a sound architecture (daemon via
IPC plus a tiny observer for button release). Then pick one:

1. **Contribute upstream** (best): add the keyboard map, restore on unsnap, cycling, thirds on the bottom
   edge. MIT, early, single author, 0 stars, so a PR is likely welcome.
2. **Fork** if the compiled C++ helper or Python daemon is unacceptable. Mouse-First's approach (a Lua
   module that reports events, no compiled code) is the lighter alternative and shows the Lua API
   cannot read mouse buttons, so every pure-Lua drag watcher needs binds as a workaround.
3. **Build omagnet** only if both are rejected, and then as keyboard-first (hyprfloat style fractional
   snap bound to Magnet's keys) with drag zones second, matching the existing plan in
   `docs/magnet-reference/features.md`.

Ideas worth copying:

- Gate on floating workspace mode only (omarchy-zones), so tiled and scrolling workspaces are untouched.
- Snap on release with a translucent landing preview; pausing during a drag does not snap.
- Hysteresis and thresholds (hyprtoggle 20 px edge, 60 px corner; hyprwinsnap threshold and hysteresis).
- Account for titlebar height, borders, bars, dock and gaps in the geometry (omarchy-zones, Mouse-First,
  windowized-hyprland). Keep geometry as pure functions with unit tests (Mouse-First, omarchy-zones).
- From FancyZones: hover the shared edge to merge two zones, margin setting, restore original size on
  unsnap, exclude-apps list, a CLI, `set-layout` style scripting.
- From Rectangle and Loop: repeated shortcut cycles sizes, URL or CLI actions for scripting.
- Respect apps with minimum sizes and say so in docs (the same limit Rectangle and Magnet document).
- Compatibility trap: Hyprland 0.56.2 crashes when calling a method on a removed `HL.Keybind`
  (Mouse-First docs); `:remove()` drops every bind with the same key and mods.

Not checked: hyprscrolling and hyprexpo source, the "Floating Window Mode" integration referenced by
omarchy-windows-like (not located), the Omarchy plugin store (page rendered empty), Pop Shell and Polonium
READMEs, Amethyst and AeroSpace feature lists, and whether omarchy-zones actually works on a live
floating workspace (README and tree read, not run).
