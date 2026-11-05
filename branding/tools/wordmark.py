#!/usr/bin/env python3
"""Draw the omagnet wordmark as pure vector shapes (no fonts): a monoline geometric alphabet built from strokes, and a pixel
alphabet built from squares. Only the seven letters of the name exist here: o m a g n e t.
Usage: python3 branding/tools/wordmark.py   (writes wordmark.svg and lockup.svg into each variation folder)"""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel import pixel_svg

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---- monoline letters: centre-line paths in a box 40 wide, x-height 40 (top y=0, baseline y=40), round caps
MONO = {
    "o": (44, ["M 20 3 A 17 17 0 1 1 19.99 3 Z"]),
    "m": (68, ["M 4 40 V 4", "M 4 24 A 14 14 0 0 1 32 24 V 40", "M 32 24 A 14 14 0 0 1 60 24 V 40"]),
    "a": (44, ["M 20 6 A 16 16 0 1 0 20.01 6 Z", "M 36 6 V 40"]),
    "g": (44, ["M 20 6 A 16 16 0 1 0 20.01 6 Z", "M 36 6 V 48 C 36 62 22 66 10 62"]),
    "n": (44, ["M 4 40 V 4", "M 4 24 A 16 16 0 0 1 36 24 V 40"]),
    "e": (44, ["M 4 22 H 36", "M 36 22 A 16 16 0 1 0 31.3 33.3"]),
    "t": (36, ["M 14 -8 V 32 Q 14 40 24 40 H 30", "M 4 10 H 28"]),
}

def mono_wordmark(color, accent=None, accent_first=True, weight=9, text="omagnet"):
    x, parts = 0, []
    for i, ch in enumerate(text):
        adv, paths = MONO[ch]
        c = accent if (accent and accent_first and i == 0) else color
        d = " ".join(paths)
        parts.append(f'<path transform="translate({x} 0)" d="{d}" stroke="{c}" fill="none"/>')
        x += adv
    w = x
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-8 -22 {w+16} 100" height="100" fill="none" '
            f'stroke-width="{weight}" stroke-linecap="round" stroke-linejoin="round">' + "".join(parts) + '</svg>\n')

# ---- pixel letters (x-height 5, ascender row above, descender rows below). Rows run from the ascender line down.
PIX = {
 "o": ["", ".###.", "#...#", "#...#", "#...#", ".###.", "", "", ""],
 "m": ["", ".##.##.", "#..#..#", "#..#..#", "#..#..#", "#..#..#", "", "", ""],
 "a": ["", ".####", "#...#", "#...#", "#...#", ".####", "", "", ""],
 "g": ["", ".####", "#...#", "#...#", "#...#", ".####", "....#", "....#", ".###."],
 "n": ["", ".###.", "#...#", "#...#", "#...#", "#...#", "", "", ""],
 "e": ["", ".###.", "#...#", "#####", "#....", ".####", "", "", ""],
 "t": [".#..", "####", ".#..", ".#..", ".#..", "..##", "", "", ""],
}

def pixel_wordmark(color, accent=None, cursor=None, cell=16):
    rows = [""] * 9
    keys = {}
    pal = {"c": color, "a": accent or color, "k": cursor or color}
    out = [[] for _ in range(9)]
    for i, ch in enumerate("omagnet"):
        glyph = PIX[ch]
        w = max(len(r) for r in glyph)
        for y in range(9):
            row = glyph[y].ljust(w, ".")
            row = row.replace("#", "a" if (i == 0 and accent) else "c")
            out[y].append(row)
        for y in range(9): out[y].append(".")
    if cursor:  # a cursor block after the word, like a terminal prompt
        for y in range(9):
            out[y].append("kk" if 1 <= y <= 5 else "..")
    rows = ["".join(r).rstrip(".") for r in out]
    width = max(len(r) for r in rows)
    rows = [r.ljust(width, ".") for r in rows]
    return pixel_svg(rows, pal, cell)

def inner(svg_text):
    """The drawing inside an <svg> element, and its viewBox size."""
    m = re.search(r"<svg[^>]*>", svg_text); head = m.group(0)
    vb = re.search(r'viewBox="([^"]+)"', head)
    size = [float(v) for v in vb.group(1).split()][2:] if vb else [float(re.search(r'width="(\d+)"', head).group(1)), float(re.search(r'height="(\d+)"', head).group(1))]
    body = svg_text[m.end():svg_text.rindex("</svg>")]
    return body, size

def lockup(icon_svg, word_svg, icon_px=160, gap=48, word_h=64):
    ibody, (iw, ih) = inner(icon_svg)
    wbody, wsz = inner(word_svg)
    wvb = re.search(r'viewBox="([^"]+)"', word_svg)
    wx, wy, ww, wh = [float(v) for v in wvb.group(1).split()] if wvb else (0, 0, wsz[0], wsz[1])
    scale_i = icon_px / ih
    scale_w = word_h / wh
    total_w = icon_px + gap + ww * scale_w
    attrs = re.search(r"<svg[^>]*>", word_svg).group(0)
    wattrs = " ".join(re.findall(r'(fill|stroke|stroke-width|stroke-linecap|stroke-linejoin)="[^"]*"', attrs) and re.findall(r'((?:fill|stroke|stroke-width|stroke-linecap|stroke-linejoin)="[^"]*")', attrs))
    y_off = (icon_px - word_h) / 2
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {total_w:.0f} {icon_px}" height="{icon_px}">'
            f'<g transform="scale({scale_i:.5f})">{ibody}</g>'
            f'<g transform="translate({icon_px+gap} {y_off:.1f}) scale({scale_w:.5f}) translate({-wx} {-wy})" {wattrs}>{wbody}</g></svg>\n')

def build():
    # name: (icon file, kind, colours for dark backgrounds, colours for light backgrounds)
    cfg = {
        "v1-notch":    ("icon.svg", "pixel", dict(color="#fff1d6", accent="#ff9f1c"), dict(color="#14161b", accent="#c77700")),
        "v2-snapgrid": ("icon.svg", "mono", dict(color="#e8e6ff", accent="#8b7bff", weight=8), dict(color="#16181d", accent="#6a5af0", weight=8)),
        "v3-pole":     ("icon.svg", "mono", dict(color="#f4efe6", accent="#ffb000", weight=11), dict(color="#14161b", accent="#c77700", weight=11)),
        "v4-halfblock":("icon.svg", "pixel", dict(color="#5ef2c1", cursor="#ff6b6b"), dict(color="#0c7a58", cursor="#d6404a")),
    }
    for name, (icon, kind, dark, light) in cfg.items():
        d = os.path.join(ROOT, "explorations", name)
        if not os.path.isdir(d): continue
        make = pixel_wordmark if kind == "pixel" else mono_wordmark
        ip = os.path.join(d, icon)
        for suffix, kw in (("", dark), ("-light", light)):
            word = make(**kw)
            open(os.path.join(d, f"wordmark{suffix}.svg"), "w").write(word)
            if os.path.exists(ip):
                open(os.path.join(d, f"lockup{suffix}.svg"), "w").write(lockup(open(ip).read(), word))
        print("wordmark and lockup (dark and light):", name)

if __name__ == "__main__":
    build()
