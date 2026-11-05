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
assert.equal(d.keys.two_thirds_center, ""); assert.equal(Object.keys(d.keys).length, 19)
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
  console.log("config_io ok (" + inputs.length + " inputs cross-checked against config.lua)")
}
