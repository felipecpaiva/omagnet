# Omarchy app and plugin stack for omagnet

Status as of 2026-11-05. Studied on Omarchy 4.5.0-3, Hyprland 0.56.2, read-only: nothing under
`/usr/share/omarchy` was edited and nothing was installed.

Evidence labels used on every claim:

- **read from source**: a file on this machine or in the public marketplace repo, with path and line.
- **tested**: a command was run and its output seen.
- **from docs only**: stated by a skill or README, not confirmed against code.

`$OMARCHY` below means `/usr/share/omarchy`. `~` is the user's home.

## 1. The three shapes for the settings app

### 1a. Qt Quick / C++ standalone app (like Hype, Monologue, Omacut)

| Question | Answer | Evidence |
|---|---|---|
| Effort | Highest. C++ backend (`QObject`), QML window, qmake `.pro`, `Theme` and `Translator` classes, Qt Test binary, PKGBUILD, icon, `.desktop`. The skill lists about 15 files before any feature code. | from docs only (`omarchy-app` skill, SKILL.md "Shape") |
| Theme | Reads `accent` from `~/.local/state/omarchy/current/theme/colors.toml`, watched with `QFileSystemWatcher`, re-armed on every change because a theme switch replaces files. Rounding is read from `hyprctl`. Fallback accent `#FFD60A`. | from docs only (skill + `templates.md` `Theme` class). The colors file itself exists and has `accent`, `background`, `foreground` keys: tested (`head colors.toml`) |
| Packaging | PKGBUILD that runs `bin/build` and installs the binary, license, icon and `.desktop` under `/usr`. The three real packages are in the `omarchy` pacman repo (`pkgs.omarchy.org`), packager "Omarchy". | read from `pacman -Qi omacut hype monologue` (all MIT, depend on `qt6-base`, `qt6-declarative`, `xdg-desktop-portal`, ...) and `pacman -Si omacut` -> `Repository : omarchy`: tested |
| Getting into that repo | PR to `omacom/omarchy-pkgs` under `pkgbuilds/<name>/` with `.omarchy/package.json`. Only the Omarchy team ships it on installs. For anyone else the options are AUR (`yay` is installed here) or a local `makepkg -fsi`. | from docs only (skill "README and release"); `yay` present: tested (`which yay`) |
| Launcher | `/usr/share/applications/<name>.desktop`; the shell's app library is `DesktopEntries.applications`. | read from source: `$OMARCHY/shell/services/AppLibrary.qml:43` and `:53`; `omacut.desktop` content: tested |
| Update | `pacman -Syu` after each release plus a pkgs PR or AUR bump. Needs a compiled binary per architecture. | from docs only |
| Fit for a bar toggle | Good. An external process can call `omarchy plugin enable/disable` and `omarchy bar put`, because those go through shell IPC. | read from source: `omarchy-plugin-enable`, `omarchy-bar` `cmd_put` |
| Marketplace | Cannot be listed: a listing is one public repo with `manifest.json` at its root. A required native binary makes the listing "manual setup". | read from marketplace `SUBMISSION.md` and `AGENTS.md` (line 148) |

### 1b. Quickshell shell plugin with a settings panel

Six plugins already live in `~/.config/omarchy/plugins/` and are worked examples. The closest is a
settings-style panel that writes Hyprland Lua (Omaland) and a bar-configurator panel of ours.

| Question | Answer | Evidence |
|---|---|---|
| Effort | Lowest of the GUI options. One `manifest.json`, `Panel.qml`, optional `Service.qml`, optional `BarWidget.qml`. No compile step. Real panels are 27 KB (Omaland `Panel.qml`) and 49 KB (the configurator) of QML, so a settings page for omagnet is smaller than both. | read from source: file sizes, `ls -la` of each plugin |
| Manifest | `schemaVersion: 1`, `id`, `name`, `version`, `kinds`, `entryPoints`. Valid kinds: `bar`, `bar-widget`, `menu`, `overlay`, `panel`, `service`; each kind needs its entry point. No symlinks inside the folder. `omarchy.*` ids are reserved. | read from source: `$OMARCHY/bin/omarchy-plugin-validate:59-116` |
| Validation | `omarchy plugin validate <folder>` printed no error and exited 0 on the Omaland plugin. | tested |
| Theme | Automatic and live. Colors and sizes come from `qs.Commons` (`Color`, `Style`) and the `qs.Ui` kit (`Panel`, `KeyboardPanel`, `Button`, `ToggleSwitch`, `PanelSlider`, `Dropdown`, `NumberField`, `Toggle`). `Color.qml` reads `colors.toml` from the current theme. Durations must go through `Style.duration()`. | read from source: `$OMARCHY/shell/Commons/Color.qml:8,228-231`, `$OMARCHY/shell/Ui/` listing, skill `plugins.md` "Plugin Motion"; Omaland `Panel.qml` imports `qs.Commons` and `qs.Ui` |
| Translations | `i18n/<code>.json` beside the QML, read through `Commons.Translations`; missing keys fall back to base language then `en.json`. | from docs only (skill `plugins.md` "Translations") |
| Safety rule | Plugins run unsandboxed in the shell process. Bind plain text with `textFormat: Text.PlainText`. | from docs only (skill `plugins.md` "Plugin UI Safety") |
| Hot reload | Saving a file under `~/.config/omarchy/plugins/` reloads plugin code; fallback `omarchy-shell shell rescanPlugins`. | from docs only (skill `plugins.md`); `rescanPlugins` exists: read from source `$OMARCHY/shell/shell.qml:1796` |
| Packaging and install | A git repo with `manifest.json` at its root. `omarchy plugin add <git-url> --enable --yes` clones into `~/.config/omarchy/plugins/<id>/`. `omarchy plugin update` does `git fetch` and compares `HEAD` to `FETCH_HEAD` (so it updates to the default branch head). | read from source: `omarchy-plugin-add`, `omarchy-plugin-update:43-48`; `omarchy plugin --help`: tested |
| Launcher entry | A plugin gets no launcher entry by itself. Two existing plugins add one the same way: a `.desktop` in `~/.local/share/applications/` with `Exec=omarchy-shell shell toggle <id>`, written either by `install.sh` (configurator) or by the plugin's `Service.qml` at load and removed at destruction (Omaland, guarded by an `X-...-Managed=true` marker). | read from source: both plugins' `.desktop`, `install.sh`, Omaland `Service.qml` |
| Panel can be summoned only if enabled | `summon` refuses a plugin that is not enabled. | read from source: `$OMARCHY/shell/shell.qml:1192-1196` |
| Update story | `omarchy plugin update` (git pull) or marketplace re-verify of a newer commit. No compile, no per-arch build, no sudo. | read from source (above) and marketplace `SUBMISSION.md` "Update an existing listing" |
| Marketplace | Fits exactly: one public repo, root `manifest.json`, README with install and removal, root license. | read from marketplace `SUBMISSION.md` |
| Weakness | Tied to Quickshell internals. The configurator's notes record a 4.x change that stripped `__sourceDir` from the manifest handed to third parties (Omaland `Paths.js` works around it with `Qt.resolvedUrl`). Plugin APIs can change between Omarchy releases. | read from source: Omaland `Paths.js` comment |

### 1c. TUI or script

| Question | Answer | Evidence |
|---|---|---|
| Effort | Smallest: a bash script with `gum` (already used by Omarchy's own plugin scripts: `gum choose`, `gum confirm`). | read from source: `omarchy-plugin-add` |
| Theme | Inherited from the terminal. Omarchy themes the terminal, and `omarchy.current.theme.gum_env` is loaded by Hyprland's env setup for gum styling. | read from source: `$OMARCHY/default/hypr/envs.lua:5` |
| Launcher | `.desktop` with `Exec=omarchy-launch-tui <cmd>` (opens the default terminal with an app id). | read from source: `$OMARCHY/bin/omarchy-launch-tui` |
| Packaging and update | Any of the above: a plugin-less repo with `install.sh`, an AUR `-git` package, or shipped inside the plugin folder. Updates by `git pull` or the package manager. | from docs only |
| Weakness | No sliders, no live preview, no key capture for recording a shortcut. Poor match for "a small settings app like Omarchy's". | judgement |

## 2. Optional bar widget, off by default, toggled from the settings app

What the code does (all read from source):

- `omarchy plugin enable <id>` goes to `PluginRegistry.setEnabled` (`$OMARCHY/shell/services/PluginRegistry.qml:497`).
  If the manifest lists `bar-widget` and the id is not already in `bar.layout`, it splices
  `{ "id": ... }` into the manifest's `barWidget.defaultSection` (`:560-571`). It does **not** add it to `plugins[]`
  in that case.
- If the manifest has no `bar-widget` kind, enabling appends `{ "id": ... }` to `plugins[]` (`:573-575`).
  Omaland and the configurator use this path: `kinds: ["panel"...]`, so no bar slot.
- `omarchy plugin disable <id>` removes the `bar.layout` entry or the `plugins[]` entry (`:588-589`).
  The entry object, with any inline settings, is discarded. A hide/show must therefore store the whole
  entry itself (a prior finding of ours, recorded in the configurator's `FINDINGS.md`).
- A plugin is enabled when its id is found in `bar.layout.*` or `plugins[]` (`:148-165`). A disabled plugin
  cannot be summoned (`shell.qml:1192`). **So a single plugin whose only bar entry is removed also loses its
  panel and service.**
- A plugin that lists `panel` is opened by the panel loader, not through the bar
  (`shell.qml:1167-1176`), so a multi-kind plugin can be both `bar-widget` and `panel`.
- A panel plugin cannot mutate `bar.layout` itself: the config mutator is gated to `kinds: ["bar"]`
  (configurator `FINDINGS.md`, citing `shell.qml:639` and `:354-356`). It must shell out to the CLI.
- `omarchy bar put <id> [--section S] [--after X]` places a widget only if it is not already on the bar
  (`omarchy-bar` `cmd_put`). `omarchy bar move`, `omarchy bar set <id> <key> <value>` and
  `omarchy bar get` exist. `omarchy bar --help`: tested.
- A manifest may declare `barWidget.defaultSection` (`left, centerBegin, center, centerEnd, tray, right`, checked at
  `omarchy-plugin-validate:70-81`), `allowMultiple`, `displayName`, and a `schema` array of settings
  (`bool`, `enum`, ... with `default`), seen in the Spaces plugin manifest.
- A bar widget can hide itself. `SystemUpdate.qml:23` sets `visible: updateAvailable`, and the bar's
  placeholder for an empty slot is `Item { implicitWidth: 0; visible: false }` (`Bar.qml:2017`).

Three ways to make the icon optional, with the trade-off:

| Option | How | Cost |
|---|---|---|
| **A. Self-hiding widget (recommended)** | One plugin, `kinds: ["panel", "service", "bar-widget"]`. `BarWidget.qml` sets `visible`, `implicitWidth` and `implicitHeight` to 0 unless the user config says `bar_icon = true`. The app's toggle writes the config; nothing in `shell.json` changes. | `omarchy plugin add --enable` puts an invisible `{ "id": ... }` entry into `bar.layout`, so `shell.json` does list the widget even while the icon is off. No visible bar change, but "adds nothing to the bar by default" holds only for what the user sees. Whether an invisible widget leaves any gap or margin in a real bar was **not tested**; the `SystemUpdate` and empty-slot code suggest it does not. |
| B. Two plugins | `<id>` (`panel`, `service`) and `<id>-bar` (`bar-widget` only). The settings app runs `omarchy bar put <id>-bar --section right` and `omarchy plugin disable <id>-bar`. Cleanest `shell.json`. | One marketplace listing is one repo with one root `manifest.json`; a second plugin folder would have to be created by `Service.qml` or `install.sh` (precedent for a service writing outside its folder: Omaland's `.desktop`). Marketplace says multi-plugin sources exist ("promoted source-wide") but new submissions are single-plugin roots. Not tested. |
| C. Command module in `shell.json` | A `type: "command"` or `type: "qml"` custom module entry. | The app would edit `shell.json` directly; no CLI removes a non-plugin id. Rejected. |

## 3. Where user config lives, and a format Lua and Qt both read

Where:

- `~/.config/omagnet/config.toml`. Reasons: `shell.json` belongs to the shell (the config mutator rewrites
  it from memory, and `disable` discards inline settings); a hidden-widget store in `~/.config/omarchy/` already
  exists as a precedent for an own-file approach (`oma-bar-configurator.json`, configurator `Panel.qml:423`);
  Omarchy's Hyprland side already resolves `~/.config/<tool>/...` through `paths.config_home`
  (`$OMARCHY/default/hypr/paths.lua`, and `dictation-backend.lua:16-20` loads `<config_home>/<backend>/shortcuts.lua`).
  All read from source.
- Respect `XDG_CONFIG_HOME` the way `paths.lua` does (set but empty means unset).

Format comparison:

| Format | Lua (inside Hyprland) | Qt / QML | Verdict |
|---|---|---|---|
| JSON | No JSON helper found in Omarchy's Lua (`grep json default/hypr`: only a `colors.toml` mention). Needs a hand-written parser. Not tested in Hyprland. | Trivial (`JSON.parse`, `QJsonDocument`) | Poor for Lua |
| Lua table file (`return {...}`) | Native, `dofile` | No parser; Omaland works around it by running a Lua script that records what the file sets (`read.lua`) | Heavy for the app |
| **Flat TOML subset** (`key = value`, optional `[section]`, strings, numbers, booleans) | About 15 lines of `line:match`. Omarchy already does this for `colors.toml` (`workspace-modes.lua:417-424`) | A small parser in QML/JS, or `QSettings` in INI mode for C++ | **Recommended**: matches what Omarchy themes already use, human editable, no new dependency |

The app writes the file atomically (temp file and rename). After a write it calls `hyprctl reload` and then
`hyprctl configerrors`, the validation Omarchy's own skill requires (`hyprland.md`); Omaland uses `hyprctl eval`
for live preview of the same Lua it saves (Omaland README, "How it works"; from docs only).

## 4. Loading a Lua module without editing the user's files

How Hyprland's Lua path is built (read from source, `$OMARCHY/default/hypr/bootstrap.lua:33-40`):
`package.path` is `~/.local/state/?.lua;~/.config/?.lua;$OMARCHY_PATH/?.lua;<default>`. Modules under the prefixes
`default.hypr`, `hypr` and `omarchy.current.theme` are un-cached on every reload (`bootstrap.lua:6-31`).
Dots in a module name become slashes, and there is no `?/init.lua` template, so `require("omagnet.init")` finds
`~/.config/omagnet/init.lua` and `require("omagnet")` finds `~/.config/omagnet.lua`.

The user's `hyprland.lua` requires only fixed names (`hypr.monitors`, `hypr.bindings`, `default.hypr.toggles`, ...).
Omarchy hooks are shell scripts for events such as `theme-set`, `post-update`, `post-boot`
(skill `hooks.md`, from docs only); none of them loads Lua.

| Option | What it takes | Touches user files? | Status |
|---|---|---|---|
| **1. Drop-in in the toggles folder** | `default/hypr/toggles.lua` puts `~/.local/state/omarchy/toggles/hypr` on `package.path` and requires **every** `*.lua` there on each reload (`toggles.lua:5-11`, via `require_all.files`). `Service.qml` copies a tiny `omagnet.lua` there that does `dofile(<plugin dir>/lua/omagnet/init.lua)` inside `pcall`. Same idea as Omaland's service writing its `.desktop`. | No user-edited file | Read from source only, **not tested**. The folder is documented in its own `flags.lua` as "permanent config toggle flags"; it is Omarchy's, not a public extension point, and a migration may delete files by name. Fragile across Omarchy updates. |
| 2. One `require` line in `~/.config/hypr/hyprland.lua` | `require("omagnet")` after `require("hypr.bindings")`; module at `~/.config/omagnet.lua` or `dofile` to the plugin folder. | Yes, one line, with consent | Always works; the `.lua` files are the supported place for overrides (skill `hyprland.md`). |
| 3. Fenced managed block | What Omaland does in `looknfeel.lua` and `hyprland.lua`: text between `-- >>> omaland managed block >>>` fences, nothing outside touched, removable. | Yes, with consent | Proven by Omaland (its README), not tested by us. |

Recommendation: ship option 2 as the documented, supported path (the app offers a button "Add to hyprland.lua"
that writes the fenced block, shows the diff, and can remove it), and treat option 1 as an opt-in experiment to
test on a clean Omarchy before relying on it. Never write to `~/.config/hypr/*.lua` without that explicit
consent: the marketplace checklist forbids overwriting user configuration without it (section 5).

## 5. Marketplace norms

Read from source: `omacom/omarchy-plugin-marketplace` (`README.md`, `SUBMISSION.md`, `AGENTS.md`, `NOTICE.md`).

- One public GitHub repo per plugin, root URL, with `manifest.json`, a README and a license file **at the root**.
- README must give installation **and removal** instructions, and document the license and any external dependencies.
- Plugin id is permanent and globally unique, outside `omarchy.*`; the marketplace suggests
  `io.github.<name>.<plugin>`. Retired ids cannot be reused.
- One category from: Appearance, Desktop, Developer Tools, Hardware, Kids, Productivity, System, Widgets, Other.
  One to three tags from: ai, bar, education, games, hyprland, kids, launcher, media, power-management,
  quickshell, security, system, vpn, workspaces. Likely for omagnet: category `Desktop`, tags `hyprland`,
  `quickshell`, `workspaces`. Add `bar` only if the icon is a headline feature.
- Optional `preview.png` (or jpg, jpeg, webp, avif) at the root, max 50 MB and 40 megapixels.
- Submission checklist includes: "The plugin does not overwrite user configuration without explicit consent."
- Review is a static scan of the exact commit (`passed`, `review-required`, `needs-fixes`) plus maintainer
  approval; patterns checked include download-to-shell, unpinned external git execution, passwordless sudoers.
  `install.sh` scripts that run `sudo` or `curl | sh` would be flagged.
- Marketplace install and update commands clone mutable upstream HEAD and are not tied to the reviewed SHA.
- A listing that needs a native binary or a mandatory build before enabling gets a manual-setup override.
- License: no license is mandated by the marketplace beyond "a root license file". All existing plugins here
  carry MIT (the Omaland `LICENSE` is the MIT text) and Omarchy's own apps are MIT (`pacman -Qi`: tested).
  The repo already has a `LICENSE`; keep it MIT for consistency and so the Omarchy repo could adopt it.
- Third-party code needs its own notice: the marketplace keeps a `THIRD_PARTY_NOTICES.md`; the skill asks for
  attribution on copied code (for example Omacut's portal file picker).

## 6. Recommendation

Build **shape 1b: one Quickshell plugin**, with the optional bar icon as the self-hiding widget (option A in
section 2), config in `~/.config/omagnet/config.toml` (section 3), and the Lua module loaded by a consented
`require` line (option 2 in section 4), with the toggles-folder drop-in tested later as a convenience.

Why:

- It is the only shape that follows the theme, translations and motion of the shell for free, installs with
  `omarchy plugin add`, updates with `omarchy plugin update`, needs no compiler or packager, and can be listed
  in the marketplace.
- A Qt app is the stronger long-term "same as Omacut" story and can drive the bar CLI from outside, but it
  needs a binary release, a package, and a PR to Omarchy's package repo for non-manual installs. Keep it as the
  later migration path: `config.toml` and the Lua module do not change if the front end is swapped.
- A TUI cannot record a shortcut or show a layout preview, which a Magnet-style settings page needs.

Open items before coding (none tested yet):

1. Confirm an invisible bar widget leaves no gap or margin in the real bar.
2. Confirm option 1 (toggles drop-in) survives `hyprctl reload` and `omarchy update`.
3. Confirm Hyprland re-registers `o.bind` / `hl.bind` cleanly when the module re-runs on reload.
4. Pick the plugin id (for example `io.github.<owner>.omagnet`) and search the marketplace for conflicts.

### Folder layout that follows

```text
manifest.json              id, kinds ["panel","service","bar-widget"], entryPoints, barWidget.defaultSection
Panel.qml                  settings app: shortcuts, snap sizes, gaps, bar icon on/off, "add to hyprland.lua"
Service.qml                installs/removes the launcher .desktop (marker-guarded); watches config.toml
BarWidget.qml              hidden unless bar_icon = true; click opens the panel
Config.js                  parse and write the flat TOML subset; one source of truth for keys and defaults
i18n/en.json               strings (add languages one file at a time)
omagnet.desktop            Exec=omarchy-shell shell toggle <id>, Categories=Settings;DesktopSettings;
icon.svg
lua/omagnet/init.lua       entry point required from hyprland.lua; reads config, registers binds and drag hooks
lua/omagnet/config.lua     reads ~/.config/omagnet/config.toml with the 15-line parser
lua/omagnet/snap.lua       pure geometry (rects for halves, thirds, quarters), no hl.* calls
test/                      plain `lua` tests for config.lua and snap.lua; QML parser test for Config.js
scripts/install.sh         optional: copy to plugins dir, validate, enable (no sudo)
scripts/uninstall.sh       remove plugin, .desktop and the fenced block, only if marked as ours
docs/                      architecture.md, research/, magnet-reference/
preview.png                real screenshot for the marketplace card
README.md                  install, removal, dependencies, what it writes and where
LICENSE                    MIT
```

Constraint from `omarchy-plugin-validate:116`: no symlinks anywhere in this folder.
