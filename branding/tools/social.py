#!/usr/bin/env python3
"""Render social images from the logo set with headless Chromium into branding/social/. Run logo.py and kit.py first."""
import os, subprocess, tempfile
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L, S = os.path.join(ROOT, "logo"), os.path.join(ROOT, "social")
os.makedirs(S, exist_ok=True)
TAG = "Magnet-style window snapping for Omarchy"
SUB = "Keys or drag. Floating workspaces. Pure Lua."
KEYS = ["CTRL + ALT + ←", "CTRL + ALT + →", "CTRL + ALT + U"]
THEMES = {
  "dark":  dict(bg="#16181d", fg="#e8e6ff", mute="#9a9eb0", chip="#23262e", lockup="lockup.svg"),
  "light": dict(bg="#f4f3f0", fg="#16181d", mute="#5b5f6e", chip="#e4e2dd", lockup="lockup-light.svg"),
}
def page(w, h, th, layout):
    t = THEMES[th]
    lk = open(os.path.join(L, t["lockup"])).read()
    chips = "".join(f'<span class="chip">{k}</span>' for k in KEYS)
    big = layout == "square"
    return f"""<!doctype html><meta charset="utf-8"><style>
*{{box-sizing:border-box;margin:0}}
body{{width:{w}px;height:{h}px;background:{t['bg']};color:{t['fg']};font-family:'JetBrainsMono Nerd Font','JetBrains Mono',monospace;
 display:flex;flex-direction:column;justify-content:center;padding:0 {int(w*0.08)}px;gap:{int(h*0.05)}px;overflow:hidden}}
.lk svg{{height:{int(h*(0.22 if big else 0.30))}px;width:auto;display:block;margin-left:-{int(h*(0.22 if big else 0.30)*0.207)}px}}
.tag{{font-size:{int(h*(0.045 if big else 0.07))}px;font-weight:700;line-height:1.25}}
.sub{{font-size:{int(h*(0.028 if big else 0.042))}px;color:{t['mute']};line-height:1.4}}
.chips{{display:flex;gap:14px;flex-wrap:wrap}}
.chip{{background:{t['chip']};color:{t['fg']};border-radius:10px;padding:10px 18px;font-size:{int(h*(0.026 if big else 0.038))}px}}
.url{{position:absolute;right:{int(w*0.04)}px;bottom:{int(h*0.05)}px;font-size:{int(h*0.03)}px;color:{t['mute']}}}
</style><div class="lk">{lk}</div><div class="tag">{TAG}</div>
{'' if layout=='banner' else f'<div class="sub">{SUB}</div><div class="chips">{chips}</div>'}
<div class="url">github.com/felipecpaiva/omagnet</div>"""
def shot(name, w, h, th, layout="wide"):
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False) as f: f.write(page(w, h, th, layout))
    out = os.path.join(S, name)
    subprocess.run(["chromium", "--headless", "--no-sandbox", "--hide-scrollbars", "--force-device-scale-factor=1",
                    f"--window-size={w},{h}", f"--screenshot={out}", "file://" + f.name], check=True, capture_output=True)
    os.unlink(f.name); print(name)
shot("github-social-preview.png", 1280, 640, "dark")
shot("card-wide.png", 1200, 630, "dark")
shot("card-wide-light.png", 1200, 630, "light")
shot("card-square.png", 1080, 1080, "dark", "square")
shot("banner-dark.png", 1600, 400, "dark", "banner")
shot("banner-light.png", 1600, 400, "light", "banner")

# marketplace preview: the lockup and tagline beside the settings window
def preview(out="preview.png", w=1280, h=640):
    t = THEMES["dark"]; lk = open(os.path.join(L, t["lockup"])).read()
    shot_path = os.path.join(ROOT, "screens", "settings-top.png")
    html = f"""<!doctype html><meta charset="utf-8"><style>*{{box-sizing:border-box;margin:0}}
body{{width:{w}px;height:{h}px;background:{t['bg']};color:{t['fg']};font-family:'JetBrainsMono Nerd Font',monospace;display:flex;align-items:center;padding:0 64px;gap:48px;overflow:hidden}}
.l{{flex:1}} .lk svg{{height:130px;width:auto;display:block;margin-left:-27px}}
.tag{{font-size:34px;font-weight:700;line-height:1.3;margin-top:32px}} .sub{{font-size:20px;color:{t['mute']};margin-top:20px;line-height:1.5}}
img{{height:{h-80}px;border-radius:14px;box-shadow:0 12px 40px #0008}}</style>
<div class="l"><div class="lk">{lk}</div><div class="tag">{TAG}</div><div class="sub">{SUB}</div></div><img src="file://{shot_path}">"""
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False) as f: f.write(html)
    dest = os.path.join(os.path.dirname(ROOT), out)
    subprocess.run(["chromium", "--headless", "--no-sandbox", "--hide-scrollbars", "--force-device-scale-factor=1", f"--window-size={w},{h}",
                    f"--screenshot={dest}", "file://" + f.name], check=True, capture_output=True)
    os.unlink(f.name); print(out)
preview()

# sizes other places ask for
shot("card-linkedin.png", 1200, 627, "dark")
shot("card-x.png", 1600, 900, "dark")
subprocess.run(["rsvg-convert", "-w", "400", os.path.join(L, "icon.svg"), "-o", os.path.join(S, "avatar-400.png")], check=True)
print("avatar-400.png")
