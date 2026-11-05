# omagnet roadmap

Goal: every Magnet function that makes sense on Omarchy, planned, implemented, tested and
validated, one small batch at a time, working only on floating workspaces.

Magnet is the quality bar. Sources: [features.md](magnet-reference/features.md) and
[screenshots-findings.md](magnet-reference/screenshots-findings.md). Facts about Hyprland and Omarchy:
[hyprland-capabilities.md](research/hyprland-capabilities.md),
[omarchy-app-stack.md](research/omarchy-app-stack.md). Existing projects:
[existing-solutions.md](research/existing-solutions.md),
[omarchy-upstream-community.md](research/omarchy-upstream-community.md).

Last updated: 2026-11-05 (end of day). What is left: A5 (marketplace
listing; needs a packaging decision, see [architecture.md](architecture.md)), D6 (top and bottom halves by drag, blocked on
unclear Magnet drawings) and the hand checks in [validation-checklist.md](validation-checklist.md).

## Non-negotiable rules

1. **Floating workspaces only.** Every action checks the `omarchy-floating-workspace` tag. Tiled and
   scrolling workspaces are never touched. A test proves it for every feature.
2. **Nothing on the Omarchy bar by default.** A bar icon is an option the user turns on in the settings app.
3. **Pure Lua on Hyprland's own Lua API.** No native module that must be rebuilt after each Hyprland update.
4. **Own code, borrowed ideas.** Other projects are references (see
   [reference-code-review.md](research/reference-code-review.md)). If a snippet is copied, keep the MIT notice
   in `CREDITS.md`.
5. **Public repo.** No LAN IPs, hostnames, home paths or client names in any file.
6. Never `hl.unbind` a key we share with Omarchy (it removes Omarchy's own bind too).

## How a feature gets done

Each feature moves through four gates. A feature is **done** only when all four are ticked, or a reason
is written next to the gate that cannot apply.

| Gate | Meaning | Evidence kept |
|------|---------|---------------|
| **Plan** | Behaviour, defaults and edge cases written here, Magnet source cited | This file |
| **Impl** | Code merged to `main` | Commit |
| **Test** | Pure logic has a unit test (`lua lua/test_*.lua`); behaviour has a live scripted run on a throwaway window with a screenshot where it is visual | Test file and a line in the batch log |
| **Valid** | The maintainer tries it with a real mouse or keyboard on a floating workspace, or a written reason why a script is enough | Batch log |

Loop for every batch: plan the batch here, build it, run all tests, update the status table, commit and
push `omagnet`, update the workspace pointer, ask for the manual check, fix, then start the next batch.
An independent review agent reads the batch diff before the manual check.

Tests run with `bash tests/run-all.sh` (add `--no-live` anywhere without Hyprland). Pure tests use Lua 5.5 like
Hyprland. The live test types real keys through a virtual keyboard. Traps found so far: [gotchas.md](gotchas.md).

Legend: `-` not started, `P` planned, `I` implemented, `T` tested, `V` validated, `n/a` not applicable.

## Feature list

### A. Positions by keyboard

Default keys copy Magnet (Control + Option on a Mac is `CTRL + ALT` here; Hyprland needs every modifier joined with `+`). Checked on 2026-11-05: only
`CTRL + ALT + DELETE` and `CTRL + ALT + TAB` are used by Omarchy, so these are free.

| ID | Function (Magnet name) | Default key | Plan | Impl | Test | Valid |
|----|------------------------|-------------|------|------|------|-------|
| K1 | Left half | `CTRL + ALT + LEFT` | P | I | T | V (the maintainer, 2026-11-05) |
| K2 | Right half | `CTRL + ALT + RIGHT` | P | I | T | V (the maintainer, 2026-11-05) |
| K3 | Top half | `CTRL + ALT + UP` | P | I | T | V (the maintainer, 2026-11-05) |
| K4 | Bottom half | `CTRL + ALT + DOWN` | P | I | T | V (the maintainer, 2026-11-05) |
| K5 | Top left, top right, bottom left, bottom right | `CTRL + ALT + U / I / J / K` | P | I | T | V (the maintainer, 2026-11-05) |
| K6 | Left, center, right third | `CTRL + ALT + D / F / G` | P | I | T | V (the maintainer, 2026-11-05) |
| K7 | Left and right two thirds | `CTRL + ALT + E / T` (which is which is unconfirmed, see Open questions) | P | I | T | V (the maintainer, 2026-11-05) |
| K8 | Center two thirds | none in Magnet's visible list; we pick one | P | I | T (unit only; no default key) | -
| K9 | Maximize (whole usable area, not fullscreen) | `CTRL + ALT + RETURN` | P | I | T | V (the maintainer, 2026-11-05) |
| K10 | Center (keep size) | to pick | P | I | T | V (the maintainer, 2026-11-05) |
| K11 | Restore (previous size and place) | to pick | P | I | T | V (the maintainer, 2026-11-05) |
| K12 | Next and previous display | `SUPER + CTRL + ALT + RIGHT / LEFT` (the Magnet key list does not show it) | P | I | T (virtual monitor) | -
| K13 | Repeat a key to cycle (half, two thirds, one third) | none in Magnet's sources, so **not planned** (Rectangle has it; add on request) | P (not planned) | - | - | - |

Plan notes: a snap saves the window's first size and place in a window tag, so Restore works after many
snaps. Resize first and move second (floating resize is centre-anchored). A maximized window is
un-maximized first. A window that refuses a small size is left where the app put it, and we log it.

### B. Drag to snap

| ID | Function | Plan | Impl | Test | Valid |
|----|----------|------|------|------|-------|
| D1 | Left and right edge gives half | P | I | T | V (`SUPER` + drag, real Chrome window, 2026-11-05) |
| D2 | Top edge gives maximize | P | I | T | V (the maintainer, with the mouse, 2026-11-05) | D3 | Outline of where the window will land (Magnet "target area") | P | I | T (scripted, every zone) | V (the maintainer, 2026-11-05) |
| D3 | Outline of where the window will land (Magnet "target area") | P | I | T (scripted, every zone) | V (the maintainer, with the mouse, 2026-11-05) |
| D4 | Corners give quarters | P | I | T | V (the maintainer, with the mouse, 2026-11-05) | D5 | Bottom edge gives thirds, slide to get two thirds | P | I | T | V (the maintainer, 2026-11-05) |
| D5 | Bottom edge gives thirds, slide to get two thirds | P | I | T | V (the maintainer, with the mouse, 2026-11-05) |
| D6 | Top and bottom halves by drag (Magnet's drawings are unclear about where these zones sit; keyboard only until a Magnet screenshot settles it) | P (blocked) | - | - | - |
| D7 | Restore the old size when you drag a snapped window away (the pointer stays at the same spot on the window) | P | I | T (real mouse) | V (the maintainer, with the mouse, 2026-11-05) | D8 | Several monitors: zones follow the monitor under the cursor | P | I | T (virtual monitor, scripted pointer) | V (the maintainer, 2026-11-05) |
| D8 | Several monitors: zones follow the monitor under the cursor | P | I | T (virtual monitor, scripted pointer) | -
| D9 | Portrait displays: thirds along the side edges | P | I | T (unit tests; live on a rotated virtual monitor: every position, all the drag zones, the slide, a release) | -
| D10 | Highlight all activation areas while dragging (Magnet default on); moved to a later batch, it needs a different overlay | P | I (setting `highlight`, off by default because it starts the 230 MB overlay at every drag) | T (zone strips, screenshot) | - |
| D11 | Drag by an app's own title bar (Chrome, VS Code) also snaps | **Documented limit**: no bind fires for these drags and Hyprland's Lua has no drag event; only a native plugin could see them (rule 3) | - | - | - |

Plan notes: D1 to D3 are the current prototype. The `SUPER` + drag bind is the only drag signal we
proved. D11 needs a spike: no bind fires when an app moves its own window. Candidates are a Quickshell
global shortcut or a native plugin; native is against rule 3, so the spike decides whether D11 is
supported or documented as a limit.

### C. Settings (Magnet Preferences, translated)

Config file: `~/.config/omagnet/config.toml`, a flat TOML subset that both Lua and the settings app read.

| ID | Magnet setting (default) | Our setting | Plan | Impl | Test | Valid |
|----|---------------------------|-------------|------|------|------|-------|
| S1 | Config file the Lua reads, with safe defaults when missing or broken | `config.toml` | P | I | T | -
| S2 | Add margins around windows (8 pt) | `margin = 8` | P | I | T | -
| S3 | Fit tightly to screen edges, no margins near edges (on) | `edge_tight = true` | P | I | T | -
| S4 | Width of screen edge activation areas (12 pt) | `edge_width` (prototype uses 8 px) | P | I | T | -
| S5 | Scale of regular activation areas (80 %) | `corner_size = 64` pixels (how far a corner zone reaches along an edge; our own pick) | P | I | T | - |
| S6 | Highlight activation areas when dragging (on), outline 4 pt, colour | `highlight`, `highlight_outline`, colour follows theme accent | P | I | T (unit tests; screenshot with a red outline and highlight; settings window fields) | - |
| S7 | Target area appearance: outline 2 pt, colour | `target_outline`, `target_color` (default theme accent, stronger fill) | P | I | T (unit tests; screenshot; a colour typed in the settings window reached the running Lua) | - |
| S13 | **Requirement (maintainer, 2026-11-05):** the drag outline matches the theme by default: the colour of the windows' active border, read live from Hyprland, so it follows a theme change; a two-colour border gives a gradient fill; your own colour still wins | `target_color` empty means the theme | P | I | T (unit tests with a fake Hyprland, live check against the real value, screenshot of the gradient) | - |
| S8 | Turn trigger areas, keyboard shortcuts on and off separately | `drag = true`, `keys = true` | P | I | T | -
| S9 | Custom shortcuts for every command | `[keys]` table | P | I | T | -
| S10 | Ignore apps (not found in Magnet's sources; Rectangle has it) | `ignore = ["class", ...]` | P | I | T | -
| S11 | Keep space free, for example under the dock (the dock reserves none itself) | `reserve_top`, `reserve_bottom`, `reserve_left`, `reserve_right` in pixels | P | I | T | -
| S12 | Load at login | handled by the Hyprland config line or the plugin | P | I (one guarded line in the Hyprland config) | T (loaded after every reload in the tests) | - |

### D. Custom commands

| ID | Function | Plan | Impl | Test | Valid |
|----|----------|------|------|------|-------|
| C1 | User defines a rectangle on a grid (Magnet: about 24 by 14 cells), gives it a key and an optional drag area | P | I (the grid editor in the settings window) | T (rendered in the real shell; a typed name, a dragged rectangle, Add, delete: file and running Lua checked) | - |
| C2 | Config form of C1 (`[[command]]` with fractions) before any visual editor exists | P | I | T | -
| C3 | Visual grid editor in the settings app | P | I | T (same) | - |

### E. The settings app and the bar

| ID | Function | Plan | Impl | Test | Valid |
|----|----------|------|------|------|-------|
| A1 | Settings app as a Quickshell plugin panel, opened from the launcher, follows the Omarchy theme | P | I (the repo root) | T (JavaScript config reader and writer, validator; rendered in the real shell; a click on a switch wrote the file and the running Lua applied it without a reload) | - |
| A2 | Optional bar icon, **off by default**, switched on in the settings app (Magnet's menu bar icon is "hidable") | P | I (`BarWidget.qml`, self-hiding) | T (real bar: identical to the original with the icon off, icon shown with it on, click opens the settings window) | - |
| A3 | Icon menu with the main commands (Magnet menu bar menu; its contents are unknown). For now a click opens the settings window | P (partial) | I (click only) | - | - |
| A4 | Launcher entry (`.desktop`) | P | I (written by the plugin's service; the file exists) | - | - |
| A5 | Marketplace listing and `omarchy plugin add` install | P | - | - | - |

A2 note: `omarchy plugin enable` puts a widget entry for any bar-widget plugin into the bar layout. The widget hides
itself (no size, no gap) unless the icon is on, so nothing shows. Tested on the real bar: with the icon off it is
identical to the bar without the plugin. The layout in `shell.json` does list the plugin's id while the icon is off.

### F. Safety and quality (every batch)

| ID | Function | Plan | Impl | Test | Valid |
|----|----------|------|------|------|-------|
| Q1 | Floating-workspace guard on every action | P | I | T | - |
| Q2 | Tiled and scrolling workspaces untouched: a scripted check per feature | P | I | T (keys and maximized path; drag path pending) | - |
| Q3 | Survives `hyprctl reload`, layout toggle (`Super + L`), monitor hotplug | P | I | T (reload before every live run; a monitor added and removed; the layout toggle itself was not run) | - |
| Q4 | Windows with minimum size or fixed size: no crash, no stuck state | P | I | T (a fake window that refuses a size is retried once, not forever) | - |
| Q5 | Fullscreen and maximized windows handled | P | I | T (keys) | - |
| Q6 | Never a stuck outline: cap and cleanup tested (prototype has a 20 s cap) | P | I | T | - |
| Q7 | Geometry as pure functions with unit tests | P | I | T | - |
| Q8 | Public-repo scrub check script before every push | P | I (`tests/scrub.sh`, part of `run-all.sh`) | T (shown to catch a planted leak) | - |

### Not planned (no equivalent on Omarchy)

- **Green button menu** (hover the window's green button): Omarchy has no such button. The nearest
  idea is the icon menu (A3). Revisit if Omarchy titlebars gain a hook.
- **iCloud sync**: the config file lives in dotfiles or git instead.
- **macOS Accessibility permission, Spaces limit, Setapp, Family Sharing**: macOS only.

### Z. Grid zones (from PowerToys FancyZones, design in [zones-design.md](zones-design.md))

| ID | Function | Default | Plan | Impl | Test | Valid |
|----|----------|---------|------|------|------|-------|
| Z1 | Layouts as data: columns, rows, grid, priority, custom rectangles | config | P | I | T | - |
| Z2 | Zone under the pointer, nearest zone in a gap, smallest of overlapping zones | | P | I | T | - |
| Z3 | Two zones at a shared edge give the rectangle that covers both | | P | I | T | - |
| Z4 | Drag mode: `SUPER + SHIFT + drag` shows the zones and snaps to one on release | `SUPER + SHIFT` | P | I | T | - |
| Z5 | Overlay draws every zone and the active one in the theme colour | | P | I | T | - |
| Z6 | A layout per monitor, one for landscape and one for portrait | `grid:3x2` | P | I | T | - |
| Z7 | Keys to step a window through the zones | `CTRL + ALT + ] / [` | P | I | T | - |
| Z8 | Keys to switch layout: next and previous, or a key per custom layout | none | P | I | T | - |
| Z9 | Settings app: layout per monitor, spacing, modifier | | P | I | T (in the real shell: renders, a click wrote `[zone_layouts]`, the running Lua used it at once, Default removed it) | - |
| Z10 | Wheel to switch layout during a drag, layout name flash, refit on layout change | | not planned yet | - | - | - |

### L. Layout editor (design in [layout-editor-design.md](layout-editor-design.md))

| ID | Function | Plan | Impl | Test | Valid |
|----|----------|------|------|------|-------|
| L1 | Pure layout operations: split, move a divider, merge, remove, canvas add and resize, text conversion | P | - | - | - |
| L2 | A layout per workspace (`[workspace_layouts]`), resolved before the monitor's layout | P | - | - | - |
| L3 | Show on screen: draw a layout on the real monitors for a few seconds | P | - | - | - |
| L4 | Layouts page: gallery with thumbnails, apply to a monitor or a workspace | P | - | - | - |
| L5 | Editor: grid mode (split, dividers, merge, delete) | P | - | - | - |
| L6 | Editor: canvas mode (add, move, resize rectangles) | P | - | - | - |
| L7 | Editor: name, shortcut, save, delete, preview with the real margin | P | - | - | - |

## Batches

Each batch is small enough to finish and check in one sitting.

| Batch | Contents | Done when |
|-------|----------|-----------|
| **B1 Keyboard core** | S1 config loader, pure position table, K1 to K11, Q2, Q5, Q7, tag-based restore | Unit tests green, live scripted run of every key on a throwaway window, maintainer tries the keys |
| **B2 Spacing** | S2, S3, S11, K10 | Margins correct on edge and inside, tested at scale 2 and a fractional scale |
| **B3 Drag zones** (done 2026-11-05) | D2, D4, D5, S4, S5, outline for every zone (D3). D6 and D10 moved out, see their rows | Every zone gives the right rectangle and outline |
| **B4 Restore and displays** | D7, D8, K12, K13, Q3 | Drag away restores, windows move between two displays (needs a second monitor or a virtual one) |
| **B5 Settings app** | A1, A4, S6 to S9, S12 | Changing a setting in the app changes behaviour without a reload |
| **B6 Bar icon and packaging** | spike, A2, A3, A5 | Fresh install shows nothing on the bar; the toggle adds and removes the icon |
| **B7 Custom commands** (C2 and S10 done 2026-11-05, C1 and C3 need the app) | C1, C2, C3, S10 | A custom rectangle works by key and by drag |
| **B8 Hard cases** | D9, D11 spike, Q4, polish, upstream discussion or PR | Each hard case is either working or documented as a limit with its reason |

Batch log: see [batch-log.md](batch-log.md) (one entry per batch: what changed, tests run, results, the
maintainer's check).

## Open questions (need Magnet itself, not the web)

Menu bar menu contents; default keys for Center, Restore, Center Two Thirds, Next and Previous Display;
whether E is left or right two thirds; whether repeated presses cycle; Preferences sections below Spacing.
One screenshot each from a Mac that has Magnet would close all of these.
