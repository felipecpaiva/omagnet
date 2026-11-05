#!/usr/bin/env python3
"""Build wordmark and lockups (SVG + PNG) into branding/logo/ from the Snap Grid mark. Run tools/logo.py first."""
import os, sys, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wordmark import mono_wordmark, lockup
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = os.path.join(ROOT, "logo")
rd = lambda n: open(os.path.join(L, n)).read()
def wr(n, t): open(os.path.join(L, n), "w").write(t)

dark = dict(color="#e8e6ff", accent="#8b7bff", weight=8)
light = dict(color="#16181d", accent="#6a5af0", weight=8)
wr("wordmark.svg", mono_wordmark(**dark))
wr("wordmark-light.svg", mono_wordmark(**light))
wr("lockup.svg", lockup(rd("glyph.svg"), mono_wordmark(**dark), icon_px=160, gap=40, word_h=72))            # for dark backgrounds
wr("lockup-light.svg", lockup(rd("glyph-light.svg"), mono_wordmark(**light), icon_px=160, gap=40, word_h=72))  # for light backgrounds
for n in ("wordmark", "wordmark-light", "lockup", "lockup-light"):
    subprocess.run(["rsvg-convert", "-h", "256" if "lockup" in n else "160", os.path.join(L, n + ".svg"), "-o", os.path.join(L, n + ".png")], check=True)
print("wordmark and lockups written")
