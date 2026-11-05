import QtQuick
import Quickshell
import Quickshell.Io
import "ConfigIO.js" as ConfigIO

// Reads and writes ~/.config/omagnet/config.toml and tells the running Lua module to re-read it.
// The model is ConfigIO's parsed tree, so unknown keys and sections survive every save.
Item {
  id: store

  readonly property string dir: Quickshell.env("HOME") + "/.config/omagnet"
  readonly property string path: dir + "/config.toml"

  property var model: ({})
  readonly property var eff: ConfigIO.merge(model)
  readonly property var customList: ConfigIO.customSections(model)
  property bool loaded: false
  property string status: ""        // "", "Saving...", "Saved", or an error message
  property bool failed: false
  readonly property bool pending: saveTimer.running
  property string boundSignature: ""      // shortcut signature the running Hyprland session has bound
  readonly property bool needsReload: loaded && boundSignature !== "" && ConfigIO.bindSignature(model) !== boundSignature

  function reload() { file.reload() }

  function setValue(k, v) { store.model = ConfigIO.withValue(store.model, k, v); scheduleSave() }
  function setKey(name, v) { store.model = ConfigIO.withKey(store.model, name, v); scheduleSave() }

  function scheduleSave() { store.status = ""; saveTimer.restart() }

  // The folder may not exist on a fresh install, and FileView does not create it.
  function saveNow() {
    saveTimer.stop()
    store.status = "Saving..."
    store.failed = false
    mkdirProc.running = true
  }

  function reloadHyprland() { hyprReload.running = true }

  Process { id: mkdirProc; command: ["mkdir", "-p", store.dir]; onExited: file.setText(ConfigIO.serialize(store.model)) }

  // Live re-read, no Hyprland reload. Fails quietly if the Lua module has no reload_config yet.
  Process {
    id: evalProc
    command: ["hyprctl", "eval", "_G.omagnet.reload_config()"]
    onExited: if (!store.failed) store.status = "Saved"
  }

  Process {
    id: hyprReload
    command: ["hyprctl", "reload"]
    onExited: store.boundSignature = ConfigIO.bindSignature(store.model)
  }

  Timer { id: saveTimer; interval: 450; onTriggered: store.saveNow() }
  Timer { interval: 2000; running: store.status === "Saved"; onTriggered: store.status = "" }

  FileView {
    id: file
    path: store.path
    atomicWrites: true
    printErrors: false
    onLoaded: {
      store.model = ConfigIO.parse(text()).root
      if (!store.loaded) store.boundSignature = ConfigIO.bindSignature(store.model)
      store.loaded = true
    }
    onLoadFailed: {
      store.model = ({})
      if (!store.loaded) store.boundSignature = ConfigIO.bindSignature(store.model)
      store.loaded = true
    }
    onSaved: evalProc.running = true
    onSaveFailed: { store.failed = true; store.status = "Could not write " + store.path }
  }
}
