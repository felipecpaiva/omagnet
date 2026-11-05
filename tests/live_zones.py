"""Live check of the grid zones: a real SUPER + SHIFT drag (virtual keyboard and mouse) on a throwaway window.
For each cell of the 3 x 2 layout it moves the pointer into the cell, checks the outline the overlay was told to draw, drops,
and checks the exact rectangle. Also: two zones near a shared edge, the zone keys, a layout switch, and that nothing is left
behind. Do not type or move the mouse while it runs (about 60 seconds).
Needs: Hyprland with omagnet loaded (after `hyprctl reload`), kitty, write access to /dev/uinput.  Usage: python3 tests/live_zones.py"""
import json, math, os, subprocess, sys, time
from fractions import Fraction as F

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
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
def geom():
    c = win(); return (c["at"][0], c["at"][1], c["size"][0], c["size"][1])
def rnd(v): return int(math.floor(v + F(1, 2)))


def check(label, got, want):
    ok = got == want
    print(("  ok   " if ok else "  FAIL ") + f"{label} -> {got}" + ("" if ok else f" (wanted {want})"))
    if not ok:
        failed.append(label)


def area():
    m = next(m for m in jq("monitors") if m["focused"])
    w, h = (m["height"], m["width"]) if m["transform"] % 2 else (m["width"], m["height"])
    w, h = int(F(w) / F(str(m["scale"]))), int(F(h) / F(str(m["scale"])))
    r = m["reserved"]
    return m["name"], m["x"], m["y"], (m["x"] + r[0], m["y"] + r[1], w - r[0] - r[2], h - r[1] - r[3])


def cell(a, col, row, cols, rows):
    """The exact rectangle of a grid cell with no margin: edges are rounded, not sizes, so neighbours meet."""
    x, y, w, h = a
    l, r = rnd(x + F(col, cols) * w), rnd(x + F(col + 1, cols) * w)
    t, b = rnd(y + F(row, rows) * h), rnd(y + F(row + 1, rows) * h)
    return (l, t, r - l, b - t)


def main():
    prev = (jq("activewindow") or {}).get("address", "")
    cur = sh("hyprctl", "cursorpos").strip().replace(",", "").split()
    binds = [b["description"] for b in jq("binds")]
    check("the zone binds are registered (run hyprctl reload first if not)", sum(1 for d in binds if "zones" in d or "zone" in d) >= 6, True)
    ev('hl.exec_cmd("[float; size 500 300; move 400 300] kitty --class omagnet-test")'); time.sleep(2.5)
    w = win()
    if not w:
        print("could not open the test window"); return 2
    ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.tag({ tag = "+%s", window = w })); hl.dispatch(hl.dsp.focus({ window = w })) end end' % TAG); time.sleep(0.8)
    ev('_G.omagnet.saved = { _G.omagnet.cfg.margin, _G.omagnet.cfg.zone_span }; _G.omagnet.cfg.margin = 0; _G.omagnet.cfg.zone_span = 24; '
       '_G.omagnet.layout_override = {}; _G.omagnet.cfg.zone_layouts = {}; _G.omagnet.cfg.layout_landscape = "grid:3x2"; _G.omagnet.cfg.layout_portrait = "grid:3x2"')
    start = geom()
    mon, mx, my, a = area()
    try:
        with Keyboard() as kb, Mouse() as mouse:
            def zone_drag(px, py, label, want_rect, extra_wait=0.7):
                ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {start[0] + 100}, y = {start[1] + 100} }}))"); time.sleep(0.3)
                kb.down("super"); kb.down("shift"); mouse.press(); time.sleep(0.2)
                mouse.move(2, 0, steps=1); time.sleep(0.2)
                ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {px}, y = {py} }}))"); time.sleep(extra_wait)
                shown = read("omagnet-preview")
                lines = (read("omagnet-zones") or "").split("\n")
                check(f"{label}: outline", shown, f"{mon} {want_rect[0] - mx} {want_rect[1] - my} {want_rect[2]} {want_rect[3]}")
                check(f"{label}: every zone of the layout is shown to the overlay", len([l for l in lines if l]) , ZONES[0])
                mouse.release(); kb.up("shift"); kb.up("super"); time.sleep(0.8)
                check(f"{label}: snapped", geom(), want_rect)
                ev('_G.omagnet.command("restore")'); time.sleep(0.6)

            print("a SUPER + SHIFT drag, one cell at a time (3 x 2 grid):")
            ZONES = [6]
            for col in range(3):
                for row in range(2):
                    r = cell(a, col, row, 3, 2)
                    zone_drag(r[0] + r[2] // 2, r[1] + r[3] // 2, f"cell {col},{row}", r)
            check("restore after the zone snaps goes back to where the window was", geom(), start)

            print("two zones near a shared edge:")
            c0, c1 = cell(a, 0, 0, 3, 2), cell(a, 1, 0, 3, 2)
            zone_drag(c1[0] - 4, c0[1] + 100, "edge between column 0 and 1 (top row)", (c0[0], c0[1], c0[2] + c1[2], c0[3]))
            r0, r1 = cell(a, 2, 0, 3, 2), cell(a, 2, 1, 3, 2)
            zone_drag(r0[0] + 100, r1[1] - 4, "edge between the two rows (right column)", (r0[0], r0[1], r0[2], r0[3] + r1[3]))

            print("a plain SUPER drag still does the edge snapping, not zones:")
            ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {start[0] + 100}, y = {start[1] + 100} }}))"); time.sleep(0.3)
            kb.down("super"); mouse.press(); time.sleep(0.2); mouse.move(-3000, 0); time.sleep(0.6)
            half = rnd(F(a[2], 2))
            check("the left edge gives the left half, not a zone", read("omagnet-preview"), f"{mon} {a[0] - mx} {a[1] - my} {half} {a[3]}")
            mouse.release(); kb.up("super"); time.sleep(0.8)
            ev('_G.omagnet.command("restore")'); time.sleep(0.6)

            print("the zone keys step the window through the zones:")
            ev(f'for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.focus({{ window = w }})) end end'); time.sleep(0.4)
            r = cell(a, 0, 0, 3, 2)
            ev(f'for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.resize({{ x = {r[2]}, y = {r[3]}, relative = false, window = w }})); hl.dispatch(hl.dsp.window.move({{ x = {r[0]}, y = {r[1]}, relative = false, window = w }})) end end'); time.sleep(0.6)
            kb.tap("ctrl+alt+bracketright"); time.sleep(0.8)
            check("next zone is the middle top cell", geom(), cell(a, 1, 0, 3, 2))
            kb.tap("ctrl+alt+bracketleft"); time.sleep(0.8)
            check("previous zone is the top left cell", geom(), cell(a, 0, 0, 3, 2))
            kb.tap("ctrl+alt+bracketleft"); time.sleep(0.8)
            check("previous again wraps to the last cell", geom(), cell(a, 2, 1, 3, 2))

            print("switching the layout of the monitor:")
            # the window was placed by hand before the key steps, so Restore returns to that place; put it back at the start
            ev('_G.omagnet.command("restore")'); time.sleep(0.8)
            ev(f'for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.resize({{ x = {start[2]}, y = {start[3]}, relative = false, window = w }})); hl.dispatch(hl.dsp.window.move({{ x = {start[0]}, y = {start[1]}, relative = false, window = w }})) end end'); time.sleep(0.6)
            check("back at the start before the layout test (within a pixel: a hand-placed resize can be off by one)", all(abs(x - y) <= 1 for x, y in zip(geom(), start)), True)
            ev('_G.omagnet.command("layout:nothing")'); time.sleep(0.3)
            ev('_G.omagnet.command("layout_next")'); time.sleep(0.5)
            ZONES[0] = 9
            r33 = cell(a, 1, 1, 3, 3)
            zone_drag(r33[0] + r33[2] // 2, r33[1] + r33[3] // 2, "after layout_next (grid:3x3), the centre cell", r33)


            print("Show on screen (the editor's preview) and a layout per workspace:")
            nmon = len(jq("monitors"))
            ev('_G.omagnet.preview("grid:3x3", 2)'); time.sleep(1.2)
            lines = [l for l in (read("omagnet-zones") or "").split("\n") if l]
            check("the preview gives nine zones per monitor to the overlay", len(lines), 9 * nmon)
            check("the overlay process is running", len(sh("pgrep", "-f", "^qs -p .*preview.qml").split()), 1)
            ev('local f = io.open("/tmp/omagnet-live-val", "w"); f:write(tostring(_G.omagnet.preview("nonsense", 2))); f:close()'); time.sleep(0.4)
            check("an unreadable layout is refused", open("/tmp/omagnet-live-val").read(), "nil")
            time.sleep(2.3)
            check("the preview cleans itself up", (read("omagnet-zones"), len(sh("pgrep", "-f", "^qs -p .*preview.qml").split())), ("", 0))
            # a layout for this monitor's workspace wins over its own layout
            ws = next(m for m in jq("monitors") if m["focused"])["activeWorkspace"]["id"]
            ev('_G.omagnet.layout_override = {}')  # a layout picked by key would win over the workspace entry (that order is tested in test_glue.lua)
            ev(f'_G.omagnet.cfg.workspace_layouts = {{ ["{ws}"] = "columns:2" }}'); time.sleep(0.2)
            r = cell(a, 1, 0, 2, 1); ZONES[0] = 2
            zone_drag(r[0] + r[2] // 2, r[1] + r[3] // 2, "workspace layout columns:2, right column", r)
            ev('_G.omagnet.cfg.workspace_layouts = {}')
        check("no outline process is left", len(sh("pgrep", "-f", "^qs -p .*preview.qml").split()), 0)
        check("the zones file is empty", read("omagnet-zones"), "")
    finally:
        ev('local m = _G.omagnet; m.cfg.margin, m.cfg.zone_span = m.saved[1], m.saved[2]; m.layout_override = {}')
        ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.close({ window = w })) end end'); time.sleep(0.6)
        if prev:
            ev(f"for _, w in ipairs(hl.get_windows()) do if w.address == '{prev}' then hl.dispatch(hl.dsp.focus({{ window = w }})) end end".replace("{{", "{").replace("}}", "}"))
        ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {cur[0]}, y = {cur[1]} }}))")
    print("\nALL OK" if not failed else "\nFAILED: " + "; ".join(failed))
    return 0 if not failed else 1


sys.exit(main())
