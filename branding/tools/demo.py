#!/usr/bin/env python3
"""Record the omagnet demo on a temporary virtual monitor (your own windows are never on screen) and build demo/demo.gif.
Do not touch the keyboard or mouse while it runs (about 40 seconds). Needs grim, ffmpeg, kitty, Hyprland with omagnet loaded.
Usage: python3 branding/tools/demo.py"""
import json, os, subprocess, sys, tempfile, threading, time
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(ROOT), "tests"))
from uinput_kbd import Keyboard
from livehelp import forget_headless_blocks
OUT = os.path.join(ROOT, "demo"); os.makedirs(OUT, exist_ok=True)
TAG = "omarchy-floating-workspace"
FONT = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf"

def sh(*a): return subprocess.run(a, capture_output=True, text=True).stdout
def ev(l): subprocess.run(["hyprctl", "eval", l], capture_output=True)
def jq(*a): return json.loads(sh("hyprctl", *a, "-j") or "null")
def monitors(): return {m["name"]: m for m in jq("monitors")}
def cmd(name, cls): ev('for _, w in ipairs(hl.get_windows()) do if w.class == "%s" then _G.omagnet.command("%s", w) end end' % (cls, name))
def retag(): ev('for _, w in ipairs(hl.get_windows()) do if w.class:find("^omagnet%%-demo") then hl.dispatch(hl.dsp.window.tag({ tag = "+%s", window = w })) end end' % TAG)

# (class, colour, big letter)
WINS = [("omagnet-demo-a", "#8b7bff", "A"), ("omagnet-demo-b", "#e8e6ff", "B"), ("omagnet-demo-c", "#5ec8b0", "C")]
# (window index, command, caption)
STEPS = [(2, "bottom", "CTRL + ALT + ↓   bottom half"), (0, "top_left", "CTRL + ALT + U   top left quarter"),
         (1, "top_right", "CTRL + ALT + I   top right quarter"), (2, "maximize", "CTRL + ALT + Return   maximize"),
         (2, "restore", "CTRL + ALT + Backspace   restore"), (0, "left", "CTRL + ALT + ←   left half"),
         (1, "right", "CTRL + ALT + →   right half"), (0, "third_left", "CTRL + ALT + D   left third"),
         (1, "two_thirds_right", "CTRL + ALT + T   two thirds")]

def main():
    before = set(monitors())
    created = None; frames = []; stop = threading.Event(); t0 = time.time(); fdir = tempfile.mkdtemp(prefix="omagnet-demo-")
    try:
        sh("hyprctl", "output", "create", "headless"); time.sleep(2.0)
        if "omarchy-image-selector" in sh("hyprctl", "layers"):
            with Keyboard() as kb: kb.tap("escape")
            time.sleep(0.8)
        new = [n for n in monitors() if n not in before]
        created = new[0]; m = monitors()[created]; wsid = m["activeWorkspace"]["id"]
        ev(f'o.workspace_mode({{ workspace = "{wsid}", mode = "floating" }})'); time.sleep(1.0)
        ev('_G.omagnet.cfg.margin = 8')
        for i, (cls, col, ch) in enumerate(WINS):
            lab = os.path.join(fdir, f"label-{ch}.sh")
            open(lab, "w").write(f"#!/bin/sh\nprintf '\\033[2J\\033[H\\033[?25l\\n\\n  \\033[1m{ch}\\033[0m'\nsleep 600\n"); os.chmod(lab, 0o755)
            x, y = 90 + i * 60, 70 + i * 50
            ev('hl.exec_cmd("[float; size 440 270; move %d %d; workspace %d silent] kitty --class %s -o background=%s -o foreground=#16181d -o font_size=40 -o window_padding_width=24 %s")'
               % (x, y, wsid, cls, col, lab))
            time.sleep(1.6)
        retag(); time.sleep(0.5)
        print([(c['class'], c['workspace']['id'], c['at'], c['size']) for c in jq('clients') if c['class'].startswith('omagnet-demo')], wsid, flush=True)
        time.sleep(1.0)
        t0 = time.time()
        def grab():
            n = 0
            while not stop.is_set():
                p = os.path.join(fdir, f"f{n:05d}.jpg"); a = time.time() - t0
                subprocess.run(["grim", "-o", created, "-t", "jpeg", "-q", "85", p], capture_output=True)
                frames.append((a, p)); n += 1
        th = threading.Thread(target=grab); th.start()
        time.sleep(2.2); marks = [(0.0, "Three floating windows")]
        for idx, name, cap in STEPS:
            retag(); marks.append((time.time() - t0, cap)); cmd(name, WINS[idx][0]); time.sleep(2.2)
        marks.append((time.time() - t0, ""))
        stop.set(); th.join(); total = time.time() - t0
    finally:
        stop.set()
        ev('for _, w in ipairs(hl.get_windows()) do if w.class:find("^omagnet%-demo") then hl.dispatch(hl.dsp.window.close({ window = w })) end end')
        time.sleep(0.8)
        if created: sh("hyprctl", "output", "remove", created); time.sleep(2.0)
        if "omarchy-image-selector" in sh("hyprctl", "layers"):
            with Keyboard() as kb: kb.tap("escape")
        ev("_G.omagnet.cfg.margin = 8")
    FPS = 12; n = int(total * FPS); j = 0
    for k in range(n):   # the latest captured frame at or before each tick
        while j + 1 < len(frames) and frames[j + 1][0] <= k / FPS: j += 1
        os.symlink(frames[j][1], os.path.join(fdir, f"s{k:05d}.jpg"))
    draw = ",".join(f"drawtext=fontfile={FONT}:text='{c}':fontsize=38:fontcolor=#e8e6ff:box=1:boxcolor=#16181dcc:boxborderw=18:x=(w-text_w)/2:y=h-90:enable='between(t,{a:.2f},{marks[i+1][0]:.2f})'"
                    for i, (a, c) in enumerate(marks[:-1]))
    vf = f"{draw},scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer:bayer_scale=4"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", os.path.join(fdir, "s%05d.jpg"), "-filter_complex", vf, "-loop", "0", os.path.join(OUT, "demo.gif")], check=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", os.path.join(fdir, "s%05d.jpg"), "-vf", f"{draw},scale=1280:-2", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "24", "-r", "30", os.path.join(OUT, "demo.mp4")], check=True)
    removed = forget_headless_blocks()  # Omarchy keeps a block of workspaces for every monitor it has seen, virtual ones too
    print("frames:", len(frames), "seconds:", round(total, 1), "| virtual monitor entries removed from Omarchy's state:", removed)

main()
