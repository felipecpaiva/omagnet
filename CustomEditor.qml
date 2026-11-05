import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "ConfigIO.js" as ConfigIO

// Custom positions: one row per [cmd_*] section, and a grid to draw a new one (press and drag across cells).
ColumnLayout {
  id: ed

  property var cfgStore: null
  property color foreground: "white"
  property color accent: "white"
  property string fontFamily: ""

  readonly property int cols: 24
  readonly property int rows: 14
  property bool picked: false           // a rectangle is selected
  property int c0: 0
  property int r0: 0
  property int c1: 0
  property int r1: 0
  property string editing: ""           // section loaded from a row, so "Update" may reuse its name

  readonly property string name: ConfigIO.customName(nameField.text)
  readonly property bool used: name !== "" && name !== editing && ed.cfgStore.model[name] !== undefined
  readonly property var rect: picked ? ConfigIO.gridRect(c0, r0, c1, r1, cols, rows) : null
  readonly property bool ready: name !== "" && !used && picked

  Layout.fillWidth: true
  spacing: Style.spacing.sm

  function faint(a) { return Qt.rgba(foreground.r, foreground.g, foreground.b, a) }

  function load(name, r) {
    var g = ConfigIO.rectGrid(r, cols, rows)
    c0 = g.c0; r0 = g.r0; c1 = g.c1; r1 = g.r1
    picked = true
    editing = name
    nameField.text = name.slice(4)
    keyField.text = ed.cfgStore.eff.keys[name] || ""
  }

  function add() {
    if (!ready) return
    ed.cfgStore.setCustom(name, rect, keyField.text)
    picked = false; editing = ""; nameField.text = ""; keyField.text = ""
  }

  // A rectangle drawn on a small grid. Used for the thumbnails; `r` is [x, y, w, h] or null.
  component Thumb: Rectangle {
    property var r: null
    width: Style.space(72)
    height: Style.space(42)
    color: ed.faint(0.08)
    border.width: 1
    border.color: ed.faint(0.4)
    Rectangle {
      visible: parent.r !== null
      x: parent.r ? parent.r[0] * parent.width : 0
      y: parent.r ? parent.r[1] * parent.height : 0
      width: parent.r ? parent.r[2] * parent.width : 0
      height: parent.r ? parent.r[3] * parent.height : 0
      color: ed.accent
      opacity: 0.7
    }
  }

  Text {
    Layout.fillWidth: true
    visible: ed.cfgStore.customList.length === 0
    text: "None defined."
    color: Qt.darker(ed.foreground, 1.6)
    font.family: ed.fontFamily
    font.pixelSize: Style.font.caption
  }

  Repeater {
    model: ed.cfgStore.customList
    RowLayout {
      required property var modelData
      readonly property var pos: ed.cfgStore.eff.custom[modelData.name] || null
      Layout.fillWidth: true
      spacing: Style.spacing.lg

      Text {
        Layout.preferredWidth: Style.space(130)
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: modelData.name + (modelData.valid ? "" : " (ignored)")
        color: modelData.valid ? ed.foreground : Color.urgent
        font.family: ed.fontFamily
        font.pixelSize: Style.font.body
      }
      Thumb {
        r: parent.pos
        MouseArea {
          anchors.fill: parent
          enabled: parent.r !== null
          cursorShape: Qt.PointingHandCursor
          onClicked: ed.load(modelData.name, { x: parent.r[0], y: parent.r[1], w: parent.r[2], h: parent.r[3] })
        }
      }
      TextField {
        Layout.fillWidth: true
        text: modelData.key
        placeholderText: "no shortcut"
        foreground: ed.foreground
        accent: ed.accent
        onEditingFinished: ed.cfgStore.setCustomKey(modelData.name, text)
      }
      PanelActionButton {
        iconText: "󰆴"
        tooltipText: "Delete " + modelData.name
        foreground: ed.foreground
        onClicked: { if (ed.editing === modelData.name) ed.editing = ""; ed.cfgStore.removeCustom(modelData.name) }
      }
    }
  }

  Text {
    Layout.fillWidth: true
    text: "Add a position. Press and drag across the grid to choose its size and place. Click a thumbnail above to change that one."
    wrapMode: Text.WordWrap
    color: Qt.darker(ed.foreground, 1.6)
    font.family: ed.fontFamily
    font.pixelSize: Style.font.caption
  }

  TextField {
    id: nameField
    Layout.fillWidth: true
    placeholderText: "name, for example wide centre"
    foreground: ed.foreground
    accent: ed.accent
  }

  Text {
    Layout.fillWidth: true
    visible: ed.used
    text: "That name is already used."
    color: Color.urgent
    font.family: ed.fontFamily
    font.pixelSize: Style.font.caption
  }

  Item {
    id: grid
    Layout.fillWidth: true
    Layout.preferredHeight: width * ed.rows / ed.cols
    readonly property real cw: width / ed.cols
    readonly property real ch: height / ed.rows

    Repeater {
      model: ed.cols * ed.rows
      Rectangle {
        required property int index
        readonly property int c: index % ed.cols
        readonly property int r: Math.floor(index / ed.cols)
        readonly property bool on: ed.picked && c >= Math.min(ed.c0, ed.c1) && c <= Math.max(ed.c0, ed.c1)
          && r >= Math.min(ed.r0, ed.r1) && r <= Math.max(ed.r0, ed.r1)
        x: c * grid.cw
        y: r * grid.ch
        width: grid.cw - 1
        height: grid.ch - 1
        color: on ? ed.accent : ed.faint(0.1)
      }
    }

    MouseArea {
      anchors.fill: parent
      function cell(v, size, n) { return Math.max(0, Math.min(n - 1, Math.floor(v / size))) }
      onPressed: function(m) {
        ed.c0 = ed.c1 = cell(m.x, grid.cw, ed.cols)
        ed.r0 = ed.r1 = cell(m.y, grid.ch, ed.rows)
        ed.picked = true
      }
      onPositionChanged: function(m) {
        if (!pressed) return
        ed.c1 = cell(m.x, grid.cw, ed.cols)
        ed.r1 = cell(m.y, grid.ch, ed.rows)
      }
    }
  }

  Text {
    Layout.fillWidth: true
    text: ed.rect ? "x " + ed.rect.x + "   y " + ed.rect.y + "   w " + ed.rect.w + "   h " + ed.rect.h : "No area chosen."
    color: Qt.darker(ed.foreground, 1.6)
    font.family: ed.fontFamily
    font.pixelSize: Style.font.caption
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.lg
    TextField {
      id: keyField
      Layout.fillWidth: true
      placeholderText: "shortcut, for example CTRL + ALT + W (optional)"
      foreground: ed.foreground
      accent: ed.accent
    }
    Button {
      text: ed.editing !== "" && ed.name === ed.editing ? "Update" : "Add"
      enabled: ed.ready
      bordered: true
      foreground: ed.foreground
      accent: ed.accent
      fontFamily: ed.fontFamily
      onClicked: ed.add()
    }
  }
}
