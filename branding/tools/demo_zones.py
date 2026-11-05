#!/usr/bin/env python3
"""Record the grid zones demo on one of your REAL external monitors (no virtual monitor is created, so Omarchy's workspace
numbering is not touched): three windows snapped into zones with SUPER + SHIFT drags, SHIFT pressed in the middle of a drag, and the
zone keys. Writes branding/demo/zones.gif and zones.mp4. It moves your pointer onto that monitor for about a minute; do not touch
the mouse or keyboard. Needs grim, ffmpeg, kitty, Hyprland with omagnet loaded, a second monitor.  Usage: python3 branding/tools/demo_zones.py [MONITOR]"""
import json, os, subprocess, sys, tempfile, threading, time
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(ROOT), "tests"))
from uinput_kbd import Keyboard, Mouse
import gifkit

TAG = "omarchy-floating-workspace"
def sh(*a): return subprocess.run(a, capture_output=True, text=True).stdout
def ev(l): subprocess.run(["hyprctl", "eval", l], capture_output=True)
def jq(*a): return json.loads(sh("hyprctl", *a, "-j") or "null")

WINS = [("omagnet-demo-a", "#8b7bff", "A"), ("omagnet-demo-b", "#e8e6ff", "B"), ("omagnet-demo-c", "#5ec8b0", "C")]


def main():
    mons = jq("monitors")
    want = sys.argv[1] if len(sys.argv) > 1 else next((m["name"] for m in mons if m["id"] != 0), None)
    mon = next((m for m in mons if m["name"] == want), None)
    if not mon:
        print("needs a second monitor"); return 2
    w, h = (mon["height"], mon["width"]) if mon["transform"] % 2 else (mon["width"], mon["height"])
    lw, lh = int(w / mon["scale"]), int(h / mon["scale"])
    ax, ay, aw, ah = mon["x"], mon["y"] + mon["reserved"][1], lw, lh - mon["reserved"][1]
    ws = mon["activeWorkspace"]["id"]
    before_cursor = sh("hyprctl", "cursorpos").strip().replace(",", "").split()
    before_focus = (jq("activewindow") or {}).get("address", "")
    fdir = tempfile.mkdtemp(prefix="omagnet-zdemo-")
    frames, stop, marks = [], threading.Event(), []
    t0 = time.time()
    def say(text): marks.append((time.time() - t0, text))

    ev('local m = _G.omagnet; m.saved = { m.cfg.margin, m.cfg.zone_span }; m.cfg.margin = 8; m.cfg.zone_span = 24; m.layout_override = {}; m.cfg.zone_layouts = {}; m.cfg.workspace_layouts = {}; m.cfg.layout_landscape = "auto"; m.cfg.layout_portrait = "auto"')
    try:
        for i, (cls, col, ch) in enumerate(WINS):
            lab = os.path.join(fdir, f"label-{ch}.sh")
            open(lab, "w").write(f"#!/bin/sh\nprintf '\\033[2J\\033[H\\033[?25l\\n  \\033[1m{ch}\\033[0m'\nsleep 900\n"); os.chmod(lab, 0o755)
            ev('hl.exec_cmd("[float; size 280 170; move %d %d; workspace %d silent] kitty --class %s -o background=%s -o foreground=#16181d -o font_size=30 -o window_padding_width=16 %s")'
               % (30 + i * 305, 50 + i * 12, ws, cls, col, lab)); time.sleep(1.6)  # side by side: none covers another
        ev('for _, w in ipairs(hl.get_windows()) do if w.class:find("^omagnet%%-demo") then hl.dispatch(hl.dsp.window.tag({ tag = "+%s", window = w })) end end' % TAG); time.sleep(0.8)

        def addr(cls): return next(c["address"] for c in jq("clients") if c["class"] == cls)
        def rect(cls):
            c = next(c for c in jq("clients") if c["class"] == cls); return c["at"][0], c["at"][1], c["size"][0], c["size"][1]
        def focus(cls): ev("for _, w in ipairs(hl.get_windows()) do if w.class == '%s' then hl.dispatch(hl.dsp.window.bring_to_top({ window = w })); hl.dispatch(hl.dsp.focus({ window = w })) end end" % cls); time.sleep(0.3)  # raised, so the pointer grabs this one even when others cover it
        def warp(x, y): ev("hl.dispatch(hl.dsp.cursor.move({ x = %d, y = %d }))" % (x, y))
        def glide(x0, y0, x1, y1, steps=14, dt=0.035):
            for k in range(1, steps + 1):
                warp(x0 + (x1 - x0) * k // steps, y0 + (y1 - y0) * k // steps); time.sleep(dt)
        def retag(): ev('for _, w in ipairs(hl.get_windows()) do if w.class:find("^omagnet%%-demo") then hl.dispatch(hl.dsp.window.tag({ tag = "+%s", window = w })) end end' % TAG); time.sleep(0.2)

        def grab():
            n = 0
            while not stop.is_set():
                p = os.path.join(fdir, f"f{n:05d}.jpg"); a = time.time() - t0
                subprocess.run(["grim", "-o", mon["name"], "-c", "-t", "jpeg", "-q", "85", p], capture_output=True)
                frames.append((a, p)); n += 1
        warp(ax + aw // 2, ay + ah // 2); time.sleep(0.5)
        t0 = time.time(); th = threading.Thread(target=grab); th.start()
        say("Three floating windows"); time.sleep(2.0)
        with Keyboard() as kb, Mouse() as mouse:
            def zone_drag(cls, tx, ty, hold=0.9, shift_mid=False):
                retag(); focus(cls)
                x, y, w_, h_ = rect(cls); sx, sy = x + w_ // 2, y + h_ // 2
                warp(sx, sy); time.sleep(0.3)
                kb.down("super")
                if not shift_mid: kb.down("shift")
                mouse.press(); time.sleep(0.25); mouse.move(2, 0, steps=1)
                if shift_mid:
                    glide(sx, sy, sx + 40, sy + 20, 6); time.sleep(0.5)
                    say("Press SHIFT in the middle of the drag"); kb.down("shift"); time.sleep(0.6)
                glide(sx + (40 if shift_mid else 0), sy + (20 if shift_mid else 0), tx, ty, 18); time.sleep(hold)
                mouse.release(); kb.up("shift"); kb.up("super"); time.sleep(1.0)
            half, qh = aw // 2, ah // 4
            say("Pick a layout, see it first"); ev('_G.omagnet.layout_override["%s"] = "grid:2x2"' % mon["name"])
            ev('_G.omagnet.preview("grid:2x2", 3)'); time.sleep(3.6)
            say("Hold SUPER + SHIFT and drag"); zone_drag("omagnet-demo-a", ax + half // 2, ay + ah - qh)
            say("Or press SHIFT in the middle of a drag"); zone_drag("omagnet-demo-b", ax + half // 2, ay + qh, shift_mid=True)
            say("Drop on the line between two cells to fill both"); zone_drag("omagnet-demo-c", ax + half + half // 2, ay + ah // 2, hold=1.4)
            say("CTRL + ALT + ]  steps through the zones"); retag(); focus("omagnet-demo-c")
            for _ in range(3): kb.tap("ctrl+alt+bracketright"); time.sleep(1.2)
            say("CTRL + ALT + Backspace  restores the size"); kb.tap("ctrl+alt+backspace"); time.sleep(1.6)
            say("")
        time.sleep(0.5)
        stop.set(); th.join(); total = time.time() - t0
    finally:
        stop.set()
        ev('local m = _G.omagnet; m.cfg.margin, m.cfg.zone_span = m.saved[1], m.saved[2]; m.layout_override = {}')
        ev('for _, w in ipairs(hl.get_windows()) do if w.class:find("^omagnet%-demo") then hl.dispatch(hl.dsp.window.close({ window = w })) end end'); time.sleep(0.8)
        if before_focus:
            ev("for _, w in ipairs(hl.get_windows()) do if w.address == '%s' then hl.dispatch(hl.dsp.focus({ window = w })) end end" % before_focus)
        warp(int(float(before_cursor[0])), int(float(before_cursor[1])))
    gifkit.build(frames, total, marks, os.path.join(ROOT, "demo"), "zones")
    print("frames:", len(frames), "seconds:", round(total, 1))


main()
