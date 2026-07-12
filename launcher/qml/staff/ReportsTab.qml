import QtQuick
import Jarton

// Player reports queue — resolve clears them. Heads via crafatar.
Item {
    id: root
    property var reports: []
    property bool loading: false
    property string error: ""
    property int reqList: -1
    property bool loadedOnce: false
    property var pendingWrites: []

    // background refresh: silent + change-gated
    readonly property int autoRefreshMs: 20000
    property int quietReq: -1
    property string lastPayload: ""

    onVisibleChanged: if (visible && !loadedOnce) { loadedOnce = true; load() }

    function load() { loading = true; error = ""; reqList = ProctorApi.send("GET", "/proctor/reports") }
    function quietLoad() {
        if (loading || quietReq !== -1) return
        quietReq = ProctorApi.send("GET", "/proctor/reports")
    }
    function resolve(id) {
        var p = pendingWrites
        p.push(ProctorApi.send("POST", "/proctor/reports/" + id + "/resolve", "{}"))
        pendingWrites = p
    }

    Timer { interval: root.autoRefreshMs; repeat: true; running: root.visible; onTriggered: root.quietLoad() }
    function relTime(ms) { return TimeFmt.rel(ms) }

    Connections {
        target: ProctorApi
        function onResponse(id, ok, status, body) {
            if (id === root.quietReq) {
                root.quietReq = -1
                if (!ok || body === root.lastPayload) return
                root.lastPayload = body
                var y = list.contentY
                try { root.reports = JSON.parse(body).reports || [] } catch (e) { return }
                Qt.callLater(function () { list.contentY = Math.max(0, Math.min(y, list.contentHeight - list.height)) })
                return
            }
            if (id === root.reqList) {
                root.loading = false
                if (ok) {
                    root.lastPayload = body
                    try { root.reports = JSON.parse(body).reports || [] } catch (e) { root.reports = [] }
                } else root.error = "Couldn't load reports."
                return
            }
            // only OUR resolve completions reload — reacting to every foreign
            // response is the cross-tab churn that caused the detail flicker
            var idx = root.pendingWrites.indexOf(id)
            if (idx !== -1) { root.pendingWrites.splice(idx, 1); root.load() }
        }
    }

    Column {
        anchors.fill: parent; anchors.margins: 4; spacing: 12
        Item {
            width: parent.width; height: 32
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Reports"; color: "#F2E8D0"; font.pixelSize: 16; font.bold: true }
            SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.loading ? "…" : "Refresh"; icon: "refresh"; variant: "secondary"; onClicked: root.load() }
        }
        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }
        ListView {
            id: list
            width: parent.width; height: parent.height - 44; clip: true; spacing: 6
            model: root.reports
            delegate: Rectangle {
                width: ListView.view.width; height: 64; radius: 10
                color: "#16110a"; border.color: "#241c12"; border.width: 1
                Avatar {
                    id: rHead; anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    size: 30; uuid: modelData.targetUuid ? modelData.targetUuid : ""
                    visible: !!modelData.targetUuid
                }
                Column {
                    anchors.left: parent.left; anchors.leftMargin: modelData.targetUuid ? 54 : 14
                    anchors.right: resolveBtn.left; anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Row {
                        spacing: 8
                        Text { text: modelData.targetName; color: "#F2E8D0"; font.pixelSize: 14; font.bold: true }
                        Text { text: modelData.category; color: "#FFB81C"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: root.relTime(modelData.timestamp); color: "#6b5d3f"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { text: modelData.reason; color: "#cfc3a6"; font.pixelSize: 12; elide: Text.ElideRight; width: parent.width }
                    Text { text: "by " + modelData.reporterName; color: "#6b5d3f"; font.pixelSize: 11 }
                }
                SButton {
                    id: resolveBtn
                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    text: "Resolve"; variant: "secondary"
                    onClicked: root.resolve(modelData.id)
                }
            }
            Text { anchors.centerIn: parent; visible: root.loading && root.reports.length === 0; text: "Loading reports…"; color: "#6b5d3f"; font.pixelSize: 14 }
            Text { anchors.centerIn: parent; visible: !root.loading && root.reports.length === 0; text: "No open reports."; color: "#6b5d3f"; font.pixelSize: 14 }
        }
    }
}
