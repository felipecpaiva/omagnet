// Run by tests/qml/run.sh against stub Quickshell modules. Plays helper exits and stalls against SettingsStore.qml and Service.qml.
import QtQuick
import Quickshell
import "../.."

Item {
  id: t
  property int passed: 0
  property int failed: 0
  readonly property int expected: 15
  function check(cond, what) { if (cond) passed++; else failed++; console.log((cond ? "ok: " : "FAIL: ") + what) }
  function find(o, pred) { for (var i = 0; i < o.data.length; i++) if (pred(o.data[i])) return o.data[i]; return null }
  function cmd(p) { return p.command ? p.command.join(" ") : "" }

  SettingsStore { id: s; helperDeadline: 60 }
  Service { id: svc }
  Component { id: svcMaker; Service {} }

  Timer { id: wait; property var then; onTriggered: then() }
  function after(ms, fn) { wait.interval = ms; wait.then = fn; wait.start() }

  function sync() {
    var mkdir = find(s, p => cmd(p).indexOf("mkdir") === 0)
    var ev = find(s, p => cmd(p).indexOf("reload_config") > 0)
    var rl = find(s, p => cmd(p) === "hyprctl reload")
    var file = find(s, p => p.writes !== undefined)
    s.saveNow(); mkdir.finish(1, 0)
    check(file.writes.length === 0, "mkdir exit 1 writes nothing")
    check(s.failed && s.status.indexOf("Could not create") === 0, "mkdir exit 1 shows a failed state")
    s.saveNow(); mkdir.finish(0, 0)
    check(file.writes.length === 1 && !s.failed, "mkdir exit 0 writes the file")
    s.saveNow(); mkdir.kill()
    check(file.writes.length === 1 && s.failed, "killed mkdir writes nothing and fails")
    s.status = "Saving..."; s.failed = false; ev.running = true; ev.finish(1, 0)
    check(s.status !== "Saved" && s.failed, "failed eval never says Saved")
    s.status = "Saving..."; s.failed = false; ev.running = true; ev.finish(0, 0)
    check(s.status === "Saved" && !s.failed, "clean eval says Saved")
    s.boundSignature = "old"; rl.running = true; rl.finish(1, 0)
    check(s.boundSignature === "old" && s.failed, "failed reload keeps the bound signature")
    s.failed = false; rl.running = true; rl.finish(0, 0)
    check(s.boundSignature !== "old" && !s.failed, "clean reload updates the bound signature")

    // stalled helpers: the deadline stops them and shows a failure
    s.failed = false; s.status = ""; s.saveNow()
    s.reloadHyprland(); ev.running = true
    s.previewLayout("grid", 3)
    var pv = find(s, p => cmd(p).indexOf("omagnet.preview") > 0)
    var stalled = [mkdir, ev, rl, pv]
    after(200, function () {
      check(stalled.every(p => !p.running), "every stalled helper is stopped by its deadline")
      check(s.failed, "a stalled helper shows a failed state")
      check(file.writes.length === 1, "a stalled mkdir writes nothing")
      var prevSig = s.boundSignature
      check(!rl.running && s.boundSignature === prevSig, "a stalled reload leaves the bound signature alone")
      service()
    })
  }

  function service() {
    check(svc.installProc !== undefined && svc.installProc.starts === 1, "install runs as a tracked Process")
    svc.installProc.running = true
    after(5300, function () {
      check(!svc.installProc.running, "a stalled install is stopped by its deadline")
      var o = svcMaker.createObject(null)
      var before = Quickshell.detached.length
      o.destroy()
      after(50, function () {
        var d = Quickshell.detached[before]
        check(d !== undefined && d[0] === "timeout", "removal shell is bounded by timeout")
        finish()
      })
    })
  }

  function finish() { console.log(passed + " passed, " + failed + " failed"); Qt.exit(failed === 0 && passed === expected ? 0 : 1) }

  Timer { interval: 15000; running: true; onTriggered: { console.log("FAIL: test did not finish"); Qt.exit(1) } }

  Component.onCompleted: after(1, sync)
}
