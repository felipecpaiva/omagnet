-- Pure geometry for omagnet: no Hyprland calls, so it runs and tests under plain Lua (5.5, like Hyprland).
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
--
-- opts.margin (default 0): the gap between two snapped windows. Each side of a shared edge gives half,
-- so two neighbours end up exactly `margin` apart. opts.edge_tight (default true, like Magnet): an edge
-- on the screen border gets no margin; when false it gets the whole margin.
function G.place(area, name, opts)
  local f = G.positions[name]
  if not f then return nil end
  local l, t = round(area.x + f[1] * area.w), round(area.y + f[2] * area.h)
  local r, b = round(area.x + (f[1] + f[3]) * area.w), round(area.y + (f[2] + f[4]) * area.h)
  local m = math.max(0, math.floor((opts and opts.margin) or 0))
  if m == 0 then return { x = l, y = t, w = r - l, h = b - t } end
  local tight = not (opts and opts.edge_tight == false)
  local lo, hi = math.floor(m / 2), m - math.floor(m / 2) -- on a shared edge the far window (right or bottom) insets by hi, the near one by lo
  local function inset(on_screen_edge, interior)
    if on_screen_edge then return tight and 0 or m end
    return interior
  end
  -- A tolerance, not ==: custom positions such as 0.1 + 0.9 do not add up to exactly 1 in floating point.
  local function at(v, edge) return math.abs(v - edge) < 1e-9 end
  local il, it = inset(at(f[1], 0), hi), inset(at(f[2], 0), hi)
  local ir, ib = inset(at(f[1] + f[3], 1), lo), inset(at(f[2] + f[4], 1), lo)
  local x, y = l + il, t + it
  return { x = x, y = y, w = math.max(1, (r - ir) - x), h = math.max(1, (b - ib) - y) }
end

-- Where on a window of the new size w x h should the pointer stay, if it held rect `win` at point (px, py)?
-- Same relative spot, clamped to the window. Returns the offset from the window's top left corner.
function G.grab(win, px, py, w, h)
  local fx = math.min(1, math.max(0, (px - win.x) / math.max(1, win.w)))
  local fy = math.min(1, math.max(0, (py - win.y) / math.max(1, win.h)))
  return fx * w, fy * h
end

-- Move rect `r` from one usable area to another, keeping its relative place and size, and keep it inside
-- the new area. Used for "next display".
function G.transfer(r, from, to)
  local fx, fy = (r.x - from.x) / math.max(1, from.w), (r.y - from.y) / math.max(1, from.h)
  local fw, fh = r.w / math.max(1, from.w), r.h / math.max(1, from.h)
  local w, h = math.max(1, math.min(to.w, round(fw * to.w))), math.max(1, math.min(to.h, round(fh * to.h)))
  local x = math.min(to.x + to.w - w, math.max(to.x, round(to.x + fx * to.w)))
  local y = math.min(to.y + to.h - h, math.max(to.y, round(to.y + fy * to.h)))
  return { x = x, y = y, w = w, h = h }
end

-- The monitor after (step 1) or before (step -1) `name`, in left to right order (top to bottom for the same x),
-- wrapping around. `list` items have name, x and y. With one monitor, or an unknown name, returns nil.
function G.next_monitor(list, name, step)
  local sorted = {}
  for _, m in ipairs(list) do sorted[#sorted + 1] = m end
  table.sort(sorted, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
  if #sorted < 2 then return nil end
  for i, m in ipairs(sorted) do
    if m.name == name then return sorted[(i - 1 + step) % #sorted + 1] end
  end
  return nil
end

-- Keep the window's size and put it in the middle of the area. A window larger than the area is
-- pinned to the area's top left corner.
function G.center(area, w, h)
  w, h = round(w), round(h)
  return { x = area.x + math.max(0, round((area.w - w) / 2)), y = area.y + math.max(0, round((area.h - h) / 2)), w = w, h = h }
end

-- Is the cursor within `px` of any screen edge? Used to start the outline only when it can matter.
function G.near_edge(cx, cy, area, px)
  return cx <= area.x + px or cx >= area.x + area.w - 1 - px or cy <= area.y + px or cy >= area.y + area.h - 1 - px
end

-- Zones, from Magnet's website drawings. `o.edge` is how thick the active strip along a screen edge is,
-- `o.corner` how far along an edge a corner zone reaches.
--   corner                -> quarter
--   left or right edge    -> half
--   top edge              -> maximize
--   bottom edge           -> third; sliding along it from one third to the next -> two thirds
-- Which half a top or bottom half would use is not clear from Magnet's drawings, so those stay keyboard only.

-- Which third (1, 2 or 3) of the bottom edge the cursor is on, or nil when it is not on the bottom strip
-- or is in a corner.
function G.bottom_third(cx, cy, area, o)
  if cy < area.y + area.h - 1 - o.edge then return nil end
  if cx <= area.x + o.corner or cx >= area.x + area.w - 1 - o.corner then return nil end
  if cx < area.x + area.w / 3 then return 1 end
  if cx < area.x + 2 * area.w / 3 then return 2 end
  return 3
end

-- The zone name under the cursor, or nil. `start_third` is the third where the slide along the bottom edge
-- began (nil when it has not started): moving to the next third gives two thirds, toward that side.
function G.drag_zone(cx, cy, area, o, start_third)
  local x0, y0 = area.x, area.y
  local x1, y1 = area.x + area.w - 1, area.y + area.h - 1
  local on_side = cx <= x0 + o.edge or cx >= x1 - o.edge
  local on_cap = cy <= y0 + o.edge or cy >= y1 - o.edge
  local reach_side = cx <= x0 + o.corner or cx >= x1 - o.corner
  local reach_cap = cy <= y0 + o.corner or cy >= y1 - o.corner
  if (on_side and reach_cap) or (on_cap and reach_side) then
    return (cy < y0 + area.h / 2 and "top" or "bottom") .. "_" .. (cx < x0 + area.w / 2 and "left" or "right")
  end
  if on_side then return cx < x0 + area.w / 2 and "left" or "right" end
  if cy <= y0 + o.edge then return "maximize" end
  local third = G.bottom_third(cx, cy, area, o)
  if not third then return nil end
  if start_third and math.abs(start_third - third) == 1 then
    return math.min(start_third, third) == 1 and "two_thirds_left" or "two_thirds_right"
  end
  return ({ "third_left", "third_center", "third_right" })[third]
end

-- The zone as a rectangle (and its name), or nil.
function G.drag_rect(cx, cy, area, o, opts, start_third)
  local name = G.drag_zone(cx, cy, area, o, start_third)
  return name and G.place(area, name, opts), name
end

-- Usable area of a monitor in logical pixels: size / scale (swapped on rotated monitors) minus the
-- space the bar reserves. Same formula as Omarchy's own place() in workspace-modes.lua.
-- `reserve` (optional {top, bottom, left, right}) takes extra space off the area, for a dock that
-- reserves nothing itself.
function G.usable(mon, reserve)
  local w, h = mon.width, mon.height
  if mon.transform % 2 == 1 then w, h = h, w end
  w, h = math.floor(w / mon.scale), math.floor(h / mon.scale)
  local r = mon.reserved
  local e = reserve or {}
  local left, top = r.left + (e.left or 0), r.top + (e.top or 0)
  local right, bottom = r.right + (e.right or 0), r.bottom + (e.bottom or 0)
  return { x = mon.x + left, y = mon.y + top, w = w - left - right, h = h - top - bottom }
end

-- The pre-snap rectangle lives in a window tag so it dies with the window and survives reloads.
G.orig_prefix = "omagnet-orig="

-- Round first: at a fractional scale a window can report 100.5, and %d refuses a non-integer.
function G.encode_orig(r)
  return string.format("%s%d,%d,%d,%d", G.orig_prefix, round(r.x), round(r.y), round(r.w), round(r.h))
end

function G.decode_orig(tag)
  -- the prefix holds a "-", which is special in Lua patterns, so escape it
  local x, y, w, h = tostring(tag):match("^" .. G.orig_prefix:gsub("%p", "%%%0") .. "(-?%d+),(-?%d+),(%d+),(%d+)$")
  if not x then return nil end
  return { x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h) }
end

return G
