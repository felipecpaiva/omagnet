// omagnet layout operations: pure JavaScript (no Qt imports), so node can test it and the settings app can
// `import "LayoutOps.js" as LayoutOps`. A layout is a list of zones {x, y, w, h}. Numbers are integers in ten-thousandths
// of the screen (UNIT = 10000), so edges meet exactly and repeated edits never drift. Text form, as in the config file:
// "x y w h; x y w h" with fractions. The Lua side (geometry.lua, G.layout and G.parse_zones) is the source of truth for the
// built-in layouts and for what counts as a readable layout; tests/layout_ops.test.mjs cross-checks the two.
//
// Every edit returns a NEW list, or null when it is refused (the caller keeps the old list). Grid edits (split, moveEdge,
// merge, remove) keep the zones tiling the screen; canvas edits (add, setRect) do not promise that.

var UNIT = 10000
var MIN = 300 // the smallest zone side: 3 percent of the screen
var MAX_ZONES = 64

function clone(zones) { return zones.map(function (z) { return { x: z.x, y: z.y, w: z.w, h: z.h } }) }
function lo(z, axis) { return axis === "x" ? z.x : z.y }
function size(z, axis) { return axis === "x" ? z.w : z.h }
function hi(z, axis) { return lo(z, axis) + size(z, axis) }
function other(axis) { return axis === "x" ? "y" : "x" }
function area(z) { return z.w * z.h }
function isInt(v) { return typeof v === "number" && isFinite(v) && Math.floor(v) === v }

// ---- built-in layouts (same as G.layout in lua/geometry.lua) and text

function span(i, n) { return [Math.round(i * UNIT / n), Math.round((i + 1) * UNIT / n)] }

// Zones for "columns:N", "rows:N", "grid:CxR" (1 to 12) or "priority"; null for anything else.
function builtin(name) {
  name = String(name == null ? "" : name).toLowerCase().replace(/\s/g, "")
  var m = /^([a-z]+):?(.*)$/.exec(name)
  if (!m) return null
  var count = function (v) { return /^[0-9]+$/.test(v) && Number(v) >= 1 && Number(v) <= 12 ? Number(v) : 0 }
  var z = [], i, j, a, b
  if (m[1] === "columns" || m[1] === "rows") {
    var n = count(m[2])
    if (!n) return null
    for (i = 0; i < n; i++) {
      a = span(i, n)
      z.push(m[1] === "columns" ? { x: a[0], y: 0, w: a[1] - a[0], h: UNIT } : { x: 0, y: a[0], w: UNIT, h: a[1] - a[0] })
    }
    return z
  }
  if (m[1] === "grid") {
    var g = /^([0-9]+)x([0-9]+)$/.exec(m[2])
    var c = g ? count(g[1]) : 0, r = g ? count(g[2]) : 0
    if (!c || !r) return null
    for (j = 0; j < r; j++) for (i = 0; i < c; i++) {
      a = span(i, c); b = span(j, r)
      z.push({ x: a[0], y: b[0], w: a[1] - a[0], h: b[1] - b[0] })
    }
    return z
  }
  if (name === "priority") return [{ x: 0, y: 0, w: 2500, h: UNIT }, { x: 2500, y: 0, w: 5000, h: UNIT }, { x: 7500, y: 0, w: 2500, h: UNIT }]
  return null
}

// Read "x y w h; ..." into zones. Returns { zones } or { error }. Same rules as G.parse_zones in Lua: four numbers per zone,
// positive size, inside the screen, 1 to 64 zones. A value is rounded to a ten-thousandth.
function parse(text) {
  var parts = String(text == null ? "" : text).split(";").filter(function (p) { return /\S/.test(p) })
  if (parts.length === 0) return { error: "no zones" }
  if (parts.length > MAX_ZONES) return { error: "at most 64 zones" }
  var zones = []
  for (var k = 0; k < parts.length; k++) {
    var words = parts[k].trim().split(/\s+/)
    if (words.length !== 4) return { error: "a zone needs four numbers: x y w h" }
    var v = words.map(function (w) { return /^-?[0-9]+\.?[0-9]*$/.test(w) ? Number(w) : NaN })
    if (v.some(function (n) { return isNaN(n) })) return { error: "a zone has something that is not a number" }
    if (v[2] <= 0 || v[3] <= 0 || v[0] < 0 || v[1] < 0 || v[0] + v[2] > 1 + 1e-9 || v[1] + v[3] > 1 + 1e-9) {
      return { error: "a zone must lie inside the screen (0 to 1)" }
    }
    var z = { x: Math.round(v[0] * UNIT), y: Math.round(v[1] * UNIT), w: Math.max(1, Math.round(v[2] * UNIT)), h: Math.max(1, Math.round(v[3] * UNIT)) }
    z.w = Math.min(z.w, UNIT - z.x); z.h = Math.min(z.h, UNIT - z.y)
    zones.push(z)
  }
  return { zones: zones }
}

function fmt(v) { return (v / UNIT).toFixed(4).replace(/\.?0+$/, "") || "0" }

function toText(zones) {
  return zones.map(function (z) { return [z.x, z.y, z.w, z.h].map(fmt).join(" ") }).join("; ")
}

// ---- hit testing and information

// The zone under a point (fractions of UNIT): the smallest one that contains it, or -1.
function zoneAt(zones, x, y) {
  var best = -1
  for (var i = 0; i < zones.length; i++) {
    var z = zones[i]
    if (x >= z.x && x < z.x + z.w && y >= z.y && y < z.y + z.h && (best < 0 || area(z) < area(zones[best]))) best = i
  }
  return best
}

// How much of the screen no zone covers (0 to 1) and whether two zones overlap. A warning for the editor, not an error.
function coverage(zones) {
  var xs = [0, UNIT], ys = [0, UNIT], i, j, k
  zones.forEach(function (z) { xs.push(z.x, z.x + z.w); ys.push(z.y, z.y + z.h) })
  var uniq = function (a) { return a.sort(function (p, q) { return p - q }).filter(function (v, n, s) { return n === 0 || v !== s[n - 1] }) }
  xs = uniq(xs); ys = uniq(ys)
  var gap = 0, overlap = false
  for (i = 0; i + 1 < xs.length; i++) for (j = 0; j + 1 < ys.length; j++) {
    var n = 0
    for (k = 0; k < zones.length; k++) {
      var z = zones[k]
      if (z.x <= xs[i] && z.x + z.w >= xs[i + 1] && z.y <= ys[j] && z.y + z.h >= ys[j + 1]) n++
    }
    if (n === 0) gap += (xs[i + 1] - xs[i]) * (ys[j + 1] - ys[j])
    if (n > 1) overlap = true
  }
  return { gap: gap / (UNIT * UNIT), overlap: overlap }
}

// ---- dividers: the lines between zones, each one connected run of zone edges at the same coordinate

// Zone edges on the line `axis` = c, as { i, side: "lo"|"hi", a, b } with [a, b] the span along the line.
function edgesAt(zones, axis, c) {
  var out = [], p = other(axis)
  zones.forEach(function (z, i) {
    if (lo(z, axis) === c) out.push({ i: i, side: "lo", a: lo(z, p), b: hi(z, p) })
    if (hi(z, axis) === c) out.push({ i: i, side: "hi", a: lo(z, p), b: hi(z, p) })
  })
  return out.sort(function (m, n) { return m.a - n.a || m.b - n.b })
}

// Group edges into connected runs (touching or overlapping spans). Each run is { a, b, edges }.
function runs(edges) {
  var out = []
  edges.forEach(function (e) {
    var r = out[out.length - 1]
    if (r && e.a <= r.b) { r.b = Math.max(r.b, e.b); r.edges.push(e) } else out.push({ a: e.a, b: e.b, edges: [e] })
  })
  return out
}

// Every divider: { axis, c, a, b } with c strictly inside the screen. An "x" divider is a vertical line at x = c running from
// y = a to y = b. Only lines with a zone on both sides count, so a screen border or a lone edge is not a divider.
function dividers(zones) {
  var out = []
  ;["x", "y"].forEach(function (axis) {
    var seen = {}
    zones.forEach(function (z) {
      ;[lo(z, axis), hi(z, axis)].forEach(function (c) {
        if (c <= 0 || c >= UNIT || seen[c]) return
        seen[c] = true
        runs(edgesAt(zones, axis, c)).forEach(function (r) {
          var sides = {}
          r.edges.forEach(function (e) { sides[e.side] = true })
          if (sides.lo && sides.hi) out.push({ axis: axis, c: c, a: r.a, b: r.b })
        })
      })
    })
  })
  return out
}

// ---- grid edits

// Cut zone i with a line: axis "x" gives a vertical line at x = at (left and right parts), "y" a horizontal one.
// The first part keeps index i, the second follows it. Refused when a part would be smaller than MIN.
function split(zones, i, axis, at) {
  var z = zones[i]
  if (!z || (axis !== "x" && axis !== "y") || !isInt(at)) return null
  if (at - lo(z, axis) < MIN || hi(z, axis) - at < MIN) return null
  if (zones.length >= MAX_ZONES) return null
  var a = { x: z.x, y: z.y, w: z.w, h: z.h }, b = { x: z.x, y: z.y, w: z.w, h: z.h }
  if (axis === "x") { a.w = at - z.x; b.x = at; b.w = z.x + z.w - at } else { a.h = at - z.y; b.y = at; b.h = z.y + z.h - at }
  var out = clone(zones)
  out.splice(i, 1, a, b)
  return out
}

// Move the divider at line `axis` = c, the run that contains position p along the line, to `to`. `to` is clamped so no zone
// gets smaller than MIN. A screen border cannot move. Returns the new zones (the same numbers when nothing could move), or
// null when there is no such divider.
function moveEdge(zones, axis, c, p, to) {
  if (c <= 0 || c >= UNIT || !isInt(to)) return null
  var run = null
  runs(edgesAt(zones, axis, c)).forEach(function (r) { if (!run && p >= r.a && p <= r.b) run = r })
  if (!run) return null
  var min = -Infinity, max = Infinity
  run.edges.forEach(function (e) {
    var z = zones[e.i]
    if (e.side === "hi") min = Math.max(min, lo(z, axis) + MIN)
    else max = Math.min(max, hi(z, axis) - MIN)
  })
  if (min > max) return null
  to = Math.max(min, Math.min(max, to))
  var out = clone(zones)
  run.edges.forEach(function (e) {
    var z = out[e.i]
    if (e.side === "hi") { if (axis === "x") z.w = to - z.x; else z.h = to - z.y }
    else if (axis === "x") { z.w = z.x + z.w - to; z.x = to } else { z.h = z.y + z.h - to; z.y = to }
  })
  return out
}

function overlaps(a, b) { return Math.min(a.x + a.w, b.x + b.w) > Math.max(a.x, b.x) && Math.min(a.y + a.h, b.y + b.h) > Math.max(a.y, b.y) }

// Join the zones at `idx` (two or more indexes) into one, only when together they fill a rectangle and no other zone is
// inside it. The new zone takes the place of the lowest index.
function merge(zones, idx) {
  var set = {}, list = []
  idx.forEach(function (i) { if (zones[i] && !set[i]) { set[i] = true; list.push(i) } })
  if (list.length < 2) return null
  var l = Infinity, t = Infinity, r = -Infinity, b = -Infinity, sum = 0
  list.forEach(function (i) {
    var z = zones[i]
    l = Math.min(l, z.x); t = Math.min(t, z.y); r = Math.max(r, z.x + z.w); b = Math.max(b, z.y + z.h); sum += area(z)
  })
  var box = { x: l, y: t, w: r - l, h: b - t }
  if (sum !== area(box)) return null
  for (var i = 0; i < zones.length; i++) {
    if (set[i]) { for (var j = i + 1; j < zones.length; j++) if (set[j] && overlaps(zones[i], zones[j])) return null }
    else if (overlaps(zones[i], box)) return null
  }
  var first = Math.min.apply(null, list), out = []
  zones.forEach(function (z, k) {
    if (k === first) out.push(box)
    else if (!set[k]) out.push({ x: z.x, y: z.y, w: z.w, h: z.h })
  })
  return out
}

// Delete zone i: a neighbour that shares its whole edge grows over the space. Refused when no zone fits that way
// (or when it is the last zone).
function remove(zones, i) {
  var z = zones[i]
  if (!z || zones.length < 2) return null
  for (var j = 0; j < zones.length; j++) {
    var n = zones[j]
    if (j === i) continue
    var sameCol = n.x === z.x && n.w === z.w && (n.y + n.h === z.y || z.y + z.h === n.y)
    var sameRow = n.y === z.y && n.h === z.h && (n.x + n.w === z.x || z.x + z.w === n.x)
    if (!sameCol && !sameRow) continue
    var out = clone(zones)
    out[j] = { x: Math.min(n.x, z.x), y: Math.min(n.y, z.y), w: sameRow ? n.w + z.w : n.w, h: sameCol ? n.h + z.h : n.h }
    out.splice(i, 1)
    return out
  }
  return null
}

// ---- canvas edits

// Keep a rectangle inside the screen and at least MIN on each side.
function fit(r) {
  var w = Math.max(MIN, Math.min(UNIT, Math.round(r.w))), h = Math.max(MIN, Math.min(UNIT, Math.round(r.h)))
  return { x: Math.max(0, Math.min(UNIT - w, Math.round(r.x))), y: Math.max(0, Math.min(UNIT - h, Math.round(r.y))), w: w, h: h }
}

function add(zones, rect) {
  if (zones.length >= MAX_ZONES) return null
  var out = clone(zones)
  out.push(fit(rect))
  return out
}

function setRect(zones, i, rect) {
  if (!zones[i]) return null
  var out = clone(zones)
  out[i] = fit(rect)
  return out
}

// Drop zone i with no neighbour taking the space (canvas mode). The last zone cannot be dropped.
function drop(zones, i) {
  if (!zones[i] || zones.length < 2) return null
  var out = clone(zones)
  out.splice(i, 1)
  return out
}

var api = {
  UNIT: UNIT, MIN: MIN, MAX_ZONES: MAX_ZONES,
  builtin: builtin, parse: parse, toText: toText, zoneAt: zoneAt, coverage: coverage, dividers: dividers,
  split: split, moveEdge: moveEdge, merge: merge, remove: remove, add: add, setRect: setRect, drop: drop, fit: fit
}
if (typeof module !== "undefined" && module.exports) module.exports = api
