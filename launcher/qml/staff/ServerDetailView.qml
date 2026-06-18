import QtQuick
import Jarton

// One server, desktop-laid-out: power + live stats header, a tab bar, and the active
// tab (Console = wings console + command input; Files = browser + editor). More tabs
// (backups, schedules, network, subusers, databases) slot into the same tab bar.
Item {
    id: view
    signal back()

    property string tab: "console"
    property string filesServer: ""   // which server PteroFiles is currently browsing
    property string lastServer: ""

    // when a different server is opened, snap back to the console tab and drop stale file state
    Connections {
        target: PteroServer
        function onChanged() {
            if (PteroServer.serverId !== view.lastServer) {
                view.lastServer = PteroServer.serverId
                view.tab = "console"
                view.filesServer = ""
            }
        }
    }

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
    function selectTab(t) {
        tab = t
        if (t === "files" && filesServer !== PteroServer.serverId) {
            filesServer = PteroServer.serverId
            PteroFiles.start(PteroServer.serverId)
        }
    }

    // ---- fixed header: back + name + state, power, stats, tab bar ----
    Column {
        id: head
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 16
        spacing: 12

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
                        anchors.fill: parent; hoverEnabled: true
                        id: pwArea
                        enabled: !PteroServer.powerBusy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PteroServer.power(modelData.sig)
                    }
                }
            }
        }

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

        Row {
            spacing: 6
            Repeater {
                model: [ { id: "console", label: "Console" }, { id: "files", label: "Files" } ]
                delegate: Rectangle {
                    width: tabLabel.width + 26; height: 30; radius: 8
                    color: view.tab === modelData.id ? "#2a1f10" : (tabArea.containsMouse ? "#1a140e" : "transparent")
                    border.color: view.tab === modelData.id ? "#8B6F2A" : "#332a14"; border.width: 1
                    Text { id: tabLabel; anchors.centerIn: parent; text: modelData.label; color: view.tab === modelData.id ? "#FFE082" : "#9a8a66"; font.pixelSize: 13 }
                    MouseArea {
                        id: tabArea
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.selectTab(modelData.id)
                    }
                }
            }
        }
    }

    // ---- content area (fills below the header) ----
    Item {
        anchors.top: head.bottom; anchors.topMargin: 12
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 16; anchors.rightMargin: 16; anchors.bottomMargin: 16

        // ===== Console =====
        Column {
            anchors.fill: parent
            spacing: 10
            visible: view.tab === "console"

            Rectangle {
                width: parent.width
                height: parent.height - 50
                radius: 10
                color: "#0a0805"; border.color: "#332a14"; border.width: 1
                ListView {
                    id: log
                    anchors.fill: parent; anchors.margins: 10
                    clip: true
                    model: PteroServer.lines
                    delegate: Text {
                        width: log.width
                        text: modelData; color: "#cfc3a6"
                        font.family: "Menlo"; font.pixelSize: 12
                        lineHeight: 1.15
                        wrapMode: Text.WrapAnywhere; textFormat: Text.RichText
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
            Rectangle {
                width: parent.width; height: 40; radius: 9
                color: "#1a140e"
                border.color: cmdInput.activeFocus ? "#FFB81C" : "#332a14"; border.width: 1
                opacity: PteroServer.consoleState === "live" ? 1.0 : 0.5
                Row {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                    Text { text: "›"; color: "#FFB81C"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter; rightPadding: 8 }
                    TextInput {
                        id: cmdInput
                        width: parent.width - 24
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#FFFFFF"; font.family: "Menlo"; font.pixelSize: 13; clip: true
                        enabled: PteroServer.consoleState === "live"
                        activeFocusOnPress: true
                        persistentSelection: true
                        cursorVisible: activeFocus
                        cursorDelegate: Rectangle {
                            width: 2; color: "#FFB81C"; visible: cmdInput.cursorVisible
                            SequentialAnimation on opacity {
                                running: cmdInput.cursorVisible; loops: Animation.Infinite
                                NumberAnimation { to: 0; duration: 500 }
                                NumberAnimation { to: 1; duration: 500 }
                            }
                        }
                        onAccepted: { if (text.length > 0) { PteroServer.sendCommand(text); text = "" } }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Type a command and press Enter"; color: "#6b5d3f"; font.pixelSize: 13
                            visible: cmdInput.text.length === 0 && !cmdInput.activeFocus
                        }
                    }
                }
            }
        }

        // ===== Files =====
        Item {
            anchors.fill: parent
            visible: view.tab === "files"

            // path bar
            Row {
                id: pathBar
                width: parent.width; height: 30; spacing: 8
                Rectangle {
                    width: 40; height: 28; radius: 7
                    color: upArea.containsMouse ? "#221a0f" : "transparent"
                    border.color: "#8B6F2A"; border.width: 1
                    Text { anchors.centerIn: parent; text: "↑"; color: "#FFE082"; font.pixelSize: 14 }
                    MouseArea { id: upArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: PteroFiles.up() }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: PteroFiles.cwd; color: "#9a8a66"; font.family: "Menlo"; font.pixelSize: 12
                    elide: Text.ElideMiddle; width: parent.width - 110
                }
                Rectangle {
                    width: 50; height: 28; radius: 7
                    color: refArea.containsMouse ? "#221a0f" : "transparent"
                    border.color: "#8B6F2A"; border.width: 1
                    Text { anchors.centerIn: parent; text: PteroFiles.loading ? "…" : "↻"; color: "#FFE082"; font.pixelSize: 13 }
                    MouseArea { id: refArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: PteroFiles.refresh() }
                }
            }

            ListView {
                anchors.top: pathBar.bottom; anchors.topMargin: 8
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                clip: true; spacing: 4
                model: PteroFiles
                delegate: Rectangle {
                    width: ListView.view.width; height: 36; radius: 7
                    color: fileArea.containsMouse ? "#221a0f" : "#16110a"
                    border.color: "#332a14"; border.width: 1
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: isFile ? "📄" : "📁"; font.pixelSize: 13
                    }
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 38
                        anchors.verticalCenter: parent.verticalCenter
                        text: name; color: "#FFFFFF"; font.pixelSize: 13
                    }
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: isFile ? view.fmtBytes(size) : ""
                        color: "#6b5d3f"; font.pixelSize: 11
                    }
                    MouseArea {
                        id: fileArea
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: isFile ? PteroFiles.openFile(name) : PteroFiles.enter(name)
                    }
                }
            }

            // ---- file editor overlay ----
            Rectangle {
                anchors.fill: parent
                visible: PteroFiles.openPath !== ""
                color: "#0f0a06"

                Row {
                    id: edBar
                    width: parent.width; height: 34; spacing: 8
                    Rectangle {
                        width: 64; height: 30; radius: 8
                        color: edCloseArea.containsMouse ? "#221a0f" : "transparent"
                        border.color: "#8B6F2A"; border.width: 1
                        Text { anchors.centerIn: parent; text: "‹ Files"; color: "#FFE082"; font.pixelSize: 13 }
                        MouseArea { id: edCloseArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: PteroFiles.closeFile() }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: PteroFiles.openPath; color: "#9a8a66"; font.family: "Menlo"; font.pixelSize: 12
                        elide: Text.ElideMiddle; width: parent.width - 200
                    }
                    Rectangle {
                        width: 70; height: 30; radius: 8
                        color: PteroFiles.saving ? "#5c4a2a" : (saveArea.containsMouse ? "#FFC93C" : "#FFB81C")
                        Text { anchors.centerIn: parent; text: PteroFiles.saving ? "…" : "Save"; color: "#1a140e"; font.pixelSize: 13; font.bold: true }
                        MouseArea { id: saveArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: PteroFiles.save(editor.text) }
                    }
                }
                Text {
                    id: edErr
                    anchors.top: edBar.bottom; anchors.topMargin: 4
                    text: PteroFiles.editorError; color: "#e06c6c"; font.pixelSize: 12
                    visible: PteroFiles.editorError.length > 0
                }
                Rectangle {
                    anchors.top: edErr.visible ? edErr.bottom : edBar.bottom; anchors.topMargin: 8
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    radius: 8; color: "#0a0805"; border.color: "#332a14"; border.width: 1
                    Flickable {
                        id: flick
                        anchors.fill: parent; anchors.margins: 10
                        clip: true
                        contentWidth: editor.width; contentHeight: editor.height
                        function ensureVisible(r) {
                            if (contentY >= r.y) contentY = r.y
                            else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height
                        }
                        TextEdit {
                            id: editor
                            width: flick.width
                            text: PteroFiles.content
                            color: "#e6dcc4"; font.family: "Menlo"; font.pixelSize: 12.5
                            selectByMouse: true; persistentSelection: true
                            wrapMode: TextEdit.WrapAnywhere
                            textFormat: TextEdit.PlainText
                            tabStopDistance: 28
                            selectionColor: "#5c4a2a"
                            cursorDelegate: Rectangle {
                                width: 2; color: "#FFB81C"; visible: editor.cursorVisible
                                SequentialAnimation on opacity {
                                    running: editor.cursorVisible; loops: Animation.Infinite
                                    NumberAnimation { to: 0; duration: 500 }
                                    NumberAnimation { to: 1; duration: 500 }
                                }
                            }
                            // syntax-highlight the document (comments/keys/strings/numbers)
                            Component.onCompleted: SyntaxHelper.attach(editor.textDocument)
                            // keep the caret in view as you move through a long file
                            onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: PteroFiles.editorLoading
                        text: "Loading…"; color: "#6b5d3f"; font.pixelSize: 13
                    }
                }
            }
        }
    }
}
