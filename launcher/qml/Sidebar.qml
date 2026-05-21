import QtQuick
import QtQuick.Layouts

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

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        spacing: 18

        // Brand mark, honey J. Clicking opens About.
        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "qrc:/jarton/icons/jartonclient.svg"
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
            Layout.alignment: Qt.AlignHCenter
            iconSource: "qrc:/multimc/scalable/launcher.svg"
            label: "Home"
            active: sidebar.currentTab === 0
            onClicked: sidebar.tabSelected(0)
        }

        SidebarTab {
            Layout.alignment: Qt.AlignHCenter
            iconSource: "qrc:/multimc/scalable/viewfolder.svg"
            label: "Instances"
            active: sidebar.currentTab === 1
            onClicked: sidebar.tabSelected(1)
        }

        SidebarTab {
            Layout.alignment: Qt.AlignHCenter
            iconSource: "qrc:/multimc/scalable/centralmods.svg"
            label: "Marketplace"
            active: sidebar.currentTab === 2
            onClicked: sidebar.tabSelected(2)
        }

        Item { Layout.fillHeight: true }

        SidebarTab {
            Layout.alignment: Qt.AlignHCenter
            iconSource: "qrc:/multimc/scalable/appearance.svg"
            label: "Settings"
            active: sidebar.currentTab === 3
            onClicked: sidebar.tabSelected(3)
        }
    }
}
