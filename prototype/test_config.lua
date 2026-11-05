-- Plain Lua self-check:  lua5.4 prototype/test_config.lua
local dir = arg[0]:match("^(.*)/") or "."
local C = dofile(dir .. "/config.lua")

local t, bad = C.parse([[
# a comment
keys_enabled = false   # trailing comment
edge_width = 12
[keys]
left = "CTRL + ALT + H"
restore = ""
garbage line
oops = notavalue
]])
assert(t.keys_enabled == false and t.edge_width == 12 and t.keys.left == "CTRL + ALT + H" and t.keys.restore == "", "parse values")
assert(#bad == 2, "two unreadable lines reported, got " .. #bad)

local cfg = C.merge(t)
assert(cfg.keys_enabled == false and cfg.drag_enabled == true, "merge keeps defaults")
assert(cfg.keys.left == "CTRL + ALT + H" and cfg.keys.right == "CTRL + ALT + RIGHT" and cfg.keys.restore == "", "key override and default")

-- wrong types and unknown keys never change anything
local c2 = C.merge({ keys_enabled = "yes", edge_width = "wide", keys = { left = 5, nonsense = "X" } })
assert(c2.keys_enabled == true and c2.edge_width == 8 and c2.keys.left == "CTRL + ALT + LEFT" and c2.keys.nonsense == nil, "bad types ignored")

-- defaults must not be shared with the merged copy
local c3 = C.merge(nil)
c3.keys.left = "X"
assert(C.defaults.keys.left == "CTRL + ALT + LEFT", "defaults not mutated")

-- missing file gives defaults
local c4, b4 = C.load("/nonexistent/omagnet.toml")
assert(c4.keys.left == "CTRL + ALT + LEFT" and #b4 == 0, "missing file")

-- no two commands share a shortcut
local seen = {}
for name, key in pairs(C.defaults.keys) do
  if key ~= "" then assert(not seen[key], "duplicate shortcut " .. key); seen[key] = name end
end
-- a top-level key named like a section must not crash the parser
local t5 = C.parse("keys = true\n[keys]\nleft = \"CTRL + ALT + H\"\n")
assert(type(t5.keys) == "table" and t5.keys.left == "CTRL + ALT + H", "section after a same-named key")
-- only plain decimals are numbers
local t6, bad6 = C.parse("a = 0x10\nb = 1e999\nc = -3\nd = 2.5\ne = 7")
assert(t6.a == nil and t6.b == nil and t6.c == -3 and t6.d == 2.5 and t6.e == 7 and #bad6 == 2, "strict numbers")
-- CRLF line endings
local t7 = C.parse("margin = 6\r\nedge_tight = false\r\n")
assert(t7.margin == 6 and t7.edge_tight == false, "CRLF")

-- workspace mode as Omarchy saves it
assert(C.workspace_mode('o.workspace_mode({ workspace = "1", mode = "floating" })') == "floating", "mode floating")
assert(C.workspace_mode('o.workspace_mode({ workspace = "2", mode = "scrolling" })') == "scrolling", "mode scrolling")
assert(C.workspace_mode("nothing here") == nil and C.workspace_mode(nil) == nil, "no mode")
print("config ok")
