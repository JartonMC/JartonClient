import QtQuick
import Jarton

// In-game staff login, one click from anywhere in the staff section (it used to hide
// at the bottom of More). Click mints a code via POST /proctor/codes and copies the
// whole command — "staff login <code>", no slash, so it pastes straight after the
// "/" that opens chat. Clicking again while a code is live re-copies it.
Rectangle {
    id: chip

    property string code: ""
    property double expiry: 0
    property int secsLeft: 0
    property var pending: ({})
    property bool busy: false
    property bool failed: false
    property bool justCopied: false
    readonly property bool active: code.length > 0 && secsLeft > 0
    readonly property string command: "staff login " + code

    width: row.implicitWidth + 26
    height: 30
    radius: 8
    color: ma.containsMouse ? "#26200f" : "#1b150e"
    border.color: chip.active ? "#4a3c1e" : "#2a2114"
    border.width: 1
    Behavior on color { ColorAnimation { duration: 120 } }

    function request() {
        failed = false
        busy = true
        busyFailsafe.restart()   // send() can early-return with no response (token mid-refresh)
        pending[ProctorApi.send("POST", "/proctor/codes", JSON.stringify({ deviceName: "Jarton Client" }))] = true
    }
    function copy() {
        ProctorClient.copyToClipboard(command)
        justCopied = true
        copiedReset.restart()
    }
    function fmtLeft() {
        var s = secsLeft
        return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60)
    }

    Connections {
        target: ProctorApi
        function onResponse(id, ok, status, body) {
            if (chip.pending[id] === undefined) return
            delete chip.pending[id]
            chip.busy = false
            busyFailsafe.stop()
            if (!ok) { chip.code = ""; chip.failed = true; return }
            try {
                chip.code = JSON.parse(body).code || ""
                chip.expiry = Date.now() + 5 * 60 * 1000
                chip.secsLeft = 300
                chip.copy()   // lands on the clipboard ready to paste
            } catch (e) { chip.code = ""; chip.failed = true }
        }
    }

    Timer {
        interval: 500; repeat: true; running: chip.code.length > 0 && chip.secsLeft > 0
        onTriggered: chip.secsLeft = Math.max(0, Math.round((chip.expiry - Date.now()) / 1000))
    }
    Timer { id: copiedReset; interval: 1800; onTriggered: chip.justCopied = false }
    Timer { id: busyFailsafe; interval: 8000; onTriggered: chip.busy = false }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7
        Image {
            anchors.verticalCenter: parent.verticalCenter
            source: "qrc:/jarton/staff/icons/ui/copy-cream.svg"
            width: 13; height: 13; sourceSize: Qt.size(26, 26)
            opacity: 0.85
        }
        Text {
            visible: !chip.active || chip.justCopied
            anchors.verticalCenter: parent.verticalCenter
            text: chip.justCopied ? "Copied — paste in chat"
                : chip.busy ? "Getting code…"
                : chip.failed ? "Couldn't get a code — retry" : "Staff login code"
            color: chip.failed && !chip.busy && !chip.justCopied ? "#e06c6c" : "#C9B98A"
            font.pixelSize: 12
        }
        Text {
            visible: chip.active && !chip.justCopied
            anchors.verticalCenter: parent.verticalCenter
            text: chip.command
            color: "#FFE082"
            font.family: "Menlo"; font.pixelSize: 12
        }
        Text {
            visible: chip.active && !chip.justCopied
            anchors.verticalCenter: parent.verticalCenter
            text: chip.fmtLeft()
            color: chip.secsLeft < 60 ? "#e06c6c" : "#6b5d3f"
            font.family: "Menlo"; font.pixelSize: 11
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent; hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.active ? chip.copy() : chip.request()
    }
}
