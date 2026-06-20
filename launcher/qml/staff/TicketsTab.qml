import QtQuick
import Jarton

// Open tickets queue — tap a row to expand the submitted details in-client, see the
// claim state, and open the Discord channel. Mirrors the app's ticket queue.
Item {
    id: root
    property var tickets: []
    property bool loading: false
    property string error: ""
    property int reqList: -1
    property bool loadedOnce: false
    property var openId: null

    onVisibleChanged: if (visible && !loadedOnce) { loadedOnce = true; load() }

    function load() { loading = true; error = ""; reqList = ProctorApi.send("GET", "/proctor/tickets") }
    function relTime(s) {
        if (!s) return ""
        var iso = (("" + s).indexOf("T") === -1) ? ("" + s).replace(" ", "T") + "Z" : s
        var t = Date.parse(iso); if (isNaN(t)) return ""
        var d = Date.now() - t
        var days = Math.floor(d / 86400000); if (days > 0) return days + "d ago"
        var h = Math.floor(d / 3600000); if (h > 0) return h + "h ago"
        return Math.max(1, Math.floor(d / 60000)) + "m ago"
    }

    Connections {
        target: ProctorApi
        function onResponse(id, ok, status, body) {
            if (id !== root.reqList) return
            root.loading = false
            if (ok) { try { root.tickets = JSON.parse(body).tickets || [] } catch (e) { root.tickets = [] } }
            else root.error = "Couldn't load tickets."
        }
    }

    Column {
        anchors.fill: parent; anchors.margins: 4; spacing: 12
        Item {
            width: parent.width; height: 32
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Open tickets"; color: "#FFFFFF"; font.pixelSize: 17; font.bold: true }
            SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.loading ? "…" : "Refresh"; glyph: "↻"; variant: "secondary"; onClicked: root.load() }
        }
        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }
        ListView {
            width: parent.width; height: parent.height - 56; clip: true; spacing: 8
            model: root.tickets
            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property bool open: root.openId === modelData.id
                width: ListView.view.width; height: col.height + 24; radius: 12; color: Qt.rgba(1, 1, 1, 0.04)
                Behavior on height { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

                Column {
                    id: col
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12; spacing: 8
                    Item {
                        width: parent.width; height: 36
                        Avatar { id: av; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; size: 34; url: modelData.openerAvatar ? modelData.openerAvatar : ""; radiusFactor: 0.5 }
                        Column {
                            anchors.left: av.right; anchors.leftMargin: 12; anchors.right: badge.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                            Text { text: modelData.category ? modelData.category : "Ticket"; color: "#FFFFFF"; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight; width: parent.width }
                            Text { text: "by " + (modelData.openerName ? modelData.openerName : "Unknown") + "   ·   " + root.relTime(modelData.createdAt); color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 11; elide: Text.ElideRight; width: parent.width }
                        }
                        Rectangle {
                            id: badge; anchors.right: chevron.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                            width: bt.width + 16; height: 18; radius: 9
                            color: modelData.claimed ? Qt.rgba(0.35, 0.82, 0.48, 0.16) : Qt.rgba(0.94, 0.66, 0.35, 0.16)
                            Text { id: bt; anchors.centerIn: parent; text: modelData.claimed ? (modelData.claimedByName ? "Claimed · " + modelData.claimedByName : "Claimed") : "Unclaimed"; color: modelData.claimed ? "#5ad17a" : "#f0a85a"; font.pixelSize: 9; font.bold: true }
                        }
                        Text { id: chevron; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: card.open ? "▾" : "▸"; color: Qt.rgba(1, 1, 1, 0.3); font.pixelSize: 13 }
                    }
                    Column {
                        width: parent.width; spacing: 7; visible: card.open
                        Repeater {
                            model: card.open && modelData.details ? modelData.details : []
                            delegate: Column {
                                required property var modelData
                                width: col.width; spacing: 2
                                Text { visible: modelData[0] && modelData[0].length > 0; text: modelData[0] ? modelData[0] : ""; color: Qt.rgba(1, 0.72, 0.2, 0.85); font.pixelSize: 11; font.bold: true; wrapMode: Text.WordWrap; width: parent.width }
                                Text { text: modelData[1] ? modelData[1] : ""; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 12; wrapMode: Text.WordWrap; width: parent.width }
                            }
                        }
                        SButton { text: "Open in Discord ↗"; variant: "ghost"; onClicked: if (modelData.deepLink) Qt.openUrlExternally(modelData.deepLink) }
                    }
                }
                MouseArea {
                    anchors.fill: parent; anchors.bottomMargin: card.open ? card.height - 44 : 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openId = card.open ? null : modelData.id
                }
            }
            Text { anchors.centerIn: parent; visible: !root.loading && root.tickets.length === 0; text: "No open tickets."; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 14 }
        }
    }
}
