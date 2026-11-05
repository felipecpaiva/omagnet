-- omagnet prototype v0: drag a window with SUPER + left mouse to a screen edge, let go, and it snaps.
--   left edge -> left half, right edge -> right half, top edge -> whole usable area.
-- Only acts on windows of an Omarchy floating workspace (tag below). Tiled and scrolling workspaces
-- are never touched. Load live:  hyprctl eval 'dofile("<path to this file>")'
-- shortcut: only SUPER+drag is caught; dragging an app's own title bar (Chrome, VS Code) does not
-- fire a bind, so it does not snap. Upgrade when we pick a signal for those drags.
-- shortcut: no preview, no corners, no restore-on-drag-away yet.

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

-- Runs when SUPER + left mouse is released after a real drag (bind flag `drag`).
function M.on_release()
  M.snap(hl.get_active_window(), hl.get_cursor_pos())
end

-- Bind once per Lua state. Never hl.unbind this key: it would also remove Omarchy's own
-- SUPER + mouse:272 "Move window" bind.
if not _G.omagnet_bound then
  _G.omagnet_bound = true
  hl.bind("SUPER + mouse:272", function() _G.omagnet.on_release() end,
    { drag = true, non_consuming = true, description = "omagnet: snap on release" })
end

_G.omagnet = M
return M
