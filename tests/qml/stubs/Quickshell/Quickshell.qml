pragma Singleton
import QtQml
// Test double: records detached launches instead of running them.
QtObject {
  property var detached: []
  function env(name) { return "/tmp/omagnet-test-home" }
  function execDetached(cmd) { detached = detached.concat([cmd]) }
}
