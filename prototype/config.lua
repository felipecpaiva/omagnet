-- omagnet config: a flat TOML subset (comments, [sections], key = true | 123 | 1.5 | "text") that both
-- Lua and the settings app can read. Pure, so it tests under plain lua5.4.
-- shortcut: no arrays, no inline tables, no '#' inside strings. Upgrade if the app needs them.
local C = {}

C.defaults = {
  keys_enabled = true,
  drag_enabled = true,
  edge_width = 12, -- Magnet default: thickness of the active strip along a screen edge
  corner_size = 64, -- how far along an edge a corner zone reaches (our pick; Magnet scales its zones to 80 %)
  margin = 8, -- Magnet default: gap between snapped windows
  edge_tight = true, -- Magnet default: no margin against the screen border
  bar_icon = false, -- the settings app's optional bar icon; the Lua side ignores it, the app reads it
  ignore = "", -- window classes omagnet leaves alone, comma separated
  reserve_top = 0, reserve_bottom = 0, reserve_left = 0, reserve_right = 0, -- extra space to keep free, for example under a dock
  -- command -> shortcut. An empty string means "no shortcut". Center, restore and center two thirds
  -- are our own picks, not confirmed Magnet defaults.
  keys = {
    left = "CTRL + ALT + LEFT", right = "CTRL + ALT + RIGHT", top = "CTRL + ALT + UP", bottom = "CTRL + ALT + DOWN",
    top_left = "CTRL + ALT + U", top_right = "CTRL + ALT + I", bottom_left = "CTRL + ALT + J", bottom_right = "CTRL + ALT + K",
    third_left = "CTRL + ALT + D", third_center = "CTRL + ALT + F", third_right = "CTRL + ALT + G",
    two_thirds_left = "CTRL + ALT + E", two_thirds_right = "CTRL + ALT + T", two_thirds_center = "",
    maximize = "CTRL + ALT + RETURN", center = "CTRL + ALT + C", restore = "CTRL + ALT + BACKSPACE",
    next_display = "SUPER + CTRL + ALT + RIGHT", prev_display = "SUPER + CTRL + ALT + LEFT", -- our picks, Magnet's keys are not shown
  },
}

local function value(v)
  if v == "true" then return true elseif v == "false" then return false end
  local s = v:match('^"(.*)"$')
  if s then return s end
  -- plain decimals only: tonumber alone would also accept 0x10 and 1e999 (infinity)
  if v:match("^-?%d+%.?%d*$") then return tonumber(v) end
  return nil -- not a value we know: the line is ignored
end

-- Returns a table of top-level keys and sections, plus a list of lines it could not read.
function C.parse(text)
  local root, sec, bad = {}, nil, {}
  sec = root
  for raw in (text or ""):gmatch("[^\r\n]+") do
    -- Hyprland's Lua makes a for-loop variable read-only, so copy it before changing it
    local line = raw:gsub("%s*#.*$", "")
    if line:match("%S") then
      local name = line:match("^%s*%[([%w_]+)%]%s*$")
      if name then
        -- "keys = true" earlier in the file must not break a later [keys] section
        if type(root[name]) ~= "table" then root[name] = {} end
        sec = root[name]
      else
        local k, v = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        local parsed = k and value(v)
        if parsed ~= nil then sec[k] = parsed else bad[#bad + 1] = line end
      end
    end
  end
  return root, bad
end

-- Defaults overlaid with the user's file. A wrong type is ignored, so a bad edit never disables a feature.
function C.merge(user)
  local cfg = { keys = {} }
  for k, v in pairs(C.defaults) do if k ~= "keys" then cfg[k] = v end end
  for k, v in pairs(C.defaults.keys) do cfg.keys[k] = v end
  for k, v in pairs(user or {}) do
    if k ~= "keys" and type(v) == type(C.defaults[k]) then cfg[k] = v end
  end
  if type(user and user.keys) == "table" then
    for k, v in pairs(user.keys) do
      if C.defaults.keys[k] ~= nil and type(v) == "string" then cfg.keys[k] = v end
    end
  end
  -- Custom positions: a section [cmd_<name>] with x, y, w, h as fractions of the usable area (0 to 1) and an
  -- optional key. Anything out of range or incomplete is skipped, never half applied.
  cfg.custom = {}
  for name, sec in pairs(user or {}) do
    if type(name) == "string" and name:match("^cmd_%w[%w_]*$") and type(sec) == "table" then
      local x, y, w, h = sec.x, sec.y, sec.w, sec.h
      local ok = type(x) == "number" and type(y) == "number" and type(w) == "number" and type(h) == "number"
        and x >= 0 and y >= 0 and w > 0 and h > 0 and x + w <= 1 + 1e-9 and y + h <= 1 + 1e-9
      if ok then
        cfg.custom[name] = { x, y, w, h }
        if type(sec.key) == "string" and sec.key ~= "" then cfg.keys[name] = sec.key end
      end
    end
  end
  return cfg
end

-- Is `class` in the comma separated `list`? Case does not matter and spaces around a name are ignored.
function C.is_ignored(list, class)
  if type(list) ~= "string" or type(class) ~= "string" or class == "" then return false end
  local want = class:lower()
  for item in list:gmatch("[^,]+") do
    if item:match("^%s*(.-)%s*$"):lower() == want then return true end
  end
  return false
end

-- Omarchy saves each workspace's layout as a one-line Lua file (o.workspace_mode({ ..., mode = "floating" })).
-- Its own `omarchy hyprland workspace layout current` reads the mode back with the same match.
function C.workspace_mode(text)
  return tostring(text or ""):match('mode%s*=%s*"(%a+)"')
end

function C.load(path)
  local f = io.open(path, "r")
  if not f then return C.merge(nil), {} end
  local text = f:read("a")
  f:close()
  local user, bad = C.parse(text)
  return C.merge(user), bad
end

return C
