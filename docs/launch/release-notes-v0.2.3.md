v0.2.2 was a mistake. This puts maximize back, and fixes the shadow the right way.

## Changed

- **Maximize fills the screen again, for as many windows as you want.** In v0.2.2 I used Hyprland's maximized state. Hyprland allows only one maximized window per desktop, so a second one made the first one small again. That is wrong for a floating desktop, where each window is on its own.
- **No shadow over the bar.** A window as tall as the usable screen loses its shadow, because the shadow would fall over the bar. When the window is shorter again, the shadow comes back. This works for snaps, drags, and windows you make full height by hand.

## Known limits

- Hyprland has no "window moved" or "window resized" event. So omagnet checks after a snap, after a `SUPER` drag, after a `SUPER` + right mouse resize, when a window opens, and when a window gets focus. A resize done another way updates on the next focus change.
- `SUPER + ALT + F` (Omarchy's own maximize) still casts the shadow. I sent a fix to Omarchy: https://github.com/omacom/omarchy/pull/18884. Until it ships, add this line to `~/.config/hypr/hyprland.lua`:

  ```lua
  o.window({ fullscreen_state_internal = 1 }, { no_shadow = true })
  ```

## How it was checked

New tests in the fake-Hyprland test: maximize, a half and a hand-made full-height window lose the shadow, a quarter and a short window keep it, and a window that is not ours is left alone. On my Z13: the check run on real windows set the shadow off for a full-height window and kept it on a short one.

## Update

`omarchy plugin update io.github.felipecpaiva.omagnet`, then `hyprctl reload`. Your `config.toml` keeps working.

omagnet is an independent project. It is not affiliated with or endorsed by Omarchy, Microsoft or Magnet. MIT license.
