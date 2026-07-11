import QtQuick
import Jarton

// Staff (Proctor) section host: a pill sub-tab bar over Players / Tickets / Applications
// / Reports. Each sub-tab is its own component (queues are read views that deep-link to
// Discord; Players has search + punishment history). Alerts + staff-admin come next.
Item {
    id: section
    property string subtab: "players"

    // access can be revoked mid-session (admin edits the account, /proctor/me refresh
    // lands) — don't leave the view parked on a tab whose chip just disappeared
    Connections {
        target: ProctorClient
        function onChanged() {
            if ((section.subtab === "applications" && !ProctorClient.allowApplications)
                || (section.subtab === "staff" && !ProctorClient.admin)) {
                section.subtab = "players"
            }
        }
    }

    STabBar {
        id: tabs
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 16
        current: section.subtab
        onSelected: (id) => section.subtab = id
        model: {
            var m = [
                { id: "players", label: "Players", icon: "gamepad" },
                { id: "tickets", label: "Tickets", icon: "ticket" }
            ]
            if (ProctorClient.allowApplications) m.push({ id: "applications", label: "Applications", icon: "file-text" })
            m.push({ id: "reports", label: "Reports", icon: "flag" })
            // everyone's personal notification inbox; the raw server-alert history
            // inside it stays gated to admin + panel role
            m.push({ id: "alerts", label: "Alerts", icon: "bell" })
            if (ProctorClient.admin) m.push({ id: "staff", label: "Staff", icon: "shield" })
            m.push({ id: "more", label: "More", icon: "more-horizontal" })
            return m
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
