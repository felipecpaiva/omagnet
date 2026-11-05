# omagnet settings (Omarchy plugin)

A settings panel for omagnet, Magnet-style window snapping for Omarchy floating workspaces. It edits
`~/.config/omagnet/config.toml` (format: [docs/config.md](../docs/config.md)), keeps anything it does
not edit (unknown keys, unknown sections, your `[cmd_*]` positions), and asks the running Lua module to
re-read the file with `hyprctl eval "_G.omagnet.reload_config()"`. Changes to shortcuts need a Hyprland
reload, so the panel shows a "Reload Hyprland" button instead of doing it silently.

It adds nothing to the Omarchy bar. It adds one launcher entry, `omagnet`, written to
`~/.local/share/applications/omagnet.desktop` while the plugin is enabled (only if that file is absent or
carries the `X-Omagnet-Managed=true` marker) and removed when the plugin is disabled.

## Install (manual, for now)

Installing with `omarchy plugin add` from this folder is not decided yet. Until then, copy or symlink
this folder to `~/.config/omarchy/plugins/io.github.felipecpaiva.omagnet`, then:

```
omarchy plugin enable io.github.felipecpaiva.omagnet
```

Open it from the launcher (search "omagnet") or with `omarchy-shell shell toggle io.github.felipecpaiva.omagnet`.
Remove it with `omarchy plugin disable io.github.felipecpaiva.omagnet` and delete the folder.

## Files

- `ConfigIO.js`: parse, merge, serialize. Pure JavaScript, mirrors `prototype/config.lua`.
- `SettingsStore.qml`: reads and writes the file, triggers the live re-read.
- `SettingsPanel.qml`, `Service.qml`, `omagnet.desktop`, `Paths.js`: the panel, the launcher entry, helpers.

## Tests

```
node plugin/tests/config_io.test.mjs
```

No install needed. If `lua` is on the PATH it also runs the same inputs (including those in
`prototype/test_config.lua`) through `prototype/config.lua` and compares the merged result.

## Developing

Copy the folder into `~/.config/omarchy/plugins/io.github.felipecpaiva.omagnet` after every change. The first time a
plugin is added, restart the shell once (`omarchy restart shell`); a failed compile is cached until then. Look for
`unavailable` and `Cannot` in the shell's log. Omarchy's theme picker pops up whenever the shell reloads; press
Escape to close it.

