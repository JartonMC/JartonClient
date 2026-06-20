import QtQuick
import Jarton

// Player lookup → detail (status + punishment history). Read-only; punish actions
// (raw + offence-ladder) come next. One of the Staff section's sub-tabs.
Item {
    id: view

    property string selUuid: ""
    property string selName: ""
    property bool punishing: false

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
            anchors.margins: 4
            spacing: 12

            Rectangle {
                width: parent.width; height: 42; radius: 9
                color: "#15100a"
                border.color: searchInput.activeFocus ? "#FFB81C" : "#2a2114"
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }
                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: "#F2E8D0"; font.pixelSize: 15
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
                height: parent.height - 56
                clip: true
                spacing: 6
                model: PlayerSearchModel
                delegate: Rectangle {
                    width: ListView.view.width
                    height: 48
                    radius: 10
                    color: rowHover.containsMouse ? "#221a0f" : "#16110a"
                    border.color: rowHover.containsMouse ? "#3a2f1c" : "#241c12"; border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Avatar {
                        id: rowHead
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        size: 30; uuid: model.uuid
                    }
                    Text {
                        anchors.left: rowHead.right; anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: name; color: "#F2E8D0"; font.pixelSize: 15
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
            anchors.margins: 4
            spacing: 12

            Item {
                width: parent.width; height: 34
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    SButton { text: "Back"; glyph: "‹"; variant: "ghost"; onClicked: view.selUuid = "" }
                    Avatar {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 34; uuid: view.selUuid
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: view.selName
                        color: "#F2E8D0"; font.pixelSize: 18; font.bold: true
                    }
                }
                SButton {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "Punish"; glyph: "⚖"; variant: "primary"; onClicked: view.punishing = true
                }
            }

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
                spacing: 6
                model: PlayerHistoryModel
                delegate: Rectangle {
                    width: ListView.view.width
                    height: 60
                    radius: 10
                    color: "#16110a"
                    border.color: "#241c12"; border.width: 1
                    Column {
                        anchors.left: parent.left; anchors.leftMargin: 14
                        anchors.right: parent.right; anchors.rightMargin: 14
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

        PunishPanel {
            anchors.fill: parent
            visible: view.punishing
            uuid: view.selUuid
            name: view.selName
            onClose: { view.punishing = false; PlayerHistoryModel.load(view.selUuid, view.selName) }
        }
    }
}
