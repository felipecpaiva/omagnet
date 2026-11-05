"""Live checks of omagnet on a throwaway window: every keyboard shortcut with real key events, plus the
drag path with a scripted cursor.
Needs: a running Hyprland with omagnet loaded, kitty, write access to /dev/uinput.
The test window takes focus for a few seconds; focus goes back at the end.
Usage:  python3 tests/live.py
"""
import json, os, subprocess, sys, tempfile, time
from fractions import Fraction as F

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from uinput_kbd import Keyboard

TAG = "omarchy-floating-workspace"
LOG = os.path.join(tempfile.gettempdir(), "omagnet-keys.log")
failed = []


def sh(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout


def ev(lua):
    subprocess.run(["hyprctl", "eval", lua], capture_output=True)


def clients():
    return json.loads(sh("hyprctl", "clients", "-j"))


def window():
    return next((c for c in clients() if c["class"] == "omagnet-test"), None)


def geom():
    w = window()
    return None if w is None else (w["at"][0], w["at"][1], w["size"][0], w["size"][1])


def area():
    m = next(m for m in json.loads(sh("hyprctl", "monitors", "-j")) if m["focused"])
    w, h = (m["height"], m["width"]) if m["transform"] % 2 else (m["width"], m["height"])
    w, h = int(w / m["scale"]), int(h / m["scale"])
    r = m["reserved"]
    return m["x"] + r[0], m["y"] + r[1], w - r[0] - r[2], h - r[1] - r[3]


def rnd(v):
    return int((v * 2 + 1) // 2)  # half up, like geometry.lua


def expect(fr):  # fr = (fx, fy, fw, fh) as Fractions of the area
    ax, ay, aw, ah = area()
    l, t = rnd(ax + fr[0] * aw), rnd(ay + fr[1] * ah)
    r, b = rnd(ax + (fr[0] + fr[2]) * aw), rnd(ay + (fr[1] + fr[3]) * ah)
    return (l, t, r - l, b - t)


def check(label, got, want):
    ok = got == want
    print(("  ok   " if ok else "  FAIL ") + f"{label} -> {got}" + ("" if ok else f" (wanted {want})"))
    if not ok:
        failed.append(label)


def tag(spec):
    ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then '
       f'hl.dispatch(hl.dsp.window.tag({{ tag = "{spec}", window = w }})) end end')


def focus(address):
    ev(f"for _, w in ipairs(hl.get_windows()) do if w.address == '{address}' then "
       "hl.dispatch(hl.dsp.focus({ window = w })) end end")


def main():
    if os.path.exists(LOG):
        os.remove(LOG)
    prev = json.loads(sh("hyprctl", "activewindow", "-j") or "{}").get("address", "")
    ev('hl.exec_cmd("[float; size 500 300; move 400 300] kitty --class omagnet-test -e sh -c \\"cat -v >> %s\\"")' % LOG)
    time.sleep(2.5)
    w = window()
    if not w:
        print("could not open the test window"); return 2
    tag("+" + TAG)
    focus(w["address"])
    time.sleep(0.8)
    start = geom()
    if start != (400, 300, 500, 300):
        print("setup failed, window is at", start); ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.close({ window = w })) end end'); return 2
    print("area:", area())
    ev("_G.omagnet.saved_cfg = { margin = _G.omagnet.cfg.margin, edge_tight = _G.omagnet.cfg.edge_tight }")
    ev("_G.omagnet.cfg.margin = 0; _G.omagnet.cfg.edge_tight = true")  # exact-rectangle checks first
    try:
        with Keyboard() as kb:
            def press(combo, wait=0.5):
                kb.tap(combo); time.sleep(wait)

            print("positions, window tagged as on a floating workspace:")
            half, third = F(1, 2), F(1, 3)
            cases = [
                ("left", "left", (0, 0, half, 1)), ("right", "right", (half, 0, half, 1)),
                ("top", "up", (0, 0, 1, half)), ("bottom", "down", (0, half, 1, half)),
                ("top_left", "u", (0, 0, half, half)), ("top_right", "i", (half, 0, half, half)),
                ("bottom_left", "j", (0, half, half, half)), ("bottom_right", "k", (half, half, half, half)),
                ("third_left", "d", (0, 0, third, 1)), ("third_center", "f", (third, 0, third, 1)),
                ("third_right", "g", (2 * third, 0, third, 1)),
                ("two_thirds_left", "e", (0, 0, 2 * third, 1)), ("two_thirds_right", "t", (third, 0, 2 * third, 1)),
                ("maximize", "return", (0, 0, 1, 1)),
            ]
            for name, key, fr in cases:
                press("ctrl+alt+" + key)
                check(name, geom(), expect(tuple(F(x) for x in fr)))

            print("spacing: margin 8, tight to the screen border (Magnet defaults):")
            ev("_G.omagnet.cfg.margin = 8")
            ax, ay, aw, ah = area()
            hw = rnd(F(aw, 2))
            press("ctrl+alt+left");  check("left, margin 8", geom(), (ax, ay, hw - 4, ah))
            press("ctrl+alt+right"); check("right, margin 8", geom(), (ax + hw + 4, ay, aw - hw - 4, ah))
            l1, r1 = rnd(F(aw, 3)), rnd(F(2 * aw, 3))
            press("ctrl+alt+f");     check("middle third, margin 8", geom(), (ax + l1 + 4, ay, (r1 - 4) - (l1 + 4), ah))
            press("ctrl+alt+return"); check("maximize stays tight", geom(), (ax, ay, aw, ah))
            ev("_G.omagnet.cfg.edge_tight = false")
            press("ctrl+alt+left");  check("left, margin 8 on the screen border too", geom(), (ax + 8, ay + 8, hw - 4 - 8, ah - 16))
            ev("_G.omagnet.cfg.edge_tight = true; _G.omagnet.cfg.margin = 0")
            ev("_G.omagnet.cfg.reserve_bottom = 60")
            press("ctrl+alt+down");  check("bottom half keeps 60 px free (dock)", geom(), (ax, ay + rnd(F(ah - 60, 2)), aw, (ah - 60) - rnd(F(ah - 60, 2))))
            ev("_G.omagnet.cfg.reserve_bottom = 0")
            press("ctrl+alt+backspace")

            print("restore goes back to the first rectangle, after many snaps:")
            press("ctrl+alt+backspace"); check("restore", geom(), start)
            open(LOG, "w").close()
            press("ctrl+alt+backspace"); check("second restore changes nothing", geom(), start)
            kb.tap("return"); time.sleep(0.4)
            leaked = open(LOG).read().strip() if os.path.exists(LOG) else ""
            check("a key with nothing to do is still consumed on a floating workspace", leaked, "")

            print("center keeps the size:")
            ax, ay, aw, ah = area()
            press("ctrl+alt+c"); check("center", geom(), (rnd(F(ax) + F(aw - 500, 2)), rnd(F(ay) + F(ah - 300, 2)), 500, 300))
            press("ctrl+alt+backspace")

            print("a maximized window can still be snapped (Omarchy drops its tag, so the saved workspace mode decides):")
            state = tempfile.mkdtemp(prefix="omagnet-state-")
            wsid = window()["workspace"]["id"]
            with open(os.path.join(state, f"{wsid}.lua"), "w") as f:
                f.write(f'o.workspace_mode({{ workspace = "{wsid}", mode = "floating" }})\n')
            ev(f'_G.omagnet.state_dir = "{state}/"')
            ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then '
               'hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "set", window = w })) end end')
            time.sleep(0.8)
            press("ctrl+alt+left", 0.9); check("left from maximized", geom(), expect((0, 0, half, 1)))
            press("ctrl+alt+backspace")
            ev("_G.omagnet.state_dir = nil")

            print("a window NOT on a floating workspace is left alone, and the key reaches the app:")
            tag("-" + TAG); time.sleep(0.4)
            before = geom()
            open(LOG, "w").close()  # forget the keys of the earlier steps
            press("ctrl+alt+left")
            check("untagged window did not move", geom(), before)
            kb.tap("return"); time.sleep(0.5)  # cat prints a line only after a newline
            seen = open(LOG).read() if os.path.exists(LOG) else ""
            ok = "^[" in seen  # Ctrl+Alt+Left reaches cat as an escape sequence
            print(("  ok   " if ok else "  FAIL ") + f"key passed through to the app: {seen.strip()[:30]!r}")
            if not ok:
                failed.append("pass-through")
        print("drag to an edge (scripted cursor, the outline state file, then release):")
        cursor = sh("hyprctl", "cursorpos").strip().replace(",", " ").split()
        statefile = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "omagnet-preview")
        m = next(m for m in json.loads(sh("hyprctl", "monitors", "-j")) if m["focused"])
        mon, mx, my = m["name"], m["x"], m["y"]
        ax, ay, aw, ah = area()
        tag("+" + TAG); focus(w["address"]); time.sleep(0.6)  # the keyboard part left it untagged
        ev("_G.omagnet.on_press()"); time.sleep(0.4)
        ev("hl.dispatch(hl.dsp.cursor.move({ x = 0, y = 300 }))"); time.sleep(1.2)
        shown = open(statefile).read().strip()
        check("outline shows the left half while dragging", shown, f"{mon} {ax - mx} {ay - my} {aw // 2} {ah}")
        ev("hl.dispatch(hl.dsp.cursor.move({ x = 640, y = 400 }))"); time.sleep(0.5)
        check("outline hides away from the edge", open(statefile).read().strip(), "")
        ev("hl.dispatch(hl.dsp.cursor.move({ x = 1279, y = 300 }))"); time.sleep(0.5)
        ev("_G.omagnet.on_release()"); time.sleep(0.7)
        check("release snaps to the right half", geom(), expect((half, 0, half, 1)))
        for _ in range(30):  # the overlay needs a moment to exit
            procs = sh("pgrep", "-f", "^qs -p .*preview.qml").split()
            if not procs:
                break
            time.sleep(0.1)
        check("outline process is gone after release", len(procs), 0)
        ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {cursor[0]}, y = {cursor[1]} }}))")
    finally:
        ev("_G.omagnet.cfg.margin = _G.omagnet.saved_cfg.margin; _G.omagnet.cfg.edge_tight = _G.omagnet.saved_cfg.edge_tight; _G.omagnet.cfg.reserve_bottom = 0")
        ev("_G.omagnet.state_dir = nil")
        ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.close({ window = w })) end end')
        time.sleep(0.5)
        if prev:
            focus(prev)
    print("\nALL OK" if not failed else "\nFAILED: " + ", ".join(failed))
    return 0 if not failed else 1


sys.exit(main())
