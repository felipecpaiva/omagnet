import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "ConfigIO.js" as ConfigIO

// Optional bar icon. Omarchy puts a widget entry on the bar when the plugin is enabled, so this one
// hides itself: invisible and zero size (no slot, no gap) unless bar_icon = true in the config.
BarWidget {
  id: root
  moduleName: "io.github.felipecpaiva.omagnet"

  property var model: ({})
  readonly property bool shown: ConfigIO.merge(model).bar_icon === true

  visible: shown
  implicitWidth: shown ? button.implicitWidth : 0
  implicitHeight: shown ? button.implicitHeight : 0

  FileView {
    id: file
    path: Quickshell.env("HOME") + "/.config/omagnet/config.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.model = ConfigIO.parse(text()).root
    onLoadFailed: root.model = ({})
  }

  // A watcher on a file that does not exist yet never hears that it gets created, and on a fresh install the settings
  // window creates the file the first time the icon is switched on. So the (tiny) file is also read every 2 seconds.
  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: file.reload()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\udb81\udd6e"
    tooltipText: "omagnet"
    onPressed: function(mouseButton) {
      if (root.bar && mouseButton === Qt.LeftButton) root.bar.run("omarchy-shell shell toggle io.github.felipecpaiva.omagnet")
    }
  }
}
