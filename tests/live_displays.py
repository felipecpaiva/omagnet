"""Live check of omagnet across two monitors, using a temporary virtual (headless) monitor.
Commands get the test window passed in, because with a second monitor Hyprland does not focus the test window.
It records your windows first, always removes the virtual monitor, and compares your windows afterwards.
Do not type or move the mouse while it runs (about 40 seconds).
NOTE: Omarchy remembers every monitor it has seen and gives it a block of ten workspaces for good, virtual ones included. This test
cleans that up at the end (livehelp.forget_headless_blocks, which reloads Hyprland); with two or more real monitors prefer
live_real_displays.py, which adds no monitor.
Needs: Hyprland with omagnet loaded, kitty, write access to /dev/uinput.  Usage: python3 tests/live_displays.py
"""
import json, os, subprocess, sys, tempfile, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livehelp import go_home, forget_headless_blocks

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from uinput_kbd import Keyboard

TAG = "omarchy-floating-workspace"
failed = []


def sh(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout


def ev(lua):
    subprocess.run(["hyprctl", "eval", lua], capture_output=True)


def jq(*a):
    return json.loads(sh("hyprctl", *a, "-j") or "null")


def monitors():
    return {m["name"]: m for m in jq("monitors")}


def win(cls="omagnet-test"):
    return next((c for c in jq("clients") if c["class"] == cls), None)


def rect_of(c):
    return (c["at"][0], c["at"][1], c["size"][0], c["size"][1])


def check(label, got, want):
    ok = got == want
    print(("  ok   " if ok else "  FAIL ") + f"{label} -> {got}" + ("" if ok else f" (wanted {want})"))
    if not ok:
        failed.append(label)


def rnd(v):
    return int(v * 2 + 1) // 2 if v >= 0 else -int(-v * 2 + 1) // 2


def usable(m):
    w, h = (m["height"], m["width"]) if m["transform"] % 2 else (m["width"], m["height"])
    w, h = int(w / m["scale"]), int(h / m["scale"])
    r = m["reserved"]
    return (m["x"] + r[0], m["y"] + r[1], w - r[0] - r[2], h - r[1] - r[3])


def transfer(r, fa, ta):
    fx, fy, fw, fh = (r[0] - fa[0]) / fa[2], (r[1] - fa[1]) / fa[3], r[2] / fa[2], r[3] / fa[3]
    w, h = max(1, min(ta[2], rnd(fw * ta[2]))), max(1, min(ta[3], rnd(fh * ta[3])))
    x = min(ta[0] + ta[2] - w, max(ta[0], rnd(ta[0] + fx * ta[2])))
    y = min(ta[1] + ta[3] - h, max(ta[1], rnd(ta[1] + fy * ta[3])))
    return (x, y, w, h)


def overlays():
    """Names of Omarchy's overlay surfaces on screen (the theme picker is one)."""
    return sorted({i["namespace"] for m in jq("layers").values() for l in m["levels"].values() for i in l})


def dismiss_picker():
    """Adding a monitor makes Omarchy open its theme picker, and it stays open after the monitor is removed. It holds
    keyboard focus, so close it with Escape (a cancel) and say so."""
    if "omarchy-image-selector" in overlays():
        with Keyboard() as kb:
            kb.tap("escape")
        time.sleep(0.8)
        return True
    return False


def snapshot():
    return {
        "windows": {c["address"]: (c["workspace"]["id"], rect_of(c), c["floating"]) for c in jq("clients")},
        "monitors": sorted(monitors()),
        "overlays": overlays(),
        "active": {n: m["activeWorkspace"]["id"] for n, m in monitors().items()},
        "focus": (jq("activewindow") or {}).get("address", ""),
        "cursor": sh("hyprctl", "cursorpos").strip().replace(",", "").split(),
    }


def focus(address):
    ev(f"for _, w in ipairs(hl.get_windows()) do if w.address == '{address}' then hl.dispatch(hl.dsp.focus({{ window = w }})) end end")


def lua_value(expr):
    """hyprctl eval prints only 'ok', so the Lua writes the value to a file and we read it back."""
    path = os.path.join(tempfile.gettempdir(), "omagnet-val.txt")
    ev(f'local f = io.open("{path}", "w"); f:write(tostring({expr})); f:close()')
    time.sleep(0.3)
    return open(path).read()


def cmd(name):
    """Run an omagnet command on the test window, passing the window itself. With a second monitor present Hyprland
    would not give the test window focus, so the keyboard path is not used here (live.py covers the keys)."""
    ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then _G.omagnet.command("%s", w) end end' % name)


def retag():
    ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.tag({ tag = "+%s", window = w })) end end' % TAG)
    time.sleep(0.4)


def main():
    _real_cursor = subprocess.run(["hyprctl", "cursorpos"], capture_output=True, text=True).stdout
    go_home()
    print("This test adds a temporary virtual monitor and runs for about 90 seconds.\n"
          "Do not type or move the mouse. Starting in 4 seconds...")
    time.sleep(4)
    before = snapshot()
    real = next(iter(before["monitors"]))
    created = None
    try:
        ev("_G.omagnet.watch_super = false")  # scripted drags hold no SUPER key
        sh("hyprctl", "output", "create", "headless"); time.sleep(2.0)
        if dismiss_picker():
            print("  note: Omarchy opened its theme picker for the new monitor; closed it with Escape")
        new = [n for n in monitors() if n not in before["monitors"]]
        if not new:
            print("no virtual monitor appeared; cannot test"); return 2
        created = new[0]
        time.sleep(1.0)
        mons = monitors()
        print("monitors:", {n: (m["x"], m["y"], m["width"], m["height"], m["scale"]) for n, m in mons.items()})
        wsid = mons[created]["activeWorkspace"]["id"]
        ev(f'o.workspace_mode({{ workspace = "{wsid}", mode = "floating" }})'); time.sleep(1.0)  # in memory only; a reload forgets it

        ev('hl.exec_cmd("[float; size 500 300; move 400 300; workspace %d silent] kitty --class omagnet-test")' % before["active"][real]); time.sleep(2.5)
        w = win()
        if not w:
            print("could not open the test window"); return 2
        ev('_G.omagnet.cfg.margin = 0')
        # omagnet only sends a window to a monitor whose workspace is floating, read from Omarchy's saved modes. Point it
        # at a temporary folder that says both workspaces are floating (the real files are not touched).
        state_holder = tempfile.TemporaryDirectory(prefix="omagnet-state-")
        def set_mode(ws, mode):
            with open(os.path.join(state_holder.name, f"{ws}.lua"), "w") as f:
                f.write(f'o.workspace_mode({{ workspace = "{ws}", mode = "{mode}" }})\n')
        real_ws = mons[real]["activeWorkspace"]["id"]
        set_mode(real_ws, "floating"); set_mode(wsid, "dwindle")
        ev(f'_G.omagnet.state_dir = "{state_holder.name}/"')
        retag()
        start = rect_of(win())
        check("test window starts on the real monitor", win()["monitor"], mons[real]["id"])
        print("omagnet's own view of the two monitors matches Hyprland's:")
        mv = mons[created]
        check("monitor under a point on the virtual monitor", lua_value(f"hl.get_monitor_at({{ x = {mv['x'] + 10}, y = {mv['y'] + 10} }}).name"), created)
        ux, uy, uw, uh = usable(mv)
        check("usable area of the virtual monitor", lua_value(
            f"(function() local a = _G.omagnet.geometry.usable(hl.get_monitor_at({{ x = {mv['x'] + 10}, y = {mv['y'] + 10} }})); return math.floor(a.x) .. ',' .. math.floor(a.y) .. ',' .. math.floor(a.w) .. ',' .. math.floor(a.h) end)()"),
            f"{ux},{uy},{uw},{uh}")

        print("a monitor whose workspace is not floating is refused (nothing is pushed into a tiled layout):")
        cmd("next_display"); time.sleep(1.2)
        check("window stayed on the real monitor", win()["monitor"], mons[real]["id"])
        check("and did not move", rect_of(win()), start)
        set_mode(wsid, "floating")

        print("next display:")
        cmd("next_display"); time.sleep(1.5)
        c = win(); want = transfer(start, usable(mons[real]), usable(mons[created]))
        check("window is on the virtual monitor", c["monitor"], mons[created]["id"])
        check("same relative place and size", rect_of(c), want)

        print("previous display:")
        retag(); cmd("prev_display"); time.sleep(1.5)
        c = win()
        check("window is back on the real monitor", c["monitor"], mons[real]["id"])
        check("and back where it started (within a pixel of rounding)", all(abs(a - b) <= 1 for a, b in zip(rect_of(c), start)), True)

        print("a snap command on the virtual monitor uses that monitor's own area:")
        retag(); cmd("next_display"); time.sleep(1.5)
        retag(); cmd("right"); time.sleep(1.2)
        check("right half of the virtual monitor", rect_of(win()), (ux + uw - uw // 2, uy, uw // 2, uh))
        retag(); cmd("third_center"); time.sleep(1.2)
        t1, t2 = rnd(uw / 3), rnd(2 * uw / 3)
        check("middle third of the virtual monitor", rect_of(win()), (ux + t1, uy, t2 - t1, uh))
        retag(); cmd("maximize"); time.sleep(1.2)
        check("maximize fills the virtual monitor", rect_of(win()), (ux, uy, uw, uh))

        # The same checks at other scales and rotated. Your monitor rule gives every output the same scale; a rule set
        # afterwards for the virtual monitor wins, so it can be given a fractional scale or turned on its side.
        import math
        FR = {
            "left": (0, 0, 1 / 2, 1), "right": (1 / 2, 0, 1 / 2, 1), "top": (0, 0, 1, 1 / 2), "bottom": (0, 1 / 2, 1, 1 / 2),
            "top_left": (0, 0, 1 / 2, 1 / 2), "bottom_right": (1 / 2, 1 / 2, 1 / 2, 1 / 2),
            "third_left": (0, 0, 1 / 3, 1), "third_center": (1 / 3, 0, 1 / 3, 1), "third_right": (2 / 3, 0, 1 / 3, 1),
            "two_thirds_right": (1 / 3, 0, 2 / 3, 1), "maximize": (0, 0, 1, 1),
            "third_top": (0, 0, 1, 1 / 3), "third_middle": (0, 1 / 3, 1, 1 / 3), "third_bottom": (0, 2 / 3, 1, 1 / 3),
            "two_thirds_top": (0, 0, 1, 2 / 3), "two_thirds_bottom": (0, 1 / 3, 1, 2 / 3),
        }
        flo = lambda v: math.floor(v + 0.5)

        def expected(area, name):
            x, y, w, h = area
            fx, fy, fw, fh = FR[name]
            l, t, r, b = flo(x + fx * w), flo(y + fy * h), flo(x + (fx + fw) * w), flo(y + (fy + fh) * h)
            return (l, t, r - l, b - t)

        for label, scale, transform in [("scale 1.5", 1.5, 0), ("scale 1.25", 1.25, 0), ("rotated 90 degrees, scale 1", 1, 1)]:
            print(f"the same on the virtual monitor at {label}:")
            ev(f'hl.monitor({{ output = "{created}", mode = "1920x1080@60", position = "auto", scale = {scale}, transform = {transform} }})')
            time.sleep(2.0)
            if dismiss_picker():
                print("  note: closed the theme picker again")
            mv = monitors()[created]
            if mv["scale"] != scale or mv["transform"] != transform:
                print(f"  note: the monitor did not take {label} ({mv['scale']}, {mv['transform']}); skipped")
                continue
            area = usable(mv)
            print(f"  usable area {area}")
            check("omagnet's usable area matches", lua_value(
                f"(function() local a = _G.omagnet.geometry.usable(hl.get_monitor_at({{ x = {mv['x'] + 10}, y = {mv['y'] + 10} }})); return math.floor(a.x) .. ',' .. math.floor(a.y) .. ',' .. math.floor(a.w) .. ',' .. math.floor(a.h) end)()"),
                ",".join(str(v) for v in area))
            names = ["left", "right", "top", "bottom", "top_left", "bottom_right", "third_left", "third_center", "third_right", "two_thirds_right", "maximize"]
            if transform:
                names += ["third_top", "third_middle", "third_bottom", "two_thirds_top", "two_thirds_bottom"]
            for name in names:
                retag(); cmd(name); time.sleep(0.9)
                check(f"{name}", rect_of(win()), expected(area, name))

            if transform:
                print("  vertical screen, drag zones (scripted pointer):")
                retag(); focus(win()["address"]); time.sleep(0.6)
                cls = (jq("activewindow") or {}).get("class")
                if cls != "omagnet-test":
                    print(f"  note: focus did not reach the test window (focused: {cls!r}); drag zones skipped")
                else:
                    statefile = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "omagnet-preview")
                    ux, uy, uw, uh = area
                    def at(x, y): ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {x}, y = {y} }}))"); time.sleep(0.35)
                    def outline(label_, name):
                        e = expected(area, name)
                        check(label_, open(statefile).read().strip(), f"{created} {e[0] - mv['x']} {e[1] - mv['y']} {e[2]} {e[3]}")
                    ev("_G.omagnet.on_press()"); time.sleep(0.5)
                    inside = lambda: at(ux + uw // 2, uy + uh // 2)  # leave the edge strips, so the next case is not a slide
                    at(ux, uy + int(uh * 0.2)); outline("left side, top row gives the top third", "third_top")
                    inside(); at(ux, uy + int(uh * 0.5)); outline("left side, middle row gives the middle third", "third_middle")
                    inside(); at(ux + uw - 1, uy + int(uh * 0.8)); outline("right side, bottom row gives the bottom third", "third_bottom")
                    inside(); at(ux, uy + int(uh * 0.2)); at(ux, uy + int(uh * 0.5)); outline("slide from the top row to the middle gives two thirds", "two_thirds_top")
                    inside()
                    at(ux + int(uw * 0.25), uy + uh - 1); outline("bottom edge, left side gives the left half", "left")
                    at(ux + int(uw * 0.75), uy + uh - 1); outline("bottom edge, right side gives the right half", "right")
                    at(ux + uw // 2, uy); outline("top edge maximizes", "maximize")
                    at(ux + 4, uy + 4); outline("corner gives a quarter", "top_left")
                    at(ux, uy + int(uh * 0.8))
                    ev("_G.omagnet.on_release()"); time.sleep(0.9)
                    check("release on the bottom row snaps the bottom third", rect_of(win()), expected(area, "third_bottom"))
    finally:
        ev("_G.omagnet.watch_super = nil")
        ev("_G.omagnet.state_dir = nil")
        ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.close({ window = w })) end end')
        time.sleep(0.6)
        if created:
            sh("hyprctl", "output", "remove", created); time.sleep(2.0)
        if dismiss_picker():
            print("  note: closed the theme picker that was still open after removing the monitor")
        if before["focus"]:
            focus(before["focus"])
        ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {before['cursor'][0]}, y = {before['cursor'][1]} }}))")
        ev("_G.omagnet.cfg.margin = 8")
        time.sleep(0.6)
        after = snapshot()
        check("the virtual monitor is gone", after["monitors"], before["monitors"])
        check("no extra overlay left on your screen", overlays(), before["overlays"])
        # Windows on a special (hidden) workspace, id below 0, are laid out again by Hyprland whenever the monitor
        # list changes; omagnet never touches them, so they are reported but not counted.
        normal = lambda snap: {a: v for a, v in snap["windows"].items() if v[0] >= 0}
        check("your windows are where they were", normal(after), normal(before))
        for a, v in after["windows"].items():
            if v[0] < 0 and before["windows"].get(a) != v:
                print(f"  note a hidden special-workspace window was laid out again by Hyprland: {before['windows'].get(a)} -> {v}")
        check("each monitor shows the workspace it showed", after["active"], before["active"])
    n = forget_headless_blocks()
    if n: print(f"  note: removed {n} virtual monitor entry from Omarchy's monitor-workspaces file (the numbering of your real monitors is untouched)")
    print("\nALL OK" if not failed else "\nFAILED: " + "; ".join(failed))
    return 0 if not failed else 1


sys.exit(main())
