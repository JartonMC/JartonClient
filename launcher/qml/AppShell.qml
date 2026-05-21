import QtQuick

// Sidebar-only shell. The central widget area is managed by C++ (QStackedWidget
// holding HomeTab + Prism's InstanceView) and swapped on tabSelected.
Item {
    id: root

    property int currentTab: 0
    signal tabSelected(int index)

    Sidebar {
        anchors.fill: parent
        currentTab: root.currentTab
        onTabSelected: function(index) { root.tabSelected(index) }
    }
}
