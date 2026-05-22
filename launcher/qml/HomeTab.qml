import QtQuick
import Jarton

Item {
    id: home

    WallpaperLayer {
        anchors.fill: parent
    }

    // Right column: scrolling list of news entries.
    Item {
        id: rightColumn
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: bottomBar.top
        anchors.rightMargin: 28
        anchors.topMargin: 32
        anchors.bottomMargin: 18
        width: 420

        NewsFeed {
            anchors.fill: parent
            onEntryClicked: function(index) { newsDialog.showIndex(index) }
        }
    }

    // Left column: hero + featured (if any) + stats.
    Column {
        id: leftColumn
        anchors.left: parent.left
        anchors.bottom: bottomBar.top
        anchors.leftMargin: 48
        anchors.bottomMargin: 24
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

    // Latest-news ticker pinned to the bottom of the home tab.
    LatestNewsBar {
        id: bottomBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 48
        anchors.rightMargin: 28
        anchors.bottomMargin: 18
        onClicked: newsDialog.showIndex(0)
    }

    NewsDialog {
        id: newsDialog
        anchors.fill: parent
    }
}
