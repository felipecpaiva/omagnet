import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "LayoutOps.js" as LayoutOps

// Visual layout editor. Grid mode cuts, merges and drags dividers; canvas mode moves and resizes free rectangles.
// Every edit goes through LayoutOps (pure, clamping, null when refused). Interface is fixed by LayoutGallery.
Item {
  id: root
  property string layoutId: ""
  property string zonesText: ""
  property string layoutKey: ""
  property real aspect: 16 / 9
  property real margin: 8
  property color foreground: "white"
  property color accent: "steelblue"
  property string fontFamily: ""
  signal saved(string id, string zonesText, string key)
  signal canceled()
  signal previewRequested(string zonesText)

  property var zones: []
  property int selected: -1
  property var multi: ({})            // set of selected indexes, used by Merge
  property string mode: "grid"        // "grid" or "canvas"
  property bool armed: false          // click a zone to cut it
  property bool cutVertical: true     // axis of the click cut: a vertical line
  property bool several: false        // clicks toggle the multi selection
  property string err: ""
  property var act: null              // the drag in progress, set on press

  readonly property real unit: LayoutOps.UNIT
  readonly property var dvs: mode === "grid" ? LayoutOps.dividers(zones) : []
  readonly property var cov: LayoutOps.coverage(zones)
  readonly property int multiCount: Object.keys(multi).length
  readonly property real gapPx: Math.max(0, root.margin / 2 * pv.width / 1280)

  implicitHeight: col.implicitHeight
  focus: true
  Keys.onEscapePressed: root.canceled()
  Keys.onDeletePressed: root.deleteSelected()

  function faint(a) { return Qt.rgba(foreground.r, foreground.g, foreground.b, a) }

  function reset() {
    var p = LayoutOps.parse(zonesText)
    zones = p.zones ? p.zones : LayoutOps.builtin("columns:3")
    selected = -1; multi = ({}); act = null; err = ""
    mode = "grid"; armed = false; several = false
  }
  Component.onCompleted: reset()
  onZonesTextChanged: reset()

  // Take the result of an edit: null means refused and shows msg, otherwise it replaces the zones.
  function apply(list, msg, sel) {
    if (list === null || list === undefined) { err = msg; return false }
    zones = list
    err = ""
    multi = ({})
    selected = Math.min(sel === undefined ? selected : sel, list.length - 1)
    if (selected < 0 && list.length > 0 && sel !== undefined) selected = 0
    return true
  }

  function setMode(m) { mode = m; armed = false; several = false; multi = ({}); err = ""; act = null }

  function toggleMulti(i) {
    var s = {}
    Object.keys(multi).forEach(function (k) { s[k] = true })
    if (Object.keys(s).length === 0 && selected >= 0 && selected !== i) s[selected] = true
    if (s[i]) delete s[i]; else s[i] = true
    multi = s
    selected = i
  }

  function toggleSeveral() {
    several = !several
    var s = {}
    if (several && selected >= 0) s[selected] = true
    multi = s
  }

  function splitSel(axis) {
    var z = zones[selected]
    if (!z) { err = "Select a zone first"; return }
    var at = axis === "x" ? z.x + Math.round(z.w / 2) : z.y + Math.round(z.h / 2)
    apply(LayoutOps.split(zones, selected, axis, at), "Too small", selected)
  }

  function mergeSel() {
    var idx = Object.keys(multi).map(Number)
    if (idx.length < 2) { err = "Select two or more zones first"; return }
    apply(LayoutOps.merge(zones, idx), "These zones do not make a rectangle", Math.min.apply(null, idx))
  }

  function deleteSelected() {
    if (selected < 0 || selected >= zones.length) { err = "Select a zone first"; return }
    if (mode === "grid") apply(LayoutOps.remove(zones, selected), "No neighbour can take this space", Math.max(0, selected - 1))
    else apply(LayoutOps.drop(zones, selected), "The last zone cannot be deleted", Math.max(0, selected - 1))
  }

  function addZone() {
    var s = Math.round(unit * 0.3), o = Math.round(unit * 0.35)
    apply(LayoutOps.add(zones, { x: o, y: o, w: s, h: s }), "Too many zones", zones.length)
  }

  function save() {
    if (nameField.text.trim() === "") { err = "Give the layout a name"; return }
    err = ""
    root.saved(nameField.text, LayoutOps.toText(zones), keyField.text)
  }

  function clampU(v) { return Math.max(0, Math.min(unit, Math.round(v))) }

  // Nearest divider within 7 px (a 14 px wide hit area) of the point, or null.
  function dividerAt(px, py) {
    var best = null, bestD = 8
    for (var i = 0; i < dvs.length; i++) {
      var d = dvs[i], vert = d.axis === "x"
      var line = d.c / unit * (vert ? pv.width : pv.height)
      var a = d.a / unit * (vert ? pv.height : pv.width), b = d.b / unit * (vert ? pv.height : pv.width)
      var along = vert ? py : px, across = vert ? px : py
      var dist = Math.abs(across - line)
      if (along >= a - 7 && along <= b + 7 && dist < bestD) { best = d; bestD = dist }
    }
    return best
  }

  ColumnLayout {
    id: col
    width: parent.width
    spacing: Style.spacing.sm

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.sm
      Button {
        text: "Grid"; bordered: true; selected: root.mode === "grid"
        foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
        onClicked: root.setMode("grid")
      }
      Button {
        text: "Canvas"; bordered: true; selected: root.mode === "canvas"
        foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
        onClicked: root.setMode("canvas")
      }
    }

    Rectangle {
      id: pv
      Layout.fillWidth: true
      Layout.preferredHeight: width / Math.max(0.2, root.aspect)
      radius: 6
      color: "#14161a"
      border.width: 2
      border.color: root.faint(0.5)

      Repeater {
        model: root.zones
        Item {
          id: zi
          required property var modelData
          required property int index
          readonly property bool sel: index === root.selected
          readonly property bool multiSel: root.multi[index] === true
          x: modelData.x / root.unit * pv.width
          y: modelData.y / root.unit * pv.height
          width: modelData.w / root.unit * pv.width
          height: modelData.h / root.unit * pv.height
          Rectangle {
            x: root.gapPx; y: root.gapPx
            width: Math.max(1, parent.width - 2 * root.gapPx)
            height: Math.max(1, parent.height - 2 * root.gapPx)
            radius: 3
            color: root.accent
            opacity: (zi.sel || zi.multiSel) ? 0.35 : 0.18
            border.width: (zi.sel || zi.multiSel) ? 2 : 1
            border.color: zi.multiSel ? root.foreground : root.accent
          }
          Text {
            anchors.centerIn: parent
            text: String(zi.index + 1)
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
          Rectangle {
            visible: root.mode === "canvas" && zi.sel
            x: parent.width - width - root.gapPx; y: parent.height - height - root.gapPx
            width: 12; height: 12; radius: 2
            color: root.foreground
          }
        }
      }

      Repeater {
        model: root.dvs
        Rectangle {
          required property var modelData
          readonly property bool vert: modelData.axis === "x"
          x: vert ? modelData.c / root.unit * pv.width - 2 : modelData.a / root.unit * pv.width
          y: vert ? modelData.a / root.unit * pv.height : modelData.c / root.unit * pv.height - 2
          width: vert ? 4 : (modelData.b - modelData.a) / root.unit * pv.width
          height: vert ? (modelData.b - modelData.a) / root.unit * pv.height : 4
          radius: 2
          color: root.foreground
          opacity: 0.55
        }
      }

      MouseArea {
        anchors.fill: parent
        onPressed: function(m) {
          root.forceActiveFocus()
          var ux = root.clampU(m.x / pv.width * root.unit), uy = root.clampU(m.y / pv.height * root.unit)
          root.act = null
          if (root.mode === "grid") {
            var d = root.dividerAt(m.x, m.y)
            if (d) {
              root.act = { kind: "div", axis: d.axis, c: d.c, mid: Math.round((d.a + d.b) / 2), base: root.zones }
              return
            }
            var i = LayoutOps.zoneAt(root.zones, ux, uy)
            if (i < 0) return
            if (root.armed) {
              root.apply(LayoutOps.split(root.zones, i, root.cutVertical ? "x" : "y", root.cutVertical ? ux : uy), "Too small", i)
            } else if (root.several || (m.modifiers & Qt.ControlModifier)) {
              root.toggleMulti(i)
            } else {
              root.selected = i; root.multi = ({}); root.err = ""
            }
            return
          }
          var s = root.zones[root.selected]
          var corner = s && Math.abs(m.x - (s.x + s.w) / root.unit * pv.width) < 14 && Math.abs(m.y - (s.y + s.h) / root.unit * pv.height) < 14
          var j = corner ? root.selected : LayoutOps.zoneAt(root.zones, ux, uy)
          if (j < 0) return
          root.selected = j; root.multi = ({}); root.err = ""
          root.act = { kind: corner ? "size" : "move", i: j, mx: m.x, my: m.y, o: root.zones[j], base: root.zones }
        }
        onPositionChanged: function(m) {
          var a = root.act
          if (!pressed || !a) return
          if (a.kind === "div") {
            var to = root.clampU((a.axis === "x" ? m.x / pv.width : m.y / pv.height) * root.unit)
            var r = LayoutOps.moveEdge(a.base, a.axis, a.c, a.mid, to)
            if (r !== null) root.zones = r
            return
          }
          var dx = (m.x - a.mx) / pv.width * root.unit, dy = (m.y - a.my) / pv.height * root.unit
          var rect = a.kind === "move" ? { x: a.o.x + dx, y: a.o.y + dy, w: a.o.w, h: a.o.h } : { x: a.o.x, y: a.o.y, w: a.o.w + dx, h: a.o.h + dy }
          var out = LayoutOps.setRect(a.base, a.i, rect)
          if (out !== null) root.zones = out
        }
        onReleased: root.act = null
        onCanceled: root.act = null
      }
    }

    Flow {
      Layout.fillWidth: true
      spacing: Style.spacing.sm
      visible: root.mode === "grid"
      Button {
        text: "Split vertical"; bordered: true
        foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
        onClicked: root.splitSel("x")
      }
      Button {
        text: "Split horizontal"; bordered: true
        foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
        onClicked: root.splitSel("y")
      }
      Button {
        text: "Click to split"; bordered: true; selected: root.armed
        foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
        onClicked: root.armed = !root.armed
      }
      Button {
        text: root.cutVertical ? "Line: vertical" : "Line: horizontal"; bordered: true
        foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
        onClicked: root.cutVertical = !root.cutVertical
      }
      Button {
        text: "Select several"; bordered: true; selected: root.several
        foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
        onClicked: root.toggleSeveral()
      }
      Button {
        text: "Merge"; bordered: true; enabled: root.multiCount >= 2
        foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
        onClicked: root.mergeSel()
      }
    }

    Flow {
      Layout.fillWidth: true
      spacing: Style.spacing.sm
      Button {
        visible: root.mode === "canvas"
        text: "Add zone"; bordered: true
        foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
        onClicked: root.addZone()
      }
      Button {
        text: "Delete zone"; bordered: true; enabled: root.selected >= 0
        foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
        onClicked: root.deleteSelected()
      }
    }

    Text {
      Layout.fillWidth: true
      visible: root.err !== ""
      text: root.err
      wrapMode: Text.WordWrap
      color: Color.urgent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
    Text {
      Layout.fillWidth: true
      visible: root.mode === "canvas" && root.cov.overlap
      text: "Zones overlap: the smallest one under the pointer wins"
      wrapMode: Text.WordWrap
      color: Qt.darker(root.foreground, 1.6)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
    Text {
      Layout.fillWidth: true
      visible: root.mode === "canvas" && root.cov.gap > 0.001
      text: Math.round(root.cov.gap * 100) + " percent of the screen has no zone: a drop there goes to the nearest zone"
      wrapMode: Text.WordWrap
      color: Qt.darker(root.foreground, 1.6)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    TextField {
      id: nameField
      Layout.fillWidth: true
      text: root.layoutId
      placeholderText: "Name"
      foreground: root.foreground
      accent: root.accent
    }
    TextField {
      id: keyField
      Layout.fillWidth: true
      text: root.layoutKey
      placeholderText: "SUPER + CTRL + ALT + 1, empty for none"
      foreground: root.foreground
      accent: root.accent
    }

    Text {
      Layout.fillWidth: true
      text: root.zones.length + (root.zones.length === 1 ? " zone: " : " zones: ") + LayoutOps.toText(root.zones)
      textFormat: Text.PlainText
      wrapMode: Text.WrapAnywhere
      color: Qt.darker(root.foreground, 1.6)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.sm
      Button {
        text: "Show on screen"; bordered: true
        foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
        onClicked: root.previewRequested(LayoutOps.toText(root.zones))
      }
      Button {
        text: "Save"; bordered: true
        foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
        onClicked: root.save()
      }
      Button {
        text: "Cancel"; bordered: true
        foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
        onClicked: root.canceled()
      }
    }
  }
}
