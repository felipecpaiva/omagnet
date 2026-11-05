# Gotchas found while building omagnet

Things that cost time on Hyprland 0.56.2 with Omarchy 4.5 (RC). Each one says how it was found.
Useful to anyone writing Hyprland Lua for Omarchy.

| Gotcha | What happens | What to do | Found by |
|--------|--------------|------------|----------|
| Hyprland embeds **Lua 5.5** | A `for` loop variable is read-only. Assigning to it errors with "attempt to assign to const variable". `lua5.4` accepts it, so a test on 5.4 passes and Hyprland fails. | Copy the loop variable before changing it. Run tests with `lua` (5.5 here), not `lua5.4`. | Module failed to load in Hyprland while its tests passed |
| `pcall(dofile, ...)` in the config **hides load errors** | The module silently does not load. | When binds are missing, run `hyprctl eval 'dofile("<path>")'` once to see the real error. | Zero omagnet binds after a reload |
| Key strings join **every modifier with `+`** | `"CTRL ALT + LEFT"` fails: `Unknown keysym "CTRL ALT"`. | Write `"CTRL + ALT + LEFT"`. The keybindings menu prints `CTRL ALT + X` for display only. | Error on bind |
| `-` is special in **Lua patterns** | `"omagnet-orig="` as a pattern matches the wrong thing. | Escape it (`%-`) or use plain find. | Unit test |
| `hl.timer` has only `oneshot` and `repeat`, and returns **no handle** | A repeating timer cannot be stopped. | Chain `oneshot` timers gated by a flag. | Probing the API |
| **Never `hl.unbind` a key shared with Omarchy** | `hl.unbind("SUPER + mouse:272")` also removes Omarchy's own "Move window" bind. | Register once per Lua state and switch features off with a config flag. | Code review before running |
| A **maximized window loses the `omarchy-floating-workspace` tag** | Omarchy removes the tag while a window is maximized (`tags=[]`), so a tag check says "not floating". | For maximized windows (`fullscreen == 1`) read the workspace's saved mode from `~/.local/state/omarchy/workspace-layouts/<id>.lua`, as Omarchy's own `workspace layout current` does. | Live test failed on a maximized window |
| A maximized window **refuses to move**, and un-maximize is not instant | A move sent straight after `fullscreen unset` is refused. | Un-maximize, then place after about 60 ms in a one-shot timer. | Live test |
| Floating **resize is centre-anchored** | Resize then move gives the wrong spot if you move first. | Resize first, then move. | Hyprland study |
| Dispatchers take **integers only** | Percent strings and expressions are rejected. | Round edges (not sizes) so neighbours tile with no gap. | Hyprland study, unit tests |
| `hyprctl eval` prints only `ok` | Results and errors of the Lua are not shown. | Write results to a file from inside the Lua and read it back. | Hyprland study |
| **`wtype` cannot trigger modifier binds** here | `wtype -M ctrl -M alt -k Left` reaches apps but never fires a `CTRL + ALT + LEFT` bind. | Create a real virtual keyboard through `/dev/uinput` (see `tests/uinput_kbd.py`). It needs write access to `/dev/uinput`. | Live test of a plain test bind |
| `cat -v` prints a line only after a newline | A key-capture test looks empty until Enter. | Send Enter before reading the log. | Live test |
| A bind's `auto_consuming` + `return { ok = false }` **passes the key to the app** | Without it a shortcut is eaten on every workspace. | Return `{ ok = false }` for windows that are not ours. Confirmed with the real escape sequence for Ctrl+Alt+Left. | Live test |
| An idle Quickshell process costs about **230 MB** | Keeping the outline overlay running all the time is heavy. | Start it on press and stop it on release, with a time cap. | `ps` |
| A drag started from an **app's own title bar** fires no bind | Only `SUPER` + drag is seen. | Open item D11 in the roadmap. | Hyprland study |
