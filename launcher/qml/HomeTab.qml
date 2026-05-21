import QtQuick

Item {
    id: home

    WallpaperLayer {
        anchors.fill: parent
    }

    HeroBar {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }
}
