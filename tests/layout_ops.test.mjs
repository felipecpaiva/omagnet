// Plain node self-check:  node tests/layout_ops.test.mjs
import assert from "node:assert/strict"
import { createRequire } from "node:module"
import { spawnSync } from "node:child_process"
import { writeFileSync, mkdtempSync } from "node:fs"
import { tmpdir } from "node:os"
import { join, dirname } from "node:path"
import { fileURLToPath } from "node:url"

const here = dirname(fileURLToPath(import.meta.url))
const L = createRequire(import.meta.url)("../LayoutOps.js")
const U = L.UNIT
const same = (a, b, msg) => assert.deepEqual(a, b, msg)
const tiles = (z, msg) => { const c = L.coverage(z); assert.ok(c.gap === 0 && !c.overlap, (msg || "") + " must tile the screen: " + JSON.stringify(c) + " " + L.toText(z)) }

// built-in layouts
same(L.builtin("columns:3").map((z) => z.x), [0, 3333, 6667]); same(L.builtin("columns:3").map((z) => z.w), [3333, 3334, 3333])
same(L.builtin("Grid: 3x2").length, 6); same(L.builtin("rows:2"), [{ x: 0, y: 0, w: U, h: 5000 }, { x: 0, y: 5000, w: U, h: 5000 }])
same(L.builtin("priority").map((z) => z.w), [2500, 5000, 2500])
for (const bad of ["", "columns", "columns:0", "columns:13", "grid:3", "grid:0x2", "nonsense", "rows:-1", "grid:2x2x2", null]) assert.equal(L.builtin(bad), null, "rejects " + bad)
for (const name of ["columns:5", "rows:7", "grid:4x3", "grid:1x1", "priority", "grid:12x12", "columns:12"]) tiles(L.builtin(name), name)

// text
same(L.toText(L.builtin("grid:2x2")), "0 0 0.5 0.5; 0.5 0 0.5 0.5; 0 0.5 0.5 0.5; 0.5 0.5 0.5 0.5")
same(L.toText([{ x: 0, y: 0, w: U, h: U }]), "0 0 1 1"); same(L.toText([{ x: 1234, y: 5, w: 100, h: 9995 }]), "0.1234 0.0005 0.01 0.9995")
for (const t of ["0 0 0.25 1; 0.25 0 0.5 1 ;0.75 0 0.25 0.5", "0 0 1 1", "0.1 0.2 0.3 0.4"]) same(L.parse(L.toText(L.parse(t).zones)).zones, L.parse(t).zones, "round trip " + t)
for (const bad of ["", "0 0 1", "0 0 1 1 1", "a b c d", "0 0 0 1", "0.5 0 0.6 1", "-0.1 0 0.5 1", "0 0 1 1; 0 0 x 1"]) assert.ok(L.parse(bad).error, "parse rejects '" + bad + "'")
assert.ok(L.parse(Array(66).join("0 0 1 1;")).error, "more than 64 zones")

// hit test, information, dividers
const g = L.builtin("grid:3x2")
assert.equal(L.zoneAt(g, 100, 100), 0); assert.equal(L.zoneAt(g, 9999, 9999), 5); assert.equal(L.zoneAt(g, 3333, 0), 1, "half open: the edge belongs to the next zone")
assert.equal(L.zoneAt([{ x: 0, y: 0, w: U, h: U }, { x: 2000, y: 2000, w: 3000, h: 3000 }], 3000, 3000), 1, "smallest zone wins")
same(L.coverage(g), { gap: 0, overlap: false }); same(L.coverage([{ x: 0, y: 0, w: 5000, h: U }]).gap, 0.5)
assert.equal(L.coverage([{ x: 0, y: 0, w: 6000, h: U }, { x: 5000, y: 0, w: 5000, h: U }]).overlap, true)
const dv = L.dividers(g)
same(dv.filter((d) => d.axis === "x").map((d) => [d.c, d.a, d.b]), [[3333, 0, U], [6667, 0, U]]); same(dv.filter((d) => d.axis === "y").map((d) => [d.c, d.a, d.b]), [[5000, 0, U]])
same(L.dividers([{ x: 0, y: 0, w: U, h: U }]), [], "one zone has no divider")

// split
let s = L.split(g, 0, "x", 1000); assert.equal(s.length, 7); same(s[0], { x: 0, y: 0, w: 1000, h: 5000 }); same(s[1], { x: 1000, y: 0, w: 2333, h: 5000 }); tiles(s, "split")
s = L.split(L.builtin("rows:1"), 0, "y", 4000); same(s, [{ x: 0, y: 0, w: U, h: 4000 }, { x: 0, y: 4000, w: U, h: 6000 }])
assert.equal(L.split(g, 0, "x", 100), null, "a part under the minimum is refused"); assert.equal(L.split(g, 0, "x", 3300), null)
assert.equal(L.split(g, 9, "x", 1000), null); assert.equal(L.split(g, 0, "z", 1000), null); assert.equal(L.split(g, 0, "x", 1000.5), null)
assert.equal(L.split(L.parse(Array(65).join("0 0 1 1;")).zones || Array.from({ length: 64 }, () => ({ x: 0, y: 0, w: U, h: U })), 0, "x", 5000), null, "64 zones is the limit")
same(g.length, 6, "split does not change its input")

// moveEdge: the whole divider moves, as one
let m = L.moveEdge(g, "x", 3333, 100, 4000); tiles(m, "moved"); same(m.map((z) => [z.x, z.w]), [[0, 4000], [4000, 2667], [6667, 3333], [0, 4000], [4000, 2667], [6667, 3333]])
m = L.moveEdge(g, "y", 5000, 5000, 3000); same(m.map((z) => [z.y, z.h]), [[0, 3000], [0, 3000], [0, 3000], [3000, 7000], [3000, 7000], [3000, 7000]])
same(L.moveEdge(g, "x", 3333, 100, 0).map((z) => [z.x, z.w])[0], [0, 300], "clamped by the left zone's minimum")
same(L.moveEdge(g, "x", 3333, 100, 9999).map((z) => [z.x, z.w])[1], [6367, 300], "clamped by the right zone's minimum")
assert.equal(L.moveEdge(g, "x", 0, 100, 50), null, "a screen border cannot move"); assert.equal(L.moveEdge(g, "x", U, 100, 50), null)
assert.equal(L.moveEdge(g, "x", 1234, 100, 50), null, "no divider there"); assert.equal(L.moveEdge(g, "x", 3333, 100, 4000.5), null)
// only the connected run moves: a divider with a gap in it is two dividers
const twoRuns = [{ x: 0, y: 0, w: 4000, h: 2000 }, { x: 4000, y: 0, w: 6000, h: 2000 }, { x: 0, y: 2000, w: U, h: 3000 }, { x: 0, y: 5000, w: 4000, h: 5000 }, { x: 4000, y: 5000, w: 6000, h: 5000 }]
tiles(twoRuns, "fixture"); const mv = L.moveEdge(twoRuns, "x", 4000, 500, 5000)
same(mv.map((z) => z.w), [5000, 5000, U, 4000, 6000], "the upper divider moved, the lower one stayed")
same(L.moveEdge(twoRuns, "x", 4000, 7500, 2500).map((z) => z.w), [4000, 6000, U, 2500, 7500], "the lower divider moved, the upper one stayed")
assert.equal(L.moveEdge(twoRuns, "x", 4000, 3500, 2500), null, "a position between the two runs is no divider")
// a T junction: a divider that other dividers end on moves as one line
const tj = [{ x: 0, y: 0, w: 5000, h: 5000 }, { x: 0, y: 5000, w: 5000, h: 5000 }, { x: 5000, y: 0, w: 5000, h: U }]
const tm = L.moveEdge(tj, "x", 5000, 7000, 6000); same(tm.map((z) => [z.x, z.w]), [[0, 6000], [0, 6000], [6000, 4000]]); tiles(tm, "T junction")
same(g.map((z) => z.x), [0, 3333, 6667, 0, 3333, 6667], "moveEdge does not change its input")

// merge
let mg = L.merge(g, [0, 1]); same(mg.length, 5); same(mg[0], { x: 0, y: 0, w: 6667, h: 5000 }); tiles(mg, "merge")
mg = L.merge(g, [5, 2]); same(mg[mg.length - 1] === undefined, false); tiles(mg, "merge a column pair"); assert.ok(mg.some((z) => z.x === 6667 && z.y === 0 && z.h === U))
mg = L.merge(L.builtin("grid:2x2"), [0, 1, 2, 3]); same(mg, [{ x: 0, y: 0, w: U, h: U }])
assert.equal(L.merge([{ x: 0, y: 0, w: 2000, h: 2000 }, { x: 8000, y: 8000, w: 2000, h: 2000 }], [0, 1]), null, "two zones far apart leave a gap, so no merge")
assert.equal(L.merge(g, [0, 4]), null, "not a rectangle"); assert.equal(L.merge(g, [0]), null); assert.equal(L.merge(g, [0, 0]), null); assert.equal(L.merge(g, [0, 99]), null)
assert.equal(L.merge(L.builtin("grid:2x2"), [0, 1, 2]), null, "an L shape is refused")
assert.equal(L.merge([{ x: 0, y: 0, w: 4000, h: 4000 }, { x: 6000, y: 0, w: 4000, h: 4000 }, { x: 3000, y: 0, w: 4000, h: 4000 }], [0, 1]), null, "another zone sits inside the box")

// remove
let rm = L.remove(g, 1); tiles(rm, "remove"); same(rm.length, 5); same(rm[0], { x: 0, y: 0, w: 6667, h: 5000 }, "the first neighbour that fits grows over it")
rm = L.remove(L.builtin("columns:2"), 1); same(rm, [{ x: 0, y: 0, w: U, h: U }])
assert.equal(L.remove([{ x: 0, y: 0, w: U, h: U }], 0), null, "the last zone stays")
assert.equal(L.remove(L.merge(L.builtin("grid:3x2"), [0, 1]).concat([]), 0) === null, false, "a merged zone still has a neighbour to give way to")
assert.equal(L.remove([{ x: 0, y: 0, w: 5000, h: 5000 }, { x: 5000, y: 5000, w: 5000, h: 5000 }], 0), null, "no neighbour shares an edge")

// canvas
let c = L.add([{ x: 0, y: 0, w: U, h: U }], { x: 9000, y: 9500, w: 5000, h: 10 }); same(c[1], { x: 5000, y: 9500, w: 5000, h: 300 }, "fitted inside the screen and to the minimum height")
c = L.setRect(c, 1, { x: -5, y: 100, w: 20000, h: 4000 }); same(c[1], { x: 0, y: 100, w: U, h: 4000 }); assert.equal(L.setRect(c, 9, { x: 0, y: 0, w: 1, h: 1 }), null)
same(L.drop(c, 1), [{ x: 0, y: 0, w: U, h: U }]); assert.equal(L.drop([{ x: 0, y: 0, w: U, h: U }], 0), null)
assert.equal(L.add(Array.from({ length: 64 }, () => ({ x: 0, y: 0, w: U, h: U })), { x: 0, y: 0, w: 100, h: 100 }), null, "the zone limit")

// property: random grid edits keep the screen tiled exactly
{
  let seed = 12345; const rnd = (n) => { seed = (Math.imul(seed, 1103515245) + 12345) >>> 0; return (seed >>> 12) % n }
  let z = L.builtin("grid:3x2"), done = { split: 0, move: 0, merge: 0, remove: 0 }
  for (let step = 0; step < 600; step++) {
    const op = rnd(4) === 0 && z.length > 8 ? 3 : rnd(4); let next = null
    if (op === 0) { const i = rnd(z.length), axis = rnd(2) ? "x" : "y", zz = z[i]; const lo = axis === "x" ? zz.x : zz.y, sz = axis === "x" ? zz.w : zz.h; next = L.split(z, i, axis, lo + L.MIN + rnd(Math.max(1, sz - 2 * L.MIN + 1))); if (next) done.split++ }
    else if (op === 1) { const d = L.dividers(z); if (d.length) { const v = d[rnd(d.length)]; next = L.moveEdge(z, v.axis, v.c, v.a, rnd(U)); if (next) done.move++ } }
    else if (op === 2) { const a = rnd(z.length), b = rnd(z.length); next = L.merge(z, [a, b, rnd(z.length)]); if (next) done.merge++ }
    else { next = L.remove(z, rnd(z.length)); if (next) done.remove++ }
    if (next) { z = next; tiles(z, "after step " + step + " op " + op); assert.ok(z.length >= 1 && z.length <= L.MAX_ZONES); z.forEach((q) => assert.ok(q.w >= (z.length === 1 ? 1 : 1) && q.h >= 1 && q.x >= 0 && q.y >= 0 && q.x + q.w <= U && q.y + q.h <= U, "inside")) }
    if (z.length > 40) z = L.builtin("grid:3x2")
  }
  assert.ok(done.split > 20 && done.move > 20 && done.merge > 5 && done.remove > 5, "the random run exercised every edit: " + JSON.stringify(done))
}

// the recommended layout for a screen: the cases in test_geometry.lua, and every layout it names exists
for (const [w, h, want] of [[1280, 800, "columns:2"], [1600, 1000, "columns:2"], [1799, 1000, "columns:2"], [1800, 1000, "grid:2x2"], [1920, 1080, "grid:2x2"], [2300, 1300, "grid:3x2"], [3840, 2160, "grid:3x2"], [3440, 1440, "priority"], [5120, 1440, "columns:4"], [1080, 1920, "rows:3"], [960, 1280, "rows:2"]]) {
  assert.equal(L.autoLayout(w, h), want, w + "x" + h); assert.ok(L.builtin(want), want + " exists")
}
assert.ok(L.builtin(L.autoLayout(0, 0)) && L.builtin(L.autoLayout(undefined, "x")), "no usable size still gives a layout")

// cross-check with the Lua module: built-in layouts, and what the Lua reader makes of the text written here
const lua = spawnSync("lua", ["-v"])
if (lua.error || lua.status !== 0) {
  console.log("layout_ops ok (lua not found: cross-check skipped)")
} else {
  const dir = mkdtempSync(join(tmpdir(), "omagnet-"))
  const script = join(dir, "dump.lua")
  writeFileSync(script, `local G = dofile(arg[1])
for i = 2, #arg do
  local name = arg[i]
  local z = name:sub(1, 5) == "text:" and G.parse_zones(name:sub(6)) or G.layout(name)
  local out = {}
  for _, f in ipairs(z or {}) do out[#out + 1] = string.format("%.4f %.4f %.4f %.4f", f[1], f[2], f[1] + f[3], f[2] + f[4]) end
  print(z and table.concat(out, ";") or "nil")
end`)
  const names = ["columns:3", "columns:7", "rows:5", "grid:3x2", "grid:4x3", "grid:12x12", "priority", "columns:13", "grid:3", "nonsense"]
  const texts = ["0 0 0.25 1; 0.25 0 0.5 1; 0.75 0 0.25 0.5", L.toText(L.split(g, 0, "x", 1000)), L.toText(L.moveEdge(g, "x", 3333, 100, 4321)), "0 0 1", "0.5 0 0.6 1"]
  const r = spawnSync("lua", [script, join(here, "../lua/geometry.lua"), ...names, ...texts.map((t) => "text:" + t)], { encoding: "utf8" })
  assert.equal(r.status, 0, r.stderr)
  const got = r.stdout.trimEnd().split("\n")
  // compared as edges (left, top, right, bottom): the Lua side keeps exact fractions, this side whole ten-thousandths
  const asText = (z) => z ? z.map((q) => [q.x, q.y, q.x + q.w, q.y + q.h].map((v) => (v / U).toFixed(4)).join(" ")).join(";") : "nil"
  names.forEach((n, i) => assert.equal(asText(L.builtin(n)), got[i], "JS and Lua agree on the built-in layout " + n))
  texts.forEach((t, i) => assert.equal(asText(L.parse(t).zones), got[names.length + i], "JS and Lua read the same zones from: " + t))
  const sizes = [[1280, 800], [1366, 768], [1600, 1000], [1799, 1000], [1800, 1000], [1920, 1080], [2299, 1300], [2300, 1300], [2560, 1440], [3440, 1440], [2560, 1080], [5120, 1440], [1080, 1920], [960, 1280], [1440, 2560], [800, 1280], [2199, 1000], [2200, 1000]]
  const asz = join(dir, "auto.lua")
  writeFileSync(asz, `local G = dofile(arg[1])
for i = 2, #arg, 2 do print(G.auto_layout(tonumber(arg[i]), tonumber(arg[i + 1]))) end`)
  const ra = spawnSync("lua", [asz, join(here, "../lua/geometry.lua"), ...sizes.flat().map(String)], { encoding: "utf8" })
  assert.equal(ra.status, 0, ra.stderr)
  ra.stdout.trimEnd().split("\n").forEach((l, i) => assert.equal(L.autoLayout(sizes[i][0], sizes[i][1]), l, "JS and Lua recommend the same layout for " + sizes[i].join("x")))
  console.log("layout_ops ok (" + names.length + " built-ins and " + texts.length + " texts cross-checked against geometry.lua)")
}
