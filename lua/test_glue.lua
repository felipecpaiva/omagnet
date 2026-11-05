-- Smoke and safety tests for the Hyprland glue (omagnet-snap.lua) with a fake `hl`, so they run anywhere:
--   lua lua/test_glue.lua
-- They cannot prove the glue works in Hyprland (tests/live.py does), but they catch a module that no longer loads,
-- lost settings, and the safety rules (never touch what is not ours), in a second.
local dir = arg[0]:match("^(.*)/") or "."

_G.fake_cursor = { x = 0, y = 0 }
_G.execs = {}
_G.fake_keys = { Shift_L = true } -- keys held; the zone tests assume the zone modifier (SHIFT) is down unless they change it
local binds, dispatched, timers = {}, {}, {}
local windows, monitors = {}, {}
local fake_config = {}
local function dsp(name) return function(args) return { name = name, args = args } end end
hl = {
  bind = function(key, fn, opts) binds[#binds + 1] = { key = key, fn = fn, opts = opts } end,
  dispatch = function(d) dispatched[#dispatched + 1] = d end,
  timer = function(fn, o) timers[#timers + 1] = { fn = fn, o = o } end,
  get_windows = function() return windows end,
  get_active_window = function() return windows[1] end,
  get_cursor_pos = function() return { x = _G.fake_cursor.x, y = _G.fake_cursor.y } end,
  get_config = function(key) return fake_config[key] end,
  get_monitors = function() return monitors end,
  get_monitor_at = function() return monitors[1] end,
  get_active_monitor = function() return monitors[1] end,
  exec_cmd = function(c) _G.execs[#_G.execs + 1] = c end,
  is_key_down = function(k)
    if k == "Super_L" then return _G.fake_super ~= false end -- SUPER is held unless a test lets go of it
    return _G.fake_keys[k] == true
  end,
  dsp = { focus = dsp("focus"), window = setmetatable({}, { __index = function(_, k) return dsp("window." .. k) end }) },
}
local function mon(name, x, ws)
  return { name = name, x = x, y = 0, width = 2560, height = 1600, scale = 2, transform = 0,
    reserved = { left = 0, top = 26, right = 0, bottom = 0 }, active_workspace = { id = ws } }
end
local function win(extra)
  local w = { address = "0x1", class = "kitty", floating = true, fullscreen = 0, at = { x = 100, y = 100 }, size = { x = 500, y = 300 },
    workspace = { id = 2 }, tags = { "omarchy-floating-workspace" } }
  for k, v in pairs(extra or {}) do w[k] = v end
  return w
end
local function count(name)
  local n = 0
  for _, d in ipairs(dispatched) do if d.name == name then n = n + 1 end end
  return n
end

-- A config file that does not exist, so the contributor's own settings never change the result.
_G.omagnet_bound = nil
local M = dofile(dir .. "/omagnet-snap.lua")
local C = dofile(dir .. "/config.lua")

-- 1. the module loads with every setting it needs
for _, name in ipairs({ "tick_ms", "max_seconds", "unmaximize_ms", "restore_px", "follow_ms", "settle_ms", "display_move_ms", "warm_px" }) do
  assert(type(M[name]) == "number" and M[name] > 0, "setting " .. name .. " must be a positive number")
end
assert(type(M.state_file) == "string" and type(M.dir) == "string" and type(M.config_path) == "string", "paths are set")
assert(_G.omagnet == M, "the global is set")

-- 2. every shortcut and the three drag binds are registered, once, with no errors
local wanted = 0
for _, key in pairs(C.defaults.keys) do if key ~= "" then wanted = wanted + 1 end end
local drag = 0
for _, b in ipairs(binds) do if b.key == "SUPER + mouse:272" then drag = drag + 1 end end
assert(drag == 3, "three drag binds, got " .. drag)
local zonebinds = 0
for _, b in ipairs(binds) do if b.key == "SUPER + SHIFT + mouse:272" then zonebinds = zonebinds + 1 end end
assert(zonebinds == 4, "four zone binds (a drag that moves the window, and press, release, click), got " .. zonebinds)
assert(#binds == 3 + 4 + wanted, "binds: " .. #binds .. " wanted " .. (3 + 4 + wanted))
assert(#M.bound_signature > 0 and #(M.bind_errors or {}) == 0, "no bind errors")
for _, b in ipairs(binds) do
  if not b.key:find("mouse:272", 1, true) then assert(b.opts.auto_consuming, b.key .. " lets keys through when it is not ours") end
end

-- 3. a shortcut on a window that is not ours is passed through and nothing is dispatched
local function handler_for(key) for _, b in ipairs(binds) do if b.key == key then return b.fn end end end
windows = { win({ tags = {} }) }
local result = handler_for("CTRL + ALT + LEFT")()
assert(type(result) == "table" and result.ok == false, "a tiled window's key goes to the app")
assert(#dispatched == 0, "nothing dispatched for a window that is not ours")
windows = { win({ class = "steam" }) }
M.cfg.ignore = "Steam"
result = handler_for("CTRL + ALT + LEFT")()
assert(type(result) == "table" and result.ok == false and #dispatched == 0, "an ignored app is left alone")
M.cfg.ignore = ""

-- 4. restore on a maximized window does nothing and keeps the saved size
windows = { win({ fullscreen = 1, tags = { "omarchy-floating-workspace", "omagnet-orig=10,10,500,300" } }) }
dispatched = {}
assert(M.command("restore", windows[1]) == nil and #dispatched == 0, "restore does nothing on a maximized window")

-- 5. a window is not sent to a monitor whose workspace is not floating
local state = os.tmpname(); os.remove(state); os.execute("mkdir -p '" .. state .. "'")
M.state_dir = state .. "/"
monitors = { mon("A", 0, 2), mon("B", 1280, 7) }
windows = { win({ tags = { "omarchy-floating-workspace", "omagnet-orig=10,40,500,300" } }) }
dispatched, timers = {}, {}
assert(M.command("next_display", windows[1]) == nil and #dispatched == 0, "no mode file for the target: refused")
local f = io.open(state .. "/7.lua", "w"); f:write('o.workspace_mode({ workspace = "7", mode = "dwindle" })\n'); f:close()
assert(M.command("next_display", windows[1]) == nil and #dispatched == 0, "a tiled target workspace is refused")
f = io.open(state .. "/7.lua", "w"); f:write('o.workspace_mode({ workspace = "7", mode = "floating" })\n'); f:close()
local moved = M.command("next_display", windows[1])
assert(moved and count("window.move") == 1, "a floating target workspace gets the window")
assert(count("window.tag") == 2, "the saved size is carried to the new monitor (old tag out, new tag in)")
local new_tag
for _, d in ipairs(dispatched) do if d.name == "window.tag" and d.args.tag:sub(1, 1) == "+" then new_tag = d.args.tag end end
assert(new_tag and new_tag:find("omagnet-orig=1290", 1, true), "the saved rectangle is now on the second monitor: " .. tostring(new_tag))
os.remove(state .. "/7.lua"); os.remove(state)
M.state_dir = nil

-- 6. one monitor: nothing to move to
monitors = { mon("A", 0, 2) }
dispatched = {}
assert(M.command("next_display", windows[1]) == nil and #dispatched == 0, "one monitor: nothing happens")

-- 7. re-reading the config changes settings in place and reports shortcut changes
local cfg_file = os.tmpname()
f = io.open(cfg_file, "w"); f:write('margin = 5\n[keys]\nleft = "CTRL + ALT + H"\n'); f:close()
local same_table = M.cfg
M.config_path = cfg_file
assert(M.reload_config() == true and M.cfg == same_table and M.cfg.margin == 5, "settings change in the same table, shortcut change reported")
f = io.open(cfg_file, "w"); f:write("margin = 6\n"); f:close()
assert(M.reload_config() == false and M.cfg.margin == 6, "back to the bound shortcuts: no reload needed")
os.remove(cfg_file)

-- 7b. an app that refuses the size: set once more, then left alone, never a loop
monitors = { mon("A", 0, 2) }
windows = { win({ size = { x = 500, y = 300 } }) } -- the fake window never changes size, like an app with a fixed size
dispatched, timers = {}, {}
M.command("left", windows[1])
assert(count("window.resize") == 1 and #timers == 1, "first set, one check scheduled")
local fired = 0
while #timers > 0 and fired < 10 do
  local t = table.remove(timers, 1)
  fired = fired + 1
  t.fn()
end
assert(fired == 2, "the check runs, sets the size once more, and the next check gives up (fired " .. fired .. ")")
assert(count("window.resize") == 2, "two resizes in all: the first and one retry, not a loop (got " .. count("window.resize") .. ")")

-- 7c. the outline colour: yours, else the theme's active border (live from Hyprland), else the accent fallback
fake_config["general.col.active_border"] = { colors = { 0xFF6E6E6E }, angle = 0 }
M.cfg.target_color = ""
assert(M.style_line() == "2 #6e6e6e 0.18 4", "matches the theme border by default: " .. M.style_line())
fake_config["general.col.active_border"] = { colors = { setmetatable({}, { __tostring = function() return "0xFF6E6E6E" end }) }, angle = 0 }
assert(M.style_line() == "2 #6e6e6e 0.18 4", "the colour object Hyprland returns is read through its text form: " .. M.style_line())
fake_config["general.col.active_border"] = { colors = { 0x33CCFFEE, 0x00FF99EE }, angle = 45 }
assert(M.style_line() == "2 #ccffee 0.18 4 #ff99ee", "a gradient border gives two colours: " .. M.style_line())
M.cfg.target_color = "#FF8800"
assert(M.style_line() == "2 #FF8800 0.18 4", "your own colour wins")
M.cfg.target_color = ""
fake_config["general.col.active_border"] = nil
assert(M.style_line() == "2 - 0.18 4", "nothing to read: the overlay falls back to the accent")
fake_config["general.col.active_border"] = { colors = { "junk" } }
assert(M.style_line() == "2 - 0.18 4", "a junk value is ignored")
hl.get_config = function() error("config unavailable") end
assert(M.style_line() == "2 - 0.18 4", "a failing read never breaks the drag")

-- 9. grid zones: drag mode, the layout per monitor, stepping, and the safety rules
do
  monitors = { mon("A", 0, 2) } -- usable area 0,26 1280 x 774 at scale 2
  M.cfg.margin, M.cfg.zone_span, M.layout_override = 0, 24, {}
  M.cfg.layout_landscape, M.cfg.layout_portrait, M.cfg.zone_layouts, M.cfg.layouts = "grid:3x2", "rows:3", {}, {}
  local function rect_eq(r, x, y, w, h, what)
    assert(r and r.x == x and r.y == y and r.w == w and r.h == h, what .. ": got " .. (r and (r.x .. "," .. r.y .. " " .. r.w .. "x" .. r.h) or "nil"))
  end
  local function drop(x, y, w)
    windows = { w or win() }
    _G.fake_cursor = { x = x, y = y }
    M.on_press(true)
    assert(M.pressed and M.zone_mode == true, "zone drag started")
    local r = M.on_release()
    assert(M.pressed == false and M.zone_mode == false, "the drag state is cleaned up after a release")
    return r
  end
  -- the middle top cell of 3 x 2: columns 0..427, 427..853, 853..1280, rows 26..413, 413..800
  rect_eq(drop(640, 100), 427, 26, 426, 387, "middle top zone")
  rect_eq(drop(1100, 600), 853, 413, 427, 387, "bottom right zone")
  rect_eq(drop(425, 100), 0, 26, 853, 387, "near the shared edge of two columns: both zones")
  rect_eq(drop(300, 411), 0, 26, 427, 774, "near the shared edge of two rows: both zones")
  -- with a margin the zone goes through the same rule as every other snap
  M.cfg.margin = 8
  rect_eq(drop(640, 100), 431, 26, 418, 383, "margin: tight on the screen border, half each side inside")
  M.cfg.margin = 0

  -- the overlay is told about every zone of the monitor
  windows = { win() }; _G.fake_cursor = { x = 640, y = 100 }
  M.on_press(true)
  local zf = io.open(M.zones_file); local zt = zf:read("a"); zf:close()
  local n = 0; for _ in zt:gmatch("[^\n]+") do n = n + 1 end
  assert(n == 6, "six zones written for the overlay, got " .. n)
  M.finish()

  -- safety: not a floating-workspace window, or zones switched off
  windows = { win({ tags = {} }) }; dispatched = {}
  _G.fake_cursor = { x = 640, y = 100 }
  M.on_press(true)
  assert(M.on_release() == nil and #dispatched == 0, "a window that is not ours is left alone in zone mode")
  M.cfg.zones_enabled = false
  M.on_press(true)
  assert(M.pressed == false, "zones switched off: no drag state")
  M.cfg.zones_enabled = true

  -- a plain SUPER drag is not zone mode
  windows = { win() }
  _G.fake_keys = {}
  M.on_press()
  assert(M.pressed and not M.zone_mode, "the normal drag is not zone mode")
  M.finish()
  _G.fake_keys = { Shift_L = true }

  -- the layout of a monitor: override, then its own entry, then the default for its shape
  assert(M.layout_name(monitors[1]) == "grid:3x2", "default for a landscape monitor")
  M.cfg.zone_layouts = { A = "rows:2" }
  assert(M.layout_name(monitors[1]) == "rows:2", "the monitor's own layout")
  M.layout_override = { A = "columns:4" }
  assert(M.layout_name(monitors[1]) == "columns:4", "a layout set by key wins")
  M.layout_override, M.cfg.zone_layouts = {}, {}
  local portrait = mon("P", 0, 2); portrait.transform = 1
  assert(M.layout_name(portrait) == "rows:3", "default for a portrait monitor")

  -- a layout that cannot be read falls back, and says why
  M.cfg.zone_layouts = { A = "nonsense" }; M.last_error = nil
  local zs, used = M.zones_for(monitors[1])
  assert(#zs == 2 and used == "columns:2" and M.last_error and M.last_error:find("nonsense", 1, true), "fallback to the screen's recommended layout, with a reason: " .. tostring(M.last_error))
  M.cfg.zone_layouts = {}

  -- custom layout, and switching layouts by key
  M.cfg.layouts = { coding = "0 0 0.25 1; 0.25 0 0.75 1", broken = "oops" }
  windows = { win() }
  assert(M.command("layout:coding", windows[1]) == "coding" and M.layout_override.A == "coding", "a custom layout is chosen by name")
  rect_eq(drop(900, 100), 320, 26, 960, 774, "the right zone of the custom layout")
  assert(M.command("layout:broken", windows[1]) == nil and M.layout_override.A == "coding", "an unreadable layout is refused, the old one stays")
  M.layout_override = {}
  assert(M.command("layout_next", windows[1]) == "grid:3x3", "next layout after grid:3x2 in the cycle (custom layouts come first): got " .. tostring(M.layout_override.A))
  M.layout_override = {}
  M.cfg.layouts = {}

  -- stepping through zones
  windows = { win({ at = { x = 0, y = 26 }, size = { x = 427, y = 387 } }) }
  rect_eq(M.command("zone_next", windows[1]), 427, 26, 426, 387, "next zone")
  rect_eq(M.command("zone_prev", windows[1]), 853, 413, 427, 387, "previous zone from the first wraps to the last")
  windows = { win({ tags = {} }) }; dispatched = {}
  assert(M.command("zone_next", windows[1]) == nil and #dispatched == 0, "stepping on a tiled window does nothing")
  M.cfg.margin = 8
end


-- 9b. a layout per workspace, and the on-screen preview
do
  monitors = { mon("A", 0, 2), mon("B", 1280, 7) }
  M.cfg.margin, M.layout_override, M.cfg.zone_layouts, M.cfg.layouts = 0, {}, {}, {}
  M.cfg.layout_landscape, M.cfg.workspace_layouts = "grid:3x2", {}
  local ws2, ws7 = { id = 2, name = "2" }, { id = 7, name = "web" }
  assert(M.layout_name(monitors[1], ws2) == "grid:3x2", "no workspace entry: the default")
  M.cfg.workspace_layouts = { ["2"] = "columns:4", web = "rows:2" }
  assert(M.layout_name(monitors[1], ws2) == "columns:4", "a workspace entry by id")
  assert(M.layout_name(monitors[2], ws7) == "rows:2", "a workspace entry by name when the id has none")
  M.cfg.zone_layouts = { A = "rows:3" }
  assert(M.layout_name(monitors[1], ws2) == "columns:4", "the workspace wins over the monitor")
  assert(M.layout_name(monitors[1], { id = 9, name = "9" }) == "rows:3", "another workspace falls to the monitor's layout")
  assert(M.layout_name(monitors[1], nil) == "rows:3", "no workspace: the monitor's layout")
  M.layout_override = { A = "grid:2x2" }
  assert(M.layout_name(monitors[1], ws2) == "grid:2x2", "a layout picked by key wins over everything")
  M.layout_override, M.cfg.zone_layouts = {}, {}
  -- a drop uses the layout of the workspace the monitor shows: four columns on A (workspace 2)
  windows = { win() }; _G.fake_cursor = { x = 700, y = 100 }
  M.on_press(true)
  local r = M.on_release()
  assert(r and r.x == 640 and r.w == 320, "workspace 2 has four columns: the third starts at 640, got " .. tostring(r and r.x))
  -- preview
  timers = {}
  local zf = function() local f = io.open(M.zones_file); local t = f:read("a"); f:close(); return t end
  assert(M.preview("grid:2x2", 3) == true, "a built-in layout can be previewed")
  local n = 0; for _ in zf():gmatch("[^\n]+") do n = n + 1 end
  assert(n == 8, "four zones on each of two monitors, got " .. n)
  assert(zf():find("B 0 26 640 387", 1, true) and not zf():find("B 1280", 1, true), "the second monitor's zones are relative to that monitor")
  assert(#timers == 1 and timers[1].o.timeout == 3000, "one timer, for the seconds asked")
  M.preview("text:0 0 0.5 1; 0.5 0 0.5 1", 99)
  assert(timers[#timers].o.timeout == 15000, "the time is capped at 15 seconds")
  local old = timers[#timers - 1]
  old.fn(); assert(zf() ~= "", "an older preview's timer does not clear a newer one")
  timers[#timers].fn(); assert(zf() == "" and not M.overlay, "the newest timer clears the overlay")
  local ok, why = M.preview("nonsense", 3); assert(ok == nil and why, "an unreadable layout is refused with a reason")
  ok, why = M.preview("text:0 0 1", 3); assert(ok == nil and why, "bad zone text is refused")
  M.cfg.layouts = { coding = "0 0 0.5 1; 0.5 0 0.5 1" }
  assert(M.preview("coding", 1) == true and zf() ~= "", "a custom layout can be previewed by name")
  M.preview_gen = M.preview_gen + 1; M.finish()
  M.pressed = true
  ok, why = M.preview("grid:2x2", 3); assert(ok == nil and why:find("drag"), "no preview during a drag")
  M.pressed = false
  M.cfg.workspace_layouts, M.cfg.layouts, M.cfg.margin = {}, {}, 8
end


-- 9c. zone mode follows the modifier while the drag is on
do
  monitors = { mon("A", 0, 2) }
  M.cfg.margin, M.layout_override, M.cfg.zone_layouts, M.cfg.layouts, M.cfg.workspace_layouts = 0, {}, {}, {}, {}
  M.cfg.layout_landscape, M.cfg.zone_modifier, M.cfg.zones_enabled = "grid:3x2", "SUPER + SHIFT", true
  local function zlines()
    local f = io.open(M.zones_file); local t = f:read("a"); f:close()
    local n = 0; for _ in t:gmatch("[^\n]+") do n = n + 1 end
    return n
  end
  windows = { win() }; _G.fake_cursor = { x = 640, y = 100 }
  _G.fake_keys = {}
  M.on_press() -- a plain SUPER drag
  assert(M.pressed and not M.zone_mode and zlines() == 0, "a plain drag shows no zones")
  _G.fake_keys = { Shift_L = true }
  M.update_mode()
  assert(M.zone_mode and zlines() == 6, "pressing SHIFT in the middle of the drag shows the zones")
  _G.fake_keys = { Shift_R = true }
  M.update_mode(); assert(M.zone_mode, "the right SHIFT counts too")
  _G.fake_keys = {}
  M.update_mode()
  assert(not M.zone_mode and zlines() == 0, "letting go of SHIFT hides them again")
  _G.fake_keys = { Shift_L = true }
  local r = M.on_release()   -- SHIFT pressed since the last tick: the release itself settles the mode
  assert(r and r.x == 427 and r.w == 426, "a release with SHIFT held snaps to the zone even before a tick saw it, got " .. tostring(r and r.x))
  assert(M.zone_mode == false, "clean after the release")

  -- a drag that starts with the zone bind drops back to the edge zones when SHIFT is let go
  _G.fake_keys = { Shift_L = true }
  M.on_press(true); assert(M.zone_mode, "started in zone mode")
  _G.fake_keys = {}
  M.update_mode(); assert(not M.zone_mode, "SHIFT released: edge mode")
  M.finish()

  -- unknown state changes nothing
  _G.fake_keys = { Shift_L = true }
  M.on_press(true)
  hl.is_key_down = function() error("no such thing") end
  M.update_mode(); assert(M.zone_mode, "a failing key read keeps the mode")
  hl.is_key_down = function() return nil end
  M.update_mode(); assert(M.zone_mode, "an unknown key read keeps the mode")
  hl.is_key_down = function(k) if k == "Super_L" then return _G.fake_super ~= false end return _G.fake_keys[k] == true end
  M.finish()

  -- zones switched off: SHIFT does nothing
  M.cfg.zones_enabled = false
  _G.fake_keys = {}
  M.on_press(); _G.fake_keys = { Shift_L = true }; M.update_mode()
  assert(not M.zone_mode and zlines() == 0, "zones switched off: SHIFT shows nothing")
  M.finish(); M.cfg.zones_enabled = true

  -- another modifier: SUPER + CTRL needs Control, not Shift
  M.cfg.zone_modifier = "SUPER + CTRL"
  _G.fake_keys = {}
  M.on_press(); _G.fake_keys = { Shift_L = true }; M.update_mode()
  assert(not M.zone_mode, "SHIFT does nothing when the modifier is CTRL")
  _G.fake_keys = { Control_R = true }; M.update_mode()
  assert(M.zone_mode, "CTRL shows the zones when the modifier is CTRL")
  M.finish()
  M.cfg.zone_modifier = "SUPER + SHIFT"
  _G.fake_keys = { Shift_L = true }
  M.cfg.margin = 8
end


-- 9d. the overlay process: one start, one kill, and no kill that can land before its own start
do
  monitors = { mon("A", 0, 2) }
  M.cfg.margin, M.cfg.zones_enabled, M.layout_override = 0, true, {}
  windows = { win() }; _G.fake_cursor = { x = 640, y = 100 }; _G.fake_keys = { Shift_L = true }
  M.finish(); M.overlay, M.qs_running = false, false -- earlier tests left a pretend process; start from none
  timers = {}; _G.execs = {}
  local function n(kind) local c = 0; for _, e in ipairs(_G.execs) do if e:find("preview.qml", 1, true) and ((kind == "kill") == (e:find(" kill", 1, true) ~= nil)) then c = c + 1 end end return c end
  M.on_press(true)
  assert(n("start") == 1 and n("kill") == 0, "one start")
  M.finish()
  assert(n("kill") == 0 and #timers >= 1, "the stop does not kill at once: it waits")
  local waits = 0; for _, t in ipairs(timers) do if t.o.timeout == M.kill_ms then waits = waits + 1 end end
  assert(waits == 1, "one delayed kill")
  M.on_press(true) -- a new drag before the kill ran
  assert(n("start") == 1, "the running process is reused, not a second one started")
  for _, t in ipairs(timers) do if t.o.timeout == M.kill_ms then t.fn() end end
  assert(n("kill") == 0, "the waiting kill does nothing while the overlay is wanted again")
  M.finish(); timers = {}
  M.finish()
  M.on_press(true); M.finish()
  for _, t in ipairs(timers) do if t.o.timeout == M.kill_ms then t.fn() end end
  assert(n("kill") == 1, "after the last stop, exactly one kill, got " .. n("kill"))
  assert(n("start") == 1, "and no new start")
  -- a fresh start after the kill launches again
  _G.execs = {}; M.on_press(true)
  assert(n("start") == 1, "a drag after the overlay was killed starts a new process")
  M.finish(); for _, t in ipairs(timers) do if t.o.timeout == M.kill_ms then t.fn() end end
  M.cfg.margin = 8
end


-- 9e. "auto": a recommendation for the screen's size and shape
do
  local function m(w, h, scale, transform)
    return { name = "T", x = 0, y = 0, width = w, height = h, scale = scale, transform = transform or 0,
      reserved = { left = 0, top = 26, right = 0, bottom = 0 }, active_workspace = { id = 2 } }
  end
  M.cfg.layout_landscape, M.cfg.layout_portrait, M.cfg.zone_layouts, M.cfg.workspace_layouts, M.layout_override = "auto", "auto", {}, {}, {}
  assert(M.layout_name(m(2560, 1600, 2)) == "columns:2", "a Z13 at scale 2 (1280 x 800): two columns")
  assert(M.layout_name(m(2560, 1600, 1.6)) == "columns:2", "a Z13 at scale 1.6 (1600 x 1000): still two columns")
  assert(M.layout_name(m(1920, 1080, 1)) == "grid:2x2", "full HD at scale 1: halves and quarters")
  assert(M.layout_name(m(2560, 1440, 1)) == "grid:3x2", "1440p at scale 1: six cells")
  assert(M.layout_name(m(3440, 1440, 1)) == "priority", "21:9 ultrawide: 25, 50, 25")
  assert(M.layout_name(m(5120, 1440, 1)) == "columns:4", "32:9 super ultrawide: four columns")
  assert(M.layout_name(m(1080, 1920, 1)) == "rows:3", "a tall portrait monitor: three rows")
  assert(M.layout_name(m(1920, 1080, 1, 1)) == "rows:3", "a landscape monitor turned on its side")
  assert(M.layout_name(m(1080, 1920, 2)) == "rows:2", "a small portrait screen: two rows")
  M.cfg.layout_landscape = "columns:5"
  assert(M.layout_name(m(2560, 1600, 2)) == "columns:5", "a layout the user chose beats auto")
  M.cfg.layout_landscape = "auto"
  M.cfg.zone_layouts = { T = "auto" }
  assert(M.layout_name(m(2560, 1600, 2)) == "columns:2", "auto can be named for one monitor, too")
  M.cfg.zone_layouts = {}
  assert(#(M.zones_for(m(3440, 1440, 1))) == 3, "the zones for auto are really made (priority has three)")
  M.cfg.layout_landscape, M.cfg.layout_portrait = "grid:3x2", "rows:3"
end


-- 9f. letting go of SUPER before the mouse button must end the drag (no release handler runs in that case)
do
  monitors = { mon("A", 0, 2) }
  M.cfg.margin, M.cfg.zones_enabled, M.layout_override, M.cfg.layout_landscape = 0, true, {}, "grid:3x2"
  M.cfg.zone_layouts, M.cfg.workspace_layouts = {}, {}
  windows = { win() }; _G.fake_cursor = { x = 640, y = 100 }; _G.fake_keys = { Shift_L = true }; _G.fake_super = true
  M.finish(); timers = {}
  M.on_press(true)
  assert(M.pressed and M.polling, "a drag is on")
  -- one tick without SUPER is not enough (a flicker), two are
  _G.fake_super = false
  local t = table.remove(timers, 1); t.fn()
  assert(M.pressed, "one tick without SUPER does not end the drag")
  _G.fake_super = true
  t = table.remove(timers, 1); t.fn()
  _G.fake_super = false
  t = table.remove(timers, 1); t.fn()
  assert(M.pressed, "the count starts again after SUPER came back")
  t = table.remove(timers, 1); t.fn()
  assert(not M.pressed and not M.polling and not M.zone_mode, "SUPER gone for two ticks: the drag is over")
  assert(M.following == nil, "and nothing is following the pointer")
  -- the window dropped where the pointer was, like a release
  _G.fake_super = true
  -- a window restored from a snap and following the pointer stops following
  windows = { win({ tags = { "omarchy-floating-workspace", "omagnet-orig=10,40,500,300" }, at = { x = 0, y = 26 }, size = { x = 640, y = 774 } }) }
  _G.fake_cursor = { x = 100, y = 100 }; timers = {}
  M.on_press(true)
  M.following = { address = "0x1", gx = 10, gy = 10 }
  _G.fake_super = false
  for _ = 1, 6 do local tt = table.remove(timers, 1); if tt then tt.fn() end end
  assert(M.following == nil and not M.pressed, "a following window is let go when SUPER is released first")
  _G.fake_super = true
  -- unknown state: counts as held, never ends a drag
  hl.is_key_down = function() error("no") end
  windows = { win() }; timers = {}
  M.on_press()
  for _ = 1, 6 do local tt = table.remove(timers, 1); if tt then tt.fn() end end
  assert(M.pressed, "a failing key read never ends a drag")
  M.finish()
  hl.is_key_down = function(k) if k == "Super_L" then return _G.fake_super ~= false end return _G.fake_keys[k] == true end
  M.cfg.margin, M.cfg.layout_landscape = 8, "grid:3x2"
end

-- 8. a stray press with drag switched off does nothing
M.cfg.drag_enabled = false
M.on_press()
assert(M.pressed == false, "drag switched off: no drag state")
M.cfg.drag_enabled = true

print("glue ok")
