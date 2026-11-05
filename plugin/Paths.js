.pragma library

// Path of a file next to this plugin's QML, from its URL. The shell hands third-party plugins a
// manifest without __sourceDir, so Qt.resolvedUrl() is the reliable way to find our own folder.
function fromUrl(url) {
  var text = String(url)
  if (text.indexOf("file://") !== 0) return ""
  return decodeURIComponent(text.substring("file://".length))
}
