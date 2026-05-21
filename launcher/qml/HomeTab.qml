import QtQuick
import Jarton

Item {
    id: home

    WallpaperLayer {
        anchors.fill: parent
    }

    // Left column: hero + stats. Featured card slides in just above the
    // stats when the manifest has one.
    Column {
        id: leftColumn
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 48
        anchors.bottomMargin: 56
        anchors.right: rightColumn.left
        anchors.rightMargin: 32
        spacing: 22

        HeroBar { width: leftColumn.width }

        FeaturedCard {
            id: featured
            width: 380
            title: JartonManifestService.featuredTitle
            imageUrl: JartonManifestService.featuredImageUrl
            ctaUrl: JartonManifestService.featuredCtaUrl
        }

        StatsRow {}
    }

    // Right column: full-height news panel, doubled from the v1.0.1 width
    // so the markdown changelog has room to breathe.
    Item {
        id: rightColumn
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.rightMargin: 28
        anchors.topMargin: 32
        anchors.bottomMargin: 32
        width: 720

        NewsFeed {
            anchors.fill: parent
        }
    }
}
