-- omagnet prototype v0: drag a window with SUPER + left mouse to a screen edge, let go, and it snaps.
--   left edge -> left half, right edge -> right half, top edge -> whole usable area.
-- Only acts on windows of an Omarchy floating workspace (tag below). Tiled and scrolling workspaces
-- are never touched. Load live:  hyprctl eval 'dofile("<path to this file>")'
-- shortcut: only SUPER+drag is caught; dragging an app's own title bar (Chrome, VS Code) does not
-- fire a bind, so it does not snap. Upgrade when we pick a signal for those drags.
-- While you hold the drag, a click-through outline (preview.qml, run with qs) shows where the window will land.
-- shortcut: no corners, no restore-on-drag-away yet. The outline process starts on press and exits on
-- release, because an idle one costs about 230 MB; a 20 s cap ends it if the release is never seen.

local M = {}

M.tag = "omarchy-floating-workspace"
M.edge = 8 -- pixels from the screen edge that count as "at the edge"

-- Pure: where should a window go when released at (cx, cy) on a monitor whose usable area is
-- {x, y, w, h}? Returns nil when the cursor is not at an edge. Integers only, Hyprland rejects
-- percentages.
function M.rect_for(cx, cy, area, edge)
  local x, y, w, h = area.x, area.y, area.w, area.h
  local half = math.floor(w / 2)
  if cx <= x + edge then
    return { x = x, y = y, w = half, h = h }
  elseif cx >= x + w - 1 - edge then
    return { x = x + half, y = y, w = w - half, h = h }
  elseif cy <= y + edge then
    return { x = x, y = y, w = w, h = h }
  end
  return nil
end

-- Usable area of a monitor in logical pixels: size / scale (swapped on rotated monitors) minus the
-- space the bar reserves. Same formula as Omarchy's own place() in workspace-modes.lua.
function M.usable(mon)
  local w, h = mon.width, mon.height
  if mon.transform % 2 == 1 then w, h = h, w end
  w, h = math.floor(w / mon.scale), math.floor(h / mon.scale)
  local r = mon.reserved
  return { x = mon.x + r.left, y = mon.y + r.top, w = w - r.left - r.right, h = h - r.top - r.bottom }
end

local function on_floating_workspace(win)
  if not (win and win.floating) then return false end
  for _, t in ipairs(win.tags or {}) do
    if t == M.tag then return true end
  end
  return false
end

-- Snap `win` to wherever the cursor is. Returns the rectangle used, or nil if nothing happened.
function M.snap(win, cursor)
  if not on_floating_workspace(win) then return nil end
  if win.fullscreen and win.fullscreen ~= 0 then return nil end -- a maximized window refuses to move
  local mon = hl.get_monitor_at({ x = cursor.x, y = cursor.y }) or hl.get_active_monitor()
  local rect = M.rect_for(cursor.x, cursor.y, M.usable(mon), M.edge)
  if not rect then return nil end
  -- Floating resize is centre-anchored, so resize first and move second.
  hl.dispatch(hl.dsp.window.resize({ x = rect.w, y = rect.h, relative = false, window = win }))
  hl.dispatch(hl.dsp.window.move({ x = rect.x, y = rect.y, relative = false, window = win }))
  return rect
end

M.dir = (debug.getinfo(1, "S").source:match("^@(.*)/") or ".")
M.state_file = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/omagnet-preview"
M.tick_ms = 30
M.max_ticks = 666 -- about 20 s

local function write_state(text)
  local f = io.open(M.state_file, "w")
  if f then f:write(text); f:close() end
end

local function qs(...) hl.exec_cmd("qs -p " .. M.dir .. "/preview.qml " .. (... or "")) end

-- What the cursor points at right now: rect and monitor, or nil.
local function target(cursor)
  if not on_floating_workspace(hl.get_active_window()) then return nil end
  local mon = hl.get_monitor_at({ x = cursor.x, y = cursor.y }) or hl.get_active_monitor()
  local area = M.usable(mon)
  local rect = M.rect_for(cursor.x, cursor.y, area, M.edge)
  return rect, mon, area
end

-- Chained one-shot timers: hl.timer's repeat type has no stop handle, a flag does.
local function tick()
  if not M.dragging then return end
  M.ticks = M.ticks + 1
  if M.ticks > M.max_ticks then return M.finish() end
  local rect, mon = target(hl.get_cursor_pos())
  local line = rect and string.format("%s %d %d %d %d", mon.name, rect.x - mon.x, rect.y - mon.y, rect.w, rect.h) or ""
  if line ~= M.last then M.last = line; write_state(line) end
  hl.timer(tick, { type = "oneshot", timeout = M.tick_ms })
end

function M.finish()
  M.dragging = false
  write_state("")
  qs("kill")
end

-- SUPER + left mouse pressed: start the outline and the cursor watch.
function M.on_press()
  if M.dragging then return end
  M.dragging, M.ticks, M.last = true, 0, nil
  write_state("")
  qs()
  tick()
end

-- Released after a real drag (bind flag `drag`): snap, then clean up.
function M.on_release()
  local snapped = M.dragging and M.snap(hl.get_active_window(), hl.get_cursor_pos())
  M.finish()
  return snapped
end

-- Released without a drag (a click): just clean up.
function M.on_click() M.finish() end

-- Bind once per Lua state. Never hl.unbind this key: it would also remove Omarchy's own
-- SUPER + mouse:272 "Move window" bind.
if not _G.omagnet_bound then
  _G.omagnet_bound = true
  local key = "SUPER + mouse:272"
  hl.bind(key, function() _G.omagnet.on_press() end, { non_consuming = true, description = "omagnet: start preview" })
  hl.bind(key, function() _G.omagnet.on_release() end, { drag = true, non_consuming = true, description = "omagnet: snap on release" })
  hl.bind(key, function() _G.omagnet.on_click() end, { click = true, non_consuming = true, description = "omagnet: end preview on click" })
end

_G.omagnet = M
return M
