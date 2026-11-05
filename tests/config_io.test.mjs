// Plain node self-check:  node tests/config_io.test.mjs
import assert from "node:assert/strict"
import { createRequire } from "node:module"
import { readFileSync, writeFileSync, mkdtempSync } from "node:fs"
import { spawnSync } from "node:child_process"
import { tmpdir } from "node:os"
import { join, dirname } from "node:path"
import { fileURLToPath } from "node:url"

const here = dirname(fileURLToPath(import.meta.url))
const C = createRequire(import.meta.url)("../ConfigIO.js")

// defaults
const d = C.defaults()
assert.equal(d.margin, 8); assert.equal(d.edge_tight, true); assert.equal(d.keys.left, "CTRL + ALT + LEFT")
assert.equal(d.keys.two_thirds_center, ""); assert.equal(Object.keys(d.keys).length, 23)
d.keys.left = "X"; assert.equal(C.defaults().keys.left, "CTRL + ALT + LEFT", "defaults are copies")
const seen = {}
for (const [n, k] of Object.entries(C.DEFAULTS.keys)) if (k) { assert.ok(!seen[k], "duplicate shortcut " + k); seen[k] = n }

// bar_icon: boolean, default off, agrees with Lua, survives a save
assert.equal(C.defaults().bar_icon, false); assert.equal(C.merge(null).bar_icon, false)
assert.equal(C.merge(C.parse("bar_icon = true").root).bar_icon, true)
assert.equal(C.merge(C.parse('bar_icon = "yes"').root).bar_icon, false, "wrong type ignored")
assert.ok(C.serialize(C.defaults()).includes("# Optional icon in the Omarchy bar") && C.serialize(C.defaults()).includes("bar_icon = false"))
assert.equal(C.parse(C.serialize(C.withValue({}, "bar_icon", true))).root.bar_icon, true)
{
  const lt = readFileSync(join(here, "../lua/config.lua"), "utf8")
  assert.ok(/bar_icon\s*=\s*false/.test(lt), "config.lua declares bar_icon = false")
}

// appearance settings: same cases as lua/test_config.lua "appearance settings"
{
  const ap = C.merge(null)
  assert.deepEqual([ap.target_outline, ap.highlight_outline, ap.target_fill, ap.target_color, ap.highlight], [2, 4, 0.18, "", false])
  const ap2 = C.merge({ target_outline: 99, highlight_outline: -3, target_fill: 7, target_color: "#FF8800" })
  assert.deepEqual([ap2.target_outline, ap2.highlight_outline, ap2.target_fill, ap2.target_color], [20, 0, 1, "#FF8800"])
  for (const bad of ["red", "#fff", "#gg0000", "ff0000", "#ff00000", 5]) assert.equal(C.merge({ target_color: bad }).target_color, "", "bad colour dropped: " + bad)
  assert.equal(C.merge({ highlight: "yes", target_fill: "x" }).highlight, false, "wrong type ignored")
  // written file: plain decimals, clamped, stable
  const w = C.serialize({ target_fill: 0.18, target_outline: 99, highlight: true, highlight_outline: -3 })
  assert.ok(w.includes("# Drag outline") && w.includes("target_fill = 0.18\n") && w.includes("target_outline = 20\n") && w.includes("highlight = true") && w.includes("highlight_outline = 0\n"))
  assert.equal(C.serialize(C.parse(w).root), w)
  assert.equal(C.parse(C.serialize({ target_fill: 0.1 + 0.2 })).root.target_fill, 0.3, "float noise is rounded away")
  // shortcut: serialize drops '#' from strings, so a colour is not yet kept on disk (config.lua cannot read '#' in a string either)
}

// parse values, comments, bad lines
let { root: t, bad } = C.parse(`# a comment
keys_enabled = false   # trailing comment
edge_width = 12
[keys]
left = "CTRL + ALT + H"
restore = ""
garbage line
oops = notavalue
`)
assert.equal(t.keys_enabled, false); assert.equal(t.edge_width, 12)
assert.equal(t.keys.left, "CTRL + ALT + H"); assert.equal(t.keys.restore, "")
assert.equal(bad.length, 2)

// plain decimals only; CRLF
;({ root: t, bad } = C.parse("a = 0x10\nb = 1e999\nc = -3\nd = 2.5\ne = 7"))
assert.equal(t.a, undefined); assert.equal(t.b, undefined); assert.equal(t.c, -3); assert.equal(t.d, 2.5); assert.equal(t.e, 7)
assert.equal(bad.length, 2)
;({ root: t } = C.parse("margin = 6\r\nedge_tight = false\r\n"))
assert.equal(t.margin, 6); assert.equal(t.edge_tight, false)
assert.deepEqual(C.parse(null).root, {}); assert.deepEqual(C.parse("").bad, [])

// a top-level key named like a section must not break the section
;({ root: t } = C.parse('keys = true\n[keys]\nleft = "CTRL + ALT + H"\n'))
assert.equal(t.keys.left, "CTRL + ALT + H")
// prototype pollution attempt is just a bad line
;({ root: t, bad } = C.parse("__proto__ = 1\n[__proto__]\nx = 1"))
assert.equal(({}).x, undefined); assert.ok(bad.length >= 1)

// merge: overlay, wrong types, unknown keys
let c = C.merge(C.parse('keys_enabled = false\n[keys]\nleft = "CTRL + ALT + H"\nrestore = ""').root)
assert.equal(c.keys_enabled, false); assert.equal(c.drag_enabled, true)
assert.equal(c.keys.left, "CTRL + ALT + H"); assert.equal(c.keys.right, "CTRL + ALT + RIGHT"); assert.equal(c.keys.restore, "")
c = C.merge({ keys_enabled: "yes", edge_width: "wide", keys: { left: 5, nonsense: "X" } })
assert.equal(c.keys_enabled, true); assert.equal(c.edge_width, 12)
assert.equal(c.keys.left, "CTRL + ALT + LEFT"); assert.equal(c.keys.nonsense, undefined)
assert.deepEqual(C.merge(null).custom, {})
assert.equal(C.merge(C.parse("margin = 5\n[margin]\nx = 1").root).margin, 8, "section replaces same-named key, then wrong type")

// custom commands, validated like config.lua
const cmds = C.parse(`[cmd_wide]
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
`).root
c = C.merge(cmds)
assert.deepEqual(c.custom.cmd_wide, [0.1, 0, 0.8, 1]); assert.equal(c.keys.cmd_wide, "CTRL + ALT + W")
assert.ok(c.custom.cmd_nokey); assert.equal(c.keys.cmd_nokey, undefined)
assert.ok(!c.custom.cmd_toobig && !c.custom.cmd_incomplete && !c.custom.cmd_zero && !c.custom.notacommand)
const list = C.customSections(cmds)
assert.deepEqual(list.map((s) => [s.name, s.valid]),
  [["cmd_wide", true], ["cmd_nokey", true], ["cmd_toobig", false], ["cmd_incomplete", false], ["cmd_zero", false]])

// serialize: defaults, shape, no dashes
const text = C.serialize(C.defaults())
assert.ok(text.includes("[keys]\nleft = \"CTRL + ALT + LEFT\"") && text.includes("two_thirds_center = \"\""))
assert.ok(!new RegExp("[" + String.fromCharCode(0x2013, 0x2014) + "]").test(text), "no en or em dashes")
assert.deepEqual(C.merge(C.parse(text).root), C.merge(null), "defaults survive a write and read")
assert.equal(C.parse(text).bad.length, 0)

// round trip stable, and unknown content kept
const messy = `future_flag = true
# note
label = "hi"
margin = 12
ignore = "steam, mpv"
[keys]
left = ""
mine = "ALT + M"
[cmd_wide]
x = 0.1
y = 0
w = 0.8
h = 1
key = "CTRL + ALT + W"
[cmd_broken]
x = 3
[extra]
n = 1
s = "z"
`
const once = C.serialize(C.parse(messy).root)
assert.equal(C.serialize(C.parse(once).root), once, "round trip is stable")
const back = C.parse(once).root
assert.equal(back.future_flag, true); assert.equal(back.label, "hi"); assert.equal(back.margin, 12)
assert.equal(back.keys.left, ""); assert.equal(back.keys.mine, "ALT + M")
assert.deepEqual(back.cmd_wide, { x: 0.1, y: 0, w: 0.8, h: 1, key: "CTRL + ALT + W" })
assert.deepEqual(back.cmd_broken, { x: 3 }); assert.deepEqual(back.extra, { n: 1, s: "z" })
assert.deepEqual(C.merge(back), C.merge(C.parse(messy).root), "meaning unchanged by a save")

// wrong-typed known values become defaults on save; hostile strings stay safe
// a colour and a hash in a string survive a save and a read, and a comment after them still goes
const hashed = C.serialize({ target_color: "#FF8800", ignore: "a#b" })
assert.ok(hashed.includes('target_color = "#FF8800"'))
assert.equal(C.parse(hashed).root.target_color, "#FF8800")
assert.equal(C.merge(C.parse(hashed).root).target_color, "#FF8800", "the colour is kept after a round trip")
assert.equal(C.parse('c = "#fff" # note\nd = 5 # gap').root.c, "#fff")
assert.equal(C.parse('c = "#fff" # note\nd = 5 # gap').root.d, 5)
assert.equal(C.serialize({ ignore: 'say "hi"' }).includes('say hi'), true, "a double quote cannot be written, it is dropped")
const odd = C.serialize({ margin: "big", ignore: "a#b\nc", edge_width: Infinity, x: NaN })
assert.equal(C.serialize(C.parse(odd).root), odd)
assert.equal(C.parse(odd).root.margin, 8); assert.equal(C.parse(odd).root.ignore, "a#bc") // a hash is kept, a line break is dropped; assert.equal(C.parse(odd).root.x, undefined)
assert.equal(C.serialize(C.parse(C.serialize({ a: 1e-7 })).root), C.serialize({ a: 1e-7 }))
assert.equal(C.serialize(null), C.serialize({}))

// edits do not mutate, and the bind signature moves only with shortcuts
const m0 = C.parse("margin = 4").root
const m1 = C.withValue(m0, "margin", 9), m2 = C.withKey(m0, "left", "ALT + L")
assert.equal(m0.margin, 4); assert.equal(m1.margin, 9)
assert.equal(C.bindSignature(m0), C.bindSignature(m1)); assert.notEqual(C.bindSignature(m0), C.bindSignature(m2))
assert.notEqual(C.bindSignature(m0), C.bindSignature(C.parse('[cmd_a]\nx=0\ny=0\nw=1\nh=1\nkey="ALT + A"').root))

// ---- custom position editor helpers
{
  const lt = (r) => r.x >= 0 && r.y >= 0 && r.w > 0 && r.h > 0 && r.x + r.w <= 1 && r.y + r.h <= 1
  assert.deepEqual(C.gridRect(0, 0, 23, 13, 24, 14), { x: 0, y: 0, w: 1, h: 1 }, "full grid")
  assert.deepEqual(C.gridRect(6, 0, 6, 0, 24, 14), { x: 0.25, y: 0, w: 0.0417, h: 0.0714 }, "single cell")
  assert.deepEqual(C.gridRect(23, 13, 0, 0, 24, 14), { x: 0, y: 0, w: 1, h: 1 }, "reversed corners")
  assert.deepEqual(C.gridRect(-5, -5, 99, 99, 24, 14), { x: 0, y: 0, w: 1, h: 1 }, "clamped")
  assert.deepEqual(C.gridRect(12, 0, 99, 99, 24, 14), { x: 0.5, y: 0, w: 0.5, h: 1 })
  const cols = 24, rows = 14
  for (let a = 0; a < cols; a++) for (let b = a; b < cols; b++) for (let r0 = 0; r0 < rows; r0++) for (let r1 = r0; r1 < rows; r1++) {
    const g = C.gridRect(a, r0, b, r1, cols, rows)
    assert.ok(lt(g), "valid " + JSON.stringify([a, r0, b, r1, g]))
    assert.deepEqual(C.rectGrid(g, cols, rows), { c0: a, r0, c1: b, r1 }, "round trip " + [a, r0, b, r1])
  }
  assert.deepEqual(C.rectGrid({ x: 0.1, y: 0, w: 0.8, h: 1 }, 24, 14), { c0: 2, r0: 0, c1: 21, r1: 13 })

  assert.equal(C.customName("Wide centre!"), "cmd_wide_centre")
  assert.equal(C.customName("  __A--b__c  "), "cmd_a_b_c")
  assert.equal(C.customName("cmd_left"), "cmd_left")
  for (const e of ["", "   ", "!!!", null]) assert.equal(C.customName(e), "", "empty stays empty")
  assert.equal(C.customName("cmd_"), "cmd_cmd", "never the bare prefix")

  const base = C.parse('future = 1\n[cmd_a]\nx = 0\ny = 0\nw = 0.5\nh = 1\nkey = "ALT + A"\nnote = "keep"\n[extra]\nn = 1').root
  const snap = JSON.stringify(base)
  const r = { x: 0.25, y: 0, w: 0.5, h: 0.5 }
  const added = C.withCustom(base, "cmd_b", r, "")
  assert.equal(JSON.stringify(base), snap, "no mutation")
  assert.deepEqual(Object.keys(added.cmd_b), ["x", "y", "w", "h"], "no key when empty")
  assert.equal(added.future, 1); assert.deepEqual(added.extra, { n: 1 }); assert.equal(added.cmd_a.note, "keep")
  assert.equal(C.withCustom(base, "cmd_b", r, "ALT + B").cmd_b.key, "ALT + B")
  const rekey = C.withCustom(base, "cmd_a", null, "ALT + Z")
  assert.deepEqual([rekey.cmd_a.x, rekey.cmd_a.w, rekey.cmd_a.key, rekey.cmd_a.note], [0, 0.5, "ALT + Z", "keep"])
  assert.equal(C.withCustom(base, "cmd_a", null, "").cmd_a.key, undefined, "empty key removes it")
  const gone = C.withoutCustom(base, "cmd_a")
  assert.ok(!("cmd_a" in gone) && gone.future === 1 && "cmd_a" in base)
  assert.ok(C.serialize(added).includes("[cmd_b]\nx = 0.25\ny = 0\nw = 0.5\nh = 0.5\n"), "stable order, plain decimals")
  assert.equal(C.serialize(C.parse(C.serialize(added)).root), C.serialize(added))

  const sig = C.bindSignature
  assert.notEqual(sig(base), sig(C.withCustom(base, "cmd_a", null, "ALT + Z")), "key changed")
  assert.notEqual(sig(base), sig(C.withCustom(base, "cmd_b", r, "ALT + B")), "key added")
  assert.notEqual(sig(base), sig(C.withCustom(base, "cmd_a", null, "")), "key removed")
  assert.notEqual(sig(base), sig(C.withoutCustom(base, "cmd_a")), "command removed")
  assert.equal(sig(base), sig(C.withCustom(base, "cmd_a", r, "ALT + A")), "rectangle only: same")
  assert.equal(sig(base), sig(C.withCustom(base, "cmd_b", r, "")), "keyless add: same")
}

// grid zones: the settings are written, and the zone sections the app does not edit survive a save
{
  const src = 'zone_span = 40\n[zone_layouts]\nDP-1 = "rows:2"\n[layout_coding]\nzones = "0 0 0.5 1; 0.5 0 0.5 1"\nkey = "ALT + 1"\n'
  const out = C.serialize(C.parse(src).root)
  assert.ok(out.includes("zone_span = 40") && out.includes("zones_enabled = true") && out.includes('layout_landscape = "grid:3x2"'), "zone settings written")
  assert.ok(out.includes('[zone_layouts]\nDP-1 = "rows:2"') && out.includes('[layout_coding]\nzones = "0 0 0.5 1; 0.5 0 0.5 1"\nkey = "ALT + 1"'), "zone sections kept, hyphenated monitor name too")
  assert.deepEqual(C.merge(C.parse(out).root).zone_layouts, { "DP-1": "rows:2" }, "and read back")
  assert.equal(C.merge(C.parse(src).root).keys["layout:coding"], "ALT + 1")
}

// layout editor helpers
{
  const m0 = C.parse('layout_landscape = "coding"\n[zone_layouts]\nDP-1 = "coding"\nHDMI-A-1 = "rows:2"\n[workspace_layouts]\n3 = "coding"\nmain = "columns:2"\n').root
  assert.deepEqual(C.merge(m0).workspace_layouts, { 3: "coding", main: "columns:2" }, "workspace layouts read, numeric and named")
  assert.equal(C.merge(C.parse('[workspace_layouts]\n3 = 5\n4 = ""\n').root).workspace_layouts["3"], undefined, "wrong types and empty names skipped")
  const w = C.withWorkspaceLayout({}, 7, "grid:2x2"); assert.deepEqual(w.workspace_layouts, { 7: "grid:2x2" })
  assert.deepEqual(C.withWorkspaceLayout(w, 7, ""), {}, "an empty name removes the entry and the empty section")
  assert.equal(C.layoutId("Coding 2!"), "coding_2"); assert.equal(C.layoutId("layout_wide"), "wide"); assert.equal(C.layoutId("  "), "")
  const a = C.withLayout({ future: 1 }, "coding", "0 0 0.5 1; 0.5 0 0.5 1", "ALT + 1")
  assert.deepEqual(a.layout_coding, { zones: "0 0 0.5 1; 0.5 0 0.5 1", key: "ALT + 1" }); assert.equal(a.future, 1)
  assert.equal(C.withLayout(a, "coding", "0 0 1 1", "").layout_coding.key, undefined, "an empty key removes the shortcut")
  const keepNote = C.withLayout({ layout_x: { zones: "0 0 1 1", note: "mine" } }, "x", "0 0 0.5 1"); assert.equal(keepNote.layout_x.note, "mine", "other fields kept")
  const gone = C.withoutLayout(C.withLayout(m0, "coding", "0 0 1 1"), "coding")
  assert.equal(gone.layout_coding, undefined); assert.deepEqual(gone.zone_layouts, { "HDMI-A-1": "rows:2" }); assert.deepEqual(gone.workspace_layouts, { main: "columns:2" })
  assert.equal(gone.layout_landscape, "grid:3x2", "the default that named the deleted layout goes back to the built-in one")
  const inp = C.withLayout({}, "a", "0 0 1 1"); const copy = JSON.stringify(inp); C.withoutLayout(inp, "a"); assert.equal(JSON.stringify(inp), copy, "the input is not changed")
  // written to disk and read by the Lua module: the sections survive a save
  const text = C.serialize(C.withWorkspaceLayout(C.withLayout({}, "coding", "0 0 0.25 1; 0.25 0 0.75 1", "ALT + 1"), 3, "coding"))
  assert.ok(text.includes("[workspace_layouts]\n3 = \"coding\"") && text.includes("[layout_coding]\nzones = \"0 0 0.25 1; 0.25 0 0.75 1\"\nkey = \"ALT + 1\""), "sections written")
}

// cross-check against the Lua module: same inputs, same merged result
const lua = spawnSync("lua", ["-v"])
if (lua.error || lua.status !== 0) {
  console.log("config_io ok (lua not found: cross-check skipped)")
} else {
  const luaTest = readFileSync(join(here, "../lua/test_config.lua"), "utf8")
  const inputs = [...luaTest.matchAll(/\[\[([\s\S]*?)\]\]/g)].map((m) => m[1])
  inputs.push(...[...luaTest.matchAll(/C\.parse\("((?:[^"\\]|\\.)*)"\)/g)].map((m) => JSON.parse('"' + m[1] + '"')))
  inputs.push(messy, once, "[cmd_a]\nx = 0\ny = 0\nw = 1\nh = 1\nkey = \"ALT + A\"\n", "margin = 0x10\nedge_width = 1e999\nignore = steam")
  assert.ok(inputs.length >= 6, "found the Lua test inputs, got " + inputs.length)
  const num = (v) => String(parseFloat(v.toPrecision(12)))
  const dump = (cfg) => {
    const out = []
    const walk = (p, v) => {
      if (v && typeof v === "object") Object.keys(v).forEach((k) => walk(p + "." + k, v[k]))
      else out.push(p + "=" + (typeof v === "number" ? num(v) : JSON.stringify(v)))
    }
    walk("", cfg)
    return out.sort().join("\n")
  }
  const dir = mkdtempSync(join(tmpdir(), "omagnet-"))
  const script = join(dir, "dump.lua")
  writeFileSync(script, `local C = dofile(arg[1])
local cfg, bad = C.load(arg[2])
local out = {}
local function walk(p, v)
  if type(v) == "table" then for k, x in pairs(v) do walk(p .. "." .. (type(k) == "number" and k - 1 or k), x) end
  elseif type(v) == "number" then out[#out + 1] = p .. "=" .. string.format("%.12g", v)
  elseif type(v) == "string" then out[#out + 1] = p .. '="' .. v .. '"'
  else out[#out + 1] = p .. "=" .. tostring(v) end
end
walk("", cfg)
table.sort(out)
print(table.concat(out, "\\n"))
print("BAD " .. #bad)
`)
  inputs.forEach((input, i) => {
    const file = join(dir, "in" + i + ".toml")
    writeFileSync(file, input)
    const r = spawnSync("lua", [script, join(here, "../lua/config.lua"), file], { encoding: "utf8" })
    assert.equal(r.status, 0, r.stderr)
    const [body, badLine] = r.stdout.trimEnd().split(/\nBAD /)
    const parsed = C.parse(input)
    assert.equal(dump(C.merge(parsed.root)), body, "JS and Lua agree on input #" + i + "\n" + input)
    assert.equal(String(parsed.bad.length), badLine, "same unreadable line count on input #" + i)
  })
  // a section written by withCustom must survive config.lua: accepted, same four numbers, key bound
  for (const [rect, key] of [[C.gridRect(3, 1, 20, 12, 24, 14), "CTRL + ALT + W"], [C.gridRect(23, 13, 23, 13, 24, 14), ""], [C.gridRect(0, 0, 23, 13, 24, 14), ""], [C.gridRect(5, 0, 7, 13, 24, 14), "ALT + Q"]]) {
    const written = C.serialize(C.withCustom({}, "cmd_x1", rect, key))
    const file = join(dir, "custom.toml")
    writeFileSync(file, written)
    const r = spawnSync("lua", [script, join(here, "../lua/config.lua"), file], { encoding: "utf8" })
    assert.equal(r.status, 0, r.stderr)
    const got = [0, 1, 2, 3].map((i) => Number(/^\.custom\.cmd_x1\.\d=(.*)$/m.exec(r.stdout.split("\n").filter((l) => l.startsWith(".custom.cmd_x1." + i + "=")).join("\n"))[1]))
    assert.deepEqual(got, [rect.x, rect.y, rect.w, rect.h], "Lua returns the same numbers")
    assert.equal(r.stdout.includes('.keys.cmd_x1="' + key + '"'), key !== "", "key bound only when set")
  }
  console.log("config_io ok (" + inputs.length + " inputs cross-checked against config.lua)")
}

{
  // withZoneLayout: set, replace, delete, delete the empty section, no mutation, hyphens survive a round trip
  const base = Object.freeze({ margin: 8 })
  const a = C.withZoneLayout(base, "DP-1", "columns:3")
  assert.deepEqual(a.zone_layouts, { "DP-1": "columns:3" })
  assert.equal(base.zone_layouts, undefined, "input not mutated")
  const b = C.withZoneLayout(a, "DP-1", "rows:2")
  assert.deepEqual(b.zone_layouts, { "DP-1": "rows:2" })
  assert.deepEqual(a.zone_layouts, { "DP-1": "columns:3" }, "input not mutated on replace")
  const two = C.withZoneLayout(b, "HDMI-A-1", "priority")
  assert.deepEqual(C.withZoneLayout(two, "DP-1", "").zone_layouts, { "HDMI-A-1": "priority" })
  assert.equal(has(C.withZoneLayout(b, "DP-1", ""), "zone_layouts"), false, "empty section removed")
  assert.equal(has(C.withZoneLayout(base, "DP-1", ""), "zone_layouts"), false, "deleting from nothing is fine")
  const round = C.parse(C.serialize(two)).root
  assert.deepEqual(round.zone_layouts, { "DP-1": "rows:2", "HDMI-A-1": "priority" })
  assert.deepEqual(C.merge(round).zone_layouts, { "DP-1": "rows:2", "HDMI-A-1": "priority" })
  console.log("withZoneLayout ok")
}
function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k) }
