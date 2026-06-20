import QtQuick
import QtQuick.Effects

// Player head, matching the app: mc-heads.net at 3x for crisp retina, async + cached so
// list scrolling never blocks the UI thread, rounded-square (radius = size * 0.22).
Item {
    id: root
    property string uuid: ""
    property int size: 32
    property real radiusFactor: 0.22
    width: size
    height: size

    Rectangle { anchors.fill: parent; radius: root.size * root.radiusFactor; color: "#292929" }

    Image {
        id: img
        anchors.fill: parent
        source: root.uuid.length ? "https://mc-heads.net/avatar/" + root.uuid + "/" + Math.round(root.size * 3) : ""
        sourceSize.width: Math.round(root.size * 3)
        sourceSize.height: Math.round(root.size * 3)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: false
    }

    Item {
        id: mask
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Rectangle { anchors.fill: parent; radius: root.size * root.radiusFactor }
    }

    MultiEffect {
        anchors.fill: parent
        source: img
        maskEnabled: true
        maskSource: mask
        visible: img.status === Image.Ready
    }
}
