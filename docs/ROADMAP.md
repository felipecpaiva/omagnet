# omagnet roadmap

Goal: every Magnet function that makes sense on Omarchy, planned, implemented, tested and
validated, one small batch at a time, working only on floating workspaces.

Magnet is the quality bar. Sources: [features.md](magnet-reference/features.md) and
[screenshots-findings.md](magnet-reference/screenshots-findings.md). Facts about Hyprland and Omarchy:
[hyprland-capabilities.md](research/hyprland-capabilities.md),
[omarchy-app-stack.md](research/omarchy-app-stack.md). Existing projects:
[existing-solutions.md](research/existing-solutions.md),
[omarchy-upstream-community.md](research/omarchy-upstream-community.md).

Last updated: 2026-11-05.

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
| **Test** | Pure logic has a unit test (`lua5.4 prototype/test_*.lua`); behaviour has a live scripted run on a throwaway window with a screenshot where it is visual | Test file and a line in the batch log |
| **Valid** | The maintainer tries it with a real mouse or keyboard on a floating workspace, or a written reason why a script is enough | Batch log |

Loop for every batch: plan the batch here, build it, run all tests, update the status table, commit and
push `omagnet`, update the workspace pointer, ask for the manual check, fix, then start the next batch.
An independent review agent reads the batch diff before the manual check.

Legend: `-` not started, `P` planned, `I` implemented, `T` tested, `V` validated, `n/a` not applicable.

## Feature list

### A. Positions by keyboard

Default keys copy Magnet (Control + Option on a Mac is `CTRL ALT` here). Checked on 2026-11-05: only
`CTRL ALT + DELETE` and `CTRL ALT + TAB` are used by Omarchy, so these are free.

| ID | Function (Magnet name) | Default key | Plan | Impl | Test | Valid |
|----|------------------------|-------------|------|------|------|-------|
| K1 | Left half | `CTRL ALT + LEFT` | P | - | - | - |
| K2 | Right half | `CTRL ALT + RIGHT` | P | - | - | - |
| K3 | Top half | `CTRL ALT + UP` | P | - | - | - |
| K4 | Bottom half | `CTRL ALT + DOWN` | P | - | - | - |
| K5 | Top left, top right, bottom left, bottom right | `CTRL ALT + U / I / J / K` | P | - | - | - |
| K6 | Left, center, right third | `CTRL ALT + D / F / G` | P | - | - | - |
| K7 | Left and right two thirds | `CTRL ALT + E / T` (which is which is unconfirmed, see Open questions) | P | - | - | - |
| K8 | Center two thirds | none in Magnet's visible list; we pick one | P | - | - | - |
| K9 | Maximize (whole usable area, not fullscreen) | `CTRL ALT + RETURN` | P | - | - | - |
| K10 | Center (keep size) | to pick | P | - | - | - |
| K11 | Restore (previous size and place) | to pick | P | - | - | - |
| K12 | Next and previous display | `SUPER CTRL ALT + RIGHT / LEFT` (the Magnet key list does not show it) | P | - | - | - |
| K13 | Repeat a key to cycle (half, two thirds, one third) | none in Magnet's sources | P | - | - | - |

Plan notes: a snap saves the window's first size and place in a window tag, so Restore works after many
snaps. Resize first and move second (floating resize is centre-anchored). A maximized window is
un-maximized first. A window that refuses a small size is left where the app put it, and we log it.

### B. Drag to snap

| ID | Function | Plan | Impl | Test | Valid |
|----|----------|------|------|------|-------|
| D1 | Left and right edge gives half | P | I | T | V (`SUPER` + drag, real Chrome window, 2026-11-05) |
| D2 | Top edge gives maximize | P | I | T | - |
| D3 | Outline of where the window will land (Magnet "target area") | P | I | T (scripted, screenshot) | - |
| D4 | Corners give quarters | P | - | - | - |
| D5 | Bottom edge gives thirds, slide to get two thirds | P | - | - | - |
| D6 | Top and bottom halves from the side edges near corners (Magnet draws these pills) | P | - | - | - |
| D7 | Restore the old size when you drag a snapped window away | P | - | - | - |
| D8 | Several monitors: zones follow the monitor under the cursor | P | - | - | - |
| D9 | Portrait displays: thirds along the side edges | P | - | - | - |
| D10 | Highlight all activation areas while dragging (Magnet default on) | P | - | - | - |
| D11 | Drag by an app's own title bar (Chrome, VS Code) also snaps | P (spike first) | - | - | - |

Plan notes: D1 to D3 are the current prototype. The `SUPER` + drag bind is the only drag signal we
proved. D11 needs a spike: no bind fires when an app moves its own window. Candidates are a Quickshell
global shortcut or a native plugin; native is against rule 3, so the spike decides whether D11 is
supported or documented as a limit.

### C. Settings (Magnet Preferences, translated)

Config file: `~/.config/omagnet/config.toml`, a flat TOML subset that both Lua and the settings app read.

| ID | Magnet setting (default) | Our setting | Plan | Impl | Test | Valid |
|----|---------------------------|-------------|------|------|------|-------|
| S1 | Config file the Lua reads, with safe defaults when missing or broken | `config.toml` | P | - | - | - |
| S2 | Add margins around windows (8 pt) | `margin = 8` | P | - | - | - |
| S3 | Fit tightly to screen edges, no margins near edges (on) | `edge_tight = true` | P | - | - | - |
| S4 | Width of screen edge activation areas (12 pt) | `edge_width` (prototype uses 8 px) | P | - | - | - |
| S5 | Scale of regular activation areas (80 %) | `zone_scale = 0.8` | P | - | - | - |
| S6 | Highlight activation areas when dragging (on), outline 4 pt, colour | `highlight`, `highlight_outline`, colour follows theme accent | P | - | - | - |
| S7 | Target area appearance: outline 2 pt, colour | `target_outline`, `target_color` (default theme accent, stronger fill) | P | - | - | - |
| S8 | Turn trigger areas, keyboard shortcuts on and off separately | `drag = true`, `keys = true` | P | - | - | - |
| S9 | Custom shortcuts for every command | `[keys]` table | P | - | - | - |
| S10 | Ignore apps (not found in Magnet's sources; Rectangle has it) | `ignore = ["class", ...]` | P | - | - | - |
| S11 | Gap to the dock | `dock_gap` (the dock reserves no space, see research) | P | - | - | - |
| S12 | Load at login | handled by the Hyprland config line or the plugin | P | - | - | - |

### D. Custom commands

| ID | Function | Plan | Impl | Test | Valid |
|----|----------|------|------|------|-------|
| C1 | User defines a rectangle on a grid (Magnet: about 24 by 14 cells), gives it a key and an optional drag area | P | - | - | - |
| C2 | Config form of C1 (`[[command]]` with fractions) before any visual editor exists | P | - | - | - |
| C3 | Visual grid editor in the settings app | P | - | - | - |

### E. The settings app and the bar

| ID | Function | Plan | Impl | Test | Valid |
|----|----------|------|------|------|-------|
| A1 | Settings app as a Quickshell plugin panel, opened from the launcher, follows the Omarchy theme | P | - | - | - |
| A2 | Optional bar icon, **off by default**, switched on in the settings app (Magnet's menu bar icon is "hidable") | P (design risk: see below) | - | - | - |
| A3 | Icon menu with the main commands (Magnet menu bar menu; contents unknown) | P | - | - | - |
| A4 | Launcher entry (`.desktop`) | P | - | - | - |
| A5 | Marketplace listing and `omarchy plugin add` install | P | - | - | - |

A2 risk: `omarchy plugin enable` puts any bar-widget plugin on the bar, and disabling a widget unloads
the panel. Two designs were compared in
[omarchy-app-stack.md](research/omarchy-app-stack.md): a self-hiding widget (recommended) or two plugins.
Neither was tested. Batch 6 starts with a spike that tests the self-hiding widget on a real bar.

### F. Safety and quality (every batch)

| ID | Function | Plan | Impl | Test | Valid |
|----|----------|------|------|------|-------|
| Q1 | Floating-workspace guard on every action | P | I | T | - |
| Q2 | Tiled and scrolling workspaces untouched: a scripted check per feature | P | - | - | - |
| Q3 | Survives `hyprctl reload`, layout toggle (`Super + L`), monitor hotplug | P | - | - | - |
| Q4 | Windows with minimum size or fixed size: no crash, no stuck state | P | - | - | - |
| Q5 | Fullscreen and maximized windows handled | P | - | - | - |
| Q6 | Never a stuck outline: cap and cleanup tested (prototype has a 20 s cap) | P | I | T | - |
| Q7 | Geometry as pure functions with unit tests | P | I | T | - |
| Q8 | Public-repo scrub check script before every push | P | - | - | - |

### Not planned (no equivalent on Omarchy)

- **Green button menu** (hover the window's green button): Omarchy has no such button. The nearest
  idea is the icon menu (A3). Revisit if Omarchy titlebars gain a hook.
- **iCloud sync**: the config file lives in dotfiles or git instead.
- **macOS Accessibility permission, Spaces limit, Setapp, Family Sharing**: macOS only.

## Batches

Each batch is small enough to finish and check in one sitting.

| Batch | Contents | Done when |
|-------|----------|-----------|
| **B1 Keyboard core** | S1 config loader, pure position table, K1 to K11, Q2, Q5, Q7, tag-based restore | Unit tests green, live scripted run of every key on a throwaway window, maintainer tries the keys |
| **B2 Spacing** | S2, S3, S11, K10 | Margins correct on edge and inside, tested at scale 2 and a fractional scale |
| **B3 Drag zones** | D2, D4, D5, D6, S4, S5, outline for every zone (D3), D10 | Every zone snaps with the right rectangle and outline |
| **B4 Restore and displays** | D7, D8, K12, K13, Q3 | Drag away restores, windows move between two displays (needs a second monitor or a virtual one) |
| **B5 Settings app** | A1, A4, S6 to S9, S12 | Changing a setting in the app changes behaviour without a reload |
| **B6 Bar icon and packaging** | spike, A2, A3, A5 | Fresh install shows nothing on the bar; the toggle adds and removes the icon |
| **B7 Custom commands** | C1, C2, C3, S10 | A custom rectangle works by key and by drag |
| **B8 Hard cases** | D9, D11 spike, Q4, polish, upstream discussion or PR | Each hard case is either working or documented as a limit with its reason |

Batch log: see [batch-log.md](batch-log.md) (one entry per batch: what changed, tests run, results, the
maintainer's check).

## Open questions (need Magnet itself, not the web)

Menu bar menu contents; default keys for Center, Restore, Center Two Thirds, Next and Previous Display;
whether E is left or right two thirds; whether repeated presses cycle; Preferences sections below Spacing.
One screenshot each from a Mac that has Magnet would close all of these.
