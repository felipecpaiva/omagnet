-- Smoke and safety tests for the Hyprland glue (omagnet-snap.lua) with a fake `hl`, so they run anywhere:
--   lua lua/test_glue.lua
-- They cannot prove the glue works in Hyprland (tests/live.py does), but they catch a module that no longer loads,
-- lost settings, and the safety rules (never touch what is not ours), in a second.
local dir = arg[0]:match("^(.*)/") or "."

local binds, dispatched, timers = {}, {}, {}
local windows, monitors = {}, {}
local function dsp(name) return function(args) return { name = name, args = args } end end
hl = {
  bind = function(key, fn, opts) binds[#binds + 1] = { key = key, fn = fn, opts = opts } end,
  dispatch = function(d) dispatched[#dispatched + 1] = d end,
  timer = function(fn, o) timers[#timers + 1] = { fn = fn, o = o } end,
  get_windows = function() return windows end,
  get_active_window = function() return windows[1] end,
  get_cursor_pos = function() return { x = 0, y = 0 } end,
  get_monitors = function() return monitors end,
  get_monitor_at = function() return monitors[1] end,
  get_active_monitor = function() return monitors[1] end,
  exec_cmd = function() end,
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
assert(#binds == 3 + wanted, "binds: " .. #binds .. " wanted " .. (3 + wanted))
assert(#M.bound_signature > 0 and #(M.bind_errors or {}) == 0, "no bind errors")
for _, b in ipairs(binds) do
  if b.key ~= "SUPER + mouse:272" then assert(b.opts.auto_consuming, b.key .. " lets keys through when it is not ours") end
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

-- 8. a stray press with drag switched off does nothing
M.cfg.drag_enabled = false
M.on_press()
assert(M.pressed == false, "drag switched off: no drag state")
M.cfg.drag_enabled = true

print("glue ok")
