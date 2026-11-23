import QtQml
QtObject {
  property string path: ""
  property bool atomicWrites: false
  property bool printErrors: false
  property var writes: []
  signal loaded()
  signal loadFailed(int error)
  signal saved()
  signal saveFailed(int error)
  function text() { return "" }
  function reload() {}
  function setText(t) { writes = writes.concat([t]) }
}
