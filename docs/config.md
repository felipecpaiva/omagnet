# Settings: `~/.config/omagnet/config.toml`

Every setting is optional. A missing file, a missing key, or a value of the wrong type falls back to the default,
so a bad edit never turns a feature off. The settings are read when omagnet loads (a Hyprland reload).
A later batch adds a settings app that edits this file.

The format is a small subset of TOML: `key = value` lines, `[sections]`, `#` comments, and values that are
`true`, `false`, a plain number, or a `"quoted string"`. No arrays, no escapes inside a string (a `#` inside quotes is fine).

```toml
# Switches
keys_enabled = true        # the keyboard shortcuts
drag_enabled = true        # SUPER + drag to an edge or corner

# Spacing (Magnet's defaults)
margin = 8                 # pixels between snapped windows
edge_tight = true          # no margin against the screen border
reserve_top = 0            # extra pixels to keep free, for example under a dock
reserve_bottom = 0
reserve_left = 0
reserve_right = 0

# Drag zones
edge_width = 12            # thickness of the active strip along a screen edge (Magnet's default)
corner_size = 64           # how far along an edge a corner zone reaches (our own pick)

# How the drag outline looks (Magnet's defaults: target outline 2, zone outline 4)
target_outline = 2         # pixels
target_color = ""          # "#rrggbb", or empty to match your theme: the colour of your windows' active border
                           # (read live from Hyprland, so it follows a theme change; a two-colour border gives a gradient fill)
target_fill = 0.18         # 0 to 1, how solid the fill of the target is
highlight = false          # show every drag zone while dragging; off by default, it starts the outline overlay
                           # (about 230 MB) at the start of every drag
highlight_outline = 4      # pixels

# The settings app's optional bar icon. Off by default: nothing is added to the bar until you turn it on in the app.
bar_icon = false

# Grid zones: hold zone_modifier while dragging to snap to a cell of the monitor's grid (see "Grid zones" below)
zones_enabled = true
zone_modifier = "SUPER + SHIFT"    # a change needs hyprctl reload
zone_span = 24                     # pixels near the shared edge of two zones where a drop covers both
layout_landscape = "auto"          # auto: a recommendation for the screen's size and shape (table below)
layout_portrait = "auto"

# Apps omagnet leaves alone (window classes, comma separated, case does not matter)
ignore = "steam, mpv"

# Shortcuts: any of these names, an empty string means no shortcut
[keys]
left = "CTRL + ALT + LEFT"
maximize = "CTRL + ALT + RETURN"
two_thirds_center = "CTRL + ALT + R"   # has no default key

# Your own positions: fractions of the usable area (0 to 1) and an optional key
[cmd_wide_center]
x = 0.1
y = 0
w = 0.8
h = 1
key = "CTRL + ALT + W"
```

Key strings are Hyprland's: every modifier joined with `+`, for example `CTRL + ALT + LEFT`.

## Default shortcuts

| Name | Key | Result |
|------|-----|--------|
| `left`, `right`, `top`, `bottom` | `CTRL + ALT` with an arrow | half of the screen |
| `top_left`, `top_right`, `bottom_left`, `bottom_right` | `CTRL + ALT + U / I / J / K` | quarter |
| `third_left`, `third_center`, `third_right` | `CTRL + ALT + D / F / G` | third |
| `two_thirds_left`, `two_thirds_right` | `CTRL + ALT + E / T` | two thirds |
| `two_thirds_center` | none | the middle two thirds |
| `maximize` | `CTRL + ALT + RETURN` | the whole usable area (not fullscreen) |
| `next_display`, `prev_display` | `SUPER + CTRL + ALT + RIGHT / LEFT` | send the window to the next or previous monitor (left to right, wrapping), keeping its relative place and size |
| `center` | `CTRL + ALT + C` | keep the size, centre the window |
| `restore` | `CTRL + ALT + BACKSPACE` | the size and place from before the first snap |

Display keys are our own picks. The keys copy Magnet's where its website shows them (arrows, `U I J K`, `D F G`, `E T`, `Return`). Centre, restore and
the middle two thirds are our own picks. Which of `E` and `T` is the left two thirds is not clear from Magnet's
sources; ours are `E` left and `T` right.

## Drag zones

Hold `SUPER` and drag a window with the left button. At a screen edge an outline shows the target; let go to snap.

| Where the pointer is | Result |
|----------------------|--------|
| In a corner | quarter |
| Left or right edge | half |
| Top edge | maximize |
| Bottom edge | a third; slide along the edge to the next third to get two thirds |

On a vertical (portrait) screen the side edges give thirds (top, middle, bottom, slide for two thirds) and the bottom
edge gives the left and right halves.

Dragging a window that is already snapped away from its spot gives it its old size back, with the pointer kept at
the same place on the window.

## Grid zones

Idea from PowerToys FancyZones ([research](fancyzones-reference/features.md), [design](zones-design.md)). Hold `SUPER + SHIFT`
and drag a window with the left mouse: every zone of the monitor under the pointer is drawn, the zone (or pair of zones) you
point at is filled in your theme's colour, and letting go snaps the window to it. It works on floating workspaces only.
`SHIFT` can also be pressed in the middle of an ordinary `SUPER` drag: the zones appear, and when you let go of `SHIFT` they
go away and the edge zones are back. The drag asks Hyprland whether `SHIFT` is down on every tick (`hl.is_key_down`), because
Hyprland sends no event for a key pressed during a drag. Whatever is held when you release the mouse decides where the window goes.

| Layout name | Zones |
|-------------|-------|
| `columns:N`, `rows:N` | N equal columns or rows, N from 1 to 12 |
| `grid:CxR` | C columns by R rows, numbered row by row, for example `grid:3x2` |
| `auto` | the default: a recommendation for the screen, see below |
| `priority` | three columns of 25, 50 and 25 percent |
| a `[layout_<name>]` section | your own rectangles, see below |

**auto** (the default for both landscape and portrait) picks a layout for each monitor from its logical size, the size after
scale and rotation, so zones work with no setup:

| Screen | Example | Layout |
|--------|---------|--------|
| Portrait, small | 1080x1920 at scale 2 | `rows:2` |
| Portrait, tall | 1080x1920 at scale 1 | `rows:3` |
| 32:9 or wider | 5120x1440 | `columns:4` |
| 21:9 ultrawide | 3440x1440 | `priority` (25, 50, 25 percent) |
| Under 1800 wide | a laptop, a Z13 at scale 2 (1280x800) | `columns:2` |
| Under 2300 wide | full HD at scale 1 | `grid:2x2` |
| Larger | 1440p, 4K at scale 1.5 | `grid:3x2` |

These are our reading of how such screens are used, not a standard. Choose your own in the settings window or in the file to
change it. The settings window shows what `auto` resolves to on each screen.

Which layout a monitor uses: one picked with a key (until the next Lua reload), else its entry in `[zone_layouts]`, else
`layout_landscape` or `layout_portrait` by its shape. A layout that cannot be read falls back to the `auto` recommendation
and the reason is kept in `_G.omagnet.last_error`.

```toml
[zone_layouts]
DP-1 = "columns:3"

[workspace_layouts]
3 = "coding"

[layout_coding]
zones = "0 0 0.25 1; 0.25 0 0.5 1; 0.75 0 0.25 0.5; 0.75 0.5 0.25 0.5"   # x y w h as fractions, ';' between zones
key = "SUPER + CTRL + ALT + 1"      # optional: switch the window's monitor to this layout
```

- **A layout per workspace:** `[workspace_layouts]` maps a workspace id (or name) to a layout name, for example `3 = "coding"`.
  It wins over the monitor's layout; a layout picked with a key still wins over both. Order: key, workspace, monitor, default.
- **Two zones at once:** within `zone_span` pixels of the shared edge of two zones (or four at a crossing), a drop covers
  all of them, as one rectangle.
- **Spacing** is the same `margin` and `edge_tight` as every other snap.
- **Overlapping zones** (a custom layout): the smallest zone under the pointer wins.
- **Keys:** `zone_next` and `zone_prev` (`CTRL + ALT + ]` and `[`) step the focused window through the zones of its
  monitor's layout, wrapping round; a window that does not fill a zone goes to its nearest zone first. `layout_next` and
  `layout_prev` (no default key) switch the layout of the window's monitor through your custom layouts, then
  `columns:2`, `columns:3`, `rows:2`, `rows:3`, `grid:2x2`, `grid:3x2`, `grid:3x3`, `priority`, and show a notification.
- A normal `SUPER` drag still does the edge snapping.

## What it never touches

Windows on tiled or scrolling workspaces, real fullscreen windows, and windows whose class is in `ignore`.
A key pressed in such a window goes to the app.
