# Settings: `~/.config/omagnet/config.toml`

Every setting is optional. A missing file, a missing key, or a value of the wrong type falls back to the default,
so a bad edit never turns a feature off. The settings are read when omagnet loads (a Hyprland reload).
A later batch adds a settings app that edits this file.

The format is a small subset of TOML: `key = value` lines, `[sections]`, `#` comments, and values that are
`true`, `false`, a plain number, or a `"quoted string"`. No arrays, no `#` inside a string.

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

Dragging a window that is already snapped away from its spot gives it its old size back, with the pointer kept at
the same place on the window.

## What it never touches

Windows on tiled or scrolling workspaces, real fullscreen windows, and windows whose class is in `ignore`.
A key pressed in such a window goes to the app.
