# Magnet screenshot findings

Scope: what could be read from public images of Magnet (CrowdCafe). Only 3 Mac App Store
screenshots (one is marketing only) plus the product website's SVG illustrations were
available. Images are kept outside this repo (not ours). Nothing here is from official text
pages except where marked "text".

## Sources

| ID | URL | What it shows |
|----|-----|---------------|
| AS1 | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/f3/77/bd/f377bd7b-83c4-cc4d-4f94-4a3a3826011d/3_0_7_GM_01.png | Marketing: three side-by-side windows on a laptop. Text: "Magnet keeps your workspace organized. Activated by customizable trigger areas, hotkeys, or via dropdown menu, Magnet declutters your screen by snapping windows into organized tiles." Badges "Editors' Choice", "Mac Essentials". |
| AS2 | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/e6/0b/e0/e60be063-1114-c6bc-6136-34bfe478076a/3_0_7_GM_02.png | Commands editor (sidebar tab with command-key icon): command list, custom command grid, keyboard shortcut, activation area for dragging. |
| AS3 | https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/b4/08/84/b4088488-4202-9236-bee4-8287c7cbcda5/3_0_7_GM_03.png | Preferences tab (sidebar tab with toggles icon), dark theme. |
| W4 | https://magnet.crowdcafe.com/imgs/design-4.svg | Corner/side drag zones plus keyboard shortcut key diagrams (landscape). |
| W5 | https://magnet.crowdcafe.com/imgs/design-5.svg | Top and bottom edge zones plus key diagrams. |
| W6 | https://magnet.crowdcafe.com/imgs/design-6.svg | Portrait display zones (no keys). |
| W3 | https://magnet.crowdcafe.com/imgs/design-3.svg | Laptop (3 columns) plus external monitor (2x2 quarters). |
| T | https://magnet.crowdcafe.com/ (page text) | Captions only, cited below as "text". |

Setapp, MacUpdate, Softpedia etc. were not fetched successfully (Setapp page exposes only an og image); no further settings screenshots were found.

## Application structure (AS2, AS3)

Single window with two sidebar tabs: Preferences (toggles icon) and Commands (command-key icon).
Window title shows the tab name ("Preferences" / "Commands"; command detail pane titled by the
command name, e.g. "My Command #01"). The feature list in AS3 also says "Seamless iCloud
synchronization" (text, so settings/commands sync via iCloud). Menu bar dropdown and a green
button menu exist (AS1 text, AS3) but no screenshot of the menu bar menu was found.

## Actions and default shortcuts

Modifier shown as "control + alt/option" (Ctrl + Option). The Magnet Commands list (AS2) names
the actions; shortcut keys come from W4/W5 key diagrams (positions in a diagram are read as
the key letter, spatial layout of U I / J K matches the corner layout).

| Action (AS2 label) | Default shortcut | Source |
|---|---|---|
| Left | Ctrl+Opt+Left arrow | W4 (middle diagram, left half) |
| Right | Ctrl+Opt+Right arrow | W4 |
| Top | Ctrl+Opt+Up arrow | W4 (right diagram, top half) |
| Bottom | Ctrl+Opt+Down arrow | W4 |
| Top Left | Ctrl+Opt+U | W4 (left diagram) |
| Top Right | Ctrl+Opt+I | W4 |
| Bottom Left | Ctrl+Opt+J | W4 |
| Bottom Right | Ctrl+Opt+K | W4 |
| Left Third | Ctrl+Opt+D | W5 (middle diagram: D F G) |
| Center Third | Ctrl+Opt+F | W5 |
| Right Third | Ctrl+Opt+G | W5 |
| Left Two Thirds | Ctrl+Opt+E | W5 (right diagram E T), mapping of E vs T not certain; E is probably left two thirds |
| Right Two Thirds | Ctrl+Opt+T | W5, same caveat |
| Center Two Thirds | not shown | AS2 lists it, no key visible |
| Maximize (Full screen of the display) | Ctrl+Opt+Enter/Return | W5 (left diagram). Not in the AS2 visible list (list is scrolled/clipped), name unknown |
| Next Display | not shown | AS2 |
| Previous Display | not shown | AS2 |
| Center | not shown | AS2 |
| Restore | not shown | AS2 |
| Custom command ("My Command #01") | example shows Ctrl+Opt+O (glyphs read as "^ option O") | AS2 |

AS2 list groups, separated by dividers, in this order: (custom commands under a "Horizontal"
group header with a collapse chevron and a "+" add button), then Left/Right/Top/Bottom; Top
Left/Top Right/Bottom Left/Bottom Right; Left Third/Center Third/Right Third; Left Two
Thirds/Center Two Thirds/Right Two Thirds; Next Display/Previous Display; Center/Restore.
The four corner rows show a crossed-eye style icon at the right (read as "hidden/disabled in
this layout or activation area off"; meaning unclear).

## Custom command editor (AS2)

Pane for a command, three cards:
1. "Intended window size and position": a grid of small cells (about 24 columns by 14 rows as drawn);
   selecting a rectangle of cells defines the target. Axis badges show fractions (1/3 on the
   top axis, 2/3 on the left axis; the sample selection spans roughly 8 columns by 9 rows from
   column 3, row 3). Exact grid dimensions not certain.
2. "Keyboard shortcut" with an on/off toggle and a shortcut field (sample "^⌥O").
3. "Activation area for dragging" with an on/off toggle and a grid of dots with
   a highlighted rounded strip (sample: a vertical pill on the left, one column in from the
   edge) marking which screen region triggers this command while dragging. The grid has an
   outer ring of edge cells and an inner area, so zones can be edge cells or interior cells.

## Preferences (AS3), exact labels and shown values

Activation Areas
- Highlight activation areas when dragging: toggle (on)
- Choose activation areas' appearance: "Custom" popup plus color well (blue)
- Define activation areas' outline: stepper, 4 pt, plus color well
- Adjust scale of regular activation areas: stepper, 80 %
- Set width of screen edge activation areas: stepper, 12 pt

Target Areas (the preview overlay shown while dragging)
- Choose target areas' appearance: "Custom" popup plus color well
- Define target areas' outline: stepper, 2 pt, plus color well

Green Button
- Show green button menu: toggle (on). Help text: "When active, hovering over green button in windows' controls section (traffic lights) triggers dropdown menu with commands."
- Set green button menu hover delay: stepper, 100 ms
- Choose green button menu appearance: popup, "Compact" (other options not shown)

Spacing
- Add margins around windows: stepper, 8 pt
- Fit tightly to screen edges: toggle (on). Help text: "When active, margins are not applied near screen edges."

The list is cut at the bottom; more sections may follow (see Still unknown).

## Snap zones and drag behaviour (W3-W6, T)

Drawings show window outlines (three dots title bar) and zone indicators as small rounded
pills or circles on the screen outline.
- Landscape: four corner circles snap quarters (W4 left). Left and right edge vertical pills
  snap left and right halves (W4 middle). Pills at the top and bottom of each side edge (near corners) snap top and bottom
  halves (W4 right).
- Top edge: a pill centered at the top snaps maximize (W5 left; text "Dragging to the top
  edge maximizes").
- Bottom edge: three pills along the bottom (left, center, right) snap thirds; a long pill
  spanning two thirds plus a short one on the other third gives two thirds + one third
  (W5 middle/right; text "Bottom edge creates thirds. Slide on it to expand into two thirds").
- Portrait displays (W6, text "Create thirds along the sides on vertical display. Quarters
  and halves reside in the corners and on the bottom edge"): three stacked pills per side edge
  give three horizontal thirds; a long pill plus a short pill gives two thirds + one third;
  four corner circles give quarters; top and bottom side pills give top/bottom halves; two short pills on the bottom edge
  give left and right halves.
- Multi display: external monitor and laptop both shown tiled (W3); text says up to six
  external displays supported, Next/Previous Display actions move a window between them.
- Drag preview: window-shaped "target area" overlay with outline (default 2 pt) and
  configurable color; activation areas get highlighted (default 4 pt outline) while a window is
  dragged, edge zone width default 12 pt, corner/regular zones scaled to 80 %.

## Still unknown

- Menu bar dropdown contents and its icon (no screenshot found).
- Any Preferences sections below Spacing (launch at login, ignore apps, gestures, update
  settings, license, iCloud sync switch, shortcut for toggling).
- Default shortcuts for Center Two Thirds, Next Display, Previous Display, Center, Restore.
- Whether E/T are left/right two thirds or the reverse; name and shortcut of the maximize
  command in the list.
- Green button menu layout choices besides "Compact", appearance choices besides "Custom".
- Light theme appearance, exact grid dimensions of the custom command editor, meaning of the
  crossed-eye icon on corner rows.
- Behavior details (cycle between 1/2, 1/3, 2/3 on repeated press, restore-on-drag-out,
  keyboard-shortcut conflicts); none are visible in the images.
