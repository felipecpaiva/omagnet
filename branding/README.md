# omagnet branding

Four logo directions, made on 2026-11-05 so one can be chosen. Read [BRIEF.md](BRIEF.md) first: it says what the brand
must say and what must not be copied (Magnet's icon, Omarchy's logo).

| Folder | Idea |
|--------|------|
| `v1-notch/` | A pixel horseshoe magnet pulling a window, in a chamfered pixel tile. Terminal-native, a cousin of Omarchy's pixel look. |
| `v2-snapgrid/` | Four rounded quarters forming a square ring, one violet quarter clicking into place. Clean and neutral. |
| `v3-pole/` | A bold horseshoe magnet pulling a window toward its amber poles. Instantly a magnet; warm and friendly. |
| `v4-halfblock/` | A chunky pixel `o` followed by a terminal cursor block. The name, typed at a prompt. |

Each folder has: `icon.svg` (the real vector master), `icon-mono.svg` (one-colour stencil), `icon-512.png` and `icon-16.png`,
`concept.png` (a 1024 pixel render), `wordmark.svg` and `wordmark-light.svg`, `lockup.svg` and `lockup-light.svg`
(the `-light` files are for light backgrounds), and `notes.md` (idea, palette, why it differs from Magnet and Omarchy).
Files named `codex-*` are the first pictures and vectors the image model made, kept as a record where they were replaced.

## How they were made

- **Concepts and first vectors:** Codex (OpenAI) with its built-in image tool, one task per direction, from the brief.
- **Redrawn by hand:** `v1` and `v4`. The first concepts read as a beer mug and as a webcam, so they were redrawn on an
  exact 16 by 16 pixel grid with `tools/pixel.py`.
- **Wordmarks:** drawn as vector shapes by `tools/wordmark.py` (a monoline geometric alphabet and a pixel alphabet), so
  no font is needed. All seven letters of the name exist there and nothing else.
- **Comparison board:** `python3 tools/board.py` writes `board.html` and `board.png` (not committed). If you put the
  Omarchy and Magnet icons in `.refs/` (git-ignored, never committed: Magnet's icon is its makers' trademark) the board adds a
  "not confusable?" row.

Needs `rsvg-convert` (librsvg) and Chromium for the board. No Python packages.

## Licence

The artwork was made for this project and is released with it under the MIT licence, unless the maintainer chooses a
different licence for the brand. omagnet is not affiliated with or endorsed by Omarchy, or by Magnet or its makers.
