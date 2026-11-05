import QtQuick
import qs.Commons
import "LayoutOps.js" as LayoutOps

// A layout drawn inside a monitor-shaped frame, with an optional label below. Give zonesText (custom) or layoutName (built-in).
Item {
  id: thumb

  property string zonesText: ""
  property string layoutName: ""
  property real aspect: 16 / 9
  property color foreground: "white"
  property color accent: "steelblue"
  property bool selected: false
  property string label: ""
  property string fontFamily: ""

  readonly property var zoneList: {
    var r = thumb.zonesText !== "" ? LayoutOps.parse(thumb.zonesText) : null
    if (r && r.zones) return r.zones
    return LayoutOps.builtin(thumb.layoutName) || []
  }

  implicitWidth: Style.space(120)
  implicitHeight: frame.height + (caption.visible ? caption.implicitHeight + 4 : 0)

  Rectangle {
    id: frame
    width: thumb.width
    height: thumb.aspect > 0 ? thumb.width / thumb.aspect : thumb.width * 0.5625
    color: Qt.rgba(thumb.foreground.r, thumb.foreground.g, thumb.foreground.b, 0.06)
    border.width: thumb.selected ? 3 : 1
    border.color: thumb.selected ? thumb.accent : Qt.rgba(thumb.foreground.r, thumb.foreground.g, thumb.foreground.b, 0.4)

    Repeater {
      model: thumb.zoneList
      Rectangle {
        required property var modelData
        required property int index
        x: modelData.x / LayoutOps.UNIT * frame.width + 2
        y: modelData.y / LayoutOps.UNIT * frame.height + 2
        width: Math.max(1, modelData.w / LayoutOps.UNIT * frame.width - 4)
        height: Math.max(1, modelData.h / LayoutOps.UNIT * frame.height - 4)
        color: Qt.rgba(thumb.accent.r, thumb.accent.g, thumb.accent.b, 0.22)
        border.width: 1
        border.color: thumb.accent
      }
    }
  }

  Text {
    id: caption
    visible: thumb.label !== ""
    anchors.top: frame.bottom
    anchors.topMargin: 4
    width: thumb.width
    text: thumb.label
    elide: Text.ElideRight
    textFormat: Text.PlainText
    color: thumb.foreground
    font.family: thumb.fontFamily
    font.pixelSize: Style.font.caption
  }
}
