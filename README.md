# omagnet

Magnet-style window snapping for Omarchy's **floating workspace mode**. Drag a window to a screen edge
or press a shortcut, and it snaps to a half, third, quarter or the full screen. It does nothing in the
dwindle or scrolling layouts.

Status as of 2026-11-05: **a working prototype, built in small batches** (see
[docs/ROADMAP.md](docs/ROADMAP.md) for what is done and what is next). Keyboard shortcuts, margins, restore and
drag-to-edge with an outline all work and are tested. A settings app is in [plugin/](plugin/) (a Quickshell panel; it adds nothing to the bar); an optional bar icon (off by default) can be turned on in it.
Every claim in the docs says how it was checked.

**Research finding (2026-11-05):** core Omarchy has no snapping, but two community plugins already do
floating-workspace snapping: [omarchy-zones](https://github.com/austinwilkerson/omarchy-zones) (zone
layouts) and [omarchy-gridnet](https://github.com/hudrucan/omarchy-gridnet) (edges, corners, nine
keyboard shortcuts). Both compile a native module and add a bar icon. omagnet is pure Lua, keyboard first, and adds
nothing to the bar by default, so it stays a separate project; it may feed ideas upstream later.

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
| [docs/ROADMAP.md](docs/ROADMAP.md) | Every planned function, its status, the rules, and the batch order |
| [docs/config.md](docs/config.md) | Every setting, the default shortcuts and the drag zones |
| [docs/batch-log.md](docs/batch-log.md) | What each batch changed, its tests and the maintainer's check |
| [docs/magnet-reference/features.md](docs/magnet-reference/features.md) | Every Magnet function and where each fact came from |
| [docs/magnet-reference/screenshots-findings.md](docs/magnet-reference/screenshots-findings.md) | Magnet shortcuts and settings read from public screenshots |
| [docs/research/existing-solutions.md](docs/research/existing-solutions.md) | Window snappers on Mac, Windows, Linux and Hyprland |
| [docs/research/omarchy-upstream-community.md](docs/research/omarchy-upstream-community.md) | What core Omarchy and its plugin community already have |
| [docs/research/hyprland-capabilities.md](docs/research/hyprland-capabilities.md) | What Hyprland 0.56 Lua can do for snapping, tested on one machine |
| [docs/research/omarchy-app-stack.md](docs/research/omarchy-app-stack.md) | How an Omarchy plugin or app is built, packaged and kept off the bar |
| docs/architecture.md | Parts, folder layout, approaches and the chosen one (written after research) |

## Prototype (Batch 1 done, see [docs/ROADMAP.md](docs/ROADMAP.md))

Pure Lua on Hyprland's own Lua API, in [prototype/](prototype/). On a floating workspace only:

- **Keyboard:** `CTRL + ALT` with arrows (halves), `U I J K` (quarters), `D F G` (thirds), `E T` (two thirds),
  `Return` (maximize), `C` (centre), `Backspace` (restore the size from before the first snap).
  Every key is changeable in `~/.config/omagnet/config.toml`; a key on any other kind of window goes to the app.
- **Drag:** hold `SUPER` + left mouse, drag to the left or right edge (half) or the top edge (whole area),
  and an outline shows where the window will land; let go and it snaps.

Load it with one line in `~/.config/hypr/hyprland.lua`:
`pcall(dofile, os.getenv("HOME") .. "/<path to this repo>/prototype/omagnet-snap.lua")`.

Tests: `bash tests/run-all.sh` (pure tests plus a live test that types real keys through a virtual keyboard;
`--no-live` skips it). Traps found on the way: [docs/gotchas.md](docs/gotchas.md).
