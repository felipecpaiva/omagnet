# omagnet

Magnet-style window snapping for Omarchy's **floating workspace mode**. Drag a window to a screen edge
or press a shortcut, and it snaps to a half, third, quarter or the full screen. It does nothing in the
dwindle or scrolling layouts.

Status as of 2026-11-05: **research and design only. No code yet.** Nothing here is a finished guide.
Every claim in the docs says how it was checked.

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
| docs/research/ | Product research, what Omarchy and its community already have, what Hyprland can do |
| docs/architecture.md | Parts, folder layout, approaches and the chosen one (written after research) |
