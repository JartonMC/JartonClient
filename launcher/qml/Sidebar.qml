import QtQuick

Rectangle {
    id: sidebar

    property int currentTab: 0
    signal tabSelected(int index)

    width: 64
    color: "#0f0a06"

    // Right hairline.
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: "#332a14"
    }

    Column {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 14
        spacing: 14

        // Brand mark — clicking opens About.
        Rectangle {
            id: brandWrap
            anchors.horizontalCenter: parent.horizontalCenter
            width: 44
            height: 44
            radius: 10
            color: brandHover.containsMouse ? "#2a1f10" : "transparent"
            border.color: brandHover.containsMouse ? "#8B6F2A" : "transparent"
            border.width: 1
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

            Image {
                anchors.centerIn: parent
                source: "qrc:/jarton/icons/jartonclient_64.png"
                width: 30
                height: 30
                sourceSize.width: 64
                sourceSize.height: 64
            }

            MouseArea {
                id: brandHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sidebar.tabSelected(-1)
            }
        }

        // Discord — opens invite in system browser.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 44
            height: 44
            radius: 10
            color: discordHover.containsMouse ? "#2a1f10" : "transparent"
            border.color: discordHover.containsMouse ? "#8B6F2A" : "transparent"
            border.width: 1
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

            Image {
                anchors.centerIn: parent
                source: "qrc:/jarton/icons/discord_48.png"
                width: 22
                height: 22
                sourceSize.width: 96
                sourceSize.height: 96
                fillMode: Image.PreserveAspectFit
                opacity: discordHover.containsMouse ? 1.0 : 0.7
                Behavior on opacity { NumberAnimation { duration: 140 } }
            }

            MouseArea {
                id: discordHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally("https://discord.gg/JartonMC")
            }
        }

        // Staff edition — opens the staff window (Companion surfaces). Staff builds only.
        // Placeholder glyph; swap for a proper staff icon asset in a later polish pass.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: typeof jartonStaffBuild !== "undefined" && jartonStaffBuild
            width: 44
            height: 44
            radius: 10
            color: staffHover.containsMouse ? "#2a1f10" : "transparent"
            border.color: staffHover.containsMouse ? "#8B6F2A" : "transparent"
            border.width: 1
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

            Text {
                anchors.centerIn: parent
                text: "⬢"
                color: "#FFE082"
                font.pixelSize: 22
            }

            MouseArea {
                id: staffHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sidebar.tabSelected(4)
            }
        }
    }

    // Settings pinned to the bottom.
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 14
        width: 44
        height: 44
        radius: 10
        color: settingsHover.containsMouse ? "#2a1f10" : "transparent"
        border.color: settingsHover.containsMouse ? "#8B6F2A" : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        Text {
            anchors.centerIn: parent
            text: "⚙"
            color: "#FFE082"
            font.pixelSize: 22
        }

        MouseArea {
            id: settingsHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sidebar.tabSelected(3)
        }
    }
}
