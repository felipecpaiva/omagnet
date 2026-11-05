// omagnet snap preview: one transparent, click-through, focus-less layer window per monitor.
// It draws a rounded outline where the dragged window will land. The Lua side writes one line to
// $XDG_RUNTIME_DIR/omagnet-preview: "<monitor> <x> <y> <w> <h>" (monitor-local logical pixels), or
// an empty file to hide. Run with:  qs -p prototype/preview.qml
// shortcut: reads the accent color once at start, so a theme change shows after the next drag.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  id: root

  property string stateText: ""
  property color accent: "#7aa2f7"

  FileView {
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/omagnet-preview"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.stateText = text().trim()
    onLoadFailed: root.stateText = ""
  }

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    onLoaded: {
      var m = text().match(/^\s*accent\s*=\s*"(#[0-9a-fA-F]{6})"/m)
      if (m) root.accent = m[1]
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData

      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      mask: Region {} // click-through
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      WlrLayershell.namespace: "omagnet-preview"

      // "<monitor> x y w h"
      readonly property var parts: root.stateText.split(/\s+/)
      readonly property bool active: parts.length === 5 && parts[0] === modelData.name

      Rectangle {
        visible: win.active
        x: win.active ? Number(win.parts[1]) : 0
        y: win.active ? Number(win.parts[2]) : 0
        width: win.active ? Number(win.parts[3]) : 0
        height: win.active ? Number(win.parts[4]) : 0
        radius: 10
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.9)
        border.width: 2
      }
    }
  }
}
