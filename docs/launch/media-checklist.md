# Media checklist: what goes where

| Place | File | Size | Notes |
|-------|------|------|-------|
| GitHub social preview | `branding/social/github-social-preview.png` | 1280x640 | Manual upload in repo settings |
| README header | `branding/social/banner-dark.png`, `banner-light.png` | 1600x400 | Already in the README with a light/dark `<picture>` |
| README demo | `branding/demo/demo.gif` | 960 wide, under 0.5 MB | Already in the README |
| Omarchy marketplace card | `preview.png` (repo root) | 1280x640 | Logo, tagline and the settings window |
| README, grid zones | `branding/demo/zones.gif` | 960 wide, 1.7 MB | Recorded on a real external monitor: `python3 branding/tools/demo_zones.py` |
| Release page | `branding/demo/demo.gif`, `branding/demo/demo.mp4` | | GIF inline in the notes, MP4 as an attachment |
| LinkedIn post image | `branding/social/card-linkedin.png` | 1200x627 | Or attach `demo.mp4` for motion |
| X, Bluesky, Mastodon | `branding/social/card-x.png` | 1600x900 | Or the GIF (under 15 MB limits) |
| Reddit | `branding/demo/demo.gif` | | Upload as an image or video post, put the repo link in a comment |
| Square (Instagram, Slack, Discord) | `branding/social/card-square.png` | 1080x1080 | |
| Wide card, light | `branding/social/card-wide-light.png` | 1200x630 | For light pages and decks |
| Avatar | `branding/social/avatar-400.png` | 400x400 | |
| Favicon, app icon | `branding/logo/favicon.ico`, `icon-*.png` | 16 to 1024 | |
| Settings screenshots | `branding/screens/settings-top.png`, `settings-bottom.png` | 1280x1360 | Cropped to the window, nothing else on screen |
| Layout editor screenshots | `branding/screens/layouts-*.png` | 1280x1360 | Cropped to the window; taken by hand in the real shell |
| Terminal banner | `branding/terminal/banner.txt`, `banner.ansi` | | Plain text or violet o |
| Brand sheet | `branding/brand-sheet.png` | 1600x2150 | Palette, contrast ratios, type, do and do not |

Rebuild everything: `python3 branding/tools/logo.py && python3 branding/tools/kit.py && python3 branding/tools/social.py && python3 branding/tools/sheet.py`. The demo needs a live Hyprland session: `python3 branding/tools/demo.py` (about a minute, keep your hands off the machine).
