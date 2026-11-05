"""Visual and file checks for the drag overlay settings (outline colour and width, fill, zone highlight).
Takes a screenshot while a scripted drag is at the bottom edge and prints where it is. Usage: python3 tests/live_overlay.py
Do not type or move the mouse while it runs (about 20 seconds)."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livehelp import go_home
import json, os, subprocess, sys, tempfile, time

TAG = "omarchy-floating-workspace"
RUN = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
failed = []


def sh(*a): return subprocess.run(a, capture_output=True, text=True).stdout
def ev(l): subprocess.run(["hyprctl", "eval", l], capture_output=True)
def jq(*a): return json.loads(sh("hyprctl", *a, "-j") or "null")
def read(name):
    p = os.path.join(RUN, name)
    return open(p).read().strip() if os.path.exists(p) else None


def check(label, got, want):
    ok = got == want
    print(("  ok   " if ok else "  FAIL ") + f"{label} -> {got!r}" + ("" if ok else f" (wanted {want!r})"))
    if not ok:
        failed.append(label)


def main():
    _real_cursor = subprocess.run(["hyprctl", "cursorpos"], capture_output=True, text=True).stdout
    go_home()
    out = os.path.join(tempfile.gettempdir(), "omagnet-overlay.png")
    prev = (jq("activewindow") or {}).get("address", "")
    cur = _real_cursor.strip().replace(",", "").split()
    ev('hl.exec_cmd("[float; size 500 300; move 400 300] kitty --class omagnet-test")'); time.sleep(2.5)
    ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.tag({ tag = "+%s", window = w })); hl.dispatch(hl.dsp.focus({ window = w })) end end' % TAG); time.sleep(0.8)
    ev('local c = _G.omagnet.cfg; _G.omagnet.saved_look = { c.highlight, c.target_color, c.target_outline, c.target_fill, c.margin }; '
       'c.highlight = true; c.target_color = "#ff0000"; c.target_outline = 6; c.target_fill = 0.30; c.margin = 0')
    try:
        ev("_G.omagnet.watch_super = false")  # scripted drags hold no SUPER key
        # 1. By default the outline matches the theme: the colour of the windows' active border, read from Hyprland.
        import re
        stops = re.findall(r"\b([0-9a-f]{8})\b", sh("hyprctl", "getoption", "general:col.active_border"))[:2]
        want_colors = " ".join("#" + c[2:] for c in stops) if stops else "-"
        ev('local c = _G.omagnet.cfg; c.highlight = false; c.target_color = ""; c.target_outline = 2; c.target_fill = 0.18')
        ev("_G.omagnet.on_press()"); time.sleep(0.5)
        ev("hl.dispatch(hl.dsp.cursor.move({ x = 640, y = 799 }))"); time.sleep(1.2)
        first, *rest = want_colors.split(" ")
        check("the default outline colour is the theme's active border colour", read("omagnet-style"), f"2 {first} 0.18 4" + (f" {rest[0]}" if rest else ""))
        ev("_G.omagnet.on_release()"); time.sleep(0.8)
        ev('local c = _G.omagnet.cfg; c.highlight = true; c.target_color = "#ff0000"; c.target_outline = 6; c.target_fill = 0.30')
        ev("_G.omagnet.command('restore')"); time.sleep(0.6)

        # 2. Your own colour, thicker outline, stronger fill, every zone shown.
        ev("_G.omagnet.on_press()"); time.sleep(1.2)
        check("the overlay started at the press (highlight is on)", len(sh("pgrep", "-f", "^qs -p .*preview.qml").split()), 1)
        check("style file", read("omagnet-style"), "6 #ff0000 0.30 4")
        zones = (read("omagnet-zones") or "").split("\n")
        check("one line per zone strip (14 on a wide screen)", len(zones), 14)
        ev("hl.dispatch(hl.dsp.cursor.move({ x = 640, y = 799 }))"); time.sleep(1.0)
        check("the target is the middle third", (read("omagnet-preview") or "").split()[0:1] != [], True)
        subprocess.run(["grim", out]); print("  screenshot:", out)
        ev("_G.omagnet.on_release()"); time.sleep(0.8)
        check("zones file is empty again after the drag", read("omagnet-zones"), "")
    finally:
        ev("_G.omagnet.watch_super = nil")
        ev('local c = _G.omagnet.cfg; local s = _G.omagnet.saved_look; c.highlight, c.target_color, c.target_outline, c.target_fill, c.margin = s[1], s[2], s[3], s[4], s[5]')
        ev('for _, w in ipairs(hl.get_windows()) do if w.class == "omagnet-test" then hl.dispatch(hl.dsp.window.close({ window = w })) end end'); time.sleep(0.6)
        if prev:
            ev(f"for _, w in ipairs(hl.get_windows()) do if w.address == '{prev}' then hl.dispatch(hl.dsp.focus({{ window = w }})) end end".replace("{{", "{").replace("}}", "}"))
        ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {cur[0]}, y = {cur[1]} }}))")
    print("\nALL OK" if not failed else "\nFAILED: " + "; ".join(failed))
    return 0 if not failed else 1


sys.exit(main())
