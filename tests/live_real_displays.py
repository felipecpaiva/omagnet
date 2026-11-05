"""Live check across the REAL monitors (needs two or more plugged in): sending a window to the next and previous monitor, snaps and
SUPER + SHIFT zone drags on each monitor, a layout per monitor and per workspace, a drag from one monitor to another, and the
send-to-next-monitor key. Unlike live_displays.py it adds no virtual monitor. Nothing of yours is touched: one throwaway window,
margin and layout settings changed in memory only and put back, and a temporary folder tells omagnet every workspace is floating
(so a monitor whose workspace is tiled does not refuse the window). Workspace modes are not touched. Note: Omarchy takes the
floating tag off a window the moment it lands on a workspace that is not in floating mode, and omagnet then (rightly) leaves it
alone, so on a real setup the zones only work on monitors whose workspace you have switched to floating (Super + L). This test puts
the window on each monitor the way next_display does and re-adds the tag, so it checks the geometry on every monitor either way. About 2 minutes; do not touch the mouse or keyboard.
Usage: python3 tests/live_real_displays.py"""
import json, os, subprocess, sys, tempfile, time
from fractions import Fraction as F

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livehelp import go_home
from uinput_kbd import Keyboard, Mouse

TAG = "omarchy-floating-workspace"
RUN = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
failed = []


def sh(*a): return subprocess.run(a, capture_output=True, text=True).stdout
def ev(l): subprocess.run(["hyprctl", "eval", l], capture_output=True)
def jq(*a): return json.loads(sh("hyprctl", *a, "-j") or "null")
def read(name):
    p = os.path.join(RUN, name)
    return open(p).read().strip() if os.path.exists(p) else None
def win(): return next((c for c in jq("clients") if c["class"] == "omagnet-test"), None)
def geom(): c = win(); return (c["at"][0], c["at"][1], c["size"][0], c["size"][1])
def rnd(v): return int((F(v) * 2 + 1) // 2)


def check(label, got, want):
    ok = got == want
    print(("  ok   " if ok else "  FAIL ") + f"{label} -> {got}" + ("" if ok else f" (wanted {want})"), flush=True)
    if not ok:
        failed.append(label)


def close(a, b, tol=1): return all(abs(x - y) <= tol for x, y in zip(a, b))


def mons():
    out = []
    for m in jq("monitors"):
        w, h = (m["height"], m["width"]) if m["transform"] % 2 else (m["width"], m["height"])
        w, h = int(F(w) / F(str(m["scale"]))), int(F(h) / F(str(m["scale"])))
        r = m["reserved"]
        out.append({"name": m["name"], "x": m["x"], "y": m["y"], "ws": m["activeWorkspace"]["id"], "id": m["id"],
                    "area": (m["x"] + r[0], m["y"] + r[1], w - r[0] - r[2], h - r[1] - r[3])})
    return sorted(out, key=lambda m: (m["x"], m["y"], m["name"]))


def transfer(r, fa, ta):
    fx, fy, fw, fh = (r[0] - fa[0]) / fa[2], (r[1] - fa[1]) / fa[3], r[2] / fa[2], r[3] / fa[3]
    w, h = max(1, min(ta[2], rnd(fw * ta[2]))), max(1, min(ta[3], rnd(fh * ta[3])))
    return (min(ta[0] + ta[2] - w, max(ta[0], rnd(ta[0] + fx * ta[2]))), min(ta[1] + ta[3] - h, max(ta[1], rnd(ta[1] + fy * ta[3]))), w, h)


def cell(a, col, row, cols, rows):
    x, y, w, h = a
    l, r = rnd(x + F(col, cols) * w), rnd(x + F(col + 1, cols) * w)
    t, b = rnd(y + F(row, rows) * h), rnd(y + F(row + 1, rows) * h)
    return (l, t, r - l, b - t)


def place(rect):
    x, y, w, h = rect
    ev(f'for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.resize({{ x = {w}, y = {h}, relative = false, window = w }})); hl.dispatch(hl.dsp.window.move({{ x = {x}, y = {y}, relative = false, window = w }})) end end')
    time.sleep(0.7)


def retag():
    ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.tag({ tag = "+%s", window = w })) end end' % TAG); time.sleep(0.3)


def place_on(m, rect):
    """Put the test window on monitor m properly (its workspace becomes that monitor's, as with next_display), tag it, and place it."""
    if win()["monitor"] != m["id"]:
        ev(f'for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.move({{ monitor = "{m["name"]}", window = w }})) end end'); time.sleep(1.0)
    retag(); place(rect); retag()


def cmd(name):
    ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then _G.omagnet.command("%s", w) end end' % name)


def focus():
    ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.focus({ window = w })) end end'); time.sleep(0.4)


def main():
    _real_cursor = subprocess.run(["hyprctl", "cursorpos"], capture_output=True, text=True).stdout
    go_home()
    ms = mons()
    if len(ms) < 2:
        print("needs two or more real monitors; found", len(ms)); return 2
    print("monitors:", [(m["name"], m["area"]) for m in ms], flush=True)
    before = {"focus": (jq("activewindow") or {}).get("address", ""), "cursor": _real_cursor.strip().replace(",", "").split(),
              "windows": {c["address"]: (c["workspace"]["id"], c["at"], c["size"]) for c in jq("clients")}}
    holder = tempfile.TemporaryDirectory(prefix="omagnet-state-")
    for m in ms:
        with open(os.path.join(holder.name, f"{m['ws']}.lua"), "w") as f:
            f.write(f'o.workspace_mode({{ workspace = "{m["ws"]}", mode = "floating" }})\n')
    ev(f'_G.omagnet.state_dir = "{holder.name}/"; _G.omagnet.watch_super = nil')
    ev('local m = _G.omagnet; m.saved = { m.cfg.margin, m.cfg.zone_span }; m.cfg.margin = 0; m.cfg.zone_span = 24; m.layout_override = {}; '
       'm.cfg.zone_layouts = {}; m.cfg.workspace_layouts = {}; m.cfg.layout_landscape = "auto"; m.cfg.layout_portrait = "auto"')
    home = ms[0]
    ev('hl.exec_cmd("[float; size 500 300; move 400 300; workspace %d silent] kitty --class omagnet-test")' % home["ws"]); time.sleep(2.5)
    if not win():
        print("could not open the test window"); return 2
    retag()
    try:
        with Keyboard() as kb, Mouse() as mouse:
            print("send the window to the next monitor, all the way round, and back:")
            start = geom(); cur_area = home["area"]; cur = 0
            for step, label in ((1, "next"), (-1, "previous")):
                for _ in range(len(ms)):
                    target = ms[(cur + step) % len(ms)]
                    before_rect = geom()
                    retag(); cmd("next_display" if step == 1 else "prev_display"); time.sleep(1.6)
                    c = win()
                    check(f"{label} display: on {target['name']}", c["monitor"], target["id"])
                    check(f"{label} display: same relative place and size on {target['name']} (within a pixel)", close(geom(), transfer(before_rect, cur_area, target["area"])), True)
                    cur, cur_area = (cur + step) % len(ms), target["area"]
            check("back on the first monitor after a full circle each way", win()["monitor"], home["id"])

            print("a snap on each monitor uses that monitor's own area:")
            for m in ms:
                place_on(m, (m["area"][0] + 100, m["area"][1] + 100, 400, 250))
                for name, want in (("left", cell(m["area"], 0, 0, 2, 1)), ("right", cell(m["area"], 1, 0, 2, 1)), ("maximize", m["area"])):
                    retag(); cmd(name); time.sleep(1.0)
                    check(f"{m['name']}: {name}", geom(), want)
                cmd("restore"); time.sleep(0.5)

            print("a SUPER + SHIFT zone drag on each monitor (auto layout: what each screen gets):")
            def zdrag(m, px, py, label, want, zones):
                place_on(m, (m["area"][0] + 100, m["area"][1] + 100, 400, 250)); focus()
                ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {m['area'][0] + 200}, y = {m['area'][1] + 200} }}))"); time.sleep(0.3)
                kb.down("super"); kb.down("shift"); mouse.press(); time.sleep(0.2); mouse.move(2, 0, steps=1); time.sleep(0.2)
                ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {px}, y = {py} }}))"); time.sleep(0.7)
                check(f"{label}: outline on the right monitor", read("omagnet-preview"), f"{m['name']} {want[0] - m['x']} {want[1] - m['y']} {want[2]} {want[3]}")
                check(f"{label}: the layout's zones are shown", len([l for l in (read("omagnet-zones") or "").split("\n") if l]), zones)
                mouse.release(); kb.up("shift"); kb.up("super"); time.sleep(0.8)
                check(f"{label}: snapped", geom(), want)
                cmd("restore"); time.sleep(0.5)
            for m in ms:
                w, h = m["area"][2], m["area"][3]
                left, right = cell(m["area"], 0, 0, 2, 1), cell(m["area"], 1, 0, 2, 1)
                zdrag(m, left[0] + left[2] // 2, left[1] + left[3] // 2, f"{m['name']} left zone", left, 2)
                zdrag(m, right[0] + right[2] // 2, right[1] + right[3] // 2, f"{m['name']} right zone", right, 2)

            print("a layout for one monitor, and one for one workspace:")
            other = ms[-1]
            ev(f'_G.omagnet.cfg.zone_layouts = {{ ["{other["name"]}"] = "rows:2" }}'); time.sleep(0.2)
            top, bottom = cell(other["area"], 0, 0, 1, 2), cell(other["area"], 0, 1, 1, 2)
            zdrag(other, bottom[0] + bottom[2] // 2, bottom[1] + bottom[3] // 2, f"{other['name']} with rows:2, bottom", bottom, 2)
            mid = ms[1] if len(ms) > 2 else ms[0]
            ev(f'_G.omagnet.cfg.zone_layouts = {{}}; _G.omagnet.cfg.workspace_layouts = {{ ["{mid["ws"]}"] = "grid:2x2" }}'); time.sleep(0.2)
            br = cell(mid["area"], 1, 1, 2, 2)
            zdrag(mid, br[0] + br[2] // 2, br[1] + br[3] // 2, f"{mid['name']} workspace {mid['ws']} with grid:2x2, bottom right", br, 4)
            ev('_G.omagnet.cfg.workspace_layouts = {}')

            print("a drag that starts on one monitor and ends on another:")
            a, b = ms[0], ms[1]
            place_on(a, (a["area"][0] + 100, a["area"][1] + 100, 400, 250)); focus()
            ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {a['area'][0] + 200}, y = {a['area'][1] + 200} }}))"); time.sleep(0.3)
            kb.down("super"); kb.down("shift"); mouse.press(); time.sleep(0.2); mouse.move(2, 0, steps=1); time.sleep(0.2)
            rb = cell(b["area"], 1, 0, 2, 1)
            ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {rb[0] + rb[2] // 2}, y = {rb[1] + rb[3] // 2} }}))"); time.sleep(0.8)
            if not read("omagnet-preview"):
                # Omarchy took the floating tag off the window when it crossed onto a workspace that is not floating: correct, omagnet leaves it alone
                print(f"  skip  cross-monitor drag: {b['name']}'s workspace is not in floating mode (switch it with Super + L to run this check)", flush=True)
                mouse.release(); kb.up("shift"); kb.up("super"); time.sleep(1.0)
            else:
                check("the outline moved to the second monitor", (read("omagnet-preview") or "").split()[0:1], [b["name"]])
                mouse.release(); kb.up("shift"); kb.up("super"); time.sleep(1.0)
                check("snapped to the right half of the second monitor", (win()["monitor"], geom()), (b["id"], rb))
            retag(); cmd("restore"); time.sleep(0.6)

            print("the send-to-next-monitor key (SUPER + CTRL + ALT + RIGHT):")
            place_on(ms[0], (ms[0]["area"][0] + 100, ms[0]["area"][1] + 100, 400, 250)); focus()
            r0 = geom()
            kb.tap("super+ctrl+alt+right"); time.sleep(1.8)
            check("the key sent the window to the next monitor", win()["monitor"], ms[1]["id"])
            check("with the same relative place (within a pixel)", close(geom(), transfer(r0, ms[0]["area"], ms[1]["area"])), True)
            retag(); focus()  # Omarchy took the floating tag off when the window landed on a workspace that is not floating
            kb.tap("super+ctrl+alt+left"); time.sleep(1.8)
            check("and the other key sent it back", win()["monitor"], ms[0]["id"])

        for _ in range(30):
            if not sh("pgrep", "-f", "^qs -p .*preview.qml").split(): break
            time.sleep(0.1)
        check("no overlay process is left", len(sh("pgrep", "-f", "^qs -p .*preview.qml").split()), 0)
    finally:
        ev('local m = _G.omagnet; m.cfg.margin, m.cfg.zone_span = m.saved[1], m.saved[2]; m.layout_override = {}; m.cfg.zone_layouts = {}; m.cfg.workspace_layouts = {}; m.state_dir = nil; m.watch_super = nil')
        ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.close({ window = w })) end end'); time.sleep(0.8)
        if before["focus"]:
            ev(f"for _, w in ipairs(hl.get_windows()) do if w.address == '{before['focus']}' then hl.dispatch(hl.dsp.focus({{ window = w }})) end end".replace("{{", "{").replace("}}", "}"))
        ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {before['cursor'][0]}, y = {before['cursor'][1]} }}))")
        time.sleep(0.5)
        holder.cleanup()
        after = {c["address"]: (c["workspace"]["id"], c["at"], c["size"]) for c in jq("clients")}
        check("your windows are where they were", {a: v for a, v in after.items() if v[0] >= 0}, {a: v for a, v in before["windows"].items() if v[0] >= 0})
    print("\nALL OK" if not failed else "\nFAILED: " + "; ".join(failed))
    return 0 if not failed else 1


sys.exit(main())
