# Marketplace listing text (draft, do not submit without the maintainer's go)

The marketplace builds its card from `preview.png` at the repo root and the fields in `manifest.json`. Listing requests go to `omacom/omarchy-plugin-marketplace` as an issue.

**Name:** omagnet
**One line (under 80 characters):** Magnet-style window snapping for floating workspaces
**Category:** Utilities
**Licence:** MIT
**Repo:** https://github.com/felipecpaiva/omagnet

**Description**

Snap windows to halves, thirds, quarters or the whole screen with shortcuts or by dragging to a screen edge. Floating workspaces only: tiled and scrolling workspaces are never touched. The outline follows your theme's window border colour. Custom positions come from a grid editor in the settings window. Pure Lua, no native module, nothing added to the bar unless you switch the icon on.

**Needs:** one added line in `hyprland.lua` to load the snapping module (the README has it). A plugin cannot edit that file for you.

**Known limits:** drags started from an app's own title bar are not seen. Real second monitors are untested.

**Tags:** window snapping, floating, hyprland, utilities
**Media:** `preview.png` (root), `branding/demo/demo.gif`, `branding/screens/settings-top.png`, `branding/screens/settings-bottom.png`
