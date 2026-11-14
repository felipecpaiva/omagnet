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
| A **maximized window loses the `omarchy-floating-workspace` tag** | Omarchy removes the tag while a window is maximized (`tags=[]`), so a tag check says "not floating" (On 2026-11-14, Omarchy 4.5.0 kept the tag on a maximized window. The code accepts either.) | For maximized windows (`fullscreen == 1`) read the workspace's saved mode from `~/.local/state/omarchy/workspace-layouts/<id>.lua`, as Omarchy's own `workspace layout current` does. | Live test failed on a maximized window |
| A maximized window **refuses to move**, and un-maximize is not instant | A move sent straight after `fullscreen unset` is refused. | Un-maximize, then place after about 60 ms in a one-shot timer. | Live test |
| Hyprland allows **one maximized window per workspace** | Maximizing a second window un-maximizes the first, which goes back to its size from before. Omarchy's `SUPER + ALT + F` does the same. | Since 2026-11-14 omagnet's maximize is this real maximized state, so it behaves like Omarchy. Restore on a maximized window un-maximizes first, then places it. | Live test |
| A maximized window **still casts a shadow** on a floating workspace | The 16 px shadow spills over the top bar, for Omarchy's maximize too. | A window rule in the user's `hyprland.lua`: `o.window({ fullscreen_state_internal = 1 }, { no_shadow = true })`. Not shipped by omagnet, it is Omarchy-wide. | Pixel check, 2026-11-14 |
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
| Hyprland **computes a drag from where the window was when it began** | Resizing or moving the window mid-drag changes the size, but the next mouse motion puts the position back (begin position plus the pointer's travel). The pointer then ends up outside a smaller window. Dispatching the drag again does not start a new one: one dispatch ends it, a second does nothing. | End Hyprland's drag with one dispatch and move the window yourself from a short timer until the button is released. A release at an edge still snaps. | Real-mouse debug runs |
| A **virtual monitor** is easy to add for tests | `hyprctl output create headless` adds one and `hyprctl output remove <name>` takes it away. A monitor rule with `position = "auto"` places it, and the layout it picks can differ from run to run, so read the positions from `hyprctl monitors -j`. | See `tests/live_displays.py`; it records your windows first and checks they are back afterwards. | Live test |
| **Omarchy's theme picker opens whenever its shell reloads** | Adding a monitor, rescanning or enabling a plugin, and restarting the shell all make Omarchy show its fullscreen image selector (`omarchy-image-selector`, the theme and wallpaper picker) over everything. It holds keyboard focus, so every `focus` call is accepted (`ok = true`) but changes nothing, and it stays until you press Escape. Found the hard way: several test runs failed on focus. Not caused by omagnet; worth an upstream issue (not filed yet). | Close it with Escape after any of those events and check the overlay list (`hyprctl layers -j`) is back to what it was. `tests/live_displays.py` does both. | Live tests, then the shell restart |
| A **hidden special-workspace window** is laid out again when the monitor list changes | The window of a special workspace (for example Omarchy's agent panel) changed size after a monitor was added and removed. omagnet does not touch it. | Compare only windows on normal workspaces in tests, and report the special one. | Live test |
| Editing a block of a file **by line range** can delete lines you did not mean to | A replacement from one comment to the next removed the timing constants in between; every timer-driven check failed at once. | Anchor an edit on the exact text it changes, and keep a load test with a fake `hl` (`lua/test_glue.lua`) that checks every setting exists. Checked that the test fails when a setting is removed. | Live test failing everywhere |
| A QML property named **`baseline`** (or other `Item` built-ins) fails to compile | `Cannot override FINAL property`, and the type that uses it becomes unavailable. | Name properties after what they mean (`boundSignature`), not after common Item properties. Only a render in the real shell shows it; the validator and the unit tests cannot. | Settings plugin, shell log |
| The shell **caches a failed compile**, and a plugin added while it runs needs a shell restart | After fixing a file, a hot reload, disable/enable and rescan still showed the old error, and `summon` said `ok` with nothing on screen. A new file name did not help either; `omarchy restart shell` did. | After the first install of a plugin, restart the shell once (`omarchy restart shell`; the bar blinks). Look in the shell's log (`/run/user/<uid>/quickshell/by-pid/<shell pid>/log.qslog`) for `unavailable` and `Cannot`. | Settings plugin |
| A `FileView` watching a file that **does not exist yet** never hears that it gets created | On a fresh install the config file appears the first time the settings window saves, and the bar widget never saw it. | Also re-read the (tiny) file on a 2 second timer. | Real bar test |
| A bar widget with **no size and `visible: false`** leaves no gap | Checked in the bar code (`Bar.qml`, a hidden widget gives its slot width and height 0, and the section layout has no spacing) and on the real bar (pixel-identical apart from the clock). The widget's id is still listed in the bar layout in `shell.json`. | Fine for an optional icon. | Real bar test |
| A **monitor rule set later for one output wins** over a global rule | Your Omarchy monitor rule gives every output the same scale. `hl.monitor({ output = <name>, ..., scale = 1.5, transform = 1 })` afterwards changed the virtual monitor's scale and rotation (position stayed `auto`). | Use it in tests to cover fractional scales and a rotated screen. | Live test |
| `hl.get_config("general.col.active_border")` returns **colour objects**, not numbers | `colors[1]` prints as `0xFF6E6E6E` but `type()` is not `number`, so a converter that only took numbers silently found no colour. | Read its text form (`tostring`) as well. | Live overlay test |


## Found while building the zones and the editor (2026-11-05)

- **`hl.is_key_down` takes X key names, with their case.** `"Shift_L"`, `"Super_L"`, `"Control_R"`, `"Alt_L"` work. `"SHIFT"`, `"shift"`,
  `"code:42"` and `"mouse:272"` all return nil, and no mouse button can be read. It is the only way to see a key pressed in the middle
  of a drag: a bind on the key itself (`SUPER + code:42`) never fires during a drag. In Lua, `x and nil or false` is `false`: a "cannot
  tell" answer has to be returned with an explicit `if`.
- **A bind's modifiers are matched at release time.** Let go of SUPER before the mouse button and no release bind runs, so a drag that
  depends on the release handler stays "on": the grid stays up and a window restored from a snap keeps following the pointer. omagnet
  now watches SUPER on every tick and counts two ticks without it as the drop.
- **Hyprland runs a bind's press handler near the release.** With the zone binds, `on_press` was seen a few milliseconds before
  `on_release`. A `qs kill` sent right after a `qs` start finds nothing registered and kills nothing, which leaked an overlay process.
  A stop now waits 400 ms and a start during that wait reuses the running process.
- **Omarchy takes the floating tag off a window the moment it lands on a workspace that is not in floating mode.** omagnet then (rightly)
  leaves it alone. Drags that cross onto a tiled workspace, and `next_display` onto one, work for the move but the window is no longer
  ours until its workspace is switched to floating (`Super + L`). Tests that move windows between real monitors have to re-tag.
- **`move` in a window rule is relative to the monitor,** not to the layout. A rule `[move 180 120; workspace N silent]` on a second
  monitor puts the window at that offset from the monitor's corner.
- **A new monitor's output is painted late.** A screenshot of a freshly created headless monitor shows the wallpaper only until the
  first window moves. (Found while recording; the demos now use a real monitor.)
- **Every monitor Omarchy has ever seen keeps a block of ten workspaces for good** (`~/.local/state/omarchy/monitor-workspaces`),
  headless ones too. 25 test monitors made the real external monitors get workspaces 261 and 271. `tests/livehelp.py
  forget_headless_blocks()` removes the HEADLESS lines and reloads; `tests/live_real_displays.py` needs no virtual monitor. To repair numbering: edit the file
  (blocks 0, 1, 2 for the monitors that exist), `hyprctl reload` (Omarchy re-reads it), then rename each monitor's visible workspace with
  `hl.dispatch(hl.dsp.workspace.change_id({ workspace = "261", id = 11 }))`. `o.workspaces.focus(slot, monitor)` is not a safe way to do it: it switched the focused monitor.
- **Raising a window does not change which window a drag grabs.** `bring_to_top` and a focus did not stop a `SUPER` drag from taking the
  window on top at the pointer. Demos place windows side by side.
- **Blind clicks on the settings window go stale.** The panel's height follows its content, so its position moved by about 20 px once
  the Settings tab grew; a recording script that clicked fixed coordinates hit the wrong controls. Take a screenshot before clicking.
