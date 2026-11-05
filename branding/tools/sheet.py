#!/usr/bin/env python3
"""Build branding/brand-sheet.html and brand-sheet.png (one page): palette with computed contrast ratios, type, spacing, do and do not."""
import os, subprocess, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))); L = os.path.join(ROOT, "logo")
def lum(h):
    c = [int(h[i:i+2], 16) / 255 for i in (1, 3, 5)]
    c = [v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4 for v in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
def cr(a, b):
    x, y = sorted((lum(a), lum(b)), reverse=True); return (x + 0.05) / (y + 0.05)
GROUND, PAPER = "#16181d", "#f4f3f0"
# name, hex, role, background it sits on
PAL = [("Ground", GROUND, "Dark background, icon tile", "#e8e6ff"), ("Ink light", "#e8e6ff", "Pale ring and text on dark", GROUND),
       ("Violet", "#8b7bff", "The displaced quarter, the o, accents on dark", GROUND), ("Tick", "#6b7080", "Three small ticks (decoration only)", GROUND),
       ("Paper", PAPER, "Light background", GROUND), ("Ink dark", "#16181d", "Ring and text on light", PAPER),
       ("Violet deep", "#6a5af0", "Violet on light backgrounds", PAPER), ("Muted", "#5b5f6e", "Secondary text on light", PAPER)]
def swatch(n, h, role, on):
    r = cr(h, on); grade = "AAA" if r >= 7 else "AA" if r >= 4.5 else "graphics only, not body text" if r >= 3 else "decoration only"
    ink = "#16181d" if lum(h) > 0.4 else "#f4f3f0"
    return f'<div class="sw"><div class="chip" style="background:{h};color:{ink}">{n}</div><b>{h}</b><span>{role}</span><i>{r:.1f}:1 on {on} ({grade})</i></div>'
rd = lambda n: open(os.path.join(L, n)).read()
html = f"""<!doctype html><meta charset="utf-8"><title>omagnet brand sheet</title><style>
*{{box-sizing:border-box;margin:0}} body{{width:1600px;background:{PAPER};color:{GROUND};font-family:'JetBrainsMono Nerd Font','JetBrains Mono',monospace;padding:64px;font-size:17px;line-height:1.5}}
h2{{font-size:15px;letter-spacing:.12em;text-transform:uppercase;color:#5b5f6e;margin:48px 0 18px;border-top:2px solid {GROUND};padding-top:14px}}
.top{{display:flex;align-items:center;justify-content:space-between}} .top svg{{height:120px;width:auto}} .top p{{max-width:620px;font-size:19px}}
.row{{display:flex;gap:28px;align-items:flex-end;flex-wrap:wrap}} .tile{{border-radius:18px;padding:26px;display:flex;align-items:center;justify-content:center}}
.tile svg{{display:block}} .cap{{font-size:14px;color:#5b5f6e;margin-top:8px}}
.pal{{display:grid;grid-template-columns:repeat(4,1fr);gap:22px}} .sw{{display:flex;flex-direction:column;gap:4px}} .sw .chip{{height:84px;border-radius:12px;padding:12px 14px;font-weight:700;border:1px solid #0002}}
.sw span{{font-size:14px;color:#5b5f6e}} .sw i{{font-size:13px;font-style:normal}}
.two{{display:grid;grid-template-columns:1fr 1fr;gap:48px}} ul{{padding-left:22px}} li{{margin:6px 0}} .do li::marker{{content:"+ ";color:#2f9e6b;font-weight:700}} .dont li::marker{{content:"x ";color:#c0392b;font-weight:700}}
.mono{{font-size:15px}} code{{background:#0001;padding:1px 6px;border-radius:5px}}
</style>
<div class="top"><div>{rd('lockup-light.svg')}</div><p><b>omagnet</b> is Magnet-style window snapping for Omarchy floating workspaces. The mark: four rounded corners form a ring, and one of them (violet) has just clicked into place. Plain, exact, small.</p></div>

<h2>1. The mark</h2>
<div class="row">
 <div><div class="tile" style="background:{GROUND}"><img src="{os.path.join(L,'icon-256.png')}" width="200"></div><div class="cap">App icon (dark tile). Files: icon.svg, icon-*.png</div></div>
 <div><div class="tile" style="background:{GROUND}"><img src="{os.path.join(L,'glyph-512.png')}" width="200"></div><div class="cap">Glyph on dark: glyph.svg</div></div>
 <div><div class="tile" style="background:#fff;border:1px solid #0002"><img src="{os.path.join(L,'glyph-light-512.png')}" width="200"></div><div class="cap">Glyph on light: glyph-light.svg</div></div>
 <div><div class="tile" style="background:#fff;border:1px solid #0002"><img src="{os.path.join(L,'stencil-512.png')}" width="200"></div><div class="cap">One colour: stencil.svg, stencil-white.svg</div></div>
 <div><div class="tile" style="background:{GROUND}"><img src="{os.path.join(L,'icon-64.png')}" width="64"><img src="{os.path.join(L,'icon-32.png')}" width="32" style="margin-left:16px"><img src="{os.path.join(L,'icon-16.png')}" width="16" style="margin-left:16px"></div><div class="cap">64, 32, 16 px. Below 64 px use icon-small.svg (no ticks, wider gap)</div></div>
</div>

<h2>2. Palette and contrast (WCAG, computed from the hex values)</h2>
<div class="pal">{''.join(swatch(*p) for p in PAL)}</div>
<p class="cap">Body text uses Ink and Muted (AA or better). Violet and the ticks are graphic colours: 3:1 is the bar for graphics, so never set body text in them. The ticks are decoration, never the only carrier of meaning. No gradients, shadows or glows in the mark.</p>

<h2>3. Type</h2>
<div class="two"><div><p style="font-size:34px;font-weight:700">JetBrains Mono</p><p>Bold for headings, regular for body. It is Omarchy's own default font (SIL OFL licence), so the project looks at home on the desktop it targets. Fallback: any monospace.</p></div>
<div><p>The wordmark <b>omagnet</b> is drawn as vector strokes, not set in a font. Always lowercase, one word, the <code>o</code> in violet. Say it "oh-magnet".</p>{rd('wordmark-light.svg').replace('height="100"','height="70"')}</div></div>

<h2>4. Spacing and shape</h2>
<ul class="mono"><li>Base unit 8 px. Card padding 8% of the width, gaps 16 or 24 px.</li><li>Clear space around the mark: the width of one ring arm (1/8 of the glyph width) on every side. Keep it at least that, more is fine.</li><li>Minimum size: 16 px for the icon (small variant), 96 px wide for the lockup.</li><li>Rounded corners everywhere, like the mark: tile radius 19% of its width, chips 10 to 14 px.</li></ul>

<h2>5. Do and do not</h2>
<div class="two">
<ul class="do"><li>Use the dark icon tile for app and avatar slots, the glyph for flat backgrounds.</li><li>Use the light-background files on light pages (<code>*-light.*</code>).</li><li>Write the name in lowercase: omagnet.</li><li>Say "Magnet-style snapping for Omarchy" and keep the not-affiliated line near it.</li><li>Keep text short and plain: numbers and key names, not hype.</li></ul>
<ul class="dont"><li>Recolour the mark, stretch it, rotate it, or add a glow or shadow.</li><li>Use Magnet's blue square or tile layout, or Omarchy's logo or green.</li><li>Put the dark-ground glyph on a light or busy background (use the light glyph).</li><li>Write OMagnet, Omagnet or O-Magnet.</li><li>Imply that Omarchy, Magnet or its makers endorse the project.</li><li>Use an em-dash or en-dash in any text.</li></ul></div>
<p class="cap" style="margin-top:36px">Source: branding/tools (logo.py, kit.py, social.py, sheet.py). Artwork released with the project under MIT. Colours checked {len(PAL)} pairs.</p>"""
out = os.path.join(ROOT, "brand-sheet.html"); open(out, "w").write(html)
subprocess.run(["chromium", "--headless", "--no-sandbox", "--hide-scrollbars", "--force-device-scale-factor=1", "--window-size=1600,2150", f"--screenshot={os.path.join(ROOT,'brand-sheet.png')}", "file://" + out], check=True, capture_output=True)
print("brand-sheet written")
