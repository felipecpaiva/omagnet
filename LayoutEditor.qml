// STUB: replaced by the real editor. Interface (do not change without changing LayoutGallery's use of it):
//   in:  layoutId (string, "" for a new layout), zonesText ("x y w h; ..." fractions), layoutKey (shortcut string),
//        aspect (real, screen width / height used to draw the preview), margin (real, pixels, the snap margin),
//        foreground, accent, fontFamily (the panel's colours and font)
//   out: saved(id, zonesText, key), canceled(), previewRequested(zonesText)
import QtQuick

Item {
  id: root
  property string layoutId: ""
  property string zonesText: ""
  property string layoutKey: ""
  property real aspect: 16 / 9
  property real margin: 8
  property color foreground: "white"
  property color accent: "steelblue"
  property string fontFamily: ""
  signal saved(string id, string zonesText, string key)
  signal canceled()
  signal previewRequested(string zonesText)
  implicitHeight: 40
}
