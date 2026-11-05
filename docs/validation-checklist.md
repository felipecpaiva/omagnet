# Hand checks (the "Valid" gate)

Everything here already passes its automated checks. These are the things only a person at the machine can judge:
whether it feels right, looks right, and works with real apps. Tick a box when you have tried it, on a floating
workspace (press `Super + L` to switch a workspace to floating). Report anything that feels off with the line number.

Updated 2026-11-05. Setup: omagnet is loaded by the line in `~/.config/hypr/hyprland.lua`; the settings app is
installed in the Omarchy shell. Ten minutes covers all of it.

## 1. Keyboard (about 2 minutes). Checked by the maintainer, 2026-11-05: all good

Open any window, for example a terminal.

- [ ] `Ctrl + Alt + Left`, then `Right`, then `Up`, then `Down`: left, right, top and bottom half.
- [ ] `Ctrl + Alt + U`, `I`, `J`, `K`: the four quarters.
- [ ] `Ctrl + Alt + D`, `F`, `G`: left, middle and right third.
- [ ] `Ctrl + Alt + E`, `T`: two thirds. Which side each key picks is our guess; tell me if it should be the other way.
- [ ] `Ctrl + Alt + Return`: the whole usable area (not fullscreen). `Ctrl + Alt + C`: centre, same size.
- [ ] `Ctrl + Alt + Backspace`: back to the size and place from before your first snap, even after several snaps.
- [ ] There is an 8 pixel gap between two snapped windows and none against the screen border.
- [ ] In a window on a tiled workspace, `Ctrl + Alt + Left` does nothing to the window and reaches the app (try a
      terminal: it prints a code).

## 2. Drag (about 3 minutes). Checked by the maintainer with the mouse, 2026-11-05: works

Hold `Super`, press the left mouse button on a window, drag, let go.

- [ ] To the left or right edge: an outline of the half appears; letting go snaps it.
- [ ] To the top edge: the whole area. To a corner: a quarter.
- [ ] To the bottom edge: a third; slide along the bottom edge to the next third and it becomes two thirds.
- [ ] Drag a window that is already snapped away from its place: it shrinks back to its old size under the pointer and
      follows it. Say if the follow feels laggy or jumpy.
- [ ] The outline has the same colour as your window borders. Switch to another theme and drag again: it follows.
- [ ] A short drag in the middle of the screen moves the window as before and snaps nothing.
- [ ] With two overlapping windows, dragging the one behind snaps that one.

## 3. Screens (only if you have the hardware)

- [ ] With a second monitor: `Super + Ctrl + Alt + Right` and `Left` move the window to the other monitor, keeping its
      relative place and size. (Needs a floating workspace on both monitors.)
- [ ] On a real vertical monitor: the side edges give top, middle and bottom thirds; the bottom edge gives left and right
      halves. (Already checked on a virtual rotated monitor, all zones.)
- [ ] On a real monitor at a fractional scale: a snapped window is exactly where the outline showed. (Already checked on a
      virtual monitor at 1.5 and 1.25: every position is exact.)

## 4. Settings app (about 3 minutes)

Open "omagnet" from the launcher.

- [ ] It matches your theme and everything fits. Scroll to the shortcuts.
- [ ] Change the margin: the next snap uses it with no reload.
- [ ] Switch off "Keyboard shortcuts": the keys now go to the app. Switch it back on.
- [ ] Add a class to "Ignored apps" (for example `kitty`): that app is left alone.
- [ ] Turn on "Show an icon in the bar": a small icon appears on the right of the bar; clicking it opens this window;
      turning the switch off removes it.
- [ ] With the icon off, the bar looks exactly as it did before you installed omagnet.
- [ ] "Custom positions": type a name, drag across the grid to choose a rectangle, press Add; give it a shortcut, press
      `hyprctl reload` (the window offers a button), and use the shortcut. Delete it with the trash button.
- [ ] "Drag outline": change the colour (type `#ff0000` and press Enter) and the thickness, and turn on "Show every zone
      while dragging"; see them on the next drag.

## 6. Grid zones (about 4 minutes)

Hold `SUPER + SHIFT` (not just `SUPER`) and drag a window with the left mouse, on a floating workspace.

- [ ] Six cells appear on the screen (3 by 2) with the one under the pointer filled in your theme colour.
- [ ] Letting go in a cell snaps the window to exactly that cell.
- [ ] Near the line between two cells the outline covers both, and a drop fills both.
- [ ] Pressing `SHIFT` in the middle of a `SUPER` drag shows the cells; letting go of `SHIFT` hides them and the edge zones are back.
- [ ] A plain `SUPER` drag still does the edge snapping (halves, quarters, thirds).
- [ ] With no settings at all, each monitor gets a sensible layout for its size (two columns on a laptop screen, three rows or columns on a large monitor, four columns or 25/50/25 on an ultrawide). The Layouts page names it (`auto: columns:2`).
- [ ] `CTRL + ALT + ]` and `CTRL + ALT + [` step the focused window through the cells.
- [ ] On a second monitor the cells follow that monitor (needs the hardware).
- [ ] In the config, `[zone_layouts]` with your monitor's name and `columns:3` gives three columns after `hyprctl reload` or the settings app.

## 7. Layout editor (about 6 minutes)

Open omagnet from the launcher and click **Layouts** at the top.

- [ ] The screens are drawn in their own shape with the layout each one uses; clicking one selects it.
- [ ] Each workspace has a row of layouts to choose from, and the choice takes effect on the next drag.
- [ ] **Show on screen** on any card draws its zones on every monitor for a few seconds.
- [ ] **New layout**: click a zone, **Split vertical** or **Split horizontal**, drag a divider, select two zones with **Select several** and **Merge**, **Delete zone**. The preview always fills the screen.
- [ ] In **Canvas** mode, **Add zone**, move a zone, resize it with the corner handle.
- [ ] Type a name, **Save**: a new card appears, and `~/.config/omagnet/config.toml` has a `[layout_<name>]` section.
- [ ] **Apply** a custom layout to a screen, then `SUPER + SHIFT` drag: the zones are yours.
- [ ] **Delete** (click twice) removes the card and every setting that named it.
- [ ] A monitor you really have (needs the hardware): its thumbnail has its real shape.

## 5. Things I could not check

- A drag started from an app's own title bar (Chrome, VS Code): it does not snap. Known limit.
- Apps that refuse small sizes: the window stays as wide as the app allows, and the retry stops after one attempt.
- A real second monitor and a real vertical monitor: tested only on virtual monitors (scales 2, 1.5, 1.25 and rotated).

## When you are done

Tell me which boxes failed and I fix them first. If everything passes I mark those gates "V" in
[ROADMAP.md](ROADMAP.md).
