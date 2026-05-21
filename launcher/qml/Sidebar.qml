import QtQuick

Rectangle {
    id: sidebar

    property int currentTab: 0
    signal tabSelected(int index)

    width: 64
    color: "#0f0a06"

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: "#FFB81C44" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Column {
        id: topColumn
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 14
        spacing: 18

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "qrc:/jarton/icons/jartonclient_64.png"
            width: 36
            height: 36
            sourceSize.width: 72
            sourceSize.height: 72

            MouseArea {
                anchors.fill: parent
                onClicked: sidebar.tabSelected(-1)
                cursorShape: Qt.PointingHandCursor
            }
        }

        SidebarTab {
            anchors.horizontalCenter: parent.horizontalCenter
            glyph: "⌂"
            active: sidebar.currentTab === 0
            onClicked: sidebar.tabSelected(0)
        }

        SidebarTab {
            anchors.horizontalCenter: parent.horizontalCenter
            glyph: "▦"
            active: sidebar.currentTab === 1
            onClicked: sidebar.tabSelected(1)
        }

        SidebarTab {
            anchors.horizontalCenter: parent.horizontalCenter
            glyph: "⌬"
            active: sidebar.currentTab === 2
            onClicked: sidebar.tabSelected(2)
        }
    }

    SidebarTab {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 14
        glyph: "⚙"
        active: sidebar.currentTab === 3
        onClicked: sidebar.tabSelected(3)
    }
}
