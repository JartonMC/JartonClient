import QtQuick
import Jarton

// Staff (Proctor) section host: a pill sub-tab bar over Players / Tickets / Applications
// / Reports. Each sub-tab is its own component (queues are read views that deep-link to
// Discord; Players has search + punishment history). Alerts + staff-admin come next.
Item {
    id: section
    property string subtab: "players"

    Row {
        id: tabs
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 16
        spacing: 8
        height: 34
        Repeater {
            model: {
                var m = [
                    { id: "players", label: "Players" }, { id: "tickets", label: "Tickets" },
                    { id: "applications", label: "Applications" }, { id: "reports", label: "Reports" },
                    { id: "alerts", label: "Alerts" }
                ]
                if (ProctorClient.admin) m.push({ id: "staff", label: "Staff" })
                m.push({ id: "more", label: "More" })
                return m
            }
            delegate: Rectangle {
                width: tl.width + 30; height: 32; radius: 16
                color: section.subtab === modelData.id ? "#FFB81C" : (ta.containsMouse ? "#26200f" : "#1b150e")
                border.color: section.subtab === modelData.id ? "transparent" : "#2a2114"; border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    id: tl; anchors.centerIn: parent; text: modelData.label
                    color: section.subtab === modelData.id ? "#1a140e" : "#9a8a66"
                    font.pixelSize: 13; font.bold: section.subtab === modelData.id
                }
                MouseArea { id: ta; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: section.subtab = modelData.id }
            }
        }
    }

    Item {
        anchors.top: tabs.bottom; anchors.topMargin: 12
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 16; anchors.rightMargin: 16; anchors.bottomMargin: 16

        PlayersTab      { anchors.fill: parent; visible: section.subtab === "players" }
        TicketsTab      { anchors.fill: parent; visible: section.subtab === "tickets" }
        ApplicationsTab { anchors.fill: parent; visible: section.subtab === "applications" }
        ReportsTab      { anchors.fill: parent; visible: section.subtab === "reports" }
        AlertsTab       { anchors.fill: parent; visible: section.subtab === "alerts" }
        StaffAdminTab   { anchors.fill: parent; visible: section.subtab === "staff" }
        MoreTab         { anchors.fill: parent; visible: section.subtab === "more" }
    }
}
