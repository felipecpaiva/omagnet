// Plain node self-check:  node plugin/tests/config_io.test.mjs
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
const odd = C.serialize({ margin: "big", ignore: "a#b\nc", edge_width: Infinity, x: NaN })
assert.equal(C.serialize(C.parse(odd).root), odd)
assert.equal(C.parse(odd).root.margin, 8); assert.equal(C.parse(odd).root.ignore, "abc"); assert.equal(C.parse(odd).root.x, undefined)
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
  const luaTest = readFileSync(join(here, "../../prototype/test_config.lua"), "utf8")
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
    const r = spawnSync("lua", [script, join(here, "../../prototype/config.lua"), file], { encoding: "utf8" })
    assert.equal(r.status, 0, r.stderr)
    const [body, badLine] = r.stdout.trimEnd().split(/\nBAD /)
    const parsed = C.parse(input)
    assert.equal(dump(C.merge(parsed.root)), body, "JS and Lua agree on input #" + i + "\n" + input)
    assert.equal(String(parsed.bad.length), badLine, "same unreadable line count on input #" + i)
  })
  console.log("config_io ok (" + inputs.length + " inputs cross-checked against config.lua)")
}
