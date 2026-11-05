#!/usr/bin/env python3
"""Build the final omagnet logo set (the Snap Grid mark) as clean vector files and PNG exports into branding/logo/.
The mark: four rounded L-shaped quarters form a square ring; one (violet) is displaced up and right, clicking into place,
with three short ticks. It is built from numbers, so every gap and radius is exact.
Usage: python3 branding/tools/logo.py   (needs rsvg-convert and ImageMagick)"""
import os, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "logo")
os.makedirs(OUT, exist_ok=True)

C = dict(ground="#16181d", main="#e8e6ff", accent="#8b7bff", tick="#6b7080",
         main_on_light="#16181d", accent_on_light="#6a5af0", tick_on_light="#8b90a0")

def piece(x0, y0, x1, y1, t, R, r):
    """The top-left quarter of the ring as an L: outer box corner (x0,y0), inner end of each arm at x1 / y1."""
    return (f"M {x0} {y0+R} A {R} {R} 0 0 1 {x0+R} {y0} H {x1} V {y0+t} H {x0+t+r} "
            f"A {r} {r} 0 0 0 {x0+t} {y0+t+r} V {y1} H {x0} Z")

def mark(main, accent, tick, ticks=True, size=300, t=64, gap=16, R=64, r=16, shift=34):
    c = 256                      # centre of the 512 canvas
    x0 = c - size // 2
    arm = c - gap // 2
    d = piece(x0, x0, arm, arm, t, R, r)
    g = [f'<path id="q" d="{d}" fill="{main}"/>',
         f'<use href="#q" transform="rotate(180 {c} {c})" fill="{main}"/>',
         f'<use href="#q" transform="rotate(270 {c} {c})" fill="{main}"/>',
         f'<use href="#q" transform="translate({shift} {-shift}) rotate(90 {c} {c})" fill="{accent}"/>']
    # the displaced quarter needs its own fill: draw it as a path copy
    g[3] = f'<path d="{d}" transform="translate({shift} {-shift}) rotate(90 {c} {c})" fill="{accent}"/>'
    g[1] = f'<path d="{d}" transform="rotate(180 {c} {c})" fill="{main}"/>'
    g[2] = f'<path d="{d}" transform="rotate(270 {c} {c})" fill="{main}"/>'
    g[0] = f'<path d="{d}" fill="{main}"/>'
    if ticks:
        # three short parallel ticks in the gap between the top-left quarter and the displaced one
        # centred in the gap: halfway between the end of the pale arm and the start of the displaced quarter
        tx, cy = (arm + (c + shift + 0)) // 2 + 6, x0 + t // 2
        for i in range(3):
            y = cy + (i - 1) * 19
            g.append(f'<line x1="{tx-9}" y1="{y+9}" x2="{tx+9}" y2="{y-9}" stroke="{tick}" stroke-width="9" stroke-linecap="round"/>')
    return "\n  ".join(g)

def svg(body, tile=None, viewbox="0 0 512 512", extra=""):
    bg = f'<rect width="512" height="512" rx="96" fill="{tile}"/>\n  ' if tile else ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{viewbox}"{extra}>\n  {bg}{body}\n</svg>\n'

def write(name, text):
    with open(os.path.join(OUT, name), "w") as f: f.write(text)

def png(src, name, w, h=None):
    subprocess.run(["rsvg-convert", "-w", str(w)] + (["-h", str(h)] if h else []) + [os.path.join(OUT, src), "-o", os.path.join(OUT, name)], check=True)

def build():
    # the app icon (dark rounded tile) with ticks, and a small-size version without ticks and with a wider gap
    write("icon.svg", svg(mark(C["main"], C["accent"], C["tick"]), tile=C["ground"]))
    write("icon-small.svg", svg(mark(C["main"], C["accent"], C["tick"], ticks=False, gap=28, t=72, shift=40), tile=C["ground"]))
    # the glyph alone on transparent, for dark and for light backgrounds
    write("glyph.svg", svg(mark(C["main"], C["accent"], C["tick"])))
    write("glyph-light.svg", svg(mark(C["main_on_light"], C["accent_on_light"], C["tick_on_light"])))
    # one-colour stencil, black on transparent, and white for dark backgrounds
    write("stencil.svg", svg(mark("#000000", "#000000", "#000000")))
    write("stencil-white.svg", svg(mark("#ffffff", "#ffffff", "#ffffff")))
    for s in (1024, 512, 256, 192, 180, 128, 64):
        png("icon.svg", f"icon-{s}.png", s)
    for s in (48, 32, 16):
        png("icon-small.svg", f"icon-{s}.png", s)
    for name in ("glyph", "glyph-light", "stencil", "stencil-white"):
        png(f"{name}.svg", f"{name}-512.png", 512)
    subprocess.run(["magick", os.path.join(OUT, "icon-16.png"), os.path.join(OUT, "icon-32.png"), os.path.join(OUT, "icon-48.png"), os.path.join(OUT, "favicon.ico")], check=True)
    print("logo set written to", os.path.relpath(OUT, ROOT))

if __name__ == "__main__":
    build()
