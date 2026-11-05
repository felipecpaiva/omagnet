#!/usr/bin/env python3
"""Turn an ASCII pixel map into a clean SVG (runs of equal cells are merged into one rect).
A map is a list of equal-length strings; each character is a colour key, '.' is empty. Used for the pixel variations.
Usage as a module: pixel_svg(rows, palette, cell=32, background=None) -> str"""

def pixel_svg(rows, palette, cell=32, background=None, mono=None):
    h, w = len(rows), len(rows[0])
    assert all(len(r) == w for r in rows), "rows must be equal length"
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w*cell}" height="{h*cell}" viewBox="0 0 {w*cell} {h*cell}" shape-rendering="crispEdges">']
    if background:
        parts.append(f'<rect width="{w*cell}" height="{h*cell}" fill="{background}"/>')
    for y, row in enumerate(rows):
        x = 0
        while x < w:
            c = row[x]
            if c == '.':
                x += 1; continue
            x2 = x
            while x2 < w and row[x2] == c: x2 += 1
            fill = mono if mono else palette[c]
            parts.append(f'<rect x="{x*cell}" y="{y*cell}" width="{(x2-x)*cell}" height="{cell}" fill="{fill}"/>')
            x = x2
    parts.append('</svg>')
    return "\n".join(parts) + "\n"
