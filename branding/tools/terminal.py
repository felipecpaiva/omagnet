#!/usr/bin/env python3
"""Write branding/terminal/banner.txt (plain half-block text) and banner.ansi (violet 'o') from the pixel alphabet."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wordmark import PIX
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def grid():
    cols = []
    for i, ch in enumerate("omagnet"):
        g = PIX[ch]; w = max(len(r) for r in g)
        cols.append([r.ljust(w, ".") + "." for r in g])
    return cols
def render(color):
    cols = grid(); lines = []
    for y in range(0, 9, 2):
        line = ""
        for i, c in enumerate(cols):
            top, bot = c[y], c[y + 1] if y + 1 < 9 else "." * len(c[y])
            s = "".join(" ▀▄█"[(t == "#") + 2 * (b == "#")] for t, b in zip(top, bot))
            line += (f"\x1b[38;5;99m{s}\x1b[0m" if color and i == 0 else s)
        lines.append(line.rstrip())
    return "\n".join(lines) + "\n"
os.makedirs(os.path.join(ROOT, "terminal"), exist_ok=True)
open(os.path.join(ROOT, "terminal", "banner.txt"), "w").write(render(False))
open(os.path.join(ROOT, "terminal", "banner.ansi"), "w").write(render(True))
print(render(True))
