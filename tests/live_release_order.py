"""Live check that a drag always ends, whatever order the keys and the mouse button are let go in.
When SUPER (or SHIFT) goes up before the mouse button, no release handler runs, so the drag used to stay on: the grid stayed up
and a window restored from a snap kept following the pointer until a click. This drives the virtual keyboard and mouse through
every order, with a free window and with a snapped one, and checks: omagnet's drag state is clean, the overlay is gone, and the
window does not follow the pointer afterwards. About 2 minutes; do not touch the mouse or keyboard.
Needs: Hyprland with omagnet loaded (hyprctl reload), kitty, /dev/uinput.  Usage: python3 tests/live_release_order.py"""
import json, os, subprocess, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livehelp import go_home
from uinput_kbd import Keyboard, Mouse

TAG = "omarchy-floating-workspace"
failed = []


def sh(*a): return subprocess.run(a, capture_output=True, text=True).stdout
def ev(l): subprocess.run(["hyprctl", "eval", l], capture_output=True)
def jq(*a): return json.loads(sh("hyprctl", *a, "-j") or "null")
def win(): return next((c for c in jq("clients") if c["class"] == "omagnet-test"), None)
def geom(): c = win(); return (c["at"][0], c["at"][1], c["size"][0], c["size"][1])
def procs(): return len(sh("pgrep", "-f", "^qs -p .*preview.qml").split())


def state():
    ev('local m = _G.omagnet; local f = io.open("/tmp/omagnet-val.txt","w"); f:write(string.format("%s %s %s %s", tostring(m.pressed), tostring(m.polling), tostring(m.following ~= nil), tostring(m.zone_mode))); f:close()')
    time.sleep(0.3)
    return open("/tmp/omagnet-val.txt").read().split()


def check(label, got, want):
    ok = got == want
    print(("  ok   " if ok else "  FAIL ") + f"{label} -> {got}" + ("" if ok else f" (wanted {want})"), flush=True)
    if not ok:
        failed.append(label)


def scenario(name, order, mid_shift, snapped):
    ev('hl.exec_cmd("[float; size 500 300; move 400 300] kitty --class omagnet-test")'); time.sleep(2.5)
    ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.tag({ tag = "+%s", window = w })); hl.dispatch(hl.dsp.focus({ window = w })) end end' % TAG); time.sleep(0.6)
    if snapped:
        ev('_G.omagnet.command("left")'); time.sleep(1.0)
    g = geom(); cx, cy = g[0] + 100, g[1] + 100
    ev("hl.dispatch(hl.dsp.cursor.move({ x = %d, y = %d }))" % (cx, cy)); time.sleep(0.3)
    with Keyboard() as kb, Mouse() as m:
        if mid_shift:
            kb.down("super"); m.press(); time.sleep(0.2); m.move(30, 0, steps=5); time.sleep(0.3); kb.down("shift"); time.sleep(0.5)
        else:
            kb.down("super"); kb.down("shift"); m.press(); time.sleep(0.2); m.move(30, 0, steps=5); time.sleep(0.5)
        for what in order:
            {"mouse": m.release, "shift": lambda: kb.up("shift"), "super": lambda: kb.up("super")}[what](); time.sleep(0.25)
        time.sleep(1.2)
        s = state()
        check(f"{name}: drag state is clean (pressed, polling, following, zone mode)", s, ["false"] * 4)
        check(f"{name}: overlay is gone", procs(), 0)
        before = geom()
        ev("hl.dispatch(hl.dsp.cursor.move({ x = %d, y = %d }))" % (cx + 150, cy + 120)); time.sleep(0.6)
        check(f"{name}: the window does not follow the pointer afterwards", geom(), before)
    ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.close({ window = w })) end end'); time.sleep(0.8)


def main():
    _real_cursor = subprocess.run(["hyprctl", "cursorpos"], capture_output=True, text=True).stdout
    go_home()
    prev = (jq("activewindow") or {}).get("address", "")
    cur = _real_cursor.strip().replace(",", "").split()
    orders = [["mouse", "shift", "super"], ["shift", "mouse", "super"], ["shift", "super", "mouse"], ["super", "shift", "mouse"], ["super", "mouse", "shift"]]
    try:
        for mid in (False, True):
            for snapped in (False, True):
                if mid and snapped:
                    continue
                for order in orders:
                    scenario(("SNAPPED " if snapped else "") + ("SUPER drag then SHIFT; " if mid else "SUPER+SHIFT drag; ") + " then ".join(order) + " up", order, mid, snapped)
    finally:
        ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.close({ window = w })) end end'); time.sleep(0.5)
        if prev:
            ev(f"for _, w in ipairs(hl.get_windows()) do if w.address == '{prev}' then hl.dispatch(hl.dsp.focus({{ window = w }})) end end".replace("{{", "{").replace("}}", "}"))
        ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {cur[0]}, y = {cur[1]} }}))")
    print("\nALL OK" if not failed else "\nFAILED: " + "; ".join(failed))
    return 0 if not failed else 1


sys.exit(main())
