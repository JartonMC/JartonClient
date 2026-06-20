import QtQuick

// Player head: mc-heads.net at 2x for crisp retina, async + cached so list scrolling never
// blocks the UI thread. Deliberately a plain Image (no layer/MultiEffect) — per-delegate
// GPU layers churn texture memory hard when ListView delegates recycle, so heads render
// square inside a rounded backing tile, which reads fine for Minecraft faces.
Item {
    id: root
    property string uuid: ""
    property string url: ""          // direct image url (e.g. Discord avatar); overrides uuid
    property int size: 32
    property real radiusFactor: 0.22
    width: size
    height: size

    Rectangle {
        anchors.fill: parent
        radius: root.size * root.radiusFactor
        color: "#241c12"
        clip: true

        Image {
            anchors.fill: parent
            source: root.url.length ? root.url
                  : root.uuid.length ? "https://mc-heads.net/avatar/" + root.uuid + "/" + Math.round(root.size * 2) : ""
            sourceSize.width: Math.round(root.size * 2)
            sourceSize.height: Math.round(root.size * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }
    }
}
