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
  local il, it = inset(f[1] == 0, hi), inset(f[2] == 0, hi)
  local ir, ib = inset(f[1] + f[3] == 1, lo), inset(f[2] + f[4] == 1, lo)
  local x, y = l + il, t + it
  return { x = x, y = y, w = math.max(1, (r - ir) - x), h = math.max(1, (b - ib) - y) }
end

-- Keep the window's size and put it in the middle of the area. A window larger than the area is
-- pinned to the area's top left corner.
function G.center(area, w, h)
  w, h = round(w), round(h)
  return { x = area.x + math.max(0, round((area.w - w) / 2)), y = area.y + math.max(0, round((area.h - h) / 2)), w = w, h = h }
end

-- Is the cursor within `px` of the left, right or top edge? Used to start the outline only when it can matter.
function G.near_edge(cx, cy, area, px)
  return cx <= area.x + px or cx >= area.x + area.w - 1 - px or cy <= area.y + px
end

-- Drag release at (cx, cy): which rectangle, or nil when the cursor is not at an edge.
function G.drag_rect(cx, cy, area, edge, opts)
  if cx <= area.x + edge then return G.place(area, "left", opts)
  elseif cx >= area.x + area.w - 1 - edge then return G.place(area, "right", opts)
  elseif cy <= area.y + edge then return G.place(area, "maximize", opts) end
  return nil
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
