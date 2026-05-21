import QtQuick
import Jarton

Item {
    id: home

    WallpaperLayer {
        anchors.fill: parent
    }

    // Left column: hero + stats below.
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
        StatsRow {}
    }

    // Right column: featured card + news feed.
    Column {
        id: rightColumn
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.rightMargin: 32
        anchors.topMargin: 32
        anchors.bottomMargin: 32
        width: 360
        spacing: 14

        FeaturedCard {
            id: featured
            width: rightColumn.width
            title: JartonManifestService.featuredTitle
            imageUrl: JartonManifestService.featuredImageUrl
            ctaUrl: JartonManifestService.featuredCtaUrl
        }

        NewsFeed {
            width: rightColumn.width
            height: rightColumn.height - featured.height - rightColumn.spacing
        }
    }
}
