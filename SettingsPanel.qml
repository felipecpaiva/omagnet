import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "ConfigIO.js" as ConfigIO

// omagnet settings: a single scrolling page over ~/.config/omagnet/config.toml.
// Layout, theme tokens and open/close lifecycle follow bobbynicholas.omaland/Panel.qml.
// Every change is saved after a short pause (the Omaland idiom), so there is no Save button.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property color scrim: Color.menu.scrim
  property string fontFamily: Style.font.menuFamily

  readonly property var cfg: store.eff
  readonly property var layoutChoices: ["columns:2", "columns:3", "rows:2", "rows:3", "grid:2x2", "grid:3x2", "grid:3x3", "priority"]
    .concat(Object.keys(store.eff.layouts))
  readonly property var keyNames: Object.keys(ConfigIO.DEFAULTS.keys)

  function open(payloadJson) {
    root.opened = true
    store.reload()
    Qt.callLater(function() { content.forceActiveFocus() })
  }

  function close() {
    if (root.opened && store.pending) store.saveNow() // never drop a pending edit
    root.opened = false
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "io.github.felipecpaiva.omagnet")
    else close()
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  SettingsStore { id: store }

  // One caption line under a section header.
  component Note: Text {
    Layout.fillWidth: true
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    color: Qt.darker(root.foreground, 1.6)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  component Header: ColumnLayout {
    property alias text: head.text
    Layout.fillWidth: true
    spacing: Style.spacing.xs
    PanelSeparator { foreground: root.foreground; Layout.fillWidth: true }
    PanelSectionHeader { id: head; foreground: root.foreground; fontFamily: root.fontFamily }
  }

  component Num: NumberField {
    property string key: ""
    value: root.cfg[key]
    foreground: root.foreground
    accent: root.accent
    fontFamily: root.fontFamily
    from: 0
    to: 4000
    onModified: function(v) { store.setValue(key, v) }
  }

  component Switch: Toggle {
    property string key: ""
    Layout.fillWidth: true
    checked: root.cfg[key]
    foreground: root.foreground
    accent: root.accent
    fontFamily: root.fontFamily
    onClicked: store.setValue(key, !root.cfg[key])
  }

  // Row of buttons to pick a layout name. Empty current means "use the default" (allowDefault adds that button).
  component LayoutPick: Flow {
    id: pick
    property string current: ""
    property bool allowDefault: false
    signal picked(string name)
    Layout.fillWidth: true
    spacing: Style.spacing.xs
    Repeater {
      model: (pick.allowDefault ? [""] : []).concat(root.layoutChoices)
      Button {
        required property string modelData
        text: modelData === "" ? "default" : modelData
        bordered: modelData === pick.current
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        onClicked: pick.picked(modelData)
      }
    }
  }

  PanelWindow {
    id: window
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omagnet"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: root.scrim
      MouseArea { anchors.fill: parent; onClicked: root.dismiss() }
    }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: Math.min(Style.space(640), window.width - Style.gapsOut * 4)
      height: Math.min(Style.space(680), window.height - Style.gapsOut * 4)
      radius: Style.cornerRadius
      color: root.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.panelPadding

      MouseArea { anchors.fill: parent; onClicked: {} }

      // Ancestor of every field, so Escape from inside a text field still closes the panel.
      Item {
        id: content
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.dismiss()

        ColumnLayout {
          anchors.fill: parent
          anchors.topMargin: card.contentTopInset
          anchors.rightMargin: card.contentRightInset
          anchors.bottomMargin: card.contentBottomInset
          anchors.leftMargin: card.contentLeftInset
          spacing: Style.spacing.panelGap

          RowLayout {
            Layout.fillWidth: true
            Column {
              Layout.fillWidth: true
              spacing: Style.spacing.xxs
              Text {
                text: "omagnet"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
              }
              Text {
                text: "~/.config/omagnet/config.toml"
                color: Qt.darker(root.foreground, 1.6)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
            PanelActionButton {
              iconText: "󰅖"
              tooltipText: "Close  ·  Esc"
              foreground: root.foreground
              onClicked: root.dismiss()
            }
          }

          Flickable {
            id: scroller
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: page.implicitHeight

            ColumnLayout {
              id: page
              width: scroller.width
              spacing: Style.spacing.sm

              Header { text: "Switches" }
              Switch { key: "keys_enabled"; label: "Keyboard shortcuts"; description: "Snap the focused window with the shortcuts below." }
              Switch { key: "drag_enabled"; label: "Drag to snap"; description: "SUPER + drag a window to a screen edge or corner." }

              Header { text: "Spacing" }
              Note { text: "Pixels between snapped windows, and extra space to keep free (for example under a dock)." }
              Flow {
                Layout.fillWidth: true
                spacing: Style.spacing.lg
                Num { key: "margin"; label: "Margin" }
                Num { key: "reserve_top"; label: "Reserve top" }
                Num { key: "reserve_bottom"; label: "Reserve bottom" }
                Num { key: "reserve_left"; label: "Reserve left" }
                Num { key: "reserve_right"; label: "Reserve right" }
              }
              Switch { key: "edge_tight"; label: "No margin at the screen border"; description: "Windows touch the edge of the screen; the margin only goes between windows." }

              Header { text: "Bar" }
              Switch { key: "bar_icon"; label: "Show an icon in the bar"; description: "Off by default. Adds a small button to the bar that opens this window." }

              Header { text: "Drag zones" }
              Flow {
                Layout.fillWidth: true
                spacing: Style.spacing.lg
                Num { key: "edge_width"; label: "Edge width"; from: 1 }
                Num { key: "corner_size"; label: "Corner size"; from: 1 }
              }

              Header { text: "Grid zones" }
              Switch { key: "zones_enabled"; label: "Grid zones"; description: "Hold SUPER + SHIFT (see below) while dragging a window to snap it to a cell of the screen's grid." }
              Note { text: "Drag modifier: the keys held with the left mouse button to start a zone drag. Changing it needs the Hyprland reload button below." }
              TextField {
                Layout.fillWidth: true
                text: root.cfg.zone_modifier
                placeholderText: "SUPER + SHIFT"
                foreground: root.foreground
                accent: root.accent
                onEditingFinished: store.setValue("zone_modifier", text)
              }
              RowLayout {
                Layout.fillWidth: true
                visible: store.needsReload
                Note { Layout.fillWidth: true; color: root.accent; text: "Shortcut changes need a Hyprland reload." }
                Button {
                  text: "Reload Hyprland"
                  bordered: true
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.fontFamily
                  onClicked: store.reloadHyprland()
                }
              }
              Num { key: "zone_span"; label: "Edge reach (pixels)"; to: 200 }
              Note { text: "Near the shared edge of two zones, a drop covers both." }
              Note { text: "Layout for landscape screens" }
              LayoutPick { current: root.cfg.layout_landscape; onPicked: function(n) { store.setValue("layout_landscape", n) } }
              Note { text: "Layout for portrait screens" }
              LayoutPick { current: root.cfg.layout_portrait; onPicked: function(n) { store.setValue("layout_portrait", n) } }
              Note { text: "Layout per monitor. Default means the landscape or portrait layout above." }
              Repeater {
                model: Quickshell.screens
                ColumnLayout {
                  required property var modelData
                  Layout.fillWidth: true
                  spacing: Style.spacing.xxs
                  Text {
                    text: modelData.name
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                  }
                  LayoutPick {
                    allowDefault: true
                    current: root.cfg.zone_layouts[modelData.name] || ""
                    onPicked: function(n) { store.setZoneLayout(modelData.name, n) }
                  }
                }
              }
              Note {
                text: (Object.keys(root.cfg.layouts).length
                  ? "Custom layouts found: " + Object.keys(root.cfg.layouts).map(function(n) {
                      var k = root.cfg.keys["layout:" + n]; return n + (k ? ": key " + k : "") }).join(", ") + ". "
                  : "No custom layouts yet. ")
                  + "Custom layouts are edited in ~/.config/omagnet/config.toml as [layout_<name>] with zones = \"x y w h; ...\""
              }

              Header { text: "Drag outline" }
              Switch { key: "highlight"; label: "Show every zone while dragging"; description: "Draws a faint strip for each drag zone. Off by default: it starts the outline overlay (about 230 MB) at the start of every drag." }
              Flow {
                Layout.fillWidth: true
                spacing: Style.spacing.lg
                Num { key: "target_outline"; label: "Outline thickness"; to: 20 }
                // NumberField is integer only, so the fill is shown as a percent and stored as value / 100
                Num {
                  key: "target_fill"; label: "Fill strength (%)"; to: 100
                  value: Math.round(root.cfg.target_fill * 100)
                  onModified: function(v) { store.setValue("target_fill", v / 100) }
                }
                Num { key: "highlight_outline"; label: "Zone outline thickness"; to: 20 }
              }
              Note { text: "Outline colour. Empty matches your theme: the colour of your windows' active border. Otherwise #rrggbb." }
              TextField {
                Layout.fillWidth: true
                text: root.cfg.target_color
                placeholderText: "theme border colour"
                foreground: root.foreground
                accent: root.accent
                onEditingFinished: store.setValue("target_color", text)
              }

              Header { text: "Ignored apps" }
              Note { text: "Window classes omagnet leaves alone, separated by commas. Case does not matter." }
              TextField {
                Layout.fillWidth: true
                text: root.cfg.ignore
                placeholderText: "steam, mpv"
                foreground: root.foreground
                accent: root.accent
                onEditingFinished: store.setValue("ignore", text)
              }

              Header { text: "Shortcuts" }
              Note { text: "An empty field means no shortcut. Hyprland's key format, for example CTRL + ALT + LEFT." }
              RowLayout {
                Layout.fillWidth: true
                visible: store.needsReload
                Note { Layout.fillWidth: true; color: root.accent; text: "Shortcut changes need a Hyprland reload." }
                Button {
                  text: "Reload Hyprland"
                  bordered: true
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.fontFamily
                  onClicked: store.reloadHyprland()
                }
              }
              Repeater {
                model: root.keyNames
                RowLayout {
                  required property string modelData
                  Layout.fillWidth: true
                  spacing: Style.spacing.lg
                  Text {
                    Layout.preferredWidth: Style.space(170)
                    text: modelData.replace(/_/g, " ")
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                  }
                  TextField {
                    Layout.fillWidth: true
                    text: root.cfg.keys[modelData] || ""
                    placeholderText: ConfigIO.DEFAULTS.keys[modelData] === ""
                      ? "none" : "none (default: " + ConfigIO.DEFAULTS.keys[modelData] + ")"
                    foreground: root.foreground
                    accent: root.accent
                    onEditingFinished: store.setKey(modelData, text)
                  }
                }
              }

              Header { text: "Custom positions" }
              Note { text: "Your own positions, saved as [cmd_*] sections in the config file." }
              RowLayout {
                Layout.fillWidth: true
                visible: store.needsReload
                Note { Layout.fillWidth: true; color: root.accent; text: "Shortcut changes need a Hyprland reload." }
                Button {
                  text: "Reload Hyprland"
                  bordered: true
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.fontFamily
                  onClicked: store.reloadHyprland()
                }
              }
              CustomEditor {
                cfgStore: store
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
              }
            }
          }

          Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: store.status !== "" ? store.status : "Changes are saved automatically."
            color: store.failed ? Color.urgent : (store.status === "Saved" ? root.accent : Qt.darker(root.foreground, 1.6))
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  IpcHandler {
    target: "omagnet"
    function open(): void { root.open("{}") }
    function close(): void { root.dismiss() }
    function toggle(): void { root.toggle() }
  }
}
