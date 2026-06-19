import QtQuick
import Jarton

// Staff roster (admin only, read): who's a proctor, their rank + flags. Create/edit/
// disable need forms — a later pass; this is the at-a-glance roster.
Item {
    id: root
    property var staff: []
    property bool loading: false
    property string error: ""
    property int reqList: -1
    property bool loadedOnce: false

    onVisibleChanged: if (visible && !loadedOnce) { loadedOnce = true; load() }

    function load() { loading = true; error = ""; reqList = ProctorApi.send("GET", "/proctor/staff") }

    Connections {
        target: ProctorApi
        function onResponse(id, ok, status, body) {
            if (id !== root.reqList) return
            root.loading = false
            if (ok) { try { root.staff = JSON.parse(body).staff || [] } catch (e) { root.staff = [] } }
            else root.error = "Couldn't load staff (admin only)."
        }
    }

    Column {
        anchors.fill: parent; anchors.margins: 4; spacing: 12
        Item {
            width: parent.width; height: 32
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Staff roster"; color: "#F2E8D0"; font.pixelSize: 16; font.bold: true }
            SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.loading ? "…" : "Refresh"; glyph: "↻"; variant: "secondary"; onClicked: root.load() }
        }
        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }
        ListView {
            width: parent.width; height: parent.height - 44; clip: true; spacing: 6
            model: root.staff
            delegate: Rectangle {
                width: ListView.view.width; height: 52; radius: 10
                color: "#16110a"; border.color: "#241c12"; border.width: 1; opacity: modelData.enabled === false ? 0.5 : 1.0
                Image {
                    id: sHead; anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 28; smooth: false; fillMode: Image.PreserveAspectFit
                    visible: !!modelData.mcUuid
                    source: modelData.mcUuid ? "https://crafatar.com/avatars/" + modelData.mcUuid + "?size=64&overlay" : ""
                }
                Column {
                    anchors.left: parent.left; anchors.leftMargin: modelData.mcUuid ? 52 : 14
                    anchors.verticalCenter: parent.verticalCenter; spacing: 2
                    Text { text: modelData.displayName ? modelData.displayName : modelData.username; color: "#F2E8D0"; font.pixelSize: 14; font.bold: true }
                    Text { text: (modelData.mcName ? modelData.mcName : modelData.username); color: "#8a7a56"; font.pixelSize: 12 }
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 7
                    Rectangle {
                        width: rk.width + 16; height: 20; radius: 10; color: "#2a2114"; anchors.verticalCenter: parent.verticalCenter
                        Text { id: rk; anchors.centerIn: parent; text: modelData.rank ? modelData.rank : "staff"; color: "#FFE082"; font.pixelSize: 11; font.bold: true }
                    }
                    Rectangle {
                        visible: modelData.proctorAdmin === true
                        width: ad.width + 16; height: 20; radius: 10; color: "#23311f"; anchors.verticalCenter: parent.verticalCenter
                        Text { id: ad; anchors.centerIn: parent; text: "admin"; color: "#5ad17a"; font.pixelSize: 11; font.bold: true }
                    }
                    Rectangle {
                        visible: modelData.enabled === false
                        width: ds.width + 16; height: 20; radius: 10; color: "#3a1414"; anchors.verticalCenter: parent.verticalCenter
                        Text { id: ds; anchors.centerIn: parent; text: "disabled"; color: "#e06c6c"; font.pixelSize: 11; font.bold: true }
                    }
                }
            }
            Text { anchors.centerIn: parent; visible: !root.loading && root.staff.length === 0 && root.error.length === 0; text: "No staff."; color: "#6b5d3f"; font.pixelSize: 14 }
        }
    }
}
