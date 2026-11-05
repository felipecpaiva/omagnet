# Grid zones (from PowerToys FancyZones): design

Idea from the maintainer, 2026-11-05: hold a modifier while dragging a window and snap it straight to a cell of a grid that
fits the monitor. PowerToys FancyZones does this on Windows. Magnet does not. Research:
[fancyzones-reference/features.md](fancyzones-reference/features.md) (55 features, read from Microsoft's docs and source; the
fetch tool summarised files, so exact numbers are to be re-checked before they are relied on).

## What we take, what we leave

| FancyZones | omagnet | Why |
|------------|---------|-----|
| F1 hold Shift to show zones | **Yes, as its own bind**: `SUPER + SHIFT + drag`. Normal `SUPER + drag` keeps the edge snapping | Hyprland sends no event for a key pressed in the middle of a drag, but `hl.is_key_down("Shift_L")` can be asked on every tick, so SHIFT pressed during a plain SUPER drag shows the zones too (2026-11-05) |
| F7 key released mid-drag | **Zones hide, the drag goes back to the edge zones** | Settled once `hl.is_key_down` was found (see the first row) |
| F13 to F18 templates | **Yes** as data: `columns:N`, `rows:N`, `grid:CxR`, `priority` (25/50/25) | Easy, and covers what people use |
| F20, F21 custom layouts | **Yes, as text in the config**: `[layout_<name>]` with a list of rectangles (fractions). No visual editor in v1 | Our own 24 by 14 grid editor can be reused later |
| F22 spacing | **Yes**: the existing `margin` and `edge_tight` | Same rule as every other snap |
| F24 sensitivity | **Yes**, a pixel distance around each zone (default 0, a gap between zones picks the nearest centre) | FancyZones default 20 is unconfirmed |
| F27 to F30 two zones at the edge | **Yes**: near the shared edge of two zones, take the rectangle that covers both (union of the zones' boxes) | Needs no key, so it works in our bind model |
| F28 Ctrl for more zones | No in v1 | A key pressed mid-drag cannot be seen |
| F31 overlapping zones | Smallest zone wins, as FancyZones' default | Only matters for custom layouts |
| F32 to F35 move between zones by key | **Yes**: `zone_next`, `zone_prev` step a window through the zones of its monitor's layout | Magnet users expect keys |
| F36 quick layout switch | **Yes**: `layout_next`, `layout_prev` (no default keys, so nothing is taken from Omarchy), and a `key` on any `[layout_<name>]` section that switches to that layout | |
| F40 layout per monitor | **Yes**: `[zone_layouts]` maps a monitor name to a layout; a default for landscape and one for portrait | Core of "a grid based on your monitor" |
| F43 refit windows when the layout changes | Later | Needs zone membership state |
| F47 restore size when unsnapping | Already there (restore on drag away) | |
| F50 excluded apps | Already there (`ignore`) | |
| F8, F9, F12 wheel switch, name flash | Later | Cosmetic |
| F19 to F21 editor, F26 JSON, F41 virtual desktops, F44 to F46, F48 to F55 | No | Windows only, or an editor that is too big for v1 |

## Behaviour

- **Start:** `SUPER + SHIFT + left mouse`, on a floating workspace only. We add the same kind of bind Omarchy uses
  (`hl.dsp.window.drag()`, `mouse = true`) so Hyprland still moves the window, plus our three non-consuming binds.
- **While dragging:** every zone of the monitor under the pointer is drawn, and the zone (or pair of zones) the pointer points at
  is filled in the theme's border colour. Leaving the monitor switches to that monitor's layout.
- **On release:** the window takes the zone rectangle, through the same `apply` as every other snap: margin rules, exact size
  check, saved original size for Restore, ignore list.
- **Layout choice:** `[zone_layouts]` per monitor name, else `layout_landscape` or `layout_portrait`, else the default for its shape, `auto`: a recommendation from the monitor's logical size (see [config.md](config.md#grid-zones)).
- **Keys:** `zone_next`, `zone_prev` (default `CTRL + ALT + BRACKETRIGHT` and `BRACKETLEFT`, which Omarchy does not use; to be
  checked live), `layout_next`, `layout_prev` (no default) and a `key` per custom layout.
- **Settings app:** pick the layout per monitor, the spacing and the activation modifier. Custom layouts stay in the file.

## Layout format

```toml
layout_landscape = "auto"
layout_portrait = "auto"
zone_modifier = "SUPER + SHIFT"        # the drag bind; a change needs hyprctl reload

[zone_layouts]
DP-1 = "columns:3"

[layout_coding]
zones = "0 0 0.25 1; 0.25 0 0.5 1; 0.75 0 0.25 0.5; 0.75 0.5 0.25 0.5"   # x y w h as fractions, a ';' between zones
key = "SUPER + CTRL + ALT + 1"         # optional quick switch
```

A layout name is `columns:N`, `rows:N`, `grid:CxR`, `priority`, or a `[layout_<name>]` section.

## Plan (batches, each: build, test, update this table, commit)

Status 2026-11-05: Z-A to Z-F built and tested (unit, fake `hl`, live on the real screen); Z-G is the settings app.

| Batch | Content | Test |
|-------|---------|------|
| Z-A | Pure geometry: layout generators, zone from pointer, pair at an edge, union, margins | `lua/test_geometry.lua` |
| Z-B | Config keys and sections in `config.lua` and `ConfigIO.js` | `test_config.lua`, the Node cross-check |
| Z-C | Glue: the zone bind, drag mode, zone snap on release, ignore list, floating guard | fake `hl` glue test |
| Z-D | Overlay draws the zones and the active one | `tests/live_overlay.py` screenshot |
| Z-E | Live drag test on a virtual monitor, several scales | `tests/live_zones.py` |
| Z-F | Keys: zone and layout stepping | live test |
| Z-G | Settings app, docs, checklist, README | hand checks |

## Open questions

1. FancyZones' highlight distance and sensitivity defaults are unconfirmed (the docs give none). We pick our own: 0 and 24 px.
2. Whether `SUPER + SHIFT + drag` collides with something on the maintainer's setup: checked free in Omarchy's default binds
   (2026-11-05), to be rechecked live.
3. Whether the overlay can show many zones without a visible lag (the existing one draws up to six strips).
