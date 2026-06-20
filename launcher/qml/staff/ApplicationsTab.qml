import QtQuick
import Jarton

// Staff applications: pending + archived. Tap a row to expand the full submitted answers
// in-client; resolve from here, or open the Discord thread. Mirrors the app's queue.
Item {
    id: root
    property var apps: []
    property var archived: []
    property bool showArchived: false
    property bool loading: false
    property string error: ""
    property int reqList: -1
    property int reqArchived: -1
    property var pendingWrites: []
    property bool loadedOnce: false
    property int openId: -1

    onVisibleChanged: if (visible && !loadedOnce) { loadedOnce = true; load() }

    function load() {
        loading = true; error = ""
        reqList = ProctorApi.send("GET", "/proctor/applications")
        reqArchived = ProctorApi.send("GET", "/proctor/applications/archived")
    }
    function resolve(id) { var p = pendingWrites; p.push(ProctorApi.send("POST", "/proctor/applications/" + id + "/resolve", "")); pendingWrites = p }
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
            if (id === root.reqList) {
                root.loading = false
                if (ok) { try { root.apps = JSON.parse(body).applications || [] } catch (e) { root.apps = [] } }
                else root.error = "Couldn't load applications."
                return
            }
            if (id === root.reqArchived) {
                if (ok) { try { root.archived = JSON.parse(body).applications || [] } catch (e) { root.archived = [] } }
                return
            }
            var idx = root.pendingWrites.indexOf(id)
            if (idx !== -1) { root.pendingWrites.splice(idx, 1); root.load() }
        }
    }

    Column {
        anchors.fill: parent; anchors.margins: 4; spacing: 12
        Item {
            width: parent.width; height: 32
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Applications"; color: "#FFFFFF"; font.pixelSize: 17; font.bold: true }
            SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.loading ? "…" : "Refresh"; glyph: "↻"; variant: "secondary"; onClicked: root.load() }
        }
        // pending / archived toggle
        Row {
            spacing: 8
            Rectangle {
                width: pTab.width + 26; height: 28; radius: 14
                color: !root.showArchived ? Qt.rgba(1, 0.72, 0.2, 0.16) : Qt.rgba(1, 1, 1, 0.05)
                Text { id: pTab; anchors.centerIn: parent; text: "Pending (" + root.apps.length + ")"; color: !root.showArchived ? "#FFB833" : Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 12; font.bold: true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.showArchived = false; root.openId = -1 } }
            }
            Rectangle {
                width: aTab.width + 26; height: 28; radius: 14
                color: root.showArchived ? Qt.rgba(1, 0.72, 0.2, 0.16) : Qt.rgba(1, 1, 1, 0.05)
                Text { id: aTab; anchors.centerIn: parent; text: "Archived"; color: root.showArchived ? "#FFB833" : Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 12; font.bold: true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.showArchived = true; root.openId = -1 } }
            }
        }
        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }
        ListView {
            width: parent.width; height: parent.height - 84; clip: true; spacing: 8
            model: root.showArchived ? root.archived : root.apps
            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property bool open: root.openId === modelData.id
                width: ListView.view.width
                height: col.height + 24
                radius: 12; color: Qt.rgba(1, 1, 1, 0.04)
                Behavior on height { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

                Column {
                    id: col
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 12; spacing: 8

                    Item {
                        width: parent.width; height: 36
                        Avatar { id: av; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; size: 34; url: modelData.userAvatar ? modelData.userAvatar : ""; radiusFactor: 0.5 }
                        Column {
                            anchors.left: av.right; anchors.leftMargin: 12; anchors.right: chevron.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                            Text { text: modelData.role ? modelData.role : "Applicant"; color: "#FFFFFF"; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight; width: parent.width }
                            Text { text: "from " + (modelData.userName ? modelData.userName : "Unknown") + "   ·   " + root.relTime(modelData.submittedAt); color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 11; elide: Text.ElideRight; width: parent.width }
                        }
                        Text { id: chevron; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: card.open ? "▾" : "▸"; color: Qt.rgba(1, 1, 1, 0.3); font.pixelSize: 13 }
                    }

                    // expanded answers
                    Column {
                        width: parent.width; spacing: 7; visible: card.open
                        Repeater {
                            model: card.open && modelData.answers ? modelData.answers : []
                            delegate: Column {
                                required property var modelData
                                width: col.width; spacing: 2
                                Text { visible: modelData[0] && modelData[0].length > 0; text: modelData[0] ? modelData[0] : ""; color: Qt.rgba(1, 0.72, 0.2, 0.85); font.pixelSize: 11; font.bold: true; wrapMode: Text.WordWrap; width: parent.width }
                                Text { text: modelData[1] ? modelData[1] : ""; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 12; wrapMode: Text.WordWrap; width: parent.width }
                            }
                        }
                        Text { visible: modelData.resolvedBy; text: "resolved by " + (modelData.resolvedBy ? modelData.resolvedBy : "") + "   ·   " + root.relTime(modelData.resolvedAt); color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 11 }
                        Row {
                            spacing: 10; topPadding: 2
                            SButton { text: "Open in Discord ↗"; variant: "ghost"; onClicked: if (modelData.deepLink) Qt.openUrlExternally(modelData.deepLink) }
                            SButton { visible: !root.showArchived; text: "Resolve"; variant: "primary"; onClicked: root.resolve(modelData.id) }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent; anchors.bottomMargin: card.open ? card.height - 44 : 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openId = card.open ? -1 : modelData.id
                }
            }
            Text { anchors.centerIn: parent; visible: !root.loading && (root.showArchived ? root.archived.length === 0 : root.apps.length === 0); text: root.showArchived ? "No archived applications." : "No pending applications."; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 14 }
        }
    }
}
