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
  parts[#parts + 1] = "zone_modifier=" .. tostring(c.zones_enabled and c.zone_modifier or "") -- the zone drag bind is made from this
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

-- ---------------------------------------------------------------- grid zones (docs/zones-design.md)

M.layout_override = {} -- monitor name -> layout name set by a key; memory only, a Lua reload forgets it
M.preset_cycle = { "columns:2", "columns:3", "rows:2", "rows:3", "grid:2x2", "grid:3x2", "grid:3x3", "priority" }

-- Zones for a layout name: a [layout_<name>] section from the config, else a built-in. nil and a reason when neither.
function M.resolve_layout(name)
  local text = M.cfg.layouts[name]
  if text then return G.parse_zones(text) end
  return G.layout(name)
end

-- The layout name for a monitor showing workspace `ws` (a workspace object or nil): a layout picked by key, else the
-- workspace's own entry (by id, then by name), else the monitor's [zone_layouts] entry, else the default for its shape.
function M.layout_name(mon, ws)
  local w, h = G.logical_size(mon)
  local by_ws = ws and (M.cfg.workspace_layouts[tostring(ws.id)] or (ws.name and M.cfg.workspace_layouts[ws.name]))
  local name = M.layout_override[mon.name] or by_ws or M.cfg.zone_layouts[mon.name]
    or (h > w and M.cfg.layout_portrait or M.cfg.layout_landscape)
  if name == "auto" then name = G.auto_layout(w, h) end -- a recommendation by the screen's size and shape
  return name
end

-- The zones for a monitor. A layout that cannot be read falls back to the default, and the reason is kept in
-- M.last_error, so a typo in the config never leaves the drag without zones.
function M.zones_for(mon, ws)
  local name = M.layout_name(mon, ws or mon.active_workspace)
  local zones, why = M.resolve_layout(name)
  if zones then return zones, name end
  M.last_error = "layout " .. tostring(name) .. ": " .. tostring(why)
  local w, h = G.logical_size(mon)
  local fallback = G.auto_layout(w, h)
  return G.layout(fallback), fallback
end

local function notify(text)
  pcall(hl.exec_cmd, 'notify-send -t 1500 -a omagnet "omagnet" "' .. text:gsub('"', "") .. '"')
end

-- Step a window to the next or previous zone of its monitor's layout.
local function step_zone(win, step)
  local mon = monitor_of(win)
  local area = G.usable(mon, reserve())
  local zones = M.zones_for(mon, win.workspace)
  local _, f = G.zone_step(zones, area, { x = win.at.x, y = win.at.y, w = win.size.x, h = win.size.y }, step)
  return f and M.apply(win, G.place_frac(area, f, place_opts()))
end

-- Switch the layout of the window's monitor: to `name`, or step through the custom layouts then the built-in ones.
local function set_layout(win, name, step)
  local mon = monitor_of(win)
  if not name then
    local list = {}
    for id in pairs(M.cfg.layouts) do list[#list + 1] = id end
    table.sort(list)
    for _, p in ipairs(M.preset_cycle) do list[#list + 1] = p end
    local at = 0
    for i, n in ipairs(list) do if n == M.layout_name(mon, win.workspace) then at = i end end
    name = list[(at - 1 + step) % #list + 1]
  end
  if not M.resolve_layout(name) then return nil end
  M.layout_override[mon.name] = name
  notify(mon.name .. ": " .. name)
  return name
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
  if name == "zone_next" then return step_zone(win, 1) end
  if name == "zone_prev" then return step_zone(win, -1) end
  if name == "layout_next" then return set_layout(win, nil, 1) end
  if name == "layout_prev" then return set_layout(win, nil, -1) end
  if name:sub(1, 7) == "layout:" then return set_layout(win, name:sub(8)) end
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

-- Zone mode: every zone of the monitor, as it will be placed (margins included), for the overlay to draw.
local function write_zone_grid(mon)
  local area = G.usable(mon, reserve())
  local lines = {}
  for _, f in ipairs((M.zones_for(mon))) do
    local r = G.place_frac(area, f, place_opts())
    lines[#lines + 1] = string.format("%s %d %d %d %d", mon.name, r.x - mon.x, r.y - mon.y, r.w, r.h)
  end
  write_file(M.zones_file, table.concat(lines, "\n"))
end

-- The path is quoted so a folder with a space in its name still works.
local function qs(arg) hl.exec_cmd('qs -p "' .. M.dir .. '/preview.qml" ' .. (arg or "")) end

-- The overlay is one `qs` process. A kill sent a few milliseconds after a start finds nothing to kill (the process is not
-- registered yet) and the new process lives on, so a stop waits M.kill_ms, and a start that comes while a stop is waiting
-- reuses the running process instead of launching a second one.
M.kill_ms = 400
local function start_overlay()
  if M.overlay then return end
  M.overlay = true
  write_style()
  if not M.qs_running then M.qs_running = true; qs() end
end

local function stop_overlay()
  write_state("")
  write_file(M.zones_file, "")
  if M.overlay then
    M.overlay = false
    hl.timer(function()
      if not M.overlay and M.qs_running then M.qs_running = false; qs("kill") end
    end, { type = "oneshot", timeout = M.kill_ms })
  end
end


-- Where the cursor points, but only for a window on a floating workspace: rect (or nil), monitor, usable
-- area, zone name. `start_third` is where a slide along the bottom edge began.
local function target(cursor, start_third)
  if not on_floating_workspace(hl.get_active_window()) then return nil end
  local mon = hl.get_monitor_at({ x = cursor.x, y = cursor.y }) or hl.get_active_monitor()
  local area = G.usable(mon, reserve())
  if M.zone_mode then
    local z = G.zone_at((M.zones_for(mon, mon.active_workspace)), area, cursor.x, cursor.y, { span = M.cfg.zone_span })
    return z and G.place_frac(area, z.frac, place_opts()), mon, area, "zone"
  end
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
    M.update_mode()
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
    if M.zone_mode then
      if mon and mon.name ~= M.zone_mon then M.zone_mon = mon.name; write_zone_grid(mon) end
    elseif area then
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

-- Zone mode follows the modifier live: hold zone_modifier's extra keys (by default SHIFT, on top of the SUPER of the drag)
-- and the zones show, let go and the drag goes back to the edge zones. Hyprland sends no event for a key pressed in the
-- middle of a drag, but hl.is_key_down can be asked on every tick. nil means "cannot tell" and changes nothing.
local MOD_KEYS = { SHIFT = { "Shift_L", "Shift_R" }, CTRL = { "Control_L", "Control_R" }, CONTROL = { "Control_L", "Control_R" }, ALT = { "Alt_L", "Alt_R" } }
local function extras_down()
  local any = false
  for mod in tostring(M.cfg.zone_modifier):upper():gmatch("%a+") do
    local keys = MOD_KEYS[mod]
    if keys then
      any = true
      local down = false
      for _, k in ipairs(keys) do
        local ok, r = pcall(hl.is_key_down, k)
        if not ok or r == nil then return nil end
        down = down or r
      end
      if not down then return false end
    end
  end
  return any or nil
end

function M.update_mode()
  local down = extras_down()
  if down == nil or not M.cfg.zones_enabled or down == M.zone_mode then return end
  M.zone_mode, M.last, M.zone_mon = down, nil, nil
  local cursor = hl.get_cursor_pos()
  local mon = hl.get_monitor_at({ x = cursor.x, y = cursor.y }) or hl.get_active_monitor()
  if down then
    if on_floating_workspace(hl.get_active_window()) then M.zone_mon = mon.name; write_zone_grid(mon); start_overlay() end
  else
    write_state("")
    if M.cfg.highlight then write_zones(mon) else write_file(M.zones_file, ""); stop_overlay() end
  end
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

-- Show a layout on every monitor for a few seconds, with the overlay a drag uses: the settings app calls this from its
-- layout pages. `what` is a layout name, or "text:x y w h; ..." for zones that are not saved yet. Returns true, or nil
-- and a reason when the layout cannot be read. A drag that starts meanwhile takes the overlay over; a newer preview
-- replaces an older one.
M.preview_gen = 0
function M.preview(what, seconds)
  what = tostring(what or "")
  local zones, why
  if what:sub(1, 5) == "text:" then zones, why = G.parse_zones(what:sub(6)) else zones, why = M.resolve_layout(what) end
  if not zones then return nil, why end
  if M.pressed then return nil, "a drag is in progress" end
  local lines = {}
  for _, mon in ipairs(hl.get_monitors()) do
    local area = G.usable(mon, reserve())
    for _, f in ipairs(zones) do
      local r = G.place_frac(area, f, place_opts())
      lines[#lines + 1] = string.format("%s %d %d %d %d", mon.name, r.x - mon.x, r.y - mon.y, r.w, r.h)
    end
  end
  write_state("")
  write_file(M.zones_file, table.concat(lines, "\n"))
  start_overlay()
  M.preview_gen = M.preview_gen + 1
  local gen = M.preview_gen
  hl.timer(function()
    if gen == M.preview_gen and not M.pressed then M.preview_gen = M.preview_gen + 1; stop_overlay() end
  end, { type = "oneshot", timeout = math.floor(math.max(0.5, math.min(15, tonumber(seconds) or 4)) * 1000) })
  return true
end


function M.finish()
  M.pressed, M.polling, M.following = false, false, nil
  M.zone_mode, M.zone_mon = false, nil
  stop_overlay()
end

M.gen, M.pressed, M.polling = 0, false, false

-- SUPER + left mouse pressed. Always starts clean, so a drag that ended badly cannot block the next one.
function M.on_press(zone)
  if zone then
    if not M.cfg.zones_enabled then return end
  elseif not M.cfg.drag_enabled then
    return
  end
  M.finish()
  M.zone_mode = zone == true
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
    if M.zone_mode then
      -- Zone mode always shows the zones, from the start of the drag, on the monitor under the pointer.
      if on_floating_workspace(w) then
        local mon = hl.get_monitor_at({ x = M.press_cursor.x, y = M.press_cursor.y }) or hl.get_active_monitor()
        M.zone_mon = mon.name
        write_zone_grid(mon)
        start_overlay()
      end
    elseif M.cfg.highlight and on_floating_workspace(w) then
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
      M.update_mode() -- the modifier may have changed since the last tick
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

  -- Zone mode: its own drag bind of the same shape as Omarchy's, so Hyprland still moves the window, plus ours.
  -- Hyprland matches a bind's modifiers exactly, so this never fires together with SUPER + mouse:272.
  if M.cfg.zones_enabled then
    local mods = M.cfg.zone_modifier:gsub("%s*%+?%s*mouse:272%s*$", "")
    local zkey = mods .. " + mouse:272"
    if zkey:upper():gsub("%s+", "") ~= "SUPER+MOUSE:272" and mods:match("%S") then
      bind(zkey, hl.dsp.window.drag(), { mouse = true, description = "omagnet: move window (zones)" })
      bind(zkey, function() _G.omagnet.on_press(true) end, { non_consuming = true, description = "omagnet: start zones" })
      bind(zkey, function() _G.omagnet.on_release() end, { drag = true, non_consuming = true, description = "omagnet: snap to zone on release" })
      bind(zkey, function() _G.omagnet.on_click() end, { click = true, non_consuming = true, description = "omagnet: end zones on click" })
    else
      M.bind_errors[#M.bind_errors + 1] = "zone_modifier " .. M.cfg.zone_modifier .. ": would clash with SUPER + mouse:272, zone drag not bound"
    end
  end

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
