# Marketplace listing (draft, do not submit without the maintainer's go)

The marketplace is `omacom/omarchy-plugin-marketplace`. It reads `manifest.json` and the root `preview.png`, and generates the card images itself. The rules are in its `SUBMISSION.md` (read 2026-11-05). Category and tags must come from fixed lists, and an earlier draft of this file used values that are not on them.

## Checks against SUBMISSION.md

| Rule | Status |
|------|--------|
| Public repo, one plugin, `manifest.json` in the root | ok |
| Root README with install and removal | ok |
| Root licence file | ok (`LICENSE`, MIT) |
| External dependencies documented | ok (README "Requirements", added 2026-11-05) |
| Unique ID outside `omarchy.*` | `io.github.felipecpaiva.omagnet`, not searched in the marketplace yet |
| Does not overwrite user config without consent | ok, it never edits `hyprland.lua`; the user adds one line |
| Optional `preview.png` in the root | ok (1280x640) |
| Passes Omarchy's own validation | `omarchy plugin validate .` passes |

Before submitting: search the marketplace for the ID (the ID is permanent once listed).

## Listing values

- **Category:** `Desktop` (second choice: `Productivity`)
- **Tags (1 to 3):** `hyprland`, `workspaces`, `quickshell`
- **Suggest a missing tag:** `window-management` (there is no tag for snapping or tiling)

## Maintainer notes (goes in the form)

Magnet-style window snapping for floating workspaces. The plugin is the settings window; the snapping itself is a pure Lua file loaded from `hyprland.lua` with one guarded line the user adds (the plugin does not edit that file). Nothing is added to the bar unless the user turns the optional icon on. No native module. Not affiliated with Omarchy or Magnet.

Known limits: drags started from an app's own title bar are not seen, and real second monitors are untested.

## Submit from the command line (when approved)

```bash
cat > "$CLAUDE_JOB_DIR/tmp/submission.md" <<'BODY'
### Repository URL

https://github.com/felipecpaiva/omagnet

### Category

Desktop

### Tags

hyprland, workspaces, quickshell

### Suggest a missing tag

window-management

### Maintainer notes

(the paragraph above)

### Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
BODY
```

SUBMISSION.md says the title and body format decide the labels. Read the rest of that file for the exact `gh issue create` title format before running it.
