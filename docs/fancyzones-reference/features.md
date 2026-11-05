# FancyZones feature reference (for omagnet porting decisions)

Researched 2026-11-05. Read-only web research.

Source keys:
- LEARN = https://learn.microsoft.com/en-us/windows/powertoys/fancyzones (page dated 2026-10-14)
- DEV = https://github.com/microsoft/PowerToys/blob/main/doc/devdocs/modules/fancyzones.md
- SET = src/modules/fancyzones/FancyZonesLib/Settings.h (raw GitHub, main)
- LAY = src/modules/fancyzones/FancyZonesLib/Layout.cpp (raw GitHub, main)
- CFG = src/modules/fancyzones/FancyZonesLib/LayoutConfigurator.cpp (raw GitHub, main)
- DEF = src/modules/fancyzones/FancyZonesLib/FancyZonesData/LayoutDefaults.h (raw GitHub, main)
- OZ = https://github.com/austinwilkerson/omarchy-zones (README, fetched via raw README.md)

Evidence tags:
- `read` = I opened the page or file and read the text (through a fetch tool that summarises).
- `search result only` = seen only in a search listing.
- `unverified` = I could not confirm it.

Caveat: the fetch tool returns a model summary of each file, not raw text. Code quotes below come from that summary. Treat exact numbers as read, but re-check the source before coding against them.

The old src/modules/fancyzones/README.md only says "This file has been moved" and points to the Learn page. The DEV page has almost no behaviour detail. So Learn plus the C++ headers are the real sources.

## 1. Feature table

### Activation and drag display

| ID | Feature | Exact behaviour | Default key or setting | Source | Evidence |
|---|---|---|---|---|---|
| F1 | Shift to show zones | While dragging a window, zones appear only when Shift is held. Hovering a zone highlights it. Setting text: "Hold Shift key to activate zones while dragging". | On. `shiftDrag = true` (SET). Learn says "By default, you'll also need to select and hold Shift". | LEARN, SET | read |
| F2 | Non-primary mouse button toggle | A click of a non-primary mouse button toggles zone activation during the drag. | Off. `mouseSwitch = false` (SET). | LEARN, SET | read |
| F3 | Always-on zones | If both F1 and F2 are cleared, zones show immediately when the drag starts. | Not a separate option, it is the result of clearing F1 and F2. | LEARN | read |
| F4 | Middle button multi-zone | "Use middle mouse button to toggle multiple zones spanning". | Off. `mouseMiddleClickSpanningMultipleZones = false` (SET). | LEARN, SET | read |
| F5 | Show zones on all monitors | By default only zones of the focused monitor show. This option shows every monitor's zones. Learn warns of a possible performance cost. | Off. `showZonesOnAllMonitors = false` (SET). | LEARN, SET | read |
| F6 | Span zones across monitors | Treats all monitors as one big screen. Needs the same DPI scaling on all monitors. Learn warns of odd effects with mixed orientations. | Off. `spanZonesAcrossMonitors = false` (SET). | LEARN, SET | read |
| F7 | Key released mid-drag | NOT DOCUMENTED. Learn does not say what happens when Shift is released before the drop. The setting text says Shift toggles snapping "during a drag", which suggests zones hide and the drop is a plain move. This is my inference. | n/a | LEARN | unverified |
| F8 | Mouse wheel layout switch while dragging | With zones visible, wheel down picks the next layout, wheel up the previous one, on the monitor under the cursor. The list wraps. The window snaps into the new layout on drop. Only custom layouts are cycled: first those with a hotkey, in hotkey order (if two or more have one), else all custom layouts in editor order. With fewer than two layouts or the option off, the wheel scrolls normally. | Off. `mouseWheelLayoutSwitch = false` (SET). | LEARN, SET | read |
| F9 | Layout name indicator | Shows the layout name briefly when the layout changes while zones are visible (wheel or quick switch). Options: position, text colour, background colour, text size, padding, duration. | On. Position Top center. Text `#FFFFFF`. Background `#262626`. Size 36 (range 8 to 128). Padding 12 (0 to 64). Duration 1500 ms (300 to 10000). | LEARN, SET | read |
| F10 | Make dragged window transparent | While zones are active, the dragged window becomes transparent so zones are visible. | Learn does not state a default. SET says `makeDraggedWindowTransparent = true`. | LEARN, SET | read |
| F11 | Zone appearance | System theme colours or custom colours. Options: show zone number, opacity, highlight colour (active drop target), inactive colour, border colour, number colour. | System theme on (`systemTheme = true`). Zone `#AACDFF`. Border `#FFFFFF`. Highlight `#008CFF`. Number `#000000`. Show number on. Opacity 50 percent (Learn says "default: 50%", SET `zoneHighlightOpacity = 50`). | LEARN, SET | read |
| F12 | Flash zones on layout change | Zones flash when a layout is chosen with the shortcut. | Learn lists no default. SET: `flashZonesOnQuickSwitch = true`, but `zoneSetChange_flashZones = false`. These two names look related, I could not tell which one backs the UI toggle. | LEARN, SET | read (default unclear) |

### Built-in templates (from CFG)

Templates: Focus, Columns, Rows, Grid, Priority Grid. The editor also lists a "No layout" entry (search result only, from a third-party article). The zone count is adjustable per template. The UI default for the count is `ZoneCount = 3` (DEF). I could not confirm DEF is the file the UI reads, so treat 3 as likely, not certain.

| ID | Feature | Exact behaviour | Default | Source | Evidence |
|---|---|---|---|---|---|
| F13 | Focus template | All zones are the same size: 40 percent of work area width and height, first zone at (100, 100). Each next zone shifts 50 px right and 50 px down. They overlap in a diagonal cascade. A single zone has step 0. | Count from F17. | CFG | read |
| F14 | Columns template | Zones span full height, equal widths. Widths come from integer slices of (width minus spacing x (count+1)). Outer and inner gaps are all `spacing`. Pixel rounding makes slices differ by at most 1. | Count from F17. | CFG | read |
| F15 | Rows template | Same as Columns, rotated. Full width, equal heights. | Count from F17. | CFG | read |
| F16 | Grid template | Rows and columns are derived from the count. Rows grow while count/rows >= rows, then drop one. Columns = ceil(count/rows). Cells fill row by row. Left-over cells merge into the last zone. Example from CFG: 5 zones is 2 rows by 3 columns, last zone spans two cells. Outer edges inset by full spacing, inner edges by spacing/2 per side. | Count from F17. | CFG | read |
| F17 | Template zone count | Editable. Range 1 to 128 (editor model). | 3 (DEF, see caveat above). | DEF, editor LayoutModel.cs summary | read |
| F18 | Priority Grid template | Uses a fixed preset table for counts 1 to 10. Count 11 and above fall back to Grid. Shapes: 1 = one full zone. 2 = two columns, 2/3 and 1/3. 3 = 25 / 50 / 25 columns. 4 = 25/50/25 columns, where the right 25 percent column is split top and bottom (zones 2 and 3) and the middle and left are tall (CFG cell map {0,1,2},{0,1,3}). 5 = 2 rows of 25/50/25, middle column tall, left and right split into two each. 6 and 7 = 3 rows of 25/50/25. 8 to 10 = 3 rows by 4 columns, 25 percent each, with a tall merged middle area. Full table in CFG. | Count from F17. | CFG | read |

### Layout editor

| ID | Feature | Exact behaviour | Default | Source | Evidence |
|---|---|---|---|---|---|
| F19 | Open editor | Hotkey opens the layout editor. Also a button in Settings. Double-click a layout to apply it and close. Selecting a monitor makes it the target of the chosen layout. | Win+Shift+` (Learn table). SET: `editorHotkey` with VK_OEM_3 (the backtick key). | LEARN, SET | read |
| F20 | Grid layout (custom) | Starts as three columns. Relative, so it scales to other screen sizes. Click a zone to split it. Hold Shift to flip the split direction. Drag a divider ("thumb") to move it. Select several zones by dragging, then a popup offers Merge. Deleting a zone means merging it into another. Keyboard: Ctrl+Tab to focus, Tab to move, S or Shift+S to split, arrows to move a divider, Delete on a divider merges the zones next to it. | 3 columns start | LEARN | read |
| F21 | Canvas layout (custom) | Starts with one zone. Zones are free rectangles you move and resize like windows. Zones may overlap. Keyboard: arrows move 10 px, Ctrl+arrow 1 px, Shift+arrow resize 10 px (5 per edge), Ctrl+Shift+arrow resize 2 px (1 per edge). | 1 zone start | LEARN | read |
| F22 | Space around zones | Margin between zones. "Show space around zones" toggles it, "Space around zones" sets the width. | Spacing 16 px, ShowSpacing true (DEF). Learn gives no default. | LEARN, DEF | read (DEF default unconfirmed as the UI value) |
| F23 | Highlight distance | "Distance to highlight adjacent zones": the gap in which two neighbouring zones both light up, so you can drop into both. This is the distance used for edge-hover two-zone snapping. | Learn gives no default. DEF has no highlight distance constant. UNKNOWN. | LEARN | read (default unverified) |
| F24 | Sensitivity radius | Per layout. The hit test grows each zone rectangle by this many px. Editor range 0 to 1000. A single captured zone is only accepted if the point is also strictly inside it. Two zones count as overlapping when their intersection is larger than the radius on both axes. | 20 (DEF `SensitivityRadius`). Not described on the Learn page under this name. | LAY, DEF, editor model summary | read |
| F25 | Default layout per monitor orientation | Separate defaults for horizontal and vertical monitors, used when the display setup changes (for example a new monitor). | Learn gives no default layout name. | LEARN | read |
| F26 | Layouts stored as JSON | Custom layouts live in `%LocalAppData%\Microsoft\PowerToys\FancyZones\custom-layouts.json`. Other JSON files in that folder hold monitor and hotkey data. Learn says hand editing is not recommended. | n/a | LEARN | read |

### Multi-zone snapping and zone maths

| ID | Feature | Exact behaviour | Default | Source | Evidence |
|---|---|---|---|---|---|
| F27 | Edge hover two-zone snap | Near the shared edge of two adjacent zones, both activate. The window gets the smallest rectangle that contains both. | On, no switch | LEARN | read |
| F28 | Ctrl multi-zone with mouse | Drag until one zone is active, then hold Ctrl to select more zones. | Ctrl | LEARN | read |
| F29 | Keyboard multi-zone | Needs Override Windows Snap on and Move windows based on = Relative position. Win+Ctrl+Alt+arrows expand the window over more zones. | n/a | LEARN | read |
| F30 | Target rectangle | `GetCombinedZonesRect` is the union (min left, min top, max right, max bottom) of the chosen zones. `GetCombinedZoneRange` takes the union of the start and end zone sets, builds the bounding box, then selects every zone fully inside that box. So a selection always fills a rectangle. | n/a | LAY | read |
| F31 | Overlapping zones algorithm | When zones overlap under the cursor, pick one by: Smallest (area), Largest (area), Positional (split the overlap into slices along its longer axis, one per zone, cursor picks the slice), ClosestCenter (nearest zone centre wins if centres differ by more than a threshold, else the smaller zone). Setting: "When multiple zones overlap". | Smallest (`OverlappingZonesAlgorithm::Smallest`, SET). Closest centre threshold constant is 75 and is compared as squared distance (LAY summary), so it is about 8.7 px, which looks odd. Flagged as an open question. | LEARN, SET, LAY | read |

### Keyboard

| ID | Feature | Exact behaviour | Default | Source | Evidence |
|---|---|---|---|---|---|
| F32 | Override Windows Snap | Lets Win+arrows move a window between zones instead of the Windows snap. | Off (`overrideSnapHotkeys = false`, SET) | LEARN, SET | read |
| F33 | Move by zone index | Only Win+Left and Win+Right are overridden. They step through zones by index. Win+Up and Win+Down keep their Windows meaning. | `moveWindowsBasedOnPosition = false` means this is the default mode (SET) | LEARN, SET | read |
| F34 | Move by relative position | All four Win+arrows are overridden. The next zone is chosen by position in the layout. | Not default | LEARN | read |
| F35 | Cross-monitor zone cycling | Cleared: arrows cycle zones on the current monitor. Selected: they cycle through the zones of all monitors. | Off (`moveWindowAcrossMonitors = false`, SET) | LEARN, SET | read |
| F36 | Quick layout switch | Give a custom layout a number 0 to 9 in the editor. Win+Ctrl+Alt+number then applies it to the active screen. It also works during a drag. Needs "Enable quick layout switch". | `quickLayoutSwitch = true` (SET). Learn says the option must be selected, so the UI default is unclear. | LEARN, SET | read |
| F37 | Window switching in a zone | When several windows share a zone, Win+PgUp and Win+PgDn cycle between them. | On (`windowSwitching = true`). Next = Win+PgDn, Previous = Win+PgUp (SET `VK_NEXT`, `VK_PRIOR`, with the first flag set, which I read as Win). | LEARN, SET | read |
| F38 | Rotate windows across monitors | Hold the rotation shortcut and press Left or Right to rotate windows one monitor over. A preview shows while held. | Off (`monitorRotation = false`). Shortcut Alt+X (Learn says default Alt+X; SET has 'X' with one modifier flag). | LEARN, SET | read |
| F39 | Windows' own monitor move | FancyZones does NOT override Win+Shift+arrows (move to adjacent monitor). | n/a | LEARN | read |

### Layout per monitor, desktop, and window behaviour

| ID | Feature | Exact behaviour | Default | Source | Evidence |
|---|---|---|---|---|---|
| F40 | Layout per monitor | Each monitor has its own layout. Pick a monitor in the editor to target it. | n/a | LEARN | read |
| F41 | Layout per virtual desktop | The Learn page does NOT say layouts are stored per virtual desktop. Widely known behaviour in practice, but I did not verify it in any source I opened. | n/a | none | unverified |
| F42 | Keep windows in zones on resolution change | After a resolution change, windows go back to their zones. | On (`displayOrWorkAreaChange_moveWindows = true`, SET) | LEARN, SET | read |
| F43 | Match new layout on layout change | When the layout changes, windows keep their zone number and take the new size and place. | Off (`zoneSetChange_moveWindows = false`, SET) | LEARN, SET | read |
| F44 | Move new windows to last known zone | A new window opens in the zone that app last used. | Off (`appLastZone_moveWindows = false`, SET) | LEARN, SET | read |
| F45 | Move new windows to current monitor | Applies when F44 is off or the app has no known zone. The window moves to the active monitor. | Off (`openWindowOnActiveMonitor = false`, SET) | LEARN, SET | read |
| F46 | Move new windows to largest free zone | NOT FOUND. Neither Learn nor SET has this option. Probably does not exist in current FancyZones. | n/a | LEARN, SET | unverified |
| F47 | Restore original size when unsnapping | Dragging a window out of its zone restores the size it had before snapping. | Off (`restoreSize = false`, SET) | LEARN, SET | read |
| F48 | Allow popup windows to snap | Popups cannot snap by default. Turning this on may fix windows that ignore FancyZones. It also affects notifications. | Off. Learn says "couldn't be snapped by default". SET has no popup field. | LEARN | read |
| F49 | Allow child windows to snap | Same idea for child windows. | Off (`allowSnapChildWindows = false`, SET) | LEARN, SET | read |
| F50 | Excluded apps | A list, one entry per line. Matches by name or part of it: `Notepad` matches Notepad.exe and Notepad++.exe. Add `.exe` to match exactly. | Empty (`excludedApps = ""`, SET) | LEARN, SET | read |
| F51 | Disable rounded corners when snapped | Windows 11 only. | Off (`disableRoundCorners = false`, SET) | LEARN, SET | read |

### Other things found

| ID | Feature | Exact behaviour | Default | Source | Evidence |
|---|---|---|---|---|---|
| F52 | Elevated windows | Admin windows can only be moved if PowerToys runs as admin. | n/a | LEARN, DEV | read |
| F53 | Command line tool | `PowerToys.FancyZones.CLI.exe` with: open-editor (e), get-monitors (m), get-layouts (ls), get-active-layout (active), set-layout (s, by UUID or template name, with `--monitor` or `--all`), open-settings, get-hotkeys (hk), set-hotkey (shk, key 0 to 9), remove-hotkey (rhk). | n/a | LEARN | read |
| F54 | Open editor on a chosen display | Option for where the editor appears. | `use_cursorpos_editor_startupscreen = true` (SET), which I read as "open on the screen with the cursor". | LEARN, SET | read |
| F55 | Known incompatible apps | Many remote and game apps do not raise the move event, so they cannot be zoned. Not a feature, but it shows FancyZones depends on the OS move-start event. | n/a | LEARN | read |

## 2. What omarchy-zones copies from FancyZones, and what it leaves out

The omarchy-zones README (also named "Floating Snap Zones", plugin id io.github.austinwilkerson.zones) never mentions FancyZones. So "copies" below means "has an equivalent idea", not a stated copy. Evidence: `read`.

Has an equivalent:
- Zone layouts as presets with a translucent landing preview (like F11 and F1).
- Snap on release of a dragged window.
- Per monitor layouts, plus a per workspace override (F40, extended).
- Padding between zones and at the screen edge (F22).
- Overlapping layouts. Closest centre to the pointer wins (F31 ClosestCenter).
- Overlapping windows are allowed in occupied zones (like canvas and Focus).
- Colour and opacity of the preview (F11). Opacity 5 to 80 percent, default 35 percent.
- Presets: 50/50, 50/50 vertical, 33/33/33, 33/33/33 vertical, 25/50/25, 25x4, four-square grid, four plus a centre 50. Closest to Columns, Rows, Grid, and a Priority Grid shape.

Leaves out (the README documents no such feature):
- No editor, no custom grid or canvas layouts. Presets only.
- No keyboard control at all. It says it adds no keybindings.
- No multi-zone span (no Ctrl, no edge-hover two-zone merge).
- No Shift or mouse button activation. Zones follow the drag itself.
- No quick layout hotkeys, no wheel switching, no layout name indicator.
- No restore size on unsnap, no remember last zone, no resolution change handling, no excluded apps list, no window cycling in a zone.
- Adds on its own: edge gestures (left edge = left 50 percent, right edge = right 50 percent, top edge = 100 percent), only in Omarchy's saved Floating workspace mode, and a small C++ helper inside Hyprland to read mouse button state.

## 3. Which of these make sense on Hyprland floating workspaces

- F1 to F3 (activation mode): yes. Hyprland drag has no Shift hold by default, so a modifier or "always on while dragging" choice is a real design decision. Keep it as a setting.
- F2 and F4 (extra mouse buttons): maybe. Cheap if the Lua layer can see buttons. Low value.
- F5 (zones on all monitors): yes. Hyprland knows all monitors. Low cost.
- F6 (span monitors as one screen): no. Hyprland monitors can differ in scale and offset. Rarely wanted. Skip.
- F7 (key released mid-drag): yes, must be defined. Suggested: hide zones, drop = normal move. Needs a decision.
- F8 (wheel switch): maybe. Needs a bind that fires during a drag. Hyprland binds can do it, but low value.
- F9, F12 (layout name, flash): yes but cosmetic. Needs an overlay, which pure Lua may not draw.
- F10 (transparent dragged window): yes, if opacity can be set per window through hyprctl. Cosmetic.
- F11 (zone colours and opacity): yes, if an overlay can be drawn. Otherwise n/a.
- F13 to F18 (templates): yes. Columns, Rows, Grid are easy. Priority Grid is a fixed table, easy. Focus cascade is easy. Port as data.
- F19 to F21 (visual editor): no for v1. A visual editor is heavy. Define layouts in a Lua table instead.
- F20 and F21 as data shapes (grid versus canvas): yes. Store layouts as fractions (grid) or rectangles (canvas) in config.
- F22 (spacing): yes. Core feature. Use the CFG rule: full gap outside, half gap per side inside.
- F23, F24 (highlight distance, sensitivity): yes. Needed to pick a zone from the pointer. Start with 20 px.
- F25 (default per orientation): maybe. Simple to add: one default per landscape and portrait.
- F26 (JSON files): n/a. Config is Lua.
- F27 to F30 (multi-zone snap): yes. The union rectangle rule is simple and gives the best payoff after single zones.
- F31 (overlap algorithm): maybe. Only needed once canvas style layouts exist. Pick one algorithm, ClosestCenter like omarchy-zones, or Smallest.
- F32 to F35 (Win+arrow zone moves): yes, strongly. Keyboard zone moves are what Magnet users expect. Use Hyprland binds, no override concept needed (n/a for "override Windows Snap" itself).
- F36 (quick layout switch hotkeys): yes. Easy bind per layout.
- F37 (cycle windows in a zone): maybe. Useful if stacking windows in one zone.
- F38 (rotate across monitors): maybe. Hyprland has monitor focus moves already.
- F39 (Windows monitor move key): n/a. A Windows detail.
- F40 (layout per monitor): yes. Core.
- F41 (per virtual desktop): n/a as named. The Hyprland equivalent is per workspace. omarchy-zones has workspace overrides. Worth doing.
- F42 (resolution change re-snap): maybe. Hyprland has monitor events. Nice to have, later.
- F43 (re-fit windows on layout change): yes. Cheap once zone membership is tracked.
- F44, F45 (new window to last zone or monitor): maybe. Hyprland window rules cover monitor placement. Last zone memory is extra state.
- F46 (largest free zone): not a FancyZones feature as far as I found. Could be an original omagnet idea.
- F47 (restore size on unsnap): yes. Core to Magnet feel. Store pre-snap size.
- F48, F49 (popups, child windows): n/a. A Win32 concept. The Hyprland analogue is rules for dialogs and floating utility windows.
- F50 (excluded apps): yes. Match by window class.
- F51 (round corners): n/a. Windows 11 DWM detail.
- F52 (elevated windows): n/a. Wayland has no elevation split here.
- F53 (CLI): maybe. A hyprctl-style dispatch for scripts is cheap in Lua.
- F54 (editor display): n/a without an editor.
- F55 (incompatible apps): n/a. Caused by Win32 move events.

## 4. Open questions

1. What happens if Shift is released mid-drag? Learn is silent (F7).
2. Highlight distance has no documented default or range. Is it the same value as sensitivity radius (20)? I could not find a constant. Treat F23 and F24 as possibly one setting.
3. Learn says Spacing exists but gives no number. DEF says 16 px with ShowSpacing true. I could not confirm DEF feeds the editor UI.
4. Template default zone count: DEF says 3, but I did not see the per-template defaults, and Priority Grid differs from Focus in practice.
5. "Flash zones" has two SET fields: `zoneSetChange_flashZones = false` and `flashZonesOnQuickSwitch = true`. Which one the UI toggle uses is unclear.
6. "Enable quick layout switch" is described as opt-in on Learn, while SET says `quickLayoutSwitch = true`.
7. "Make dragged window transparent": default is not on the Learn page. Only SET says true.
8. Are layouts per virtual desktop? Not stated on the Learn page (F41).
9. "Move newly created windows to the largest free zone": not found anywhere I read (F46).
10. ClosestCenter threshold 75 is compared as a squared distance in the code summary. That means about 8.7 px, which seems too small to be intended. Needs a read of the raw code.
11. How edge hover picks two zones: the Learn text names the "highlight distance" setting, but the code path I read (`ZonesFromPoint`) uses sensitivity radius. The link between them is not proven.
12. Does Ctrl multi-zone also respect the "mouse button" activation modes? Learn does not say.
13. omarchy-zones: no stated padding default, and it says nothing about FancyZones. Its Hyprland detail (release detection needs a compiled helper) matters if omagnet stays pure Lua. Whether pure Lua can detect drag release and draw an overlay is outside this research.
14. Third-party articles disagree on Focus (cascade versus overlapping). CFG shows a cascade, so I used that.
