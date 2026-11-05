// omagnet config reader/writer. Pure JavaScript (no Qt imports) so node can test it, and so
// Panel.qml can `import "ConfigIO.js" as ConfigIO`. It mirrors lua/config.lua, which is the
// source of truth for the format: if the two ever disagree, the Lua file wins.
//
// The "model" is the parsed tree: top-level keys, plus one object per [section]. It keeps whatever
// the app does not edit (unknown keys, unknown sections, [cmd_*] sections) so a save loses nothing.
// A '#' starts a comment only outside a double quoted string, so a colour such as "#ff8800" survives a save. A string
// cannot hold a double quote or a line break (serialize() drops them): the format has no escapes.

var DEFAULTS = {
  keys_enabled: true,
  drag_enabled: true,
  edge_width: 12,
  corner_size: 64,
  margin: 8,
  edge_tight: true,
  target_outline: 2,
  target_color: "",
  target_fill: 0.18,
  highlight: false,
  highlight_outline: 4,
  bar_icon: false,
  ignore: "",
  reserve_top: 0, reserve_bottom: 0, reserve_left: 0, reserve_right: 0,
  keys: {
    left: "CTRL + ALT + LEFT", right: "CTRL + ALT + RIGHT", top: "CTRL + ALT + UP", bottom: "CTRL + ALT + DOWN",
    top_left: "CTRL + ALT + U", top_right: "CTRL + ALT + I", bottom_left: "CTRL + ALT + J", bottom_right: "CTRL + ALT + K",
    third_left: "CTRL + ALT + D", third_center: "CTRL + ALT + F", third_right: "CTRL + ALT + G",
    two_thirds_left: "CTRL + ALT + E", two_thirds_right: "CTRL + ALT + T", two_thirds_center: "",
    maximize: "CTRL + ALT + RETURN", center: "CTRL + ALT + C", restore: "CTRL + ALT + BACKSPACE",
    next_display: "SUPER + CTRL + ALT + RIGHT", prev_display: "SUPER + CTRL + ALT + LEFT"
  }
}

// Order and wording of the written file. Every entry here is a setting the app edits.
var LAYOUT = [
  ["Switches", ["keys_enabled", "drag_enabled"]],
  ["Spacing: pixels between snapped windows, extra space to keep free", ["margin", "edge_tight", "reserve_top", "reserve_bottom", "reserve_left", "reserve_right"]],
  ["Drag zones: edge strip thickness and corner reach", ["edge_width", "corner_size"]],
  ["Drag outline: thickness, colour (empty is the theme accent, or #rrggbb), fill 0 to 1, and showing every zone while dragging", ["target_outline", "target_color", "target_fill", "highlight", "highlight_outline"]],
  ["Optional icon in the Omarchy bar that opens the settings window (off by default)", ["bar_icon"]],
  ["Apps omagnet leaves alone (window classes, comma separated, case does not matter)", ["ignore"]]
]

// Same ranges as config.lua merge(): numbers clamped, a colour must look like #rrggbb or it becomes empty.
function tidy(k, v) {
  if (k === "target_outline" || k === "highlight_outline") return Math.max(0, Math.min(20, v))
  if (k === "target_fill") return Math.max(0, Math.min(1, v))
  if (k === "target_color") return /^#[0-9a-fA-F]{6}$/.test(v) ? v : ""
  return v
}

function defaults() { return JSON.parse(JSON.stringify(DEFAULTS)) }

function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k) }
function isTable(v) { return v !== null && typeof v === "object" }

function value(v) {
  if (v === "true") return true
  if (v === "false") return false
  var s = /^"(.*)"$/.exec(v)
  if (s) return s[1]
  // plain decimals only: Number() alone would also accept 0x10 and 1e999
  if (/^-?[0-9]+\.?[0-9]*$/.test(v)) return Number(v)
  return undefined
}

// Cut a trailing comment, like C.strip_comment in lua/config.lua.
function stripComment(line) {
  var inString = false
  for (var i = 0; i < line.length; i++) {
    var ch = line.charAt(i)
    if (ch === '"') inString = !inString
    else if (ch === "#" && !inString) return line.slice(0, i).replace(/\s+$/, "")
  }
  return line
}

// Returns { root, bad }: the tree of top-level keys and sections, and the lines that could not be read.
function parse(text) {
  var root = {}, sec = root, bad = []
  var lines = String(text == null ? "" : text).split(/[\r\n]+/)
  for (var i = 0; i < lines.length; i++) {
    var line = stripComment(lines[i])
    if (!/\S/.test(line)) continue
    var m = /^\s*\[([A-Za-z0-9_]+)\]\s*$/.exec(line)
    if (m) {
      var name = m[1]
      if (name === "__proto__") { bad.push(line); sec = {}; continue }
      if (!isTable(root[name])) root[name] = {}
      sec = root[name]
      continue
    }
    var kv = /^\s*([A-Za-z0-9_]+)\s*=\s*(.*?)\s*$/.exec(line)
    var parsed = kv ? value(kv[2]) : undefined
    if (parsed !== undefined && kv[1] !== "__proto__") sec[kv[1]] = parsed
    else bad.push(line)
  }
  return { root: root, bad: bad }
}

// Defaults overlaid with the user's tree. A wrong type is ignored. Same rules as config.lua merge().
function merge(user) {
  user = isTable(user) ? user : {}
  var d = defaults()
  var cfg = { keys: d.keys }
  var k
  for (k in d) if (k !== "keys") cfg[k] = d[k]
  for (k in user) {
    if (k !== "keys" && has(d, k) && typeof user[k] === typeof d[k]) cfg[k] = user[k]
  }
  if (isTable(user.keys)) {
    for (k in user.keys) {
      if (has(DEFAULTS.keys, k) && typeof user.keys[k] === "string") cfg.keys[k] = user.keys[k]
    }
  }
  for (k in d) if (k !== "keys") cfg[k] = tidy(k, cfg[k])
  cfg.custom = {}
  for (var name in user) {
    var sec = user[name]
    if (!/^cmd_[A-Za-z0-9][A-Za-z0-9_]*$/.test(name) || !isTable(sec)) continue
    var x = sec.x, y = sec.y, w = sec.w, h = sec.h
    var ok = typeof x === "number" && typeof y === "number" && typeof w === "number" && typeof h === "number" &&
      x >= 0 && y >= 0 && w > 0 && h > 0 && x + w <= 1 + 1e-9 && y + h <= 1 + 1e-9
    if (ok) {
      cfg.custom[name] = [x, y, w, h]
      if (typeof sec.key === "string" && sec.key !== "") cfg.keys[name] = sec.key
    }
  }
  return cfg
}

// The [cmd_*] sections found, valid or not, for the read-only list in the panel.
function customSections(model) {
  var valid = merge(model).custom, out = []
  for (var name in model) {
    if (/^cmd_[A-Za-z0-9][A-Za-z0-9_]*$/.test(name) && isTable(model[name])) {
      out.push({ name: name, valid: has(valid, name), key: typeof model[name].key === "string" ? model[name].key : "" })
    }
  }
  return out
}

// Changing the key binds needs `hyprctl reload`; everything else can be re-read live.
// Sorted by name like key_signature() in lua/omagnet-snap.lua, so insertion order never counts as a change.
// Custom keys are in merge().keys, so adding, changing or removing one moves the signature too.
function bindSignature(model) {
  var keys = merge(model).keys
  return Object.keys(keys).sort().map(function (n) { return n + "=" + keys[n] }).join(";")
}

// Copies, so a QML property bound to the model sees a new object and notifies.
function withValue(model, k, v) { var c = JSON.parse(JSON.stringify(model)); c[k] = v; return c }
function withKey(model, name, v) {
  var c = JSON.parse(JSON.stringify(model))
  if (!isTable(c.keys)) c.keys = {}
  c.keys[name] = v
  return c
}

// ---- custom positions: the cell grid editor. A rectangle is {x, y, w, h}, fractions of the usable area.

function round4(n) { return Math.round(n * 10000) }

// Cell rectangle from two corner cells (any order, inclusive, clamped) to fractions, 4 decimals,
// with x + w <= 1 and y + h <= 1 guaranteed after rounding (the Lua side rejects anything over).
function gridRect(c0, r0, c1, r1, cols, rows) {
  var clamp = function (v, n) { return Math.max(0, Math.min(n - 1, Math.round(v))) }
  var a = clamp(Math.min(c0, c1), cols), b = clamp(Math.max(c0, c1), cols)
  var t = clamp(Math.min(r0, r1), rows), u = clamp(Math.max(r0, r1), rows)
  var axis = function (lo, hi, n) {
    var p = round4(lo / n), len = round4((hi + 1) / n) - p
    if (p + len > 10000) len = 10000 - p
    return [p / 10000, Math.max(1, len) / 10000]
  }
  var xs = axis(a, b, cols), ys = axis(t, u, rows)
  return { x: xs[0], y: ys[0], w: xs[1], h: ys[1] }
}

// The cells nearest to a rectangle: {c0, r0, c1, r1}, inclusive.
function rectGrid(rect, cols, rows) {
  var pair = function (p, len, n) {
    var lo = Math.max(0, Math.min(n - 1, Math.round(p * n)))
    var hi = Math.max(lo, Math.min(n - 1, Math.round((p + len) * n) - 1))
    return [lo, hi]
  }
  var xs = pair(rect.x, rect.w, cols), ys = pair(rect.y, rect.h, rows)
  return { c0: xs[0], r0: ys[0], c1: xs[1], r1: ys[1] }
}

// What the user typed to a section name: "Wide centre!" -> "cmd_wide_centre". Empty stays empty.
function customName(text) {
  var s = String(text == null ? "" : text).toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "")
  if (/^cmd_./.test(s)) s = s.slice(4)
  return s === "" ? "" : "cmd_" + s
}

// New model with the position set. A null rect keeps the existing one (re-key only). Key is written only when non-empty.
function withCustom(model, name, rect, key) {
  var c = JSON.parse(JSON.stringify(model))
  var old = isTable(c[name]) ? c[name] : {}
  var sec = { x: rect ? rect.x : old.x, y: rect ? rect.y : old.y, w: rect ? rect.w : old.w, h: rect ? rect.h : old.h }
  for (var k in old) if (!has(sec, k) && k !== "key") sec[k] = old[k]
  if (typeof key === "string" && key !== "") sec.key = key
  c[name] = sec
  return c
}

function withoutCustom(model, name) {
  var c = JSON.parse(JSON.stringify(model))
  delete c[name]
  return c
}

function fmtNumber(n) {
  var s = n.toFixed(9).replace(/(\.[0-9]*?)0+$/, "$1").replace(/\.$/, "")
  return s === "-0" ? "0" : s
}

// Returns the text for a value, or null when it cannot be written in the subset.
function fmt(v) {
  if (typeof v === "boolean") return v ? "true" : "false"
  if (typeof v === "number") return isFinite(v) ? fmtNumber(v) : null
  if (typeof v === "string") return '"' + v.replace(/["\r\n]/g, "") + '"'
  return null
}

function pick(model, k) {
  return has(model, k) && typeof model[k] === typeof DEFAULTS[k] && fmt(model[k]) !== null ? tidy(k, model[k]) : DEFAULTS[k]
}

function lines(table, skip) {
  var out = []
  for (var k in table) {
    if (skip && skip(k)) continue
    var t = fmt(table[k])
    if (t !== null) out.push(k + " = " + t)
  }
  return out
}

// A clean, commented file: every setting the app edits, then whatever else the model carried.
function serialize(model) {
  model = isTable(model) ? model : {}
  var out = [
    "# omagnet settings. Written by the omagnet settings app: edit here or there.",
    "# Comments you add to this file are not kept when the app saves.",
    "# Key strings are Hyprland's, for example \"CTRL + ALT + LEFT\". An empty string means no shortcut.", ""
  ]
  LAYOUT.forEach(function (group) {
    out.push("# " + group[0])
    group[1].forEach(function (k) { out.push(k + " = " + fmt(pick(model, k))) })
    out.push("")
  })
  var known = function (k) { return has(DEFAULTS, k) }
  var extra = lines(model, function (k) { return known(k) || isTable(model[k]) })
  if (extra.length) { out.push("# Other settings (kept as found)"); out = out.concat(extra, [""]) }
  out.push("# Shortcuts: an empty string means no shortcut")
  out.push("[keys]")
  var mk = isTable(model.keys) ? model.keys : {}
  for (var k in DEFAULTS.keys) {
    out.push(k + " = " + fmt(has(mk, k) && typeof mk[k] === "string" ? mk[k] : DEFAULTS.keys[k]))
  }
  out = out.concat(lines(mk, function (n) { return has(DEFAULTS.keys, n) }), [""])
  for (var name in model) {
    // a section named like a setting would clash with that setting's own line, so it is not kept
    if (name === "keys" || !isTable(model[name]) || has(DEFAULTS, name)) continue
    out.push("[" + name + "]")
    var sec = model[name], ordered = sec
    if (/^cmd_[A-Za-z0-9][A-Za-z0-9_]*$/.test(name)) { // stable order: x, y, w, h, key, then anything else
      ordered = {}
      ;["x", "y", "w", "h", "key"].forEach(function (k) { if (has(sec, k)) ordered[k] = sec[k] })
      for (var o in sec) if (!has(ordered, o)) ordered[o] = sec[o]
    }
    out = out.concat(lines(ordered), [""])
  }
  while (out[out.length - 1] === "") out.pop()
  return out.join("\n") + "\n"
}

var api = {
  DEFAULTS: DEFAULTS, defaults: defaults, parse: parse, merge: merge, serialize: serialize,
  customSections: customSections, bindSignature: bindSignature, withValue: withValue, withKey: withKey,
  gridRect: gridRect, rectGrid: rectGrid, customName: customName, withCustom: withCustom, withoutCustom: withoutCustom
}
if (typeof module !== "undefined" && module.exports) module.exports = api
