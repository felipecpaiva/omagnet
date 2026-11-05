-- omagnet: Magnet-style snapping for Omarchy floating workspaces.
--   * keyboard: one shortcut per position (halves, quarters, thirds, two thirds, maximize, center, restore)
--   * drag: hold SUPER + left mouse, drag to the left, right or top edge, let go; an outline shows the target
-- Only windows on an Omarchy floating workspace (tag below) are touched; everything else is passed through.
-- Load live:  hyprctl eval 'dofile("<path to this file>")'   Settings: ~/.config/omagnet/config.toml
-- shortcut: drag is caught only for SUPER + drag, not an app's own title bar (no bind fires for those).
-- shortcut: the outline process (about 230 MB) starts only when the cursor of a floating-workspace drag gets
-- near an edge, and exits on release; after 20 s the outline stops but the release still snaps.

local M = {}

M.dir = (debug.getinfo(1, "S").source:match("^@(.*)/") or ".")
local G = dofile(M.dir .. "/geometry.lua")
local C = dofile(M.dir .. "/config.lua")

M.tag = "omarchy-floating-workspace"
M.cfg = C.load((os.getenv("HOME") or "") .. "/.config/omagnet/config.toml")
M.state_file = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/omagnet-preview"
M.tick_ms, M.max_ticks = 30, 666 -- about 20 s
M.unmaximize_ms = 60
M.warm_px = 150 -- start the outline this close to an edge

-- ---------------------------------------------------------------- windows

local function has_tag(win, tag)
  for _, t in ipairs(win.tags or {}) do if t == tag then return true end end
  return false
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local text = f:read("a")
  f:close()
  return text
end

-- Omarchy takes the floating-workspace tag off a maximized window, so for those the workspace's saved
-- mode decides. shortcut: relies on Omarchy's state files (the same ones its own layout command reads).
local function workspace_is_floating(id)
  -- M.state_dir exists so tests can point at a temporary folder instead of Omarchy's own
  local dir = M.state_dir or ((os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")) .. "/omarchy/workspace-layouts/")
  local mode = C.workspace_mode(read_file(dir .. tostring(id) .. ".lua")) or C.workspace_mode(read_file(dir .. "default.lua"))
  return mode == "floating"
end

local function on_floating_workspace(win)
  if win == nil or not win.floating then return false end
  if has_tag(win, M.tag) then return true end
  return win.fullscreen == 1 and win.workspace ~= nil and workspace_is_floating(win.workspace.id)
end
M.is_floating = on_floating_workspace

local function find(address)
  for _, w in ipairs(hl.get_windows()) do if w.address == address then return w end end
end

local function monitor_of(win)
  return hl.get_monitor_at({ x = win.at.x + win.size.x / 2, y = win.at.y + win.size.y / 2 }) or hl.get_active_monitor()
end

local function orig_of(win)
  for _, t in ipairs(win.tags or {}) do
    local r = G.decode_orig(t)
    if r then return r, t end
  end
end

-- Spacing and reserved space from the config, read at use time so a changed setting applies to the next snap.
local function place_opts() return { margin = M.cfg.margin, edge_tight = M.cfg.edge_tight } end
local function reserve()
  return { top = M.cfg.reserve_top, bottom = M.cfg.reserve_bottom, left = M.cfg.reserve_left, right = M.cfg.reserve_right }
end

local function tag(win, spec) hl.dispatch(hl.dsp.window.tag({ tag = spec, window = win })) end

local function round(v) return math.floor(v + 0.5) end

-- Resize first, move second: a floating resize is centre-anchored. Whole pixels only (a window can report
-- a fractional size at a fractional scale).
local function put(win, r)
  hl.dispatch(hl.dsp.window.resize({ x = round(r.w), y = round(r.h), relative = false, window = win }))
  hl.dispatch(hl.dsp.window.move({ x = round(r.x), y = round(r.y), relative = false, window = win }))
end

-- `orig` is the rectangle to remember when the caller knows better than the window's current one.
local function remember_and_put(win, r, orig)
  if not orig_of(win) then
    tag(win, "+" .. G.encode_orig(orig or { x = win.at.x, y = win.at.y, w = win.size.x, h = win.size.y }))
  end
  put(win, r)
end

-- Snap `win` to `r`, a rectangle or a function(win) that returns one once the window is un-maximized.
-- Remembers the old rectangle on the first snap only, so Restore always goes back to where the window was
-- before omagnet touched it.
function M.apply(win, r, orig)
  if not on_floating_workspace(win) then return nil end
  local fs = win.fullscreen or 0
  if fs == 1 then
    -- Maximized: a maximized window refuses to move. Give it its old size back, then finish once
    -- Hyprland has applied that (a move sent straight away is refused).
    hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "unset", window = win }))
    local address = win.address
    hl.timer(function()
      local w = find(address)
      -- Omarchy has not put its tag back yet, so do not check the tag again; check it came out of maximize.
      if w and w.floating and (w.fullscreen or 0) == 0 then
        remember_and_put(w, type(r) == "function" and r(w) or r, orig)
      end
    end, { type = "oneshot", timeout = M.unmaximize_ms })
    return true
  elseif fs > 1 then
    return nil -- real fullscreen: leave it alone
  end
  local rect = type(r) == "function" and r(win) or r
  remember_and_put(win, rect, orig)
  return rect
end

-- A named position, or "center" or "restore", on the active window.
function M.command(name, win)
  win = win or hl.get_active_window()
  if not on_floating_workspace(win) then return nil end
  if name == "restore" then
    if (win.fullscreen or 0) ~= 0 then return nil end -- a maximized window would refuse; keep the saved size
    local r, t = orig_of(win)
    if not r then return nil end
    put(win, r)
    tag(win, "-" .. t)
    return r
  end
  local area = G.usable(monitor_of(win), reserve())
  if name == "center" then
    -- from a maximized window the size is only known after un-maximizing, so work it out then
    return M.apply(win, function(w) return G.center(area, w.size.x, w.size.y) end)
  end
  local r = G.place(area, name, place_opts())
  return r and M.apply(win, r)
end

-- ---------------------------------------------------------------- drag

local function write_state(text)
  local f = io.open(M.state_file, "w")
  if f then f:write(text); f:close() end
end

-- The path is quoted so a folder with a space in its name still works.
local function qs(arg) hl.exec_cmd('qs -p "' .. M.dir .. '/preview.qml" ' .. (arg or "")) end

local function start_overlay()
  if not M.overlay then M.overlay = true; qs() end
end

local function stop_overlay()
  write_state("")
  if M.overlay then M.overlay = false; qs("kill") end
end

-- Where the cursor points, but only for a window on a floating workspace: rect (or nil), monitor, usable area.
local function target(cursor)
  if not on_floating_workspace(hl.get_active_window()) then return nil end
  local mon = hl.get_monitor_at({ x = cursor.x, y = cursor.y }) or hl.get_active_monitor()
  local area = G.usable(mon, reserve())
  return G.drag_rect(cursor.x, cursor.y, area, M.cfg.edge_width, place_opts()), mon, area
end

-- Chained one-shot timers: hl.timer's repeat type has no stop handle, a generation number does.
-- Any error ends the watch instead of leaving it half alive.
local function tick(gen)
  if gen ~= M.gen or not M.polling then return end
  M.ticks = M.ticks + 1
  if M.ticks > M.max_ticks then M.polling = false; return stop_overlay() end
  local ok = pcall(function()
    local cursor = hl.get_cursor_pos()
    local rect, mon, area = target(cursor)
    if area and G.near_edge(cursor.x, cursor.y, area, M.warm_px) then start_overlay() end
    local line = rect and string.format("%s %d %d %d %d", mon.name, rect.x - mon.x, rect.y - mon.y, rect.w, rect.h) or ""
    if line ~= M.last then M.last = line; write_state(line) end
  end)
  if not ok then M.polling = false; return stop_overlay() end
  hl.timer(function() tick(gen) end, { type = "oneshot", timeout = M.tick_ms })
end

function M.finish()
  M.pressed, M.polling = false, false
  stop_overlay()
end

M.gen, M.pressed, M.polling = 0, false, false

-- SUPER + left mouse pressed. Always starts clean, so a drag that ended badly cannot block the next one.
function M.on_press()
  if not M.cfg.drag_enabled then return end
  M.finish()
  M.gen = M.gen + 1
  M.pressed, M.polling, M.ticks, M.last = true, true, 0, nil
  local w = hl.get_active_window()
  M.press_address = w and w.address
  M.press_rect = w and { x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }
  tick(M.gen)
end

-- Released after a real drag: snap to what the cursor points at, then clean up, even if the snap fails.
function M.on_release()
  local snapped
  if M.pressed then
    local ok, result = pcall(function()
      local rect = target(hl.get_cursor_pos())
      local w = hl.get_active_window()
      -- The window was already at the edge where it was dropped, so Restore must go back to where it
      -- was when the drag began (only trusted when it is the same window).
      local orig = (w and w.address == M.press_address) and M.press_rect or nil
      return rect and M.apply(w, rect, orig)
    end)
    snapped = ok and result or nil
    if not ok then M.last_error = result end
  end
  M.finish()
  return snapped
end

function M.on_click() M.finish() end

-- ---------------------------------------------------------------- binds

_G.omagnet = M -- before any bind, so a handler never finds it missing

-- Bind once per Lua state. Never hl.unbind SUPER + mouse:272: it would also remove Omarchy's own
-- "Move window" bind. Features are switched off by the config flags, not by unbinding. A shortcut Hyprland
-- rejects, or one used twice, is skipped and listed in M.bind_errors; it never stops the others.
if not _G.omagnet_bound then
  M.bind_errors = {}
  local function bind(key, fn, opts)
    local ok, err = pcall(hl.bind, key, fn, opts)
    if not ok then M.bind_errors[#M.bind_errors + 1] = key .. ": " .. tostring(err) end
  end
  local key = "SUPER + mouse:272"
  bind(key, function() _G.omagnet.on_press() end, { non_consuming = true, description = "omagnet: start preview" })
  bind(key, function() _G.omagnet.on_release() end, { drag = true, non_consuming = true, description = "omagnet: snap on release" })
  bind(key, function() _G.omagnet.on_click() end, { click = true, non_consuming = true, description = "omagnet: end preview on click" })

  local names = {}
  for name in pairs(M.cfg.keys) do names[#names + 1] = name end
  table.sort(names) -- a fixed order, so a duplicated shortcut always goes to the same command
  local used = {}
  for _, name in ipairs(names) do
    local shortcut = M.cfg.keys[name]
    if shortcut ~= "" then
      local norm = shortcut:upper():gsub("%s+", "")
      if used[norm] then
        M.bind_errors[#M.bind_errors + 1] = shortcut .. ": already used by " .. used[norm] .. ", skipped for " .. name
      else
        used[norm] = name
        bind(shortcut, function()
          local m = _G.omagnet
          local win = hl.get_active_window()
          -- Not a floating-workspace window (or keys switched off): the key belongs to the app.
          if not (m.cfg.keys_enabled and m.is_floating(win)) then return { ok = false } end
          -- On a floating workspace the key is ours, even when there is nothing to do or the snap fails.
          local ok, err = pcall(m.command, name, win)
          if not ok then m.last_error = err end
        end, { auto_consuming = true, description = "omagnet: " .. name })
      end
    end
  end
  _G.omagnet_bound = true
end

return M
