import QtQuick
import Jarton

// Pterodactyl schedules: list + run-now + delete, over StaffApi.
Item {
    id: root
    property string serverId: ""
    property var schedules: []
    property bool loading: false
    property string error: ""
    property int reqList: -1
    property string loadedServer: ""
    property bool creating: false

    onVisibleChanged: if (visible && loadedServer !== serverId && serverId.length) { loadedServer = serverId; load() }

    function load() {
        loading = true; error = ""
        reqList = StaffApi.send("GET", "/servers/" + serverId + "/schedules")
    }
    function relTime(iso) {
        if (!iso) return "—"
        var t = Date.parse(iso); if (isNaN(t)) return "—"
        var d = t - Date.now(); var fut = d > 0; d = Math.abs(d)
        var days = Math.floor(d / 86400000); var h = Math.floor(d / 3600000); var m = Math.floor(d / 60000)
        var s = days > 0 ? days + "d" : h > 0 ? h + "h" : Math.max(1, m) + "m"
        return fut ? "in " + s : s + " ago"
    }
    function cronOf(c) { return c ? (c.minute + " " + c.hour + " " + c.dayOfMonth + " " + c.month + " " + c.dayOfWeek) : "" }

    Connections {
        target: StaffApi
        function onResponse(id, ok, status, body) {
            if (id === root.reqList) {
                root.loading = false
                if (ok) { try { root.schedules = JSON.parse(body).schedules || [] } catch (e) { root.schedules = [] } }
                else root.error = "Couldn't load schedules."
                return
            }
            root.load()
        }
    }

    Column {
        anchors.fill: parent; spacing: 12
        Item {
            width: parent.width; height: 36
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Schedules"; color: "#F2E8D0"; font.pixelSize: 18; font.bold: true }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                SButton { text: "New schedule"; glyph: "＋"; variant: "primary"; onClicked: root.creating = !root.creating }
                SButton { text: root.loading ? "…" : "Refresh"; glyph: "↻"; variant: "secondary"; onClicked: root.load() }
            }
        }
        // inline create form (name + cron)
        Rectangle {
            width: parent.width; height: 86; radius: 11; visible: root.creating
            color: "#15100a"; border.color: "#FFB81C"; border.width: 1
            Column {
                anchors.fill: parent; anchors.margins: 10; spacing: 8
                Rectangle {
                    width: parent.width; height: 30; radius: 8; color: "#0f0a06"; border.color: "#2a2114"; border.width: 1
                    TextInput { id: schName; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; verticalAlignment: TextInput.AlignVCenter; color: "#F2E8D0"; font.pixelSize: 13; clip: true
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "schedule name"; color: "#6b5d3f"; font.pixelSize: 13; visible: schName.text.length === 0 } }
                }
                Row {
                    width: parent.width; height: 30; spacing: 6
                    component CronField: Rectangle {
                        id: cfRoot
                        property alias text: cf.text
                        property string ph: ""
                        width: 64; height: 30; radius: 8; color: "#0f0a06"; border.color: "#2a2114"; border.width: 1
                        TextInput { id: cf; anchors.fill: parent; anchors.margins: 6; verticalAlignment: TextInput.AlignVCenter; horizontalAlignment: TextInput.AlignHCenter; color: "#F2E8D0"; font.family: "Menlo"; font.pixelSize: 13; clip: true; text: "*"
                            Text { anchors.centerIn: parent; text: cfRoot.ph; color: "#6b5d3f"; font.pixelSize: 10; visible: cf.text.length === 0 } }
                    }
                    CronField { id: cMin; ph: "min" }
                    CronField { id: cHr; ph: "hour" }
                    CronField { id: cDom; ph: "day" }
                    CronField { id: cMon; ph: "month" }
                    CronField { id: cDow; ph: "wkday" }
                    SButton {
                        anchors.verticalCenter: parent.verticalCenter; text: "Create"; variant: "primary"
                        onClicked: {
                            if (schName.text.length === 0) return
                            StaffApi.send("POST", "/servers/" + root.serverId + "/schedules", JSON.stringify({
                                name: schName.text, minute: cMin.text || "*", hour: cHr.text || "*",
                                dayOfMonth: cDom.text || "*", month: cMon.text || "*", dayOfWeek: cDow.text || "*", onlyWhenOnline: false
                            }))
                            root.creating = false; schName.text = ""
                        }
                    }
                }
            }
        }
        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }
        ListView {
            width: parent.width; height: parent.height - (root.creating ? 148 : 50); clip: true; spacing: 6
            model: root.schedules
            delegate: Rectangle {
                width: ListView.view.width; height: 56; radius: 11
                color: "#16110a"; border.color: "#241c12"; border.width: 1
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Row {
                        spacing: 8
                        Text { text: modelData.name; color: "#F2E8D0"; font.pixelSize: 14; font.bold: true }
                        Rectangle {
                            width: stTxt.width + 14; height: 17; radius: 8; anchors.verticalCenter: parent.verticalCenter
                            color: modelData.isActive ? "#23311f" : "#2a2114"
                            Text { id: stTxt; anchors.centerIn: parent; text: modelData.isProcessing ? "running" : (modelData.isActive ? "active" : "paused"); color: modelData.isActive ? "#5ad17a" : "#8a7a56"; font.pixelSize: 9; font.bold: true }
                        }
                    }
                    Text { text: root.cronOf(modelData.cron) + "   ·   next " + root.relTime(modelData.nextRunAt); color: "#8a7a56"; font.family: "Menlo"; font.pixelSize: 12 }
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 7
                    SButton { text: "Run now"; variant: "secondary"; onClicked: StaffApi.send("POST", "/servers/" + root.serverId + "/schedules/" + modelData.id + "/execute", "{}") }
                    SButton { text: "Delete"; variant: "danger"; onClicked: StaffApi.send("DELETE", "/servers/" + root.serverId + "/schedules/" + modelData.id) }
                }
            }
            Text { anchors.centerIn: parent; visible: !root.loading && root.schedules.length === 0; text: "No schedules."; color: "#6b5d3f"; font.pixelSize: 14 }
        }
    }
}
