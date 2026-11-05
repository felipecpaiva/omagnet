# Hand checks (the "Valid" gate)

Everything here already passes its automated checks. These are the things only a person at the machine can judge:
whether it feels right, looks right, and works with real apps. Tick a box when you have tried it, on a floating
workspace (press `Super + L` to switch a workspace to floating). Report anything that feels off with the line number.

Updated 2026-11-05. Setup: omagnet is loaded by the line in `~/.config/hypr/hyprland.lua`; the settings app is
installed in the Omarchy shell. Ten minutes covers all of it.

## 1. Keyboard (about 2 minutes)

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

## 2. Drag (about 3 minutes)

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

## 5. Things I could not check

- A drag started from an app's own title bar (Chrome, VS Code): it does not snap. Known limit.
- Apps that refuse small sizes: the window stays as wide as the app allows, and the retry stops after one attempt.
- A real second monitor and a real vertical monitor: tested only on virtual monitors (scales 2, 1.5, 1.25 and rotated).

## When you are done

Tell me which boxes failed and I fix them first. If everything passes I mark those gates "V" in
[ROADMAP.md](ROADMAP.md).
