# Layout editor and per-monitor, per-desktop layouts: design

Request from the maintainer, 2026-11-05: do what PowerToys does, a section of the app where you customize layouts, give each
monitor and desktop its own, and preview them. Source of what PowerToys does: [fancyzones-reference/features.md](fancyzones-reference/features.md),
rows F19 to F26, F40, F41 (read from Microsoft's docs; the editor itself was not run).

## What we take

| FancyZones | omagnet | Notes |
|------------|---------|-------|
| F19 editor with a gallery of layouts, double-click applies | A **Layouts** page in the settings window: gallery of built-in and custom layouts with thumbnails, click to apply to the chosen monitor | |
| F20 grid layout: click to split, drag dividers, select zones and merge, delete merges into a neighbour | **Same**, on rectangles that always tile the screen | A divider moves only its connected segment |
| F21 canvas layout: free rectangles, may overlap | **Same**: add, move and resize rectangles | Overlapping zones already work in the drop (smallest wins) |
| F22 space around zones | Preview uses the real `margin` and `edge_tight`, so the preview is what a snap will do | |
| F40 layout per monitor | A monitor picker drawn with the monitor's own shape | Already supported in the config, now editable visually |
| F41 per virtual desktop | **Per workspace** (Hyprland's equivalent): `[workspace_layouts]` maps a workspace id to a layout | New: wins over the monitor's layout |
| F36 layout hotkey | A shortcut field per custom layout (`key` in its section) | Already supported |
| Preview | Thumbnail in the editor, plus **Show on screen**: draws the zones on the real monitors for a few seconds with the existing overlay | |

Left out: JSON export (the config file is the export), a layout hotkey 0 to 9 scheme, the CLI.

## Data

A custom layout stays what it is today: `[layout_<id>]` with `zones = "x y w h; ..."` (fractions) and an optional `key`. Grid and
canvas are two ways to edit the same rectangles, not two stored kinds. New: `[workspace_layouts]` with `3 = "coding"`.
Resolution order for a drop or a zone key: layout picked by key, workspace, monitor, default for the monitor's shape.

## Editing model (pure JavaScript, `LayoutOps.js`, tested in Node)

Zones are integers in ten-thousandths of the screen, so edges meet exactly and nothing drifts. Operations return a new list or `null`
(refused, with the list unchanged): `split`, `moveEdge` (connected segment only, clamped by a minimum size), `merge` (only when the
chosen zones make a rectangle), `remove` (a neighbour with a full shared edge takes the space), `add`, `setRect` (canvas),
`coverage` (gaps and overlaps, for a warning), text conversion, and the built-in layouts for thumbnails. A property test runs random
grid operations and checks the zones still tile the screen exactly.

## Plan

| Batch | Content | Test |
|-------|---------|------|
| L-A | `LayoutOps.js`, model helpers in `ConfigIO.js` (`withLayout`, `withoutLayout`, `withWorkspaceLayout`) | Node, cross-checked with `geometry.lua` |
| L-B | Lua: `[workspace_layouts]`, resolution order, `preview` function for Show on screen | unit, fake `hl`, live |
| L-C | QML: Layouts page, gallery with thumbnails, monitor and workspace assignment | real shell |
| L-D | QML: the editor (split, drag dividers, merge, delete, canvas rectangles, name, key, save, delete, Show on screen) | real shell, driven with the virtual mouse |
| L-E | Docs, checklist, README, screenshots | hand checks |

## Open questions

1. Hyprland workspace ids can be numbers or names; the first version supports numeric ids and names without spaces.
2. A divider shared by zones that only touch at a corner is treated as two segments.
3. QML cannot be compiled outside the real shell; each QML batch is loaded into it before it counts as done.
