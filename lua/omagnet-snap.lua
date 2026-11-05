-- omagnet: Magnet-style snapping for Omarchy floating workspaces.
--   * keyboard: one shortcut per position (halves, quarters, thirds, two thirds, maximize, center, restore)
--   * drag: hold SUPER + left mouse, drag to a screen edge or corner, let go; an outline shows the target
--     (corner = quarter, side = half, top = maximize, bottom = third, slide along the bottom = two thirds)
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
M.config_path = (os.getenv("HOME") or "") .. "/.config/omagnet/config.toml"
M.cfg = C.load(M.config_path)
M.custom_names = {}
for name, f in pairs(M.cfg.custom) do G.positions[name] = f; M.custom_names[name] = true end -- the user's own positions

M.state_file = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/omagnet-preview"
M.style_file = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/omagnet-style"
M.zones_file = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/omagnet-zones"
M.tick_ms, M.max_seconds = 30, 20 -- the outline and the follow stop after this long; the release still snaps
M.unmaximize_ms = 60
M.restore_px = 12 -- how far the pointer moves before a snapped window gets its old size back
M.follow_ms = 16 -- timer step while the window follows the pointer
M.settle_ms = 40 -- wait before checking the size after a snap
M.display_move_ms = 120 -- wait after sending a window to another monitor (Omarchy waits for the move to land too)
M.warm_px = 150 -- start the outline this close to an edge

-- The shortcuts as one comparable string, for "has anything changed that needs the binds made again?".
local function key_signature(c)
  local parts = {}
  for name, key in pairs(c.keys) do parts[#parts + 1] = name .. "=" .. key end
  table.sort(parts)
  return table.concat(parts, ";")
end
M.bound_signature = key_signature(M.cfg) -- what the binds below are made from

-- Re-read the config file without reloading Hyprland (the settings app calls this after it saves). The same
-- table is refilled, so everything holding M.cfg sees the new values at once. Spacing, zones, switches, the ignore
-- list and custom position rectangles apply to the next snap. A shortcut that differs from the ones bound at load, or a
-- new custom command, needs a Hyprland reload; the result says so (true) and M.needs_reload stays set.
function M.reload_config()
  local cfg = C.load(M.config_path)
  for name in pairs(M.custom_names) do G.positions[name] = nil end
  M.custom_names = {}
  for k in pairs(M.cfg) do M.cfg[k] = nil end
  for k, v in pairs(cfg) do M.cfg[k] = v end
  for name, f in pairs(M.cfg.custom) do G.positions[name] = f; M.custom_names[name] = true end
  M.needs_reload = key_signature(M.cfg) ~= M.bound_signature
  return M.needs_reload
end

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
  if C.is_ignored(M.cfg.ignore, win.class) then return false end -- an app the user asked us to leave alone
  if has_tag(win, M.tag) then return true end
  return win.fullscreen == 1 and win.workspace ~= nil and workspace_is_floating(win.workspace.id)
end
M.is_floating = on_floating_workspace
M.geometry = G -- exported so tests can add a position

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
-- A resize from an odd position can land one pixel off (a half-pixel from the centre anchor; seen with a
-- window partly off the screen). So after a short settle time the size is checked and, if wrong, set again,
-- at most twice, and not at all when the app clearly refuses the size (it did not change).
local function put(win, r, tries, last)
  tries = tries or 0
  local want_w, want_h = round(r.w), round(r.h)
  hl.dispatch(hl.dsp.window.resize({ x = want_w, y = want_h, relative = false, window = win }))
  hl.dispatch(hl.dsp.window.move({ x = round(r.x), y = round(r.y), relative = false, window = win }))
  if tries >= 2 then return end
  local address = win.address
  hl.timer(function()
    local w = find(address)
    if not (w and w.floating) then return end
    local got_w, got_h = round(w.size.x), round(w.size.y)
    if got_w == want_w and got_h == want_h then return end
    if last and last[1] == got_w and last[2] == got_h then return end -- unchanged: the app refuses this size
    put(w, r, tries + 1, { got_w, got_h })
  end, { type = "oneshot", timeout = M.settle_ms })
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

-- Send a window to the next (step 1) or previous (step -1) monitor, left to right, keeping its relative place and
-- size. The window must be floating on both sides; on a workspace that is not floating Omarchy tiles it, and then
-- it is left as Omarchy put it.
local function move_to_display(win, step)
  if (win.fullscreen or 0) ~= 0 then return nil end
  local monitors, list = hl.get_monitors(), {}
  for _, m in ipairs(monitors) do list[#list + 1] = { name = m.name, x = m.x, y = m.y } end
  local from_mon = monitor_of(win)
  local target_info = G.next_monitor(list, from_mon.name, step)
  if not target_info then return nil end
  local to_mon
  for _, m in ipairs(monitors) do if m.name == target_info.name then to_mon = m end end
  if not to_mon then return nil end
  -- Only into a floating workspace: on a tiled or scrolling one the window would be put into that layout, which
  -- is not ours to touch. The mode is read the same way as for a maximized window (see workspace_is_floating).
  local to_ws = to_mon.active_workspace and to_mon.active_workspace.id
  if not (to_ws and workspace_is_floating(to_ws)) then return nil end
  local from_area, to_area = G.usable(from_mon, reserve()), G.usable(to_mon, reserve())
  local rect = G.transfer({ x = win.at.x, y = win.at.y, w = win.size.x, h = win.size.y }, from_area, to_area)
  local saved, saved_tag = orig_of(win)
  hl.dispatch(hl.dsp.window.move({ monitor = to_mon.name, window = win }))
  if saved then -- Restore must go back to a place on the new monitor, not to coordinates of the old one
    tag(win, "-" .. saved_tag)
    tag(win, "+" .. G.encode_orig(G.transfer(saved, from_area, to_area)))
  end
  local address = win.address
  hl.timer(function()
    local w = find(address)
    if w and w.floating then put(w, rect) end
  end, { type = "oneshot", timeout = M.display_move_ms })
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
  if name == "next_display" then return move_to_display(win, 1) end
  if name == "prev_display" then return move_to_display(win, -1) end
  local area = G.usable(monitor_of(win), reserve())
  if name == "center" then
    -- from a maximized window the size is only known after un-maximizing, so work it out then
    return M.apply(win, function(w) return G.center(area, w.size.x, w.size.y) end)
  end
  local r = G.place(area, name, place_opts())
  return r and M.apply(win, r)
end

-- ---------------------------------------------------------------- drag

local function zone_opts() return { edge = M.cfg.edge_width, corner = M.cfg.corner_size } end

local function write_file(path, text)
  local f = io.open(path, "w")
  if f then f:write(text); f:close() end
end

local function write_state(text) write_file(M.state_file, text) end

-- Two small files next to the state file tell the overlay how to draw: the style (outline width, colour, fill, zone
-- outline, an optional second colour) and, when "highlight" is on, one line per zone strip. They are written before the overlay starts.
-- The colours of the theme's active window border, as "#rrggbb" (one, two for a gradient, or none), read live from
-- Hyprland, so the outline matches what real window borders look like and follows a theme change.
local function theme_border_colors()
  local ok, v = pcall(hl.get_config, "general.col.active_border")
  local out = {}
  if ok and type(v) == "table" and type(v.colors) == "table" then
    for i = 1, math.min(#v.colors, 2) do
      local hex = C.argb_hex(v.colors[i])
      if hex then out[#out + 1] = hex end
    end
  end
  return out
end

-- One line for the overlay: "<outline> <colour or -> <fill> <zone outline> [<second colour>]". Your own colour wins; else
-- the theme's border colour (a second one makes the fill a gradient); else "-" and the overlay uses the theme accent.
function M.style_line()
  local c = M.cfg
  local color, second = "-", nil
  if c.target_color ~= "" then
    color = c.target_color
  else
    local theme = theme_border_colors()
    color, second = theme[1] or "-", theme[2]
  end
  return string.format("%d %s %.2f %d%s", c.target_outline, color, c.target_fill, c.highlight_outline, second and (" " .. second) or "")
end

local function write_style() write_file(M.style_file, M.style_line()) end

local function write_zones(mon)
  if not (M.cfg.highlight and mon) then return write_file(M.zones_file, "") end
  local lines = {}
  for _, p in ipairs(G.zone_pills(G.usable(mon, reserve()), zone_opts())) do
    lines[#lines + 1] = string.format("%s %d %d %d %d", mon.name, p.x - mon.x, p.y - mon.y, p.w, p.h)
  end
  write_file(M.zones_file, table.concat(lines, "\n"))
end

-- The path is quoted so a folder with a space in its name still works.
local function qs(arg) hl.exec_cmd('qs -p "' .. M.dir .. '/preview.qml" ' .. (arg or "")) end

local function start_overlay()
  if not M.overlay then M.overlay = true; write_style(); qs() end
end

local function stop_overlay()
  write_state("")
  write_file(M.zones_file, "")
  if M.overlay then M.overlay = false; qs("kill") end
end


-- Where the cursor points, but only for a window on a floating workspace: rect (or nil), monitor, usable
-- area, zone name. `start_third` is where a slide along the bottom edge began.
local function target(cursor, start_third)
  if not on_floating_workspace(hl.get_active_window()) then return nil end
  local mon = hl.get_monitor_at({ x = cursor.x, y = cursor.y }) or hl.get_active_monitor()
  local area = G.usable(mon, reserve())
  local rect, name = G.drag_rect(cursor.x, cursor.y, area, zone_opts(), place_opts(), start_third)
  return rect, mon, area, name
end

-- Chained one-shot timers: hl.timer's repeat type has no stop handle, a generation number does.
-- Any error ends the watch instead of leaving it half alive.
local function tick(gen)
  if gen ~= M.gen or not M.polling then return end
  if os.time() - M.started > M.max_seconds then M.polling, M.following = false, nil; return stop_overlay() end
  local ok = pcall(function()
    local cursor = hl.get_cursor_pos()
    if M.restore_armed and math.abs(cursor.x - M.press_cursor.x) + math.abs(cursor.y - M.press_cursor.y) > M.restore_px then
      M.restore_armed = false
      M.restore_for_drag(cursor)
    end
    if M.following then
      local fw = find(M.following.address)
      if fw then
        hl.dispatch(hl.dsp.window.move({ x = round(cursor.x - M.following.gx), y = round(cursor.y - M.following.gy), relative = false, window = fw }))
      else
        M.following = nil -- the window closed mid-drag; never move whatever is active instead
      end
    end
    local rect, mon, area = target(cursor, M.slide_start)
    if area then
      -- A slide along the bottom edge (the side edges on a vertical screen) starts on the third where the cursor
      -- first touched it, and ends when the cursor leaves the strip.
      local third = G.slide_index(cursor.x, cursor.y, area, zone_opts())
      M.slide_start = third and (M.slide_start or third) or nil
      if G.near_edge(cursor.x, cursor.y, area, M.warm_px) then start_overlay() end
      rect, mon = target(cursor, M.slide_start)
    end
    local line = rect and string.format("%s %d %d %d %d", mon.name, rect.x - mon.x, rect.y - mon.y, rect.w, rect.h) or ""
    if line ~= M.last then M.last = line; write_state(line) end
  end)
  if not ok then M.polling, M.following = false, nil; return stop_overlay() end
  hl.timer(function() tick(gen) end, { type = "oneshot", timeout = M.following and M.follow_ms or M.tick_ms })
end

-- Dragging a snapped window away gives it its old size back, with the pointer kept at the same relative
-- spot on the window (Magnet does the same). Hyprland works out a drag from where the window was when the drag
-- began, so after the size change its own drag would leave the pointer outside the smaller window, and starting
-- a new drag from Lua does not work (checked: a second drag dispatch does not start one). So this ends Hyprland's
-- drag and moves the window itself, on a short timer, until the button is released.
-- shortcut: the window follows the pointer at about 60 steps a second, a little less smooth than Hyprland's own
-- drag; only for a drag that starts on a snapped window.
function M.restore_for_drag(cursor)
  local w = find(M.press_address)
  if not w then return end
  local r, t = orig_of(w)
  if not r then return end
  local pc = M.press_cursor
  local gx, gy = G.grab({ x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }, pc.x, pc.y, r.w, r.h)
  put(w, { x = cursor.x - gx, y = cursor.y - gy, w = r.w, h = r.h }, 2) -- 2: no size retry, it would resend a stale position
  tag(w, "-" .. t)
  hl.dispatch(hl.dsp.window.drag()) -- ends Hyprland's own drag
  M.following = { address = w.address, gx = gx, gy = gy }
  M.press_rect = nil -- the window is no longer where the drag began: a later snap remembers the restored size
end

function M.finish()
  M.pressed, M.polling, M.following = false, false, nil
  stop_overlay()
end

M.gen, M.pressed, M.polling = 0, false, false

-- SUPER + left mouse pressed. Always starts clean, so a drag that ended badly cannot block the next one.
function M.on_press()
  if not M.cfg.drag_enabled then return end
  M.finish()
  M.gen = M.gen + 1
  M.pressed, M.polling, M.started, M.last, M.slide_start = true, true, os.time(), nil, nil
  local ok = pcall(function()
    local w = hl.get_active_window()
    M.press_address = w and w.address
    M.press_cursor = hl.get_cursor_pos()
    M.press_rect = w and { x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }
    -- Armed only when the pointer is on the active window: the dragged window can still be an unfocused one at
    -- press time, and then the focused window must not be resized. shortcut: a window that was moved by hand
    -- after a snap still counts as snapped and gets its old size back on the next drag.
    local inside = w ~= nil and M.press_cursor.x >= w.at.x and M.press_cursor.x < w.at.x + w.size.x
      and M.press_cursor.y >= w.at.y and M.press_cursor.y < w.at.y + w.size.y
    M.restore_armed = inside and on_floating_workspace(w) and orig_of(w) ~= nil and (w.fullscreen or 0) == 0
    if M.cfg.highlight and on_floating_workspace(w) then
      -- Show every zone from the start of the drag (the overlay costs about 230 MB, so this is an opt-in setting).
      local mon = hl.get_monitor_at({ x = M.press_cursor.x, y = M.press_cursor.y }) or hl.get_active_monitor()
      write_zones(mon)
      start_overlay()
    end
    tick(M.gen)
  end)
  if not ok then M.finish() end
end

-- Released after a real drag: snap to what the cursor points at, then clean up, even if the snap fails.
function M.on_release()
  local snapped
  if M.pressed then
    local ok, result = pcall(function()
      local rect = target(hl.get_cursor_pos(), M.slide_start)
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
