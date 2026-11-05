-- Pure geometry for omagnet: no Hyprland calls, so it runs and tests under plain lua5.4.
-- An area is {x, y, w, h} in logical pixels. Every position is a fraction of the usable area.
local G = {}

-- name -> { x, y, w, h } as fractions of the usable area
G.positions = {
  left = { 0, 0, 1 / 2, 1 }, right = { 1 / 2, 0, 1 / 2, 1 },
  top = { 0, 0, 1, 1 / 2 }, bottom = { 0, 1 / 2, 1, 1 / 2 },
  top_left = { 0, 0, 1 / 2, 1 / 2 }, top_right = { 1 / 2, 0, 1 / 2, 1 / 2 },
  bottom_left = { 0, 1 / 2, 1 / 2, 1 / 2 }, bottom_right = { 1 / 2, 1 / 2, 1 / 2, 1 / 2 },
  third_left = { 0, 0, 1 / 3, 1 }, third_center = { 1 / 3, 0, 1 / 3, 1 }, third_right = { 2 / 3, 0, 1 / 3, 1 },
  two_thirds_left = { 0, 0, 2 / 3, 1 }, two_thirds_center = { 1 / 6, 0, 2 / 3, 1 }, two_thirds_right = { 1 / 3, 0, 2 / 3, 1 },
  maximize = { 0, 0, 1, 1 },
}

local function round(v) return math.floor(v + 0.5) end

-- Integer rectangle for a named position. Edges are rounded, not sizes, so neighbours (for example
-- three thirds of an odd width) meet with no gap and no overlap. Hyprland rejects fractions.
function G.place(area, name)
  local f = G.positions[name]
  if not f then return nil end
  local l, t = round(area.x + f[1] * area.w), round(area.y + f[2] * area.h)
  local r, b = round(area.x + (f[1] + f[3]) * area.w), round(area.y + (f[2] + f[4]) * area.h)
  return { x = l, y = t, w = r - l, h = b - t }
end

-- Keep the window's size and put it in the middle of the area. A window larger than the area is
-- pinned to the area's top left corner.
function G.center(area, w, h)
  return { x = area.x + math.max(0, round((area.w - w) / 2)), y = area.y + math.max(0, round((area.h - h) / 2)), w = w, h = h }
end

-- Drag release at (cx, cy): which rectangle, or nil when the cursor is not at an edge.
function G.drag_rect(cx, cy, area, edge)
  if cx <= area.x + edge then return G.place(area, "left")
  elseif cx >= area.x + area.w - 1 - edge then return G.place(area, "right")
  elseif cy <= area.y + edge then return G.place(area, "maximize") end
  return nil
end

-- Usable area of a monitor in logical pixels: size / scale (swapped on rotated monitors) minus the
-- space the bar reserves. Same formula as Omarchy's own place() in workspace-modes.lua.
function G.usable(mon)
  local w, h = mon.width, mon.height
  if mon.transform % 2 == 1 then w, h = h, w end
  w, h = math.floor(w / mon.scale), math.floor(h / mon.scale)
  local r = mon.reserved
  return { x = mon.x + r.left, y = mon.y + r.top, w = w - r.left - r.right, h = h - r.top - r.bottom }
end

-- The pre-snap rectangle lives in a window tag so it dies with the window and survives reloads.
G.orig_prefix = "omagnet-orig="

function G.encode_orig(r) return string.format("%s%d,%d,%d,%d", G.orig_prefix, r.x, r.y, r.w, r.h) end

function G.decode_orig(tag)
  -- the prefix holds a "-", which is special in Lua patterns, so escape it
  local x, y, w, h = tostring(tag):match("^" .. G.orig_prefix:gsub("%p", "%%%0") .. "(-?%d+),(-?%d+),(%d+),(%d+)$")
  if not x then return nil end
  return { x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h) }
end

return G
