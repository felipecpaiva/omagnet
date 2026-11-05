-- Plain Lua self-check for the pure parts:  lua5.4 prototype/test_rect.lua
hl = { bind = function() end }
local M = dofile((arg[0]:match("^(.*)/") or ".") .. "/omagnet-snap.lua")
local A = { x = 0, y = 26, w = 1280, h = 774 } -- 1280x800 minus a 26 px bar
local function eq(got, x, y, w, h, name)
  assert(got and got.x == x and got.y == y and got.w == w and got.h == h, name)
end
eq(M.rect_for(0, 300, A, 8), 0, 26, 640, 774, "left edge")
eq(M.rect_for(8, 300, A, 8), 0, 26, 640, 774, "left edge, on the threshold")
eq(M.rect_for(1279, 300, A, 8), 640, 26, 640, 774, "right edge")
eq(M.rect_for(640, 26, A, 8), 0, 26, 1280, 774, "top edge is the whole area")
assert(M.rect_for(640, 400, A, 8) == nil, "middle does nothing")
assert(M.rect_for(9, 400, A, 8) == nil, "just inside the threshold does nothing")
eq(M.rect_for(1279, 300, { x = 0, y = 0, w = 1281, h = 10 }, 8), 640, 0, 641, 10, "odd width: right half takes the extra pixel")
local u = M.usable({ width = 2560, height = 1600, scale = 2.0, transform = 0, x = 0, y = 0, reserved = { left = 0, top = 26, right = 0, bottom = 0 } })
eq(u, 0, 26, 1280, 774, "usable area, scale 2")
local r = M.usable({ width = 1080, height = 1920, scale = 1.0, transform = 1, x = 100, y = 0, reserved = { left = 0, top = 0, right = 0, bottom = 0 } })
eq(r, 100, 0, 1920, 1080, "rotated monitor swaps width and height")
print("ok")
