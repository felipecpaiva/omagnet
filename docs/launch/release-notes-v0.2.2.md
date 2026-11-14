A small fix. Maximize now works the Omarchy way.

## Changed

- **Maximize is Omarchy's own maximize.** `CTRL + ALT + Return` and a drag to the top edge now do the same thing as `SUPER + ALT + F`. Before, omagnet only made the window as big as the screen. The window then kept its floating shadow, and the shadow showed over the top bar.
- **One maximized window per desktop.** Hyprland allows only one. If you maximize a second window, the first one goes back to its old size. Omarchy works the same way.
- **Restore on a maximized window** (`CTRL + ALT + Backspace`) un-maximizes it first, then puts it back where it was before the first snap.

## Known limits

- **A maximized window still casts a shadow on a floating desktop.** This is in Omarchy too, not only in omagnet. Until Omarchy fixes it, add this line to `~/.config/hypr/hyprland.lua`:

  ```lua
  o.window({ fullscreen_state_internal = 1 }, { no_shadow = true })
  ```

## How it was checked

New tests in the fake-Hyprland test for maximize, restore and the drag to the top edge. They fail on the old code. Then by hand on a Z13: maximize, restore, maximize again, and a pixel check of the top bar with and without the rule above.

## Update

`omarchy plugin update io.github.felipecpaiva.omagnet`, then `hyprctl reload`. Your `config.toml` keeps working.

omagnet is an independent project. It is not affiliated with or endorsed by Omarchy, Microsoft or Magnet. MIT license.
