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

  function setZoneLayout(monitor, name) { store.model = ConfigIO.withZoneLayout(store.model, monitor, name); scheduleSave() }

  function setLayout(id, zonesText, key) { store.model = ConfigIO.withLayout(store.model, id, zonesText, key); scheduleSave() }
  function deleteLayout(id) { store.model = ConfigIO.withoutLayout(store.model, id); scheduleSave() }
  function setWorkspaceLayout(workspace, name) { store.model = ConfigIO.withWorkspaceLayout(store.model, workspace, name); scheduleSave() }

  // Show a layout on screen for a few seconds. `what` is a layout name or "text:" + zones text; only plain characters pass,
  // so nothing can end the Lua string.
  function previewLayout(what, seconds) {
    var safe = String(what).replace(/[^A-Za-z0-9_:;. -]/g, "")
    var s = Math.max(1, Math.min(30, Math.round(Number(seconds) || 4)))
    previewProc.running = false
    previewProc.command = ["hyprctl", "eval", "_G.omagnet.preview(\"" + safe + "\", " + s + ")"]
    previewProc.running = true
  }

  function setCustom(name, rect, key) { store.model = ConfigIO.withCustom(store.model, name, rect, key); scheduleSave() }
  function setCustomKey(name, key) { store.model = ConfigIO.withCustom(store.model, name, null, key); scheduleSave() }
  function removeCustom(name) { store.model = ConfigIO.withoutCustom(store.model, name); scheduleSave() }

  function scheduleSave() { store.status = ""; saveTimer.restart() }

  // The folder may not exist on a fresh install, and FileView does not create it.
  function saveNow() {
    saveTimer.stop()
    store.status = "Saving..."
    store.failed = false
    mkdirProc.running = true
  }

  function reloadHyprland() { hyprReload.running = true }

  function fail(message) { store.failed = true; store.status = message }

  // Every helper below has a deadline and changes state only on a clean exit (code 0, not killed).
  property int helperDeadline: 5000
  function ok(code, exitStatus) { return code === 0 && exitStatus === 0 }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", store.dir]
    onExited: (code, st) => store.ok(code, st) ? file.setText(ConfigIO.serialize(store.model)) : store.fail("Could not create " + store.dir)
  }
  Timer { interval: store.helperDeadline; running: mkdirProc.running; onTriggered: { mkdirProc.running = false; store.fail("Could not create " + store.dir) } }

  // Live re-read, no Hyprland reload.
  Process {
    id: evalProc
    command: ["hyprctl", "eval", "_G.omagnet.reload_config()"]
    onExited: (code, st) => store.ok(code, st) ? (store.failed || (store.status = "Saved")) : store.fail("Saved, but Hyprland did not re-read it")
  }
  Timer { interval: store.helperDeadline; running: evalProc.running; onTriggered: { evalProc.running = false; store.fail("Saved, but Hyprland did not re-read it") } }

  // A preview replaced by a newer one is killed on purpose, so only a normal non-zero exit counts as a failure.
  Process {
    id: previewProc
    onExited: (code, st) => { if (st === 0 && code !== 0) store.fail("Could not show the preview") }
  }
  Timer { interval: store.helperDeadline; running: previewProc.running; onTriggered: { previewProc.running = false; store.fail("Could not show the preview") } }

  Process {
    id: hyprReload
    command: ["hyprctl", "reload"]
    onExited: (code, st) => store.ok(code, st) ? (store.boundSignature = ConfigIO.bindSignature(store.model)) : store.fail("Hyprland did not reload")
  }
  Timer { interval: store.helperDeadline * 2; running: hyprReload.running; onTriggered: { hyprReload.running = false; store.fail("Hyprland did not reload") } }

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
