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
  -- rows, for vertical (portrait) screens and for the keyboard on any screen
  third_top = { 0, 0, 1, 1 / 3 }, third_middle = { 0, 1 / 3, 1, 1 / 3 }, third_bottom = { 0, 2 / 3, 1, 1 / 3 },
  two_thirds_top = { 0, 0, 1, 2 / 3 }, two_thirds_bottom = { 0, 1 / 3, 1, 2 / 3 },
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
  return G.place_frac(area, f, opts)
end

-- The same for a fraction {x, y, w, h} of the area (a custom position or a zone).
function G.place_frac(area, f, opts)
  local l, t = round(area.x + f[1] * area.w), round(area.y + f[2] * area.h)
  local r, b = round(area.x + (f[1] + f[3]) * area.w), round(area.y + (f[2] + f[4]) * area.h)
  local m = math.max(0, math.floor((opts and opts.margin) or 0))
  if m == 0 then return { x = l, y = t, w = math.max(1, r - l), h = math.max(1, b - t) } end
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
  -- name last: mirrored outputs share a position, and table.sort alone would order them by chance
  table.sort(sorted, function(a, b)
    if a.x ~= b.x then return a.x < b.x end
    if a.y ~= b.y then return a.y < b.y end
    return a.name < b.name
  end)
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
  o = { edge = o.edge, corner = math.min(o.corner, math.floor(math.min(area.w, area.h) / 3)) }
  if cy < area.y + area.h - 1 - o.edge then return nil end
  if cx <= area.x + o.corner or cx >= area.x + area.w - 1 - o.corner then return nil end
  if cx < area.x + area.w / 3 then return 1 end
  if cx < area.x + 2 * area.w / 3 then return 2 end
  return 3
end

-- Which third (1, 2 or 3, top to bottom) of a left or right edge the cursor is on, or nil when it is not on a side
-- strip or is in a corner. Used on vertical screens, where the side edges give thirds.
function G.side_third(cx, cy, area, o)
  o = { edge = o.edge, corner = math.min(o.corner, math.floor(math.min(area.w, area.h) / 3)) }
  if cx > area.x + o.edge and cx < area.x + area.w - 1 - o.edge then return nil end
  if cy <= area.y + o.corner or cy >= area.y + area.h - 1 - o.corner then return nil end
  if cy < area.y + area.h / 3 then return 1 end
  if cy < area.y + 2 * area.h / 3 then return 2 end
  return 3
end

-- The strip a slide runs along: the bottom edge on a wide screen, the side edges on a vertical one.
function G.slide_index(cx, cy, area, o)
  if area.h > area.w then return G.side_third(cx, cy, area, o) end
  return G.bottom_third(cx, cy, area, o)
end

-- The zone name under the cursor, or nil. `start_third` is the third where the slide along the bottom edge
-- began (nil when it has not started): moving to the next third gives two thirds, toward that side.
function G.drag_zone(cx, cy, area, o, start_third)
  -- a corner never reaches past a third of the smaller side, so the middle of an edge always stays a half
  o = { edge = o.edge, corner = math.min(o.corner, math.floor(math.min(area.w, area.h) / 3)) }
  local x0, y0 = area.x, area.y
  local x1, y1 = area.x + area.w - 1, area.y + area.h - 1
  local on_side = cx <= x0 + o.edge or cx >= x1 - o.edge
  local on_cap = cy <= y0 + o.edge or cy >= y1 - o.edge
  local reach_side = cx <= x0 + o.corner or cx >= x1 - o.corner
  local reach_cap = cy <= y0 + o.corner or cy >= y1 - o.corner
  if (on_side and reach_cap) or (on_cap and reach_side) then
    return (cy < y0 + area.h / 2 and "top" or "bottom") .. "_" .. (cx < x0 + area.w / 2 and "left" or "right")
  end
  local portrait = area.h > area.w
  if portrait then
    -- Vertical screen (Magnet's drawing): thirds along the sides, halves on the bottom edge.
    local row = G.side_third(cx, cy, area, o)
    if row then
      if start_third and math.abs(start_third - row) == 1 then
        return math.min(start_third, row) == 1 and "two_thirds_top" or "two_thirds_bottom"
      end
      return ({ "third_top", "third_middle", "third_bottom" })[row]
    end
    if cy <= y0 + o.edge then return "maximize" end
    if cy >= y1 - o.edge then return cx < x0 + area.w / 2 and "left" or "right" end
    return nil
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

-- The strips to draw while dragging, so the user can see where the zones are (Magnet highlights its activation
-- areas the same way). Each is { x, y, w, h } in the area's coordinates. Same layout as drag_zone: corners as two
-- strips each, side edges (thirds on a vertical screen), the top edge, and the bottom edge in thirds (halves on a
-- vertical screen). Strips with no size are left out.
function G.zone_pills(area, o)
  local e = o.edge
  local c = math.min(o.corner, math.floor(math.min(area.w, area.h) / 3))
  local x0, y0, x1, y1 = area.x, area.y, area.x + area.w, area.y + area.h
  local pills = {}
  local function add(x, y, w, h)
    if w > 0 and h > 0 then pills[#pills + 1] = { x = x, y = y, w = w, h = h } end
  end
  -- corners: a strip along each edge, c long
  for _, left in ipairs({ true, false }) do
    for _, top in ipairs({ true, false }) do
      local px = left and x0 or x1 - c
      local py = top and y0 or y1 - e
      add(px, py, c, e)                              -- along the top or bottom edge
      add(left and x0 or x1 - e, top and y0 or y1 - c, e, c) -- along the left or right edge
    end
  end
  local portrait = area.h > area.w
  local inner_h, inner_w = area.h - 2 * c, area.w - 2 * c
  if portrait then
    local third = inner_h / 3
    for _, left in ipairs({ true, false }) do
      for i = 0, 2 do
        add(left and x0 or x1 - e, y0 + c + math.floor(i * third), e, math.floor((i + 1) * third) - math.floor(i * third))
      end
    end
    add(x0 + c, y0, inner_w, e)                       -- top: maximize
    add(x0 + c, y1 - e, math.floor(inner_w / 2), e)   -- bottom, left half
    add(x0 + c + math.floor(inner_w / 2), y1 - e, inner_w - math.floor(inner_w / 2), e) -- bottom, right half
  else
    add(x0, y0 + c, e, inner_h)                       -- left half
    add(x1 - e, y0 + c, e, inner_h)                   -- right half
    add(x0 + c, y0, inner_w, e)                       -- top: maximize
    for i = 0, 2 do                                   -- bottom: thirds
      local from, to = math.max(x0 + c, x0 + math.floor(i * area.w / 3)), math.min(x1 - c, x0 + math.floor((i + 1) * area.w / 3))
      add(from, y1 - e, to - from, e)
    end
  end
  return pills
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

-- ---------------------------------------------------------------- grid zones (see docs/zones-design.md)
-- A layout is a list of zones, each {x, y, w, h} as fractions of the usable area, in the order the keys step through them.

local function clamp_count(n, hi) n = math.floor(tonumber(n) or 0); if n < 1 or n > (hi or 12) then return nil end return n end

-- Zones for a layout name: "columns:N", "rows:N", "grid:CxR" (N, C, R from 1 to 12) or "priority" (25, 50, 25 percent
-- columns). Returns nil and a reason for anything else.
function G.layout(name)
  name = tostring(name or ""):lower():gsub("%s", "")
  local kind, arg = name:match("^(%a+):?(.*)$")
  local z = {}
  if kind == "columns" or kind == "rows" then
    local n = clamp_count(arg)
    if not n then return nil, "a count from 1 to 12 is needed, as in " .. kind .. ":3" end
    for i = 0, n - 1 do
      z[#z + 1] = kind == "columns" and { i / n, 0, 1 / n, 1 } or { 0, i / n, 1, 1 / n }
    end
  elseif kind == "grid" then
    local c, r = arg:match("^(%d+)x(%d+)$")
    c, r = clamp_count(c), clamp_count(r)
    if not (c and r) then return nil, "grid needs columns and rows from 1 to 12, as in grid:3x2" end
    for row = 0, r - 1 do
      for col = 0, c - 1 do z[#z + 1] = { col / c, row / r, 1 / c, 1 / r } end
    end
  elseif name == "priority" then
    z = { { 0, 0, 1 / 4, 1 }, { 1 / 4, 0, 1 / 2, 1 }, { 3 / 4, 0, 1 / 4, 1 } }
  else
    return nil, "unknown layout " .. name
  end
  return z
end

-- Custom zones from text: "x y w h; x y w h" with fractions. A zone outside the area, an empty one or a bad number
-- rejects the whole text (nil and a reason), so a typo never gives a half layout.
function G.parse_zones(text)
  local z = {}
  for chunk in tostring(text or ""):gmatch("[^;]+") do
    local nums = {}
    for v in chunk:gmatch("%S+") do nums[#nums + 1] = tonumber(v) end
    if #nums ~= 4 then return nil, "a zone needs four numbers: x y w h" end
    local x, y, w, h = nums[1], nums[2], nums[3], nums[4]
    if not (x and y and w and h) then return nil, "a zone has something that is not a number" end
    if w <= 0 or h <= 0 or x < 0 or y < 0 or x + w > 1 + 1e-9 or y + h > 1 + 1e-9 then return nil, "a zone must lie inside the screen (0 to 1)" end
    z[#z + 1] = { x, y, w, h }
    if #z > 64 then return nil, "at most 64 zones" end
  end
  if #z == 0 then return nil, "no zones" end
  return z
end

-- Distance in pixels from the point to the zone's rectangle (0 inside).
local function zone_distance(f, area, px, py)
  local l, t = area.x + f[1] * area.w, area.y + f[2] * area.h
  local r, b = l + f[3] * area.w, t + f[4] * area.h
  local dx = math.max(l - px, 0, px - r)
  local dy = math.max(t - py, 0, py - b)
  return math.sqrt(dx * dx + dy * dy)
end

-- The zone (or zones) a pointer points at. Returns { index = {i, ...}, frac = {x, y, w, h} } or nil outside the area.
--   * inside one zone: that zone; inside several (overlapping zones): the smallest, like FancyZones' default
--   * in a gap between zones: the nearest zone
--   * within `o.span` pixels of a second zone (near their shared edge or corner): the box that covers them all, widened
--     to every zone that lies fully inside that box, so a selection is always a rectangle
function G.zone_at(zones, area, px, py, o)
  if not zones or #zones == 0 then return nil end
  if px < area.x or py < area.y or px >= area.x + area.w or py >= area.y + area.h then return nil end
  local span = math.max(0, (o and o.span) or 0)
  local best, best_d, best_area = nil, math.huge, math.huge
  for i, f in ipairs(zones) do
    local d, a = zone_distance(f, area, px, py), f[3] * f[4]
    if d < best_d - 1e-9 or (math.abs(d - best_d) <= 1e-9 and a < best_area) then best, best_d, best_area = i, d, a end
  end
  -- only a zone beside the chosen one joins it; an overlapping zone (a custom layout) never does
  local function overlaps(a, b)
    return math.min(a[1] + a[3], b[1] + b[3]) - math.max(a[1], b[1]) > 1e-9 and math.min(a[2] + a[4], b[2] + b[4]) - math.max(a[2], b[2]) > 1e-9
  end
  local near = {}
  for i, f in ipairs(zones) do
    if i == best or (zone_distance(f, area, px, py) <= span and not overlaps(f, zones[best])) then near[#near + 1] = i end
  end
  local l, t, r, b = 1e9, 1e9, -1e9, -1e9
  for _, i in ipairs(near) do
    local f = zones[i]
    l, t, r, b = math.min(l, f[1]), math.min(t, f[2]), math.max(r, f[1] + f[3]), math.max(b, f[2] + f[4])
  end
  if #near > 1 then
    near = {}
    for i, f in ipairs(zones) do
      if f[1] >= l - 1e-9 and f[2] >= t - 1e-9 and f[1] + f[3] <= r + 1e-9 and f[2] + f[4] <= b + 1e-9 then near[#near + 1] = i end
    end
  else
    local f = zones[best]; l, t, r, b = f[1], f[2], f[1] + f[3], f[2] + f[4]
  end
  return { index = near, frac = { l, t, r - l, b - t } }
end

-- Where a window goes when it steps `step` (1 or -1) through the zones. The window counts as being in the zone whose
-- centre is nearest to its own, but only if it covers most of it; otherwise the step goes to that nearest zone first.
function G.zone_step(zones, area, win, step)
  if not zones or #zones == 0 then return nil end
  local cx, cy = win.x + win.w / 2, win.y + win.h / 2
  local best, best_d = 1, math.huge
  for i, f in ipairs(zones) do
    local zx, zy = area.x + (f[1] + f[3] / 2) * area.w, area.y + (f[2] + f[4] / 2) * area.h
    local d = (zx - cx) ^ 2 + (zy - cy) ^ 2
    if d < best_d then best, best_d = i, d end
  end
  local f = zones[best]
  local zl, zt, zw, zh = area.x + f[1] * area.w, area.y + f[2] * area.h, f[3] * area.w, f[4] * area.h
  local ow = math.max(0, math.min(win.x + win.w, zl + zw) - math.max(win.x, zl))
  local oh = math.max(0, math.min(win.y + win.h, zt + zh) - math.max(win.y, zt))
  local inter = ow * oh
  local union = win.w * win.h + zw * zh - inter
  local in_zone = union > 0 and inter / union > 0.75
  local idx = in_zone and ((best - 1 + step) % #zones + 1) or best
  return idx, zones[idx]
end


return G
