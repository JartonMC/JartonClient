import QtQuick
import Jarton

// One server, desktop-laid-out: power controls + live stats header, the wings console
// log, and a command input. Backed by the PteroServer singleton (websocket + power).
Item {
    id: view
    signal back()

    function fmtBytes(b) {
        if (b <= 0) return "0 MB"
        var mb = b / 1048576
        return mb >= 1024 ? (mb / 1024).toFixed(1) + " GB" : Math.round(mb) + " MB"
    }
    function fmtUptime(ms) {
        if (ms <= 0) return "—"
        var s = Math.floor(ms / 1000)
        var d = Math.floor(s / 86400); s -= d * 86400
        var h = Math.floor(s / 3600); s -= h * 3600
        var m = Math.floor(s / 60)
        if (d > 0) return d + "d " + h + "h"
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }
    function stateColor(s) {
        return s === "running" ? "#5ad17a" : s === "starting" || s === "stopping" ? "#FFB81C" : "#e06c6c"
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ---- header: back + name + state ----
        Row {
            width: parent.width
            spacing: 10
            Rectangle {
                width: 64; height: 30; radius: 8
                color: backArea.containsMouse ? "#221a0f" : "transparent"
                border.color: "#8B6F2A"; border.width: 1
                Text { anchors.centerIn: parent; text: "‹ Back"; color: "#FFE082"; font.pixelSize: 13 }
                MouseArea {
                    id: backArea
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.back()
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: PteroServer.serverName; color: "#FFFFFF"; font.pixelSize: 18; font.bold: true
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: stateTxt.width + 20; height: 24; radius: 12
                color: Qt.rgba(0, 0, 0, 0.25)
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Rectangle { width: 8; height: 8; radius: 4; color: view.stateColor(PteroServer.runState); anchors.verticalCenter: parent.verticalCenter }
                    Text { id: stateTxt; text: PteroServer.runState; color: view.stateColor(PteroServer.runState); font.pixelSize: 12; font.bold: true }
                }
            }
        }

        // ---- power controls ----
        Row {
            spacing: 8
            Repeater {
                model: [
                    { label: "Start", sig: "start", col: "#1f3a26" },
                    { label: "Restart", sig: "restart", col: "#3a2f14" },
                    { label: "Stop", sig: "stop", col: "#3a2414" },
                    { label: "Kill", sig: "kill", col: "#3a1414" }
                ]
                delegate: Rectangle {
                    width: 84; height: 34; radius: 8
                    color: pwArea.containsMouse ? Qt.lighter(modelData.col, 1.3) : modelData.col
                    opacity: PteroServer.powerBusy ? 0.5 : 1.0
                    border.color: "#5c4a2a"; border.width: 1
                    Text { anchors.centerIn: parent; text: modelData.label; color: "#FFE082"; font.pixelSize: 13; font.bold: true }
                    MouseArea {
                        id: pwArea
                        anchors.fill: parent; hoverEnabled: true
                        enabled: !PteroServer.powerBusy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PteroServer.power(modelData.sig)
                    }
                }
            }
        }

        // ---- live stats ----
        Row {
            width: parent.width
            spacing: 10
            Repeater {
                model: [
                    { k: "CPU", v: PteroServer.cpuPercent.toFixed(1) + "%" },
                    { k: "Memory", v: view.fmtBytes(PteroServer.memoryBytes) + (PteroServer.memoryLimitBytes > 0 ? " / " + view.fmtBytes(PteroServer.memoryLimitBytes) : "") },
                    { k: "Disk", v: view.fmtBytes(PteroServer.diskBytes) },
                    { k: "Uptime", v: view.fmtUptime(PteroServer.uptimeMs) }
                ]
                delegate: Rectangle {
                    width: (view.width - 32 - 30) / 4
                    height: 48; radius: 9
                    color: "#16110a"; border.color: "#332a14"; border.width: 1
                    Column {
                        anchors.centerIn: parent; spacing: 2
                        Text { text: modelData.k; color: "#9a8a66"; font.pixelSize: 11; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: modelData.v; color: "#FFFFFF"; font.pixelSize: 14; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }
            }
        }

        // ---- console ----
        Rectangle {
            width: parent.width
            height: parent.height - 220
            radius: 10
            color: "#0a0805"; border.color: "#332a14"; border.width: 1

            ListView {
                id: log
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                model: PteroServer.lines
                delegate: Text {
                    width: log.width
                    text: modelData
                    color: "#cfc3a6"
                    font.family: "Menlo"; font.pixelSize: 12
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                }
                onCountChanged: positionViewAtEnd()

                Text {
                    anchors.centerIn: parent
                    visible: log.count === 0
                    text: PteroServer.consoleState === "live" ? "Waiting for output…" : "Connecting to console…"
                    color: "#6b5d3f"; font.pixelSize: 13
                }
            }
        }

        // ---- command input ----
        Rectangle {
            width: parent.width; height: 40; radius: 9
            color: "#1a140e"
            border.color: cmdInput.activeFocus ? "#FFB81C" : "#332a14"; border.width: 1
            opacity: PteroServer.consoleState === "live" ? 1.0 : 0.5
            Row {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                Text { text: "›"; color: "#FFB81C"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter; rightPadding: 8 }
                TextInput {
                    id: cmdInput
                    width: parent.width - 24
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#FFFFFF"; font.family: "Menlo"; font.pixelSize: 13
                    clip: true
                    enabled: PteroServer.consoleState === "live"
                    onAccepted: {
                        if (text.length > 0) { PteroServer.sendCommand(text); text = "" }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Type a command and press Enter"
                        color: "#6b5d3f"; font.pixelSize: 13
                        visible: cmdInput.text.length === 0 && !cmdInput.activeFocus
                    }
                }
            }
        }
    }
}
