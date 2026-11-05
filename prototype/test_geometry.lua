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
print("geometry ok")
