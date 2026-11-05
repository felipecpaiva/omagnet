"""Live checks of omagnet on a throwaway window: every keyboard shortcut with real key events, plus the
drag path with a scripted cursor.
Needs: a running Hyprland with omagnet loaded, kitty, write access to /dev/uinput.
The test window takes focus for a few seconds; focus goes back at the end.
Usage:  python3 tests/live.py
"""
import json, os, subprocess, sys, tempfile, time
from fractions import Fraction as F

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from uinput_kbd import Keyboard, Mouse

TAG = "omarchy-floating-workspace"
LOG = os.path.join(tempfile.gettempdir(), "omagnet-keys.log")
failed = []


def sh(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout


def ev(lua):
    subprocess.run(["hyprctl", "eval", lua], capture_output=True)


def clients():
    return json.loads(sh("hyprctl", "clients", "-j"))


def window(cls="omagnet-test"):
    return next((c for c in clients() if c["class"] == cls), None)


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


def require_test_window_focused():
    """Stop before sending any key if the test window does not have focus: the keys would land in a real window."""
    cls = json.loads(sh("hyprctl", "activewindow", "-j") or "{}").get("class")
    if cls != "omagnet-test":
        raise RuntimeError(f"the test window is not focused (focused: {cls!r}); refusing to send keys")


def lua_value(expr):
    """Read a Lua value back from Hyprland: hyprctl eval only prints 'ok', so the Lua writes it to a file."""
    path = os.path.join(tempfile.gettempdir(), "omagnet-val.txt")
    ev(f'local f = io.open("{path}", "w"); f:write(tostring({expr})); f:close()')
    time.sleep(0.3)
    return open(path).read()


def tag(spec, cls="omagnet-test"):
    ev(f'for _, w in ipairs(hl.get_windows()) do if w.class == "{cls}" then '
       f'hl.dispatch(hl.dsp.window.tag({{ tag = "{spec}", window = w }})) end end')


def focus(address):
    ev(f"for _, w in ipairs(hl.get_windows()) do if w.address == '{address}' then "
       "hl.dispatch(hl.dsp.focus({ window = w })) end end")


def main():
    print("This test drives your real keyboard, mouse and focus for about 2 minutes.\n"
          "Do not type or move the mouse until it prints ALL OK or FAILED. Starting in 4 seconds...")
    time.sleep(4)
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
        require_test_window_focused()
        with Keyboard() as kb:
            def press(combo, wait=0.5):
                require_test_window_focused()
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

            print("a window partly off the screen still ends at the exact size (a resize from an odd spot can be 1 px off):")
            ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then '
               'hl.dispatch(hl.dsp.window.move({ x = -250, y = -150, relative = false, window = w })) end end'); time.sleep(0.4)
            press("ctrl+alt+u", 1.0); check("top left from a window half off the screen", geom(), expect((0, 0, half, half)))
            press("ctrl+alt+d", 1.0); check("left third from there", geom(), expect((0, 0, third, 1)))
            press("ctrl+alt+backspace", 1.0)
            ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then '
               'hl.dispatch(hl.dsp.window.resize({ x = 500, y = 300, relative = false, window = w })); '
               'hl.dispatch(hl.dsp.window.move({ x = 400, y = 300, relative = false, window = w })) end end'); time.sleep(0.4)
            ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then '
               'hl.dispatch(hl.dsp.window.resize({ x = 500, y = 300, relative = false, window = w })); '
               'hl.dispatch(hl.dsp.window.move({ x = 400, y = 300, relative = false, window = w })) end end'); time.sleep(0.4)

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
            press("return", 0.4)
            leaked = open(LOG).read().strip() if os.path.exists(LOG) else ""
            check("a key with nothing to do is still consumed on a floating workspace", leaked, "")

            print("center keeps the size:")
            ax, ay, aw, ah = area()
            press("ctrl+alt+c"); check("center", geom(), (rnd(F(ax) + F(aw - 500, 2)), rnd(F(ay) + F(ah - 300, 2)), 500, 300))
            press("ctrl+alt+backspace")

            print("a maximized window can still be snapped (Omarchy drops its tag, so the saved workspace mode decides):")
            state_holder = tempfile.TemporaryDirectory(prefix="omagnet-state-")
            state = state_holder.name
            wsid = window()["workspace"]["id"]
            with open(os.path.join(state, f"{wsid}.lua"), "w") as f:
                f.write(f'o.workspace_mode({{ workspace = "{wsid}", mode = "floating" }})\n')
            ev(f'_G.omagnet.state_dir = "{state}/"')
            maximize = ('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then '
                        'hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "%s", window = w })) end end')
            ev(maximize % "set"); time.sleep(0.8)
            press("ctrl+alt+left", 1.0); check("left from maximized", geom(), expect((0, 0, half, 1)))
            # The test window is on a tiled workspace, so nothing puts Omarchy's tag back after maximize.
            # On a real floating workspace Omarchy does; here the test does it.
            tag("+" + TAG)
            press("ctrl+alt+backspace"); check("restore after that", geom(), start)

            print("Restore on a maximized window changes nothing and keeps the saved size; Center works after un-maximizing:")
            press("ctrl+alt+left", 0.6)  # an ordinary snap, saves the first rectangle
            ev(maximize % "set"); time.sleep(0.8)
            maxed = geom()
            survived = any(t.startswith("omagnet-orig=") for t in window()["tags"])
            check("the saved size survives Omarchy's maximize (tag still there)", survived, True)
            press("ctrl+alt+backspace"); check("restore on a maximized window changes nothing", geom(), maxed)
            ev(maximize % "unset"); time.sleep(0.6)
            tag("+" + TAG)  # what Omarchy does on a real floating workspace
            press("ctrl+alt+backspace"); check("restore after un-maximizing still works", geom(), start)
            ev(maximize % "set"); time.sleep(0.8)
            press("ctrl+alt+c", 1.0)
            ax, ay, aw, ah = area()
            check("center from maximized: un-maximized size, centred", geom(), (rnd(F(ax) + F(aw - 500, 2)), rnd(F(ay) + F(ah - 300, 2)), 500, 300))
            tag("+" + TAG)
            press("ctrl+alt+backspace"); check("restore after center", geom(), start)
            ev("_G.omagnet.state_dir = nil")
            state_holder.cleanup()

            print("an app on the ignore list is left alone and the key reaches it:")
            ev('_G.omagnet.cfg.ignore = "something-else, Omagnet-Test"')
            before_ign = geom(); open(LOG, "w").close()
            press("ctrl+alt+left")
            check("ignored window did not move", geom(), before_ign)
            press("return", 0.4)
            seen_ign = open(LOG).read() if os.path.exists(LOG) else ""
            check("the key reached the ignored app", "^[" in seen_ign, True)
            ev('_G.omagnet.cfg.ignore = ""')
            ev('_G.omagnet.geometry.positions.cmd_live = { 0.1, 0, 0.8, 1 }; _G.omagnet.command("cmd_live")'); time.sleep(0.8)
            check("a custom position (x 0.1, w 0.8) snaps to its rectangle", geom(), expect((F(1, 10), 0, F(4, 5), 1)))
            ev('_G.omagnet.geometry.positions.cmd_live = nil; _G.omagnet.command("restore")'); time.sleep(0.8)
            before_ign = geom()
            ev('_G.omagnet.command("cmd_missing")'); time.sleep(0.2)
            check("an unknown command name does nothing", geom(), before_ign)

            print("a window NOT on a floating workspace is left alone, and the key reaches the app:")
            tag("-" + TAG); time.sleep(0.4)
            before = geom()
            open(LOG, "w").close()  # forget the keys of the earlier steps
            press("ctrl+alt+left")
            check("untagged window did not move", geom(), before)
            press("return", 0.5)  # cat prints a line only after a newline
            seen = open(LOG).read() if os.path.exists(LOG) else ""
            ok = "^[" in seen  # Ctrl+Alt+Left reaches cat as an escape sequence
            print(("  ok   " if ok else "  FAIL ") + f"key passed through to the app: {seen.strip()[:30]!r}")
            if not ok:
                failed.append("pass-through")
        print("a drag on a window that is not on a floating workspace starts no overlay and snaps nothing:")
        before = geom()
        ev("_G.omagnet.on_press()"); time.sleep(0.3)
        ev("hl.dispatch(hl.dsp.cursor.move({ x = 0, y = 300 }))"); time.sleep(1.2)
        check("no overlay process for a non-floating drag", len(sh("pgrep", "-f", "^qs -p .*preview.qml").split()), 0)
        ev("_G.omagnet.on_release()"); time.sleep(0.5)
        check("non-floating window did not move", geom(), before)

        print("drag to an edge (scripted cursor, the outline state file, then release):")
        cursor = sh("hyprctl", "cursorpos").strip().replace(",", " ").split()
        statefile = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "omagnet-preview")
        m = next(m for m in json.loads(sh("hyprctl", "monitors", "-j")) if m["focused"])
        mon, mx, my = m["name"], m["x"], m["y"]
        ax, ay, aw, ah = area()
        tag("+" + TAG); focus(w["address"]); time.sleep(0.6)  # the keyboard part left it untagged
        before_drag = geom()
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
        # The window is snapped now, so dragging it again would (rightly) give it its old size back.
        # Put it back first, so the zone checks below start from an ordinary window.
        ev('_G.omagnet.command("restore")'); time.sleep(0.8)
        check("back to where the drag began", geom(), before_drag)

        print("drag zones (the outline for each one, cursor moved by script):")
        ev("_G.omagnet.on_press()"); time.sleep(0.4)
        ax, ay, aw, ah = area()
        right, bottom = ax + aw - 1, ay + ah - 1

        def at(x, y, wait=0.3):
            ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {x}, y = {y} }}))"); time.sleep(wait)

        def outline(label, fr):
            want = expect(tuple(F(v) for v in fr))
            check(label, open(statefile).read().strip(), f"{mon} {want[0] - mx} {want[1] - my} {want[2]} {want[3]}")

        third = F(1, 3)
        at(ax + 4, ay + 4);          outline("top left corner gives a quarter", (0, 0, half, half))
        at(right - 4, ay + 4);       outline("top right corner", (half, 0, half, half))
        at(ax + 4, bottom - 4);      outline("bottom left corner", (0, half, half, half))
        at(right - 4, bottom - 4);   outline("bottom right corner", (half, half, half, half))
        at(ax, ay + 300);            outline("left edge gives a half", (0, 0, half, 1))
        at(right, ay + 300);         outline("right edge gives a half", (half, 0, half, 1))
        at(ax + aw // 2, ay);        outline("top edge maximizes", (0, 0, 1, 1))
        at(ax + 200, bottom);        outline("bottom edge, left third", (0, 0, third, 1))
        at(ax + 640, bottom);        outline("slide to the middle gives two thirds on the left", (0, 0, 2 * third, 1))
        at(right - 180, bottom);     outline("a jump to the far right is just the third under the cursor", (2 * third, 0, third, 1))
        at(ax + 640, ay + 400);      check("outline hides when the cursor leaves the strip", open(statefile).read().strip(), "")
        at(right - 180, bottom);     outline("a new slide starts on the right third", (2 * third, 0, third, 1))
        at(ax + 640, bottom);        outline("slide from the right to the middle gives two thirds on the right", (third, 0, 2 * third, 1))
        at(ax + 4, bottom - 4)
        ev("_G.omagnet.on_release()"); time.sleep(0.7)
        check("release in a corner snaps a quarter", geom(), expect((0, half, half, half)))

        ev('_G.omagnet.command("restore")'); time.sleep(0.6)
        check("restore after a drag goes back to where the drag began", geom(), before_drag)

        print("real mouse drag (virtual mouse plus the SUPER key; edges are reached by pushing the pointer into them):")
        focus(w["address"]); time.sleep(0.4)
        with Keyboard() as kb2, Mouse() as mouse:
            def drag(dx, dy, start_xy=None):
                """SUPER + left button down at start_xy (default: the middle of the test window), move, return the outline."""
                require_test_window_focused()
                cx, cy = start_xy or (geom()[0] + geom()[2] // 2, geom()[1] + geom()[3] // 2)
                ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {cx}, y = {cy} }}))"); time.sleep(0.3)
                kb2.down("super"); mouse.press()
                mouse.move(dx, dy); time.sleep(0.6)
                return open(statefile).read().strip()

            def drop():
                mouse.release(); kb2.up("super"); time.sleep(0.8)

            ax, ay, aw, ah = area()
            third = F(1, 3)
            for label, dx, dy, fr in [
                ("left edge", -3000, 0, (0, 0, half, 1)), ("right edge", 3000, 0, (half, 0, half, 1)),
                ("top edge", 0, -3000, (0, 0, 1, 1)), ("bottom edge, middle third", 0, 3000, (third, 0, third, 1)),
                ("top left corner", -3000, -3000, (0, 0, half, half)), ("bottom right corner", 3000, 3000, (half, half, half, half)),
            ]:
                shown = drag(dx, dy)
                want = expect(tuple(F(v) for v in fr))
                check(f"real drag, {label}: outline", shown, f"{mon} {want[0] - mx} {want[1] - my} {want[2]} {want[3]}")
                drop()
                check(f"real drag, {label}: snapped", geom(), want)
                ev('_G.omagnet.command("restore")'); time.sleep(0.6)
                check(f"real drag, {label}: restore goes back to the start", geom(), before_drag)

            print("dragging a snapped window away gives it its old size back; the pointer stays on it:")
            press_keys = lambda combo: (require_test_window_focused(), kb2.tap(combo), time.sleep(0.8))
            press_keys("ctrl+alt+left")
            check("snapped to the left half first", geom(), expect((0, 0, half, 1)))
            ev("hl.dispatch(hl.dsp.cursor.move({ x = 300, y = 400 }))"); time.sleep(0.3)
            kb2.down("super"); mouse.press()
            mouse.move(60, 0); time.sleep(0.5)
            gg = geom(); pc = sh("hyprctl", "cursorpos").strip().replace(",", "").split(); cxp, cyp = float(pc[0]), float(pc[1])
            check("old size is back", (gg[2], gg[3]), (before_drag[2], before_drag[3]))
            check("pointer is inside the window", gg[0] <= cxp <= gg[0] + gg[2] and gg[1] <= cyp <= gg[1] + gg[3], True)
            x_then = gg[0]
            mouse.move(80, 0); time.sleep(0.5)
            gg2 = geom()
            check("window follows the pointer (moved about 80 px)", 60 <= gg2[0] - x_then <= 100, True)
            check("size stays the old size", (gg2[2], gg2[3]), (before_drag[2], before_drag[3]))
            mouse.move(-3000, 0); time.sleep(0.5)
            mouse.release(); kb2.up("super"); time.sleep(0.9)
            check("dropped at the left edge: snapped again", geom(), expect((0, 0, half, 1)))
            ev('_G.omagnet.command("restore")'); time.sleep(0.8)
            check("restore gives the old size back", (geom()[2], geom()[3]), (before_drag[2], before_drag[3]))
            ev(f'for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.resize({{ x = {before_drag[2]}, y = {before_drag[3]}, relative = false, window = w }})); hl.dispatch(hl.dsp.window.move({{ x = {before_drag[0]}, y = {before_drag[1]}, relative = false, window = w }})) end end'); time.sleep(0.5)

            print("a short drag away from every edge moves the window and does not snap (Omarchy's own move still works):")
            shown = drag(120, 60)
            drop()
            g = geom()
            check("short drag: no outline", shown, "")
            check("short drag: size unchanged", (g[2], g[3]), (before_drag[2], before_drag[3]))
            check("short drag: window moved right", g[0] > before_drag[0], True)
            ev(f'for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.move({{ x = {before_drag[0]}, y = {before_drag[1]}, relative = false, window = w }})) end end'); time.sleep(0.4)

            print("two overlapping windows: dragging the one that is NOT focused snaps that one:")
            ev('hl.exec_cmd("[float; size 400 300; move 700 350] kitty --class omagnet-test2")'); time.sleep(2.5)
            tag("+" + TAG, "omagnet-test2")
            focus(w["address"]); time.sleep(0.5)
            second_before = window("omagnet-test2")
            sb = (second_before["at"][0], second_before["at"][1], second_before["size"][0], second_before["size"][1])
            shown = drag(-3000, 0, start_xy=(sb[0] + 300, sb[1] + 150))
            drop()
            first_now, second_now = geom(), window("omagnet-test2")
            second_now = (second_now["at"][0], second_now["at"][1], second_now["size"][0], second_now["size"][1])
            check("the dragged (unfocused) window snapped to the left half", second_now, expect((0, 0, half, 1)))
            check("the focused window did not move", first_now, before_drag)

        print("a snap that fails does not block the next drag:")
        ev("_G.omagnet.real_apply = _G.omagnet.apply; _G.omagnet.apply = function() error('boom') end")
        ev("_G.omagnet.on_press()"); time.sleep(0.3)
        ev("_G.omagnet.on_release()"); time.sleep(0.3)
        check("drag state is clean after a failed snap", lua_value("_G.omagnet.pressed"), "false")
        ev("_G.omagnet.apply = _G.omagnet.real_apply")
        check("no bind errors at load", lua_value("#(_G.omagnet.bind_errors or {})"), "0")
        ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {cursor[0]}, y = {cursor[1]} }}))")
    finally:
        ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test2" then hl.dispatch(hl.dsp.window.close({ window = w })) end end')
        ev("if _G.omagnet.real_apply then _G.omagnet.apply = _G.omagnet.real_apply end")
        ev("_G.omagnet.cfg.margin = _G.omagnet.saved_cfg.margin; _G.omagnet.cfg.edge_tight = _G.omagnet.saved_cfg.edge_tight; _G.omagnet.cfg.reserve_bottom = 0")
        ev("_G.omagnet.state_dir = nil")
        ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.close({ window = w })) end end')
        time.sleep(0.5)
        if prev:
            focus(prev)
    print("\nALL OK" if not failed else "\nFAILED: " + ", ".join(failed))
    return 0 if not failed else 1


sys.exit(main())
