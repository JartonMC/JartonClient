import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int currentTab: 0

    signal tabSelected(int index)

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            Layout.fillHeight: true
            currentTab: root.currentTab
            onTabSelected: function(index) { root.tabSelected(index) }
        }

        // Content area, host for the embedded Widgets stack.
        // C++ side does the actual widget swapping via the tabSelected signal.
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0f0a06"
        }
    }
}
