-- Plain Lua self-check:  lua lua/test_geometry.lua
local dir = arg[0]:match("^(.*)/") or "."
local G = dofile(dir .. "/geometry.lua")

local function eq(r, x, y, w, h, name)
  assert(r and r.x == x and r.y == y and r.w == w and r.h == h,
    string.format("%s: got %s", name, r and (r.x .. "," .. r.y .. " " .. r.w .. "x" .. r.h) or "nil"))
end

local A = { x = 0, y = 26, w = 1280, h = 774 }
eq(G.place(A, "left"), 0, 26, 640, 774, "left")
eq(G.place(A, "right"), 640, 26, 640, 774, "right")
eq(G.place(A, "top"), 0, 26, 1280, 387, "top")
eq(G.place(A, "bottom"), 0, 413, 1280, 387, "bottom")
eq(G.place(A, "bottom_right"), 640, 413, 640, 387, "bottom_right")
eq(G.place(A, "maximize"), 0, 26, 1280, 774, "maximize")
assert(G.place(A, "nonsense") == nil, "unknown name")

-- Neighbours must tile exactly, for odd and awkward sizes too.
for _, w in ipairs({ 1280, 1281, 1279, 1366, 1920, 2560, 7, 100 }) do
  local a = { x = 13, y = 5, w = w, h = 777 }
  local l, c, r = G.place(a, "third_left"), G.place(a, "third_center"), G.place(a, "third_right")
  assert(l.x == a.x and l.x + l.w == c.x and c.x + c.w == r.x and r.x + r.w == a.x + a.w, "thirds tile, width " .. w)
  local h1, h2 = G.place(a, "left"), G.place(a, "right")
  assert(h1.x + h1.w == h2.x and h2.x + h2.w == a.x + a.w, "halves tile, width " .. w)
  local t, b = G.place(a, "top"), G.place(a, "bottom")
  assert(t.y + t.h == b.y and b.y + b.h == a.y + a.h, "top and bottom tile, height 777")
  local two_l, two_r = G.place(a, "two_thirds_left"), G.place(a, "two_thirds_right")
  assert(two_l.x == a.x and two_r.x + two_r.w == a.x + a.w, "two thirds reach both edges, width " .. w)
  local tl, br = G.place(a, "top_left"), G.place(a, "bottom_right")
  assert(tl.x == a.x and tl.y == a.y and br.x + br.w == a.x + a.w and br.y + br.h == a.y + a.h, "quarters reach corners")
end
local two_c = G.place({ x = 0, y = 0, w = 1200, h = 100 }, "two_thirds_center")
eq(two_c, 200, 0, 800, 100, "two thirds center")

-- center keeps size
eq(G.center(A, 400, 300), 440, 263, 400, 300, "center")
eq(G.center(A, 2000, 1000), 0, 26, 2000, 1000, "center, window larger than the area")

-- drag zones: edge strip 12 px, corner reach 64 px
local O = { edge = 12, corner = 64 }
local AREA = { x = 0, y = 26, w = 1280, h = 774 } -- x 0..1279, y 26..799
local function zone(cx, cy, start) return G.drag_zone(cx, cy, AREA, O, start) end
assert(zone(0, 300) == "left" and zone(1279, 300) == "right", "side edges give halves")
assert(zone(640, 26) == "maximize", "top edge maximizes")
assert(zone(5, 30) == "top_left" and zone(1275, 30) == "top_right", "top corners")
assert(zone(5, 795) == "bottom_left" and zone(1275, 795) == "bottom_right", "bottom corners")
assert(zone(40, 26) == "top_left", "top edge close to the corner is the corner, not maximize")
assert(zone(1279, 90) == "top_right", "side edge within reach of the top is the corner")
assert(zone(0, 400) == "left" and zone(0, 120) == "left", "side edge below the corner reach is a half")
assert(zone(200, 799) == "third_left" and zone(640, 799) == "third_center" and zone(1100, 799) == "third_right", "bottom thirds")
assert(zone(70, 799) == "third_left" and zone(1209, 799) == "third_right", "just outside the corner reach is a third")
assert(zone(640, 400) == nil and zone(640, 100) == nil and zone(100, 400) == nil, "inside the screen is nothing")
assert(zone(640, 799 - 13) == nil, "one pixel above the bottom strip is nothing")
-- sliding along the bottom edge
assert(zone(640, 799, 1) == "two_thirds_left", "slide from the left third to the middle")
assert(zone(640, 799, 3) == "two_thirds_right", "slide from the right third to the middle")
assert(zone(200, 799, 2) == "two_thirds_left", "slide from the middle to the left third")
assert(zone(1100, 799, 2) == "two_thirds_right", "slide from the middle to the right third")
assert(zone(1100, 799, 1) == "third_right", "a jump from the far left to the far right is just the third under the cursor")
assert(zone(200, 799, 1) == "third_left", "staying on the same third stays a third")
assert(G.bottom_third(200, 799, AREA, O) == 1 and G.bottom_third(640, 799, AREA, O) == 2 and G.bottom_third(1100, 799, AREA, O) == 3, "bottom_third")
assert(G.bottom_third(5, 799, AREA, O) == nil and G.bottom_third(640, 400, AREA, O) == nil, "bottom_third not in a corner or off the strip")
-- the rectangle for a zone
local zr, zn = G.drag_rect(0, 300, A, O, { margin = 8 })
eq(zr, 0, 26, 636, 774, "drag left rectangle with margin"); assert(zn == "left", "drag left name")
eq(G.drag_rect(5, 795, A, O), 0, 413, 640, 387, "drag bottom left corner is a quarter")
eq(G.drag_rect(640, 799, A, O, nil, 1), 0, 26, 853, 774, "drag slide gives two thirds")
assert(G.drag_rect(640, 400, A, O) == nil, "drag in the middle is nil")
-- a small area never makes two zones fight: every edge pixel gives a name or nil, never an error
for x = 0, 99 do for y = 0, 99 do
  local n = G.drag_zone(x, y, { x = 0, y = 0, w = 100, h = 100 }, O)
  assert(n == nil or G.positions[n], "zone is a known position")
end end

-- usable
eq(G.usable({ width = 2560, height = 1600, scale = 2.0, transform = 0, x = 0, y = 0, reserved = { left = 0, top = 26, right = 0, bottom = 0 } }), 0, 26, 1280, 774, "usable scale 2")
eq(G.usable({ width = 1080, height = 1920, scale = 1.0, transform = 1, x = 100, y = 0, reserved = { left = 0, top = 0, right = 0, bottom = 0 } }), 100, 0, 1920, 1080, "usable rotated")

-- orig tag round trip
local tag = G.encode_orig({ x = -5, y = 26, w = 600, h = 400 })
assert(tag == "omagnet-orig=-5,26,600,400", tag)
local r = G.decode_orig(tag)
eq(r, -5, 26, 600, 400, "decode")
assert(G.decode_orig("omarchy-floating-workspace") == nil and G.decode_orig("omagnet-orig=1,2,3") == nil, "decode junk")
-- margins: neighbours end exactly `margin` apart, the screen border stays tight by default
local M8 = { margin = 8 }
local l, r = G.place(A, "left", M8), G.place(A, "right", M8)
eq(l, 0, 26, 636, 774, "left with margin, tight to the screen edge")
eq(r, 644, 26, 636, 774, "right with margin")
assert(r.x - (l.x + l.w) == 8, "gap between halves is the margin")
local tl, br = G.place(A, "top_left", M8), G.place(A, "bottom_right", M8)
eq(tl, 0, 26, 636, 383, "top left with margin")
eq(br, 644, 417, 636, 383, "bottom right with margin")
eq(G.place(A, "maximize", M8), 0, 26, 1280, 774, "maximize stays tight")
-- not tight: the border gets the whole margin
eq(G.place(A, "left", { margin = 8, edge_tight = false }), 8, 34, 628, 758, "left, margin on the screen border too")
eq(G.place(A, "maximize", { margin = 8, edge_tight = false }), 8, 34, 1264, 758, "maximize with margin all round")
-- three thirds with an odd margin: the gaps are the margin, nothing overlaps
for _, m in ipairs({ 1, 3, 7, 8, 11 }) do
  for _, w in ipairs({ 1280, 1281, 999 }) do
    local a = { x = 0, y = 0, w = w, h = 600 }
    local o = { margin = m }
    local p1, p2, p3 = G.place(a, "third_left", o), G.place(a, "third_center", o), G.place(a, "third_right", o)
    assert(p2.x - (p1.x + p1.w) == m and p3.x - (p2.x + p2.w) == m, "gap is the margin, margin " .. m .. " width " .. w)
    assert(p1.x == 0 and p3.x + p3.w == w, "thirds stay tight to the screen border")
    local q1, q2 = G.place(a, "top", o), G.place(a, "bottom", o)
    assert(q2.y - (q1.y + q1.h) == m, "vertical gap is the margin")
  end
end
-- a margin larger than the window never makes it vanish or go negative
local tiny = G.place({ x = 0, y = 0, w = 10, h = 10 }, "left", { margin = 50, edge_tight = false })
assert(tiny.w >= 1 and tiny.h >= 1, "never smaller than 1 pixel")
assert(G.place(A, "left", { margin = -5 }).w == 640, "negative margin is ignored")
-- reserve takes space off the usable area
local mon = { width = 2560, height = 1600, scale = 2.0, transform = 0, x = 0, y = 0, reserved = { left = 0, top = 26, right = 0, bottom = 0 } }
eq(G.usable(mon, { bottom = 60 }), 0, 26, 1280, 714, "reserve bottom for a dock")
eq(G.usable(mon, { left = 50, top = 4 }), 50, 30, 1230, 770, "reserve left and top")
-- fractional sizes (fractional scale) must not crash the restore tag
assert(G.encode_orig({ x = 10.5, y = 26, w = 600.4, h = 400.5 }) == "omagnet-orig=11,26,600,401", "encode rounds")
eq(G.center(A, 400.6, 300.2), 440, 263, 401, 300, "center rounds a fractional size")
-- every position stays tight to the screen border when it touches it, margin or not
for name, f in pairs(G.positions) do
  local p = G.place(A, name, { margin = 8 })
  if f[1] == 0 then assert(p.x == A.x, name .. " left edge tight") end
  if f[2] == 0 then assert(p.y == A.y, name .. " top edge tight") end
  if f[1] + f[3] == 1 then assert(p.x + p.w == A.x + A.w, name .. " right edge tight") end
  if f[2] + f[4] == 1 then assert(p.y + p.h == A.y + A.h, name .. " bottom edge tight") end
end
-- a custom position that reaches the right edge only through floating point (0.1 + 0.9) is still tight there
G.positions.cmd_test = { 0.1, 0, 0.9, 1 }
local ct = G.place(A, "cmd_test", { margin = 8 })
assert(ct.x + ct.w == A.x + A.w, "custom position tight to the right edge despite 0.1 + 0.9 ~= 1")
assert(ct.x == 128 + 4, "custom position keeps the margin on its inner edge: " .. ct.x)
G.positions.cmd_test = nil
-- grab: the pointer keeps its relative spot on a differently sized window
local gx, gy = G.grab({ x = 0, y = 26, w = 640, h = 774 }, 320, 413, 500, 300)
assert(gx == 250 and gy == 150, "middle stays the middle: " .. gx .. "," .. gy)
gx, gy = G.grab({ x = 0, y = 26, w = 640, h = 774 }, 0, 26, 500, 300)
assert(gx == 0 and gy == 0, "top left stays top left")
gx, gy = G.grab({ x = 100, y = 100, w = 200, h = 200 }, 5000, -50, 400, 300)
assert(gx == 400 and gy == 0, "a pointer outside the window is clamped to its edge")
gx, gy = G.grab({ x = 0, y = 0, w = 0, h = 0 }, 10, 10, 500, 300)
assert(gx == 500 and gy == 300, "a zero size window does not divide by zero")
-- transfer: relative place and size are kept, and the result stays inside the new area
local from, to = { x = 0, y = 26, w = 1280, h = 774 }, { x = 1280, y = 0, w = 1920, h = 1080 }
eq(G.transfer({ x = 0, y = 26, w = 640, h = 774 }, from, to), 1280, 0, 960, 1080, "left half becomes the left half of the other screen")
eq(G.transfer({ x = 320, y = 413, w = 640, h = 387 }, from, to), 1760, 540, 960, 540, "a window in the middle keeps its relative place")
eq(G.transfer({ x = 400, y = 300, w = 500, h = 300 }, { x = 0, y = 0, w = 1920, h = 1080 }, { x = 0, y = 0, w = 400, h = 300 }), 83, 83, 104, 83, "to a smaller screen the window shrinks in proportion")
eq(G.transfer({ x = 1800, y = 1000, w = 500, h = 300 }, { x = 0, y = 0, w = 1920, h = 1080 }, to), 2700, 780, 500, 300, "a window near the corner is pulled back inside the new screen")
-- next_monitor
local mons = { { name = "B", x = 1920, y = 0 }, { name = "A", x = 0, y = 0 }, { name = "C", x = 3840, y = 0 } }
assert(G.next_monitor(mons, "A", 1).name == "B" and G.next_monitor(mons, "B", 1).name == "C", "next goes left to right")
assert(G.next_monitor(mons, "C", 1).name == "A", "next wraps around")
assert(G.next_monitor(mons, "A", -1).name == "C" and G.next_monitor(mons, "B", -1).name == "A", "previous goes right to left and wraps")
assert(G.next_monitor({ { name = "A", x = 0, y = 0 } }, "A", 1) == nil, "one monitor: nothing to move to")
assert(G.next_monitor(mons, "Z", 1) == nil, "unknown monitor")
local stacked = { { name = "T", x = 0, y = 0 }, { name = "U", x = 0, y = 1080 } }
assert(G.next_monitor(stacked, "T", 1).name == "U", "same x: top to bottom")
-- a sub-pixel width never gives a zero-size rectangle, with or without a margin
local sliver = G.place({ x = 0, y = 0, w = 1000, h = 1000 }, "cmd_sliver" == nil and "left" or "left")
G.positions.cmd_sliver = { 0.5, 0, 0.0001, 1 }
local thin = G.place({ x = 0, y = 0, w = 1000, h = 1000 }, "cmd_sliver")
assert(thin.w >= 1 and thin.h >= 1, "no zero size even for a sliver, margin 0")
assert(G.place({ x = 0, y = 0, w = 1000, h = 1000 }, "cmd_sliver", { margin = 8 }).w >= 1, "no zero size with a margin")
G.positions.cmd_sliver = nil
-- mirrored monitors (same position): the order is fixed by name, not by chance
local mirror1 = { { name = "Z", x = 0, y = 0 }, { name = "A", x = 0, y = 0 }, { name = "M", x = 0, y = 0 } }
local mirror2 = { { name = "A", x = 0, y = 0 }, { name = "M", x = 0, y = 0 }, { name = "Z", x = 0, y = 0 } }
assert(G.next_monitor(mirror1, "A", 1).name == "M" and G.next_monitor(mirror2, "A", 1).name == "M", "same position: ordered by name")
-- negative coordinates and an unknown starting monitor
local neg = { { name = "L", x = -1920, y = 0 }, { name = "R", x = 0, y = 0 } }
assert(G.next_monitor(neg, "L", 1).name == "R" and G.next_monitor(neg, "R", 1).name == "L", "negative x sorts first")
-- a small area: a corner never swallows the whole edge
local tiny = { x = 0, y = 0, w = 90, h = 90 }
assert(G.drag_zone(0, 45, tiny, { edge = 12, corner = 64 }) == "left", "the middle of a small area's edge is still a half")
assert(G.drag_zone(0, 5, tiny, { edge = 12, corner = 64 }) == "top_left", "its corner is still a corner")
-- a corner reach smaller than the edge strip: still sane
assert(G.drag_zone(0, 300, A, { edge = 20, corner = 8 }) == "left", "corner smaller than the edge strip")
-- transfer A to B to A drifts by at most a pixel for ordinary windows
local back = G.transfer(G.transfer({ x = 400, y = 300, w = 500, h = 300 }, from, to), to, from)
assert(math.abs(back.x - 400) <= 1 and math.abs(back.y - 300) <= 1 and math.abs(back.w - 500) <= 1 and math.abs(back.h - 300) <= 1, "round trip stays within a pixel")
-- vertical (portrait) screen: thirds along the sides, halves on the bottom edge, corners quarters, top maximizes
local PA = { x = 0, y = 26, w = 700, h = 1200 } -- x 0..699, y 26..1225
local function pz(cx, cy, start) return G.drag_zone(cx, cy, PA, O, start) end
assert(pz(0, 200) == "third_top" and pz(0, 600) == "third_middle" and pz(0, 1000) == "third_bottom", "left side gives row thirds")
assert(pz(699, 200) == "third_top" and pz(699, 1000) == "third_bottom", "right side gives row thirds too")
assert(pz(0, 600, 1) == "two_thirds_top" and pz(0, 600, 3) == "two_thirds_bottom", "slide along a side gives two thirds")
assert(pz(0, 200, 2) == "two_thirds_top" and pz(0, 1000, 2) == "two_thirds_bottom", "slide from the middle row")
assert(pz(0, 1000, 1) == "third_bottom", "a jump from the top row to the bottom row is just the row under the cursor")
assert(pz(5, 30) == "top_left" and pz(695, 1220) == "bottom_right", "corners are quarters")
assert(pz(350, 26) == "maximize", "top edge maximizes")
assert(pz(100, 1225) == "left" and pz(600, 1225) == "right", "bottom edge gives halves")
assert(pz(350, 600) == nil, "inside is nothing")
assert(G.slide_index(0, 600, PA, O) == 2 and G.slide_index(640, 799, A, O) == 2, "slide strip: side on a vertical screen, bottom on a wide one")
eq(G.place(PA, "third_middle"), 0, 426, 700, 400, "row third rectangle")
eq(G.place(PA, "two_thirds_bottom"), 0, 426, 700, 800, "row two thirds rectangle")
-- rows tile exactly, like the columns do
for _, h in ipairs({ 1000, 1001, 999, 1080 }) do
  local a = { x = 0, y = 7, w = 400, h = h }
  local r1, r2, r3 = G.place(a, "third_top"), G.place(a, "third_middle"), G.place(a, "third_bottom")
  assert(r1.y == a.y and r1.y + r1.h == r2.y and r2.y + r2.h == r3.y and r3.y + r3.h == a.y + a.h, "row thirds tile, height " .. h)
  local m = { margin = 6 }
  local q1, q2 = G.place(a, "third_top", m), G.place(a, "third_middle", m)
  assert(q2.y - (q1.y + q1.h) == 6 and q1.y == a.y, "row gap is the margin, top tight")
end
-- zone pills (the strips shown while dragging)
local function inside(p, a) return p.x >= a.x and p.y >= a.y and p.x + p.w <= a.x + a.w and p.y + p.h <= a.y + a.h and p.w > 0 and p.h > 0 end
local lp = G.zone_pills(A, O)
assert(#lp == 14, "landscape: 8 corner strips + 2 sides + top + 3 bottom thirds, got " .. #lp)
for _, p in ipairs(lp) do assert(inside(p, A), "a pill stays inside the area") end
local pp = G.zone_pills(PA, O)
assert(#pp == 17, "portrait: 8 corner strips + 6 side thirds + top + 2 bottom halves, got " .. #pp)
for _, p in ipairs(pp) do assert(inside(p, PA), "a portrait pill stays inside the area") end
-- every pill is a zone: a point in the middle of a pill maps to a zone name
for _, p in ipairs(lp) do
  assert(G.drag_zone(p.x + p.w // 2, p.y + p.h // 2, A, O) ~= nil, "the middle of a pill is in a zone")
end
for _, p in ipairs(pp) do
  assert(G.drag_zone(p.x + p.w // 2, p.y + p.h // 2, PA, O) ~= nil, "the middle of a portrait pill is in a zone")
end
-- a tiny area never gives an empty or outside strip
for _, p in ipairs(G.zone_pills({ x = 0, y = 0, w = 90, h = 90 }, O)) do assert(inside(p, { x = 0, y = 0, w = 90, h = 90 }), "tiny area pill") end
-- near_edge
assert(G.near_edge(100, 300, A, 150) and G.near_edge(1200, 300, A, 150) and G.near_edge(640, 100, A, 150), "near an edge")
assert(G.near_edge(640, 780, A, 150), "near the bottom edge")
assert(not G.near_edge(640, 400, A, 150), "far from every edge")
print("geometry ok")

-- ---------------------------------------------------------------- grid zones
do
  local function near(a, b) return math.abs(a - b) < 1e-9 end
  local c3 = assert(G.layout("columns:3"))
  assert(#c3 == 3 and near(c3[2][1], 1 / 3) and c3[2][2] == 0 and near(c3[2][3], 1 / 3) and c3[2][4] == 1, "columns:3")
  local r2 = assert(G.layout("rows:2")); assert(#r2 == 2 and r2[2][2] == 0.5 and r2[2][4] == 0.5 and r2[2][3] == 1, "rows:2")
  local g = assert(G.layout("Grid: 3x2")); assert(#g == 6 and near(g[4][1], 0) and near(g[4][2], 0.5) and near(g[6][1], 2 / 3), "grid 3x2 reads row by row, case and spaces ignored")
  local pr = assert(G.layout("priority")); assert(#pr == 3 and pr[2][3] == 0.5, "priority")
  for _, bad in ipairs({ "columns", "columns:0", "columns:13", "grid:3", "grid:0x2", "grid:3x", "nonsense", "", "rows:-1", "grid:2x2x2" }) do
    local z, why = G.layout(bad); assert(z == nil and why, "rejects " .. bad)
  end
  -- every generated layout tiles the screen exactly: zone areas add up to 1 and no two zones overlap
  for _, name in ipairs({ "columns:5", "rows:7", "grid:4x3", "grid:1x1", "priority", "grid:12x12" }) do
    local z, sum = G.layout(name), 0
    for i, f in ipairs(z) do
      sum = sum + f[3] * f[4]
      for j = i + 1, #z do
        local g2 = z[j]
        local ox = math.min(f[1] + f[3], g2[1] + g2[3]) - math.max(f[1], g2[1])
        local oy = math.min(f[2] + f[4], g2[2] + g2[4]) - math.max(f[2], g2[2])
        assert(not (ox > 1e-9 and oy > 1e-9), name .. ": zones overlap")
      end
    end
    assert(near(sum, 1), name .. ": zones cover the screen, got " .. sum)
  end

  -- custom zones
  local cz = assert(G.parse_zones("0 0 0.25 1; 0.25 0 0.5 1 ;0.75 0 0.25 0.5"))
  assert(#cz == 3 and cz[2][3] == 0.5, "parse_zones")
  for _, bad in ipairs({ "", "0 0 1", "0 0 1 1 1", "a b c d", "0 0 0 1", "0.5 0 0.6 1", "-0.1 0 0.5 1", "0 0 1 1; 0 0 x 1" }) do
    local z, why = G.parse_zones(bad); assert(z == nil and why, "parse_zones rejects '" .. bad .. "'")
  end

  -- zone_at on a 1200 x 800 area at (100, 50): grid 3x2, zones 400 x 400
  local Z = { x = 100, y = 50, w = 1200, h = 800 }
  local g32 = G.layout("grid:3x2")
  local function at(x, y, span) return G.zone_at(g32, Z, x, y, { span = span }) end
  assert(at(300, 250, 0).index[1] == 1 and #at(300, 250, 0).index == 1, "top left zone")
  assert(at(700, 250, 0).index[1] == 2 and at(1100, 700, 0).index[1] == 6, "middle top, bottom right")
  assert(at(99, 250, 0) == nil and at(1300, 250, 0) == nil and at(300, 850, 0) == nil, "outside the area")
  -- near a shared edge: both zones, and the box covers both
  local two = at(498, 250, 24)
  assert(#two.index == 2 and two.index[1] == 1 and two.index[2] == 2, "two zones near the shared vertical edge")
  assert(near(two.frac[1], 0) and near(two.frac[3], 2 / 3) and near(two.frac[4], 0.5), "union of two columns")
  local rows = at(300, 448, 24)
  assert(#rows.index == 2 and rows.index[1] == 1 and rows.index[2] == 4 and near(rows.frac[4], 1) and near(rows.frac[3], 1 / 3), "two zones near the shared horizontal edge")
  -- near the crossing of four zones: all four
  local four = at(498, 448, 24)
  assert(#four.index == 4 and near(four.frac[3], 2 / 3) and near(four.frac[4], 1), "four zones at the crossing")
  -- deep inside a zone with a span on: still one zone
  assert(#at(300, 250, 24).index == 1, "inside a zone, away from edges, stays one zone")
  -- a screen edge is not a shared edge
  assert(#at(101, 250, 24).index == 1, "the screen border does not count as a shared edge")
  -- a gap picks the nearest zone
  local gapz = { { 0, 0, 0.4, 1 }, { 0.6, 0, 0.4, 1 } }
  assert(G.zone_at(gapz, Z, 100 + 0.45 * 1200, 400, { span = 0 }).index[1] == 1, "gap, nearer the left zone")
  assert(G.zone_at(gapz, Z, 100 + 0.55 * 1200, 400, { span = 0 }).index[1] == 2, "gap, nearer the right zone")
  -- overlapping zones: the smallest wins
  local ov = { { 0, 0, 1, 1 }, { 0.25, 0.25, 0.5, 0.5 } }
  assert(G.zone_at(ov, Z, 700, 450, { span = 0 }).index[1] == 2, "smallest of overlapping zones")
  assert(G.zone_at(ov, Z, 150, 100, { span = 0 }).index[1] == 1, "outside the small zone, the big one")
  assert(G.zone_at({}, Z, 300, 300) == nil and G.zone_at(nil, Z, 300, 300) == nil, "no zones")

  -- zones go through the same margin rules as every other snap
  local r = G.place_frac(Z, g32[2], { margin = 8, edge_tight = true })
  assert(r.y == 50 and r.x == 100 + 400 + 4 and r.w == 400 - 4 - 4, "zone with margin: tight on the border, half the margin each side inside")
  -- neighbours tile exactly, with margin 0, at odd widths
  for _, w in ipairs({ 1280, 1281, 1279, 1919, 7 }) do
    local a = { x = 13, y = 5, w = w, h = 777 }
    local z = G.layout("grid:3x2")
    local r1, r2, r3 = G.place_frac(a, z[1], {}), G.place_frac(a, z[2], {}), G.place_frac(a, z[3], {})
    assert(r1.x + r1.w == r2.x and r2.x + r2.w == r3.x and r3.x + r3.w == a.x + a.w, "zones tile, width " .. w)
  end

  -- stepping through zones
  local win_in_1 = { x = 100, y = 50, w = 400, h = 400 }
  local idx = G.zone_step(g32, Z, win_in_1, 1); assert(idx == 2, "next zone from zone 1")
  assert(G.zone_step(g32, Z, win_in_1, -1) == 6, "previous wraps to the last zone")
  assert(G.zone_step(g32, Z, { x = 1700, y = 900, w = 400, h = 400 }, 1) ~= nil, "a window outside everything still steps")
  -- a small window near zone 1 goes to zone 1 first, in both directions
  local small = { x = 150, y = 100, w = 100, h = 100 }
  assert(G.zone_step(g32, Z, small, 1) == 1 and G.zone_step(g32, Z, small, -1) == 1, "a window not filling a zone goes to its nearest zone first")
  assert(G.zone_step({}, Z, small, 1) == nil, "no zones, no step")
end
print("zones ok")
