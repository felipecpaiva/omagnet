import QtQml
// Test double: never runs anything. The test calls finish(code, status) to play an exit; stopping it plays a kill.
QtObject {
  property var command: []
  property bool running: false
  property int starts: 0
  signal exited(int exitCode, int exitStatus)
  onRunningChanged: { if (running) starts++ }
  function finish(code, status) { if (!running) return; running = false; exited(code, status) }
  function kill() { finish(15, 1) }
}
