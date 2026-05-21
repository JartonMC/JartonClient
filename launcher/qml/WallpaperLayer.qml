import QtQuick
import Jarton

Item {
    id: layer
    clip: true

    Image {
        id: imgA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: WallpaperService.currentUrl
        asynchronous: true
        cache: true
        smooth: true
    }

    Image {
        id: imgB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: WallpaperService.nextUrl
        asynchronous: true
        cache: true
        smooth: true
        opacity: 0
    }

    // Honey-warm bottom gradient to anchor the hero copy and keep text legible.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.55; color: "#440f0a06" }
            GradientStop { position: 1.0; color: "#cc0f0a06" }
        }
    }

    // Soft honey vignette in the top-left to tie the wallpaper into the brand palette.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#22FFB81C" }
            GradientStop { position: 0.4; color: "transparent" }
        }
    }

    NumberAnimation {
        id: fadeIn
        target: imgB
        property: "opacity"
        from: 0
        to: 1
        duration: 900
        easing.type: Easing.InOutQuad
        onFinished: {
            imgA.source = imgB.source
            imgA.opacity = 1
            imgB.opacity = 0
        }
    }

    Connections {
        target: WallpaperService
        function onCurrentChanged() {
            if (imgB.source != WallpaperService.currentUrl) {
                imgB.source = WallpaperService.currentUrl
                fadeIn.restart()
            }
        }
    }
}
