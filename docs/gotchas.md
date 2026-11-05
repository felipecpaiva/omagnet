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
| Only the **floating tag** goes when a window is maximized | Other tags, such as our saved-size tag, survive a maximize (checked live). Omarchy puts its own tag back after un-maximize only on a real floating workspace. | Keep state in our own tag. In a test on a tiled workspace, add the tag by hand to copy what Omarchy does. | Live test |
| A bind handler that errors can leave state half set | An error in a release handler left "dragging" on, so the next drag was ignored. | Wrap the work in `pcall`, always run the cleanup, and make a new press start clean. | Independent review |
| `hl.bind` raises on a bad key string and aborts the rest of the file | One bad user shortcut stopped every later bind from registering. | `pcall` each bind, record the error, keep going. Also set the global table before binding. | Independent review |
| `%d` in `string.format` refuses a non-integer | A window size such as 100.5 at a fractional scale raised "no integer representation". | Round before formatting. | Independent review |
| `tonumber` accepts `0x10` and `1e999` | A config value could become infinity. | Match plain decimals with a pattern first. | Independent review |
| A resize from an odd spot can be **one pixel off** | Center-anchored resize leaves a half pixel. A window that sat partly off the screen (as after a drag into a corner) came out 388 high instead of 387, or 641 wide instead of 640. It depends on where the window was. | After a short settle time read the size and set it again, at most twice; stop if the size did not change (the app refuses it). Retrying fixed 36 of 36 cases tried. | Real-mouse live test |
| A **virtual mouse** works through `/dev/uinput` too | A huge relative move (for example -3000) pushes the pointer to the screen edge, so edges and corners are reached without depending on pointer acceleration. | See `tests/uinput_kbd.py` (`Mouse`). | Live test |
| A **live test shares your real keyboard, mouse and focus** | Typing while it runs puts stray characters in the test window and fails checks that have nothing to do with the code. | The test prints a warning and waits 4 seconds. Keep your hands off the machine for about 2 minutes. | A failed run with stray characters in the log |
| Dragging an **unfocused** window with `SUPER` + drag | The dragged window, not the focused one, is the one that ends up active, so snapping the active window on release is right (checked with two overlapping windows and a real drag). | Nothing to do; keep the two-window live check. | Real-mouse live test |

