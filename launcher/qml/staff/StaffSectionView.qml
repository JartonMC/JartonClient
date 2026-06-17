import QtQuick
import Jarton

// Staff section — Phase 1: player search → player detail (status + punishment history).
// Read-only for now; punish actions (raw + offence-ladder) come next increment.
Item {
    id: view

    property string selUuid: ""
    property string selName: ""

    function relTime(ms) {
        if (!ms || ms <= 0) return ""
        var diff = Date.now() - ms
        var d = Math.floor(diff / 86400000)
        if (d > 0) return d + "d ago"
        var h = Math.floor(diff / 3600000)
        if (h > 0) return h + "h ago"
        var m = Math.floor(diff / 60000)
        return Math.max(1, m) + "m ago"
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: PlayerSearchModel.search(searchInput.text)
    }

    // ---- search + results ----
    Item {
        anchors.fill: parent
        visible: view.selUuid === ""

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text { text: "Staff"; color: "#FFE082"; font.pixelSize: 18; font.bold: true }

            Rectangle {
                width: parent.width; height: 42; radius: 9
                color: "#1a140e"
                border.color: searchInput.activeFocus ? "#FFB81C" : "#332a14"
                border.width: 1
                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: "#FFFFFF"; font.pixelSize: 15
                    clip: true
                    onTextChanged: debounce.restart()
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search a player by name…"
                        color: "#6b5d3f"; font.pixelSize: 15
                        visible: searchInput.text.length === 0 && !searchInput.activeFocus
                    }
                }
            }

            ListView {
                width: parent.width
                height: parent.height - 90
                clip: true
                spacing: 8
                model: PlayerSearchModel
                delegate: Rectangle {
                    width: ListView.view.width
                    height: 46
                    radius: 9
                    color: rowHover.containsMouse ? "#221a0f" : "#16110a"
                    border.color: "#332a14"; border.width: 1
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: name; color: "#FFFFFF"; font.pixelSize: 15
                    }
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"; color: "#6b5d3f"; font.pixelSize: 18
                    }
                    MouseArea {
                        id: rowHover
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            view.selUuid = uuid
                            view.selName = name
                            PlayerHistoryModel.load(uuid, name)
                        }
                    }
                }
            }
        }
    }

    // ---- player detail ----
    Item {
        anchors.fill: parent
        visible: view.selUuid !== ""

        Column {
            anchors.fill: parent
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
                        onClicked: view.selUuid = ""
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: view.selName
                    color: "#FFFFFF"; font.pixelSize: 18; font.bold: true
                }
            }

            // status chips
            Row {
                spacing: 8
                Rectangle {
                    visible: PlayerHistoryModel.banned
                    width: bannedTxt.width + 18; height: 24; radius: 12
                    color: "#3a1414"
                    Text { id: bannedTxt; anchors.centerIn: parent; text: "Banned"; color: "#e06c6c"; font.pixelSize: 12; font.bold: true }
                }
                Rectangle {
                    visible: PlayerHistoryModel.muted
                    width: mutedTxt.width + 18; height: 24; radius: 12
                    color: "#3a2e14"
                    Text { id: mutedTxt; anchors.centerIn: parent; text: "Muted"; color: "#FFB81C"; font.pixelSize: 12; font.bold: true }
                }
                Rectangle {
                    visible: !PlayerHistoryModel.banned && !PlayerHistoryModel.muted
                    width: cleanTxt.width + 18; height: 24; radius: 12
                    color: "#14331f"
                    Text { id: cleanTxt; anchors.centerIn: parent; text: "Clean"; color: "#5ad17a"; font.pixelSize: 12; font.bold: true }
                }
            }

            Text { text: "History"; color: "#FFE082"; font.pixelSize: 15; font.bold: true }

            Text {
                width: parent.width
                visible: PlayerHistoryModel.count === 0 && !PlayerHistoryModel.loading
                text: "No punishments on record."
                color: "#6b5d3f"; font.pixelSize: 14
            }

            ListView {
                width: parent.width
                height: parent.height - 130
                clip: true
                spacing: 8
                model: PlayerHistoryModel
                delegate: Rectangle {
                    width: ListView.view.width
                    height: 60
                    radius: 9
                    color: "#16110a"
                    border.color: "#332a14"; border.width: 1
                    Column {
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.right: parent.right; anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Row {
                            spacing: 6
                            Text { text: action.toUpperCase(); color: "#FFE082"; font.pixelSize: 13; font.bold: true }
                            Rectangle {
                                visible: active
                                width: actTxt.width + 12; height: 16; radius: 8; color: "#3a1414"
                                anchors.verticalCenter: parent.verticalCenter
                                Text { id: actTxt; anchors.centerIn: parent; text: "active"; color: "#e06c6c"; font.pixelSize: 9; font.bold: true }
                            }
                            Item { width: 1; height: 1 }
                            Text { text: view.relTime(ts); color: "#6b5d3f"; font.pixelSize: 11 }
                        }
                        Text { text: reason; color: "#cfc3a6"; font.pixelSize: 12; elide: Text.ElideRight; width: parent.width }
                        Text { text: "by " + staffName; color: "#6b5d3f"; font.pixelSize: 11 }
                    }
                }
            }
        }
    }
}
