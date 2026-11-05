-- Plain Lua self-check:  lua lua/test_config.lua
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
assert(c2.keys_enabled == true and c2.edge_width == C.defaults.edge_width and c2.keys.left == "CTRL + ALT + LEFT" and c2.keys.nonsense == nil, "bad types ignored")

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

-- the bar icon setting is a boolean that defaults to off
assert(C.merge(nil).bar_icon == false, "the bar icon is off by default")
assert(C.merge({ bar_icon = true }).bar_icon == true and C.merge({ bar_icon = "yes" }).bar_icon == false, "a wrong type keeps it off")

-- a "#" inside a quoted string is not a comment (a colour must survive the file)
local hc = C.parse('target_color = "#FF8800"  # the colour\nignore = "a#b" # note\nmargin = 4 # gap\n')
assert(hc.target_color == "#FF8800" and hc.ignore == "a#b" and hc.margin == 4, "hash inside quotes is kept, a comment after it still goes")
assert(C.strip_comment('x = "#fff" # c') == 'x = "#fff"' and C.strip_comment("# whole line") == "" and C.strip_comment("a = 1") == "a = 1", "strip_comment")
assert(C.merge(C.parse('target_color = "#FF8800"')).target_color == "#FF8800", "a colour read from the file is kept")

-- ARGB numbers from Hyprland become #rrggbb
assert(C.argb_hex(0xFF6E6E6E) == "#6e6e6e" and C.argb_hex(0x33CCFFEE) == "#ccffee" and C.argb_hex(0xFF000000) == "#000000", "argb_hex")
assert(C.argb_hex("0xFF6E6E6E") == "#6e6e6e" and C.argb_hex(setmetatable({}, { __tostring = function() return "0x33CCFFEE" end })) == "#ccffee", "the text form Hyprland's colour object prints")
assert(C.argb_hex("0xFF6E6E") == nil and C.argb_hex("#6e6e6e") == nil and C.argb_hex("0xZZ6E6E6E") == nil, "a wrong text form is rejected")
assert(C.argb_hex(nil) == nil and C.argb_hex("red") == nil and C.argb_hex(-1) == nil and C.argb_hex(2 ^ 40) == nil and C.argb_hex(0 / 0) == nil, "argb_hex rejects junk")

-- appearance settings: defaults, clamping, and a colour that must look like #rrggbb
local ap = C.merge(nil)
assert(ap.target_outline == 2 and ap.highlight_outline == 4 and ap.target_fill == 0.18 and ap.target_color == "" and ap.highlight == false, "appearance defaults")
local ap2 = C.merge({ target_outline = 99, highlight_outline = -3, target_fill = 7, target_color = "#FF8800" })
assert(ap2.target_outline == 20 and ap2.highlight_outline == 0 and ap2.target_fill == 1 and ap2.target_color == "#FF8800", "clamped, a good colour kept")
for _, bad in ipairs({ "red", "#fff", "#gg0000", "ff0000", "#ff00000" }) do
  assert(C.merge({ target_color = bad }).target_color == "", "a bad colour is dropped: " .. bad)
end

-- custom commands
local t8 = C.parse([[
[cmd_wide]
x = 0.1
y = 0
w = 0.8
h = 1
key = "CTRL + ALT + W"
[cmd_nokey]
x = 0
y = 0
w = 0.25
h = 0.5
[cmd_toobig]
x = 0.5
y = 0
w = 0.8
h = 1
[cmd_incomplete]
x = 0
w = 0.5
[cmd_zero]
x = 0
y = 0
w = 0
h = 1
[notacommand]
x = 0
y = 0
w = 1
h = 1
]])
local c8 = C.merge(t8)
assert(c8.custom.cmd_wide and c8.custom.cmd_wide[1] == 0.1 and c8.custom.cmd_wide[3] == 0.8, "a valid custom command")
assert(c8.keys.cmd_wide == "CTRL + ALT + W", "its key is registered")
assert(c8.custom.cmd_nokey and c8.keys.cmd_nokey == nil, "a custom command without a key has no shortcut")
assert(c8.custom.cmd_toobig == nil and c8.custom.cmd_incomplete == nil and c8.custom.cmd_zero == nil, "bad custom commands are skipped")
assert(c8.custom.notacommand == nil, "only cmd_ sections count")
assert(next(C.merge(nil).custom) == nil, "no custom commands by default")

-- ignore list
assert(C.is_ignored("steam, Firefox ,mpv", "firefox") and C.is_ignored("steam,mpv", "MPV"), "case and spaces do not matter")
assert(not C.is_ignored("steam", "steamwebhelper") and not C.is_ignored("", "steam") and not C.is_ignored("steam", ""), "exact names only")
assert(not C.is_ignored(nil, "steam") and not C.is_ignored("steam", nil), "no list or no class")

-- workspace mode as Omarchy saves it
assert(C.workspace_mode('o.workspace_mode({ workspace = "1", mode = "floating" })') == "floating", "mode floating")
assert(C.workspace_mode('o.workspace_mode({ workspace = "2", mode = "scrolling" })') == "scrolling", "mode scrolling")
assert(C.workspace_mode("nothing here") == nil and C.workspace_mode(nil) == nil, "no mode")

-- ---------------------------------------------------------------- grid zones
do
  local d = C.merge(nil)
  assert(d.zones_enabled == true and d.zone_modifier == "SUPER + SHIFT" and d.zone_span == 24, "zone defaults")
  assert(d.layout_landscape == "grid:3x2" and d.layout_portrait == "rows:3", "layout defaults")
  assert(d.keys.zone_next == "CTRL + ALT + BRACKETRIGHT" and d.keys.layout_next == "", "zone keys")
  assert(next(d.zone_layouts) == nil and next(d.layouts) == nil, "no layouts by default")
  local t2, bad2 = C.parse([[
zone_modifier = "SUPER + CTRL"
zone_span = 1000
layout_landscape = "columns:4"
[zone_layouts]
DP-1 = "rows:2"
HDMI-A-1 = ""
[layout_coding]
zones = "0 0 0.25 1; 0.25 0 0.75 1"   # a comment
key = "SUPER + CTRL + ALT + 1"
[layout_nozones]
key = "SUPER + CTRL + ALT + 2"
]])
  assert(#bad2 == 0, "no unreadable lines")
  local c = C.merge(t2)
  assert(c.zone_modifier == "SUPER + CTRL" and c.zone_span == 200 and c.layout_landscape == "columns:4", "zone settings read, span clamped")
  assert(c.zone_layouts["DP-1"] == "rows:2" and c.zone_layouts["HDMI-A-1"] == nil, "monitor layouts, an empty one skipped")
  assert(c.layouts.coding == "0 0 0.25 1; 0.25 0 0.75 1" and c.keys["layout:coding"] == "SUPER + CTRL + ALT + 1", "custom layout and its key")
  assert(c.layouts.nozones == nil and c.keys["layout:nozones"] == nil, "a layout section without zones is skipped")
  -- wrong types never change anything
  local w = C.merge({ zones_enabled = "yes", zone_span = "wide", layout_landscape = 5, zone_layouts = "x", layout_bad = "text" })
  assert(w.zones_enabled == true and w.zone_span == 24 and w.layout_landscape == "grid:3x2" and next(w.zone_layouts) == nil and next(w.layouts) == nil, "bad zone types ignored")
end
print("config ok")
