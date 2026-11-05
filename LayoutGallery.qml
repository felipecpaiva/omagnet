import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "ConfigIO.js" as ConfigIO
import "LayoutOps.js" as LayoutOps

// The Layouts page: screens, a layout per workspace, and a gallery of built-in and custom layouts with the editor.
Flickable {
  id: gal

  property var store: null
  property color foreground: "white"
  property color accent: "steelblue"
  property string fontFamily: ""

  readonly property var builtins: ["columns:2", "columns:3", "rows:2", "rows:3", "grid:2x2", "grid:3x2", "grid:3x3", "priority"]
  readonly property var customs: gal.store ? gal.store.eff.layouts || ({}) : ({})
  readonly property var choices: gal.builtins.concat(Object.keys(gal.customs))
  readonly property var zoneMap: gal.store ? gal.store.eff.zone_layouts || ({}) : ({})
  readonly property var wsMap: gal.store ? gal.store.eff.workspace_layouts || ({}) : ({})
  property string target: ""            // screen name the gallery applies to
  property bool editing: false
  onEditingChanged: contentY = 0 // the editor and the gallery have different heights, so start each at the top
  property string editId: ""            // "" for a new layout
  property string confirming: ""        // custom layout id waiting for a second click on Delete
  property string notice: ""

  function screenByName(n) {
    for (var i = 0; i < Quickshell.screens.length; i++) if (Quickshell.screens[i].name === n) return Quickshell.screens[i]
    return null
  }
  function aspectOf(s) { return s && s.height > 0 ? s.width / s.height : 16 / 9 }
  readonly property string targetName: gal.screenByName(gal.target) ? gal.target
    : (Quickshell.screens.length ? Quickshell.screens[0].name : "")
  // What the settings say for a screen: its own entry, else the landscape or portrait choice. May be "auto".
  function chosenLayout(s) {
    var n = gal.zoneMap[s.name]
    if (n) return n
    var c = gal.store.eff
    return s.height > s.width ? c.layout_portrait : c.layout_landscape
  }
  // The layout that is really used: "auto" becomes the recommendation for the screen's size and shape.
  function currentLayout(s) {
    var n = gal.chosenLayout(s)
    return n === "auto" ? LayoutOps.autoLayout(s.width, s.height) : n
  }

  clip: true
  boundsBehavior: Flickable.StopAtBounds
  contentWidth: width
  contentHeight: col.implicitHeight

  component Note: Text {
    Layout.fillWidth: true
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    color: Qt.darker(gal.foreground, 1.6)
    font.family: gal.fontFamily
    font.pixelSize: Style.font.caption
  }

  component Header: ColumnLayout {
    property alias text: head.text
    Layout.fillWidth: true
    spacing: Style.spacing.xs
    PanelSeparator { foreground: gal.foreground; Layout.fillWidth: true }
    PanelSectionHeader { id: head; foreground: gal.foreground; fontFamily: gal.fontFamily }
  }

  component Btn: Button {
    foreground: gal.foreground
    accent: gal.accent
    fontFamily: gal.fontFamily
  }

  ColumnLayout {
    id: col
    width: gal.width
    spacing: Style.spacing.sm

    RowLayout {
      Layout.fillWidth: true
      visible: gal.store.needsReload
      Note { Layout.fillWidth: true; color: gal.accent; text: "Shortcut changes need a Hyprland reload." }
      Btn { text: "Reload Hyprland"; bordered: true; onClicked: gal.store.reloadHyprland() }
    }

    Note { visible: gal.notice !== ""; color: gal.accent; text: gal.notice }

    LayoutEditor {
      id: editor
      visible: gal.editing
      Layout.fillWidth: true
      layoutId: gal.editId
      zonesText: gal.editId !== "" ? (gal.customs[gal.editId] || "") : ""
      layoutKey: gal.editId !== "" ? (gal.store.eff.keys["layout:" + gal.editId] || "") : ""
      aspect: gal.aspectOf(gal.screenByName(gal.targetName))
      margin: gal.store.eff.margin
      foreground: gal.foreground
      accent: gal.accent
      fontFamily: gal.fontFamily
      onCanceled: { gal.editing = false; gal.notice = "" }
      onPreviewRequested: function(text) { gal.store.previewLayout("text:" + text, 4) }
      onSaved: function(id, text, key) {
        var clean = ConfigIO.layoutId(id)
        if (clean === "") return
        if (gal.editId !== "" && clean !== gal.editId) {
          gal.notice = "Renaming is not supported: keep the name \"" + gal.editId + "\", or save a copy under a new name from New layout."
          return
        }
        if (gal.editId === "" && gal.customs[clean] !== undefined) {
          gal.notice = "A layout named \"" + clean + "\" already exists. Edit it from its card or pick another name."
          return
        }
        gal.store.setLayout(clean, text, key)
        gal.editing = false
        gal.notice = ""
      }
    }

    ColumnLayout {
      visible: !gal.editing
      Layout.fillWidth: true
      spacing: Style.spacing.sm

      Header { text: "Screens" }
      Note { text: "Click a screen to make it the target of Apply below." }
      Flow {
        Layout.fillWidth: true
        spacing: Style.spacing.lg
        Repeater {
          model: Quickshell.screens
          Item {
            id: scr
            required property var modelData
            readonly property string cur: gal.currentLayout(modelData)
            readonly property bool isAuto: gal.chosenLayout(modelData) === "auto"
            width: Style.space(170)
            height: thumb.implicitHeight
            LayoutThumb {
              id: thumb
              width: parent.width
              aspect: gal.aspectOf(scr.modelData)
              layoutName: scr.cur
              zonesText: gal.customs[scr.cur] || ""
              foreground: gal.foreground
              accent: gal.accent
              fontFamily: gal.fontFamily
              selected: scr.modelData.name === gal.targetName
              label: scr.modelData.name + "  " + scr.modelData.width + "x" + scr.modelData.height + "  " + (scr.isAuto ? "auto: " : "") + scr.cur
            }
            MouseArea { anchors.fill: parent; onClicked: gal.target = scr.modelData.name }
          }
        }
      }

      Header { text: "Workspaces" }
      Note { text: "Layout per workspace. Default means the screen's layout." }
      Repeater {
        model: Hyprland.workspaces.values
        ColumnLayout {
          id: wsRow
          required property var modelData
          readonly property string cur: gal.wsMap[String(modelData.id)] || gal.wsMap[modelData.name] || ""
          visible: modelData.id > 0
          Layout.fillWidth: true
          spacing: Style.spacing.xxs
          Text {
            text: "Workspace " + wsRow.modelData.id + (wsRow.modelData.name && wsRow.modelData.name !== String(wsRow.modelData.id) ? " (" + wsRow.modelData.name + ")" : "")
              + (wsRow.modelData.monitor ? "  on " + wsRow.modelData.monitor.name : "") + "  :  " + (wsRow.cur || "default")
            color: gal.foreground
            font.family: gal.fontFamily
            font.pixelSize: Style.font.body
          }
          Flow {
            Layout.fillWidth: true
            spacing: Style.spacing.xs
            Repeater {
              model: [""].concat(gal.choices)
              Btn {
                required property string modelData
                text: modelData === "" ? "default" : modelData
                bordered: modelData === wsRow.cur
                onClicked: gal.store.setWorkspaceLayout(String(wsRow.modelData.id), modelData)
              }
            }
          }
        }
      }

      Header { text: "Layouts" }
      Note { text: "Apply sets the layout of the selected screen (" + (gal.targetName || "none") + ")." }
      Flow {
        id: cards
        Layout.fillWidth: true
        spacing: Style.spacing.lg
        readonly property real cardWidth: Math.floor((width - 2 * spacing) / 3)

        Repeater {
          model: gal.choices
          ColumnLayout {
            id: card
            required property string modelData
            readonly property bool custom: gal.customs[modelData] !== undefined
            width: cards.cardWidth
            spacing: Style.spacing.xxs
            LayoutThumb {
              Layout.fillWidth: true
              aspect: gal.aspectOf(gal.screenByName(gal.targetName))
              layoutName: card.modelData
              zonesText: gal.customs[card.modelData] || ""
              foreground: gal.foreground
              accent: gal.accent
              fontFamily: gal.fontFamily
              label: card.modelData
            }
            Flow {
              Layout.fillWidth: true
              spacing: Style.spacing.xs
              Btn { text: "Apply"; onClicked: if (gal.targetName !== "") gal.store.setZoneLayout(gal.targetName, card.modelData) }
              Btn { text: "Show on screen"; onClicked: gal.store.previewLayout(card.modelData, 4) }
              Btn { visible: card.custom; text: "Edit"; onClicked: { gal.editId = card.modelData; gal.notice = ""; gal.editing = true } }
              Btn {
                visible: card.custom
                text: gal.confirming === card.modelData ? "Confirm delete" : "Delete"
                bordered: gal.confirming === card.modelData
                onClicked: {
                  if (gal.confirming === card.modelData) { gal.confirming = ""; gal.store.deleteLayout(card.modelData) }
                  else gal.confirming = card.modelData
                }
              }
            }
          }
        }

        ColumnLayout {
          width: cards.cardWidth
          spacing: Style.spacing.xxs
          Btn { text: "New layout"; bordered: true; onClicked: { gal.editId = ""; gal.notice = ""; gal.editing = true } }
        }
      }
    }
  }
}
