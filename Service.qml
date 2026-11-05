import QtQuick
import Quickshell
import "Paths.js" as Paths

// Installs the launcher entry so the settings panel is reachable from SUPER+SPACE.
// Same idiom as bobbynicholas.omaland/Service.qml: Omarchy has no install hook, so the service
// writes a .desktop file at load and removes it at destruction. Only a file carrying the
// X-Omagnet-Managed marker is ever written over or deleted.
//
// The config file itself is read and written by SettingsStore.qml inside SettingsPanel.qml, not here: a
// third-party panel is only handed its own service through a scoped facade that could not be
// tested without installing the plugin, so the panel owns its I/O (as Omaland's does).
QtObject {
  id: root

  property string omarchyPath: ""
  property var shell: null
  property var manifest: null

  // Resolved from this file's own URL: the shell strips __sourceDir from third-party manifests.
  readonly property string source: Paths.fromUrl(Qt.resolvedUrl("omagnet.desktop"))
  readonly property string dest: Quickshell.env("HOME") + "/.local/share/applications/omagnet.desktop"
  readonly property string marker: "^X-Omagnet-Managed=true$"

  readonly property string installScript:
      '[ -f "$1" ] || exit 0\n'
    + 'if [ -e "$2" ] && ! grep -q "$3" "$2"; then exit 0; fi\n'
    + 'mkdir -p "${2%/*}" || exit 0\n'
    + 'tmp=$2.omagnet.new\n'
    + 'cp "$1" "$tmp" || exit 0\n'
    + 'if cmp -s "$tmp" "$2"; then rm -f "$tmp"; else mv -f "$tmp" "$2"; fi\n'

  readonly property string removeScript:
    'grep -q "$2" "$1" 2>/dev/null && rm -f "$1"\n'

  property bool installed: false

  Component.onCompleted: {
    if (source === "") return
    installed = true
    Quickshell.execDetached(["sh", "-c", installScript, "sh", source, dest, marker])
  }

  // Reached on disable and on remove alike.
  Component.onDestruction: {
    if (!installed) return
    Quickshell.execDetached(["sh", "-c", removeScript, "sh", dest, marker])
  }
}
