// omagnet drag overlay: one transparent, click-through, focus-less layer window per monitor.
// It draws a rounded outline where the dragged window will land and, when "highlight" is on, a faint strip for
// every drag zone. The Lua side writes three small files into $XDG_RUNTIME_DIR:
//   omagnet-preview  "<monitor> <x> <y> <w> <h>" (monitor-local logical pixels), or empty for no target
//   omagnet-style    "<outline px> <#rrggbb or -> <fill 0..1> <zone outline px>"   (- means the theme's accent colour)
//   omagnet-zones    one "<monitor> <x> <y> <w> <h>" line per zone strip, or empty
// Run with:  qs -p lua/preview.qml
// shortcut: reads the theme accent colour once at start, so a theme change shows after the next drag.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  id: root

  property string stateText: ""
  property string styleText: ""
  property string zonesText: ""
  property color accent: "#7aa2f7"

  readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR")
  readonly property var styleParts: styleText.split(/\s+/)
  readonly property bool styled: styleParts.length === 4
  readonly property int outline: styled ? Number(styleParts[0]) : 2
  readonly property color tint: styled && /^#[0-9a-fA-F]{6}$/.test(styleParts[1]) ? styleParts[1] : accent
  readonly property real fill: styled ? Number(styleParts[2]) : 0.18
  readonly property int zoneOutline: styled ? Number(styleParts[3]) : 4
  readonly property var zoneLines: zonesText === "" ? [] : zonesText.split("\n")

  FileView {
    path: root.runtime + "/omagnet-preview"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.stateText = text().trim()
    onLoadFailed: root.stateText = ""
  }

  FileView {
    path: root.runtime + "/omagnet-style"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.styleText = text().trim()
    onLoadFailed: root.styleText = ""
  }

  FileView {
    path: root.runtime + "/omagnet-zones"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.zonesText = text().trim()
    onLoadFailed: root.zonesText = ""
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

      // The zone strips (only with the "highlight" setting)
      Repeater {
        model: root.zoneLines
        Rectangle {
          required property string modelData
          readonly property var q: modelData.split(" ")
          visible: q.length === 5 && q[0] === win.screen.name
          x: visible ? Number(q[1]) : 0
          y: visible ? Number(q[2]) : 0
          width: visible ? Number(q[3]) : 0
          height: visible ? Number(q[4]) : 0
          radius: 6
          color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.10)
          border.color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.55)
          border.width: root.zoneOutline
        }
      }

      // Where the window will land
      Rectangle {
        visible: win.active
        x: win.active ? Number(win.parts[1]) : 0
        y: win.active ? Number(win.parts[2]) : 0
        width: win.active ? Number(win.parts[3]) : 0
        height: win.active ? Number(win.parts[4]) : 0
        radius: 10
        color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, root.fill)
        border.color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.9)
        border.width: root.outline
      }
    }
  }
}
