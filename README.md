# omagnet

Magnet-style window snapping for Omarchy's **floating workspace mode**. Drag a window to a screen edge
or press a shortcut, and it snaps to a half, third, quarter or the full screen. It does nothing in the
dwindle or scrolling layouts.

Status as of 2026-11-05: **research and design only. No code yet.** Nothing here is a finished guide.
Every claim in the docs says how it was checked.

**Research finding (2026-11-05):** core Omarchy has no snapping, but two community plugins already do
floating-workspace snapping: [omarchy-zones](https://github.com/austinwilkerson/omarchy-zones) (zone
layouts) and [omarchy-gridnet](https://github.com/hudrucan/omarchy-gridnet) (edges, corners, nine
keyboard shortcuts). Both are days old, untested by us, and both add a bar icon. The build-or-contribute
decision is open; no architecture is written yet.

## Rules for this project

1. [Magnet](https://magnet.crowdcafe.com/) (macOS) is the quality bar. Every function it has gets
   ported or gets a written reason why not. See [docs/magnet-reference/features.md](docs/magnet-reference/features.md).
2. It works only on a floating workspace. It must not change tiled or scrolling workspaces.
3. It adds **nothing to the Omarchy bar** by default. A bar icon is an option the user turns on.
4. It ships with its own small settings app, built the way Omarchy's own apps are built.
5. Public repo: no LAN IPs, hostnames, home paths or client names in any file.

## Docs

| File | What it holds |
|------|---------------|
| [docs/magnet-reference/features.md](docs/magnet-reference/features.md) | Every Magnet function and where each fact came from |
| [docs/magnet-reference/screenshots-findings.md](docs/magnet-reference/screenshots-findings.md) | Magnet shortcuts and settings read from public screenshots |
| [docs/research/existing-solutions.md](docs/research/existing-solutions.md) | Window snappers on Mac, Windows, Linux and Hyprland |
| [docs/research/omarchy-upstream-community.md](docs/research/omarchy-upstream-community.md) | What core Omarchy and its plugin community already have |
| [docs/research/hyprland-capabilities.md](docs/research/hyprland-capabilities.md) | What Hyprland 0.56 Lua can do for snapping, tested on one machine |
| [docs/research/omarchy-app-stack.md](docs/research/omarchy-app-stack.md) | How an Omarchy plugin or app is built, packaged and kept off the bar |
| docs/architecture.md | Parts, folder layout, approaches and the chosen one (written after research) |

## Prototype

[prototype/omagnet-snap.lua](prototype/omagnet-snap.lua): drag a window with `SUPER` + left mouse to the
left or right edge and let go, and it snaps to that half; the top edge fills the usable area. Floating
workspaces only. Pure logic is checked by `lua5.4 prototype/test_rect.lua`. Status 2026-11-05: the
snap logic is tested on a real window; the release-after-drag signal is **not yet tested with a real
mouse**. Load it live with `hyprctl eval 'dofile("<path>/prototype/omagnet-snap.lua")'`.
