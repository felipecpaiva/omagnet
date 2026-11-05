-- Plain Lua self-check:  lua5.4 prototype/test_geometry.lua
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

-- drag
eq(G.drag_rect(0, 300, A, 8), 0, 26, 640, 774, "drag left")
eq(G.drag_rect(1279, 300, A, 8), 640, 26, 640, 774, "drag right")
eq(G.drag_rect(640, 26, A, 8), 0, 26, 1280, 774, "drag top")
assert(G.drag_rect(640, 400, A, 8) == nil and G.drag_rect(9, 400, A, 8) == nil, "drag middle")

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
-- drag rectangles use the same options
eq(G.drag_rect(0, 300, A, 8, M8), 0, 26, 636, 774, "drag left with margin")
print("geometry ok")
