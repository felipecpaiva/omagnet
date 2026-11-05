# Omarchy upstream and community: is Magnet-style snapping for floating windows already there?

Research date: 2026-11-05. Evidence tags: **read** = I opened the issue, PR, discussion or README and read the text; **search result only** = seen in a search listing or web summary, not opened.

## Verdict

**Not nothing. Something similar already exists, but only as community plugins, not in Omarchy core.**

1. Core Omarchy has no snapping and, by a deliberate maintainer decision, dropped it before merge (read, see PR #14482 below). No open core issue or PR asks for snap, magnet, rectangle, halves, quarters or zones (searches below; the closest are keyboard move and size-cap PRs).
2. At least two plugins in the marketplace pipeline do close to exactly what Magnet does on Omarchy 4.5 floating workspaces:
   - **Omarchy Gridnet** (formerly Omasnap, `hudrucan/omarchy-gridnet`): drag-to-edge/corner snap with live preview, drag-away restores size, plus nine keyboard shortcuts (Ctrl+Alt+Shift with arrows for halves, U/I/J/K for quarters, Enter for maximize). Floating workspaces only. Marketplace listing request #13736 is still open (read).
   - **Floating Snap Zones** (formerly Omarchy Zones, `austinwilkerson/omarchy-zones`): FancyZones-style layouts (halves, thirds, quarters, 4-square grid, overlapping zones), per-monitor and per-workspace layouts, edge gestures, landing preview. Pointer/drag driven; the README read shows no keyboard shortcuts. Listing update #13904 is open (read).
3. Both plugins need a locally compiled native Hyprland module (C++ against matching Hyprland headers), loaded into the compositor, and must be rebuilt per Hyprland release. That is the main weak point a different design could avoid.

So a new "omagnet" is only worth building if it differs: for example no native module (pure Lua/hyprctl, keyboard first), Magnet/Rectangle-exact shortcuts and cycling (half, then two thirds, then one third on repeat), or tiled/scrolling workspace support.

## Maintainer stance (scope)

| Claim | Evidence | Tag |
|---|---|---|
| The first version of #14482 (by maintainer ryanrhughes) included drag-to-edge snap (left/right half, top maximize) and a minimize Shelf. | commit 367f94b8, 2026-10-07 | read |
| Four days later the same author removed it: commit 97fd964c "Drop minimizing and edge snapping from floating workspaces": "A floating workspace is now titlebars with maximize and close, and nothing else... the titlebar plugin's edge snapping is left off, along with the shell's snap preview." PR body at merge: "There's no minimizing and no edge snapping." | commit 97fd964c, 2026-10-11; merged 2026-10-11 | read |
| No reason for the removal is written in the PR or commit. No DHH comment on #14482 (timeline shows only the bot and one reviewer). So the rationale is unknown; it reads as "keep first release minimal". | #14482 timeline | read |
| Minimize came back later as Super+M to the dock (4.5 news), so removed scope can return. Snapping did not. | news post; manual | read |
| The titlebars plugin README still describes a test "dragging to the screen edges without snapping", i.e. snapping is deliberately off in the plugin. | omacom/omarchy-hyprland-titlebars README | read |
| The 4.5 announcement and the manual Navigation page never mention snapping. Manual lists Super+Shift+Ctrl+Arrows (move to monitor), Super+Alt+F (full width), titlebar double-click maximize, edge drag resize. | omarchy.org/news/2026/11/omarchy-4-5/ and /manual/navigation/ | read |
| Marketplace maintainers (HANCORE-linux) review and accept snapping-type plugins (Snap Layouts, Arrange) with the `installer` capability. Native-module snap plugins are in the verified queue. | #11809, #11763, #13904 | read |
| No statement from DHH about snapping or floating scope found. | searches below | search result only (absence) |

Implication: upstream core will probably not take a snapping PR soon (they removed it), but the plugin route is open and active.

## Table: core repo omacom/omarchy

| # | Link | State | Why it matters | Tag |
|---|---|---|---|---|
| 14482 | https://github.com/omacom/omarchy/pull/14482 | merged 2026-10-11 | The floating workspace feature. Snapping and minimize removed before merge (see stance). | read |
| 8260 | https://github.com/omacom/omarchy/pull/8260 | closed | Earlier Super+L floating cycle PR, superseded by #14482. Explains why floating is a per-window property in Hyprland, not a layout. | read |
| 15266 | https://github.com/omacom/omarchy/pull/15266 | merged | DHH-authored workspace default-layout follow-up. Only DHH item found touching floating, nothing about snapping. | read |
| 11503 | https://github.com/omacom/omarchy/pull/11503 | open | Keyboard move of floating windows (Super+Ctrl+Shift+Arrow, 25 px steps). Closest core request; no maintainer reply. Note the 4.5 manual now uses Super+Shift+Ctrl+Arrows for monitor move, so a conflict is likely. | read |
| 16340 | https://github.com/omacom/omarchy/pull/16340 | open | Caps floating window sizes to 90% of monitor. | read |
| 17626 | https://github.com/omacom/omarchy/pull/17626 | open | Keeps a floating window on screen when moved across monitors. | read |
| 16262 | https://github.com/omacom/omarchy/pull/16262 | open | Scopes border resize to floating mode (resize_on_border was turned on globally by #14482). | read |
| 16497 | https://github.com/omacom/omarchy/pull/16497 | open | Maximized window restore on floating workspaces. | read |
| 8557 | https://github.com/omacom/omarchy/pull/8557 | open | Send floating window to back/front keybindings. Shows window keybinding PRs are accepted for review. | read |
| 13569 | https://github.com/omacom/omarchy/pull/13569 | open | Floating bar option. Not window snapping, listed only because it matched "floating". | read |
| 9113 | https://github.com/omacom/omarchy/pull/9113 | open | Ours: Super+Shift+J toggles 2/3 : 1/3 split. Tiled only. | read |
| 17391, 17049, 16974, 16973, 16242, 16366, 15996, 16736, 16241 | e.g. https://github.com/omacom/omarchy/issues/17049 | open | Floating workspace bugs (maximize/unmaximize, stacking, titlebars, pen input). Any snap plugin must coexist with these. 17391, 17049, 16974, 16973, 16242, 16366 titles seen in search; 17049 summary read via PR text. | search result only |
| 16156, 16404, 16407, 16546, 16888, 17360, 17491, 17538, 17540, 17541, 17575, 17632, 17646 | search listing | open | More floating/dock/minimize fixes from the last two weeks, showing the feature is still in heavy churn. | search result only |
| 16199 | https://github.com/omacom/omarchy/issues/16199 | open | Floating windows can be dragged under the top bar. Snap clamping would need to respect bar reservation. | search result only |
| 5072 | https://github.com/omacom/omarchy/issues/5072 | open | Drag misalignment across workspaces; matched "snap" only incidentally. | search result only |
| 17575, 17538 | https://github.com/omacom/omarchy/pull/17575 | open | Dock on all workspace layouts; dock reserves screen area that snap zones must honor. | search result only |

All other hits for "snap" in the core repo (capture picker, snap-pac, monitor arrangement, fractional scaling) are unrelated.

## Table: discussions (omacom/omarchy)

| # | Link | State | Why it matters | Tag |
|---|---|---|---|---|
| 3146 | https://github.com/omacom/omarchy/discussions/3146 | open | Ultrawide window regions request (Nov 2025). Replies point to dwindle/master tuning and the community Quilt layout plugin. | read |
| 1528 | https://github.com/omacom/omarchy/discussions/1528 | closed | Center a window 20/60/20 on ultrawide; answer was Super+right-drag; a follow-up asks for a no-mouse way. | read |
| 9744 | https://github.com/omacom/omarchy/discussions/9744 | open | Request for a keybinding that enlarges a floating window to the work area without fullscreen state. No replies. Nearest thing to "maximize" in Magnet. | read |
| 16605 | https://github.com/omacom/omarchy/discussions/16605 | open | Make auto-unmaximize on floating workspaces configurable. No replies. | read |
| 15995 | https://github.com/omacom/omarchy/discussions/15995 | open | Dock independent of floating workspaces. No replies. | read |
| 15627 | https://github.com/omacom/omarchy/discussions/15627 | open | Full-height tiling binding (PR #15628 opened by the author). Shows binding additions are welcomed as PRs. | read |
| 7724 | https://github.com/omacom/omarchy/discussions/7724 | open | Proposal for managed Hyprland plugins (Lua entry points) via the plugin manager. Would let a keyboard-only snap plugin ship Lua bindings officially. Draft PR basecamp/omarchy #8396. | read |
| 13257 | https://github.com/omacom/omarchy/discussions/13257 | open | Remember float preference. Unrelated to snapping. | read |
| 17523, 10272, 15497, 11467, 12492, 15427, 15927 | search listing | open | Titlebar glyphs, off-screen window recovery, dock on tiling, hypr-layout save/restore, equalise layout, Alt+Tab and window switcher plugin suggestions. Adjacent only. | search result only |

Zero discussions match "magnet" (only a power-button idea matched the word), and none ask for Rectangle/Magnet by name.

## Table: plugin marketplace (omacom/omarchy-plugin-marketplace) and community repos

| # / repo | Link | State | What it does / why it matters | Tag |
|---|---|---|---|---|
| #13736 Omarchy Gridnet (ex Omasnap) | https://github.com/omacom/omarchy-plugin-marketplace/issues/13736 | open | Closest existing match. Edge/corner snap, previews, restore, 9 keyboard shortcuts, floating workspaces only, native module, Omarchy 4.5 rc3. Repo hudrucan/omarchy-gridnet, MIT, 0 stars. | read (issue and README) |
| #13904 Floating Snap Zones 0.4.4 (ex Omarchy Zones) | https://github.com/omacom/omarchy-plugin-marketplace/issues/13904 | open (verify) | Zone layouts (8 presets, per monitor/workspace overrides), edge gestures, preview. Native helper, RC channel 4.5.0-1. Earlier listing requests #11718 and #8073 closed. | read (issue and README) |
| #1060 and #8388 Floating Window Mode (jwm3000/omarchy-windows) | https://github.com/omacom/omarchy-plugin-marketplace/issues/1060 | closed | Earlier "window mode" with Aero-style snapping, directional border resize, patched hyprbars titlebars. Predates the native floating workspace. Web summary also credits keyboard snapping. | read (#1060) / search result only (keyboard claim) |
| #11763 Arrange | https://github.com/omacom/omarchy-plugin-marketplace/issues/11763 | closed | Keyboard submap (Super+A) moving and resizing windows with arrows, no snapping zones. Repo TylerSw1ft/omarchy-arrange. Needs manual hyprland.lua step. | read |
| #11809 Snap Layouts (JeoCrypto) | https://github.com/omacom/omarchy-plugin-marketplace/issues/11809 | closed | Layout picker that changes tiled layout (master orientation, mfact), not floating snapping. | read |
| #13591 omarchy-window-layouts | https://github.com/omacom/omarchy-plugin-marketplace/issues/13591 | closed | Windows-style layouts and snap zones from a bar button; all windows snap into a layout. | read |
| #13592 Control the windows (mouse-in-the-corner) | https://github.com/omacom/omarchy-plugin-marketplace/issues/13592 | closed | Window controls plugin; body had no description. | read (no detail) |
| #12021 FancyZones, #12954 Per-Screen Zones (zonectl), #13041 | https://github.com/omacom/omarchy-plugin-marketplace/issues/12021 | closed | Names suggest snapping; reading shows FancyZones loads a Hyprland line (README step) and zonectl is a per-screen bar visibility tool, not snapping. | read (partial) |
| #13785 OmaMosaic, #13526 Tricky Tiles, #13860 Keycorner, #12561 Slingshot, #13462 MagicMouse | https://github.com/omacom/omarchy-plugin-marketplace/issues/13785 | mixed | Matched "window/zone" searches but are not snapping tools. | read |
| #12735 COSMIC-style Equal Tiling (r4lphio/omarchy-equal-tiling) | https://github.com/omacom/omarchy-plugin-marketplace/issues/12735 | open | Tiled equalization, not floating. | search result only |
| #13890 Hyprdrive | https://github.com/omacom/omarchy-plugin-marketplace/issues/13890 | open | Verify request, purpose not read. | search result only |
| hugorolimf/omarchy-smart-windows | https://github.com/hugorolimf/omarchy-smart-windows | n/a | Windows-style floating windows snapping to edges: top edge maximize, side half, corner quarter, restore on drag away. | search result only |
| n0rthstar88/omarchy-snap-layouts | https://github.com/n0rthstar88/omarchy-snap-layouts | n/a | Drag to top of screen to pick one of six layouts (halves, 2/3 + 1/3, thirds, quarters). Needs floating first on default tiling. | search result only |
| ugurcanbulut/omarchy-quilt | https://github.com/ugurcanbulut/omarchy-quilt | n/a | 28 tiled layouts on the Hyprland Lua layout API, for ultrawide. Linked from discussion #3146. | search result only |
| timurguseynov/omarchy-x-mode | https://github.com/timurguseynov/omarchy-x-mode | n/a | Mac-like workspace mode on 4.5: floating windows, Mac titlebars, snapping, dock, Mac shortcuts. | search result only |
| omacom/omarchy-hyprland-titlebars | https://github.com/omacom/omarchy-hyprland-titlebars | n/a | Titlebar plugin; open PRs #3 (let Lua follow titlebar drags), #5 (keep titlebar on screen after drag end), #6 (pen gestures). Hooks that a snap plugin could use. PR #1 (border resize) closed. Search listing and README read; PRs not opened. | read (README) / search result only (PRs) |

Marketplace listing state ("closed") for earlier requests is GitHub issue state; I did not confirm which were approved and published.

## Searches run (re-run these)

All on 2026-11-05. Auth via `gh`; REST search is 30 per minute. Bare words in `gh api search/issues` match loosely, so quote phrases.

Core repo issues and PRs, REST `search/issues` with `q="<terms> repo:omacom/omarchy"`:
1. `snap OR snapping`
2. `magnet OR rectangle`
3. `floating workspace`
4. `maximize floating`
5. `half OR quarter OR third window`
6. `edge OR corner OR zone floating`
7. `grid OR layout floating`
8. `move window floating keybinding`
9. `resize window floating`
10. `dock floating`
11. `tile floating`
12. `"window snapping" OR "snap to" OR "snap window" OR "snap windows"`
13. `Magnet OR Rectangle OR "tiling shortcuts" OR "window management" magnet`
14. `"move floating" OR "move window" OR "resize floating" OR "floating window"`
15. `minimize Super+M shelf`
16. `"edge snapping" OR "drag to edge" OR "Aero" OR "FancyZones" OR "Rectangle"`
17. `commenter:dhh floating`

Marketplace, same endpoint with `repo:omacom/omarchy-plugin-marketplace`: `window`; `floating OR snap OR tile`; `Zones OR Omasnap OR Gridnet OR "window-snap"`; `Omasnap OR omasnap`.
Titlebars repo: `repo:omacom/omarchy-hyprland-titlebars snap OR half OR maximize OR resize`.

Discussions, GraphQL `search(type: DISCUSSION)` with `repo:omacom/omarchy <term>` for: snap, snapping, magnet, rectangle, "floating window", "tiling shortcuts", "window management", zones, maximize, "half screen", "keyboard resize", ultrawide. Plus `gh api repos/omacom/omarchy/discussions` title grep.

Read directly: PRs 14482 (body, commits, timeline), 8260, 15266, 11503, 16340, 17626, 13569, 9113, 8557, 16262, 16497; marketplace issues 13904, 11809, 11763, 13736, 13785, 13526, 13860, 13591, 13592, 8388, 1060, 3075, 13890, 12561, 11718, 12021, 12954, 13041, 13462, 9695; READMEs of hudrucan/omarchy-gridnet, austinwilkerson/omarchy-zones, omacom/omarchy-hyprland-titlebars; discussions 3146, 16605, 1528, 7724, 13257, 9744, 15627, 15995.

Web: WebSearch "Omarchy floating windows snapping Magnet Rectangle like window snap half quarter"; WebSearch "Omarchy 4.5 floating workspace mode DHH window snapping titlebars"; WebFetch omarchy.org/news/2026/11/omarchy-4-5/ and omarchy.org/manual/navigation/.

## Gaps and caveats

- Not searched: Discord, Reddit r/omarchy, YouTube, blogs beyond the two web searches, personal dotfiles. The web search pointed to starryhope.com 4.5 posts (not opened). Absence there is unproven.
- One web summary claimed 4.5 "brought in edge snapping and a Shelf". That is stale: it describes the first commit of #14482, which was reverted before merge (read). Trust the commits.
- Gridnet and Zones are 1 to 4 days old with fresh pushes; behavior was read from READMEs, not tested.
- Core repo issue search is loose-OR; a wording like "tile windows to halves" under a different title could still exist. Spot checks of the hit lists found none.
