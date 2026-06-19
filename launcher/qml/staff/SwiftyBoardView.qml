import QtQuick
import Jarton

// One Swifty board: horizontal columns (lists) of cards; click a card for its detail
// (description, labels, members, checklist, comments). Read view for now.
Item {
    id: board
    property string boardId: ""
    property string boardName: ""
    signal back()

    property var lists: []
    property bool loading: false
    property int reqLists: -1
    property var selCard: null   // parsed card object when a card is open

    Component.onCompleted: load()
    onBoardIdChanged: load()

    function load() {
        if (!boardId.length) return
        loading = true; selCard = null
        reqLists = SwiftyApi.send("GET", "/boards/" + boardId + "/lists")
    }
    function meta(card) { try { return card && card.meta ? JSON.parse(card.meta) : {} } catch (e) { return {} } }
    function relTime(iso) {
        if (!iso) return ""
        var t = Date.parse(iso); if (isNaN(t)) return ""
        var d = Date.now() - t
        var days = Math.floor(d / 86400000); if (days > 0) return days + "d ago"
        var h = Math.floor(d / 3600000); if (h > 0) return h + "h ago"
        return Math.max(1, Math.floor(d / 60000)) + "m ago"
    }

    Connections {
        target: SwiftyApi
        function onResponse(id, ok, status, body) {
            if (id !== board.reqLists) return
            board.loading = false
            if (ok) { try { board.lists = JSON.parse(body) || [] } catch (e) { board.lists = [] } }
        }
    }

    Rectangle { anchors.fill: parent; color: "#0f0a06" }  // opaque cover over the boards list

    // header
    Row {
        id: bhead
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 16; spacing: 12
        SButton { text: "Boards"; glyph: "‹"; variant: "ghost"; onClicked: board.back() }
        Text { anchors.verticalCenter: parent.verticalCenter; text: board.boardName; color: "#F2E8D0"; font.pixelSize: 19; font.bold: true }
    }

    // columns
    Flickable {
        anchors.top: bhead.bottom; anchors.topMargin: 8
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 16; anchors.rightMargin: 16; anchors.bottomMargin: 16
        contentWidth: colRow.width; contentHeight: height
        flickableDirection: Flickable.HorizontalFlick; clip: true

        Row {
            id: colRow
            height: parent.height; spacing: 12
            Repeater {
                model: board.lists
                delegate: Rectangle {
                    width: 270; height: colRow.height; radius: 13
                    color: "#14100a"; border.color: "#241c12"; border.width: 1
                    Column {
                        anchors.fill: parent; anchors.margins: 10; spacing: 8
                        Row {
                            width: parent.width; spacing: 6
                            Text { text: modelData.name; color: "#F2E8D0"; font.pixelSize: 14; font.bold: true }
                            Text { text: modelData.cards ? modelData.cards.length : 0; color: "#6b5d3f"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        }
                        ListView {
                            width: parent.width; height: parent.height - 30; clip: true; spacing: 6
                            model: modelData.cards
                            delegate: Rectangle {
                                width: ListView.view.width; height: cardCol.height + 18; radius: 9
                                color: cMa.containsMouse ? "#241c10" : "#1b150e"
                                border.color: cMa.containsMouse ? "#3a2f1c" : "#241c12"; border.width: 1
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Column {
                                    id: cardCol
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 9
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 5
                                    Row {
                                        spacing: 4; visible: board.meta(modelData).labels && board.meta(modelData).labels.length > 0
                                        Repeater {
                                            model: board.meta(modelData).labels || []
                                            delegate: Rectangle { width: 22; height: 6; radius: 3; color: modelData.color ? modelData.color : "#FFB81C" }
                                        }
                                    }
                                    Text {
                                        width: parent.width; text: modelData.title; color: modelData.completed ? "#6b5d3f" : "#F2E8D0"
                                        font.pixelSize: 13; wrapMode: Text.WordWrap
                                        font.strikeout: modelData.completed === true
                                    }
                                }
                                MouseArea {
                                    id: cMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: board.selCard = modelData
                                }
                            }
                        }
                    }
                }
            }
        }
        Text {
            anchors.centerIn: parent; visible: !board.loading && board.lists.length === 0
            text: "This board has no lists."; color: "#6b5d3f"; font.pixelSize: 14
        }
    }

    // ---- card detail overlay ----
    Rectangle {
        anchors.fill: parent
        visible: board.selCard !== null
        color: "#0f0a06"

        Row {
            id: cdHead
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            anchors.margins: 16; spacing: 12
            SButton { text: "Board"; glyph: "‹"; variant: "ghost"; onClicked: board.selCard = null }
            Text {
                anchors.verticalCenter: parent.verticalCenter; width: parent.width - 120
                text: board.selCard ? board.selCard.title : ""; color: "#F2E8D0"; font.pixelSize: 18; font.bold: true
                wrapMode: Text.WordWrap
            }
        }

        Flickable {
            anchors.top: cdHead.bottom; anchors.topMargin: 10
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.leftMargin: 18; anchors.rightMargin: 18; anchors.bottomMargin: 18
            contentWidth: width; contentHeight: cdCol.height; clip: true

            Column {
                id: cdCol
                width: parent.width; spacing: 14

                // labels
                Flow {
                    width: parent.width; spacing: 6
                    visible: board.selCard && board.meta(board.selCard).labels && board.meta(board.selCard).labels.length > 0
                    Repeater {
                        model: board.selCard ? (board.meta(board.selCard).labels || []) : []
                        delegate: Rectangle {
                            width: lblT.width + 16; height: 20; radius: 10
                            color: modelData.color ? modelData.color : "#FFB81C"
                            Text { id: lblT; anchors.centerIn: parent; text: modelData.name ? modelData.name : ""; color: modelData.textColor ? modelData.textColor : "#1a140e"; font.pixelSize: 11; font.bold: true }
                        }
                    }
                }

                // members
                Row {
                    width: parent.width; spacing: 8
                    visible: board.selCard && board.meta(board.selCard).members && board.meta(board.selCard).members.length > 0
                    Text { text: "Members"; color: "#8a7a56"; font.pixelSize: 11; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    Repeater {
                        model: board.selCard ? (board.meta(board.selCard).members || []) : []
                        delegate: Rectangle {
                            width: mT.width + 16; height: 22; radius: 11; color: "#2a2114"; anchors.verticalCenter: parent.verticalCenter
                            Text { id: mT; anchors.centerIn: parent; text: modelData.name ? modelData.name : "?"; color: "#FFE082"; font.pixelSize: 11 }
                        }
                    }
                }

                // description
                Column {
                    width: parent.width; spacing: 5
                    visible: board.selCard && !!board.selCard.description && board.selCard.description.length > 0
                    Text { text: "Description"; color: "#FFE082"; font.pixelSize: 13; font.bold: true }
                    Text { width: parent.width; text: board.selCard ? (board.selCard.description || "") : ""; color: "#cfc3a6"; font.pixelSize: 13; wrapMode: Text.WordWrap }
                }

                // checklist
                Column {
                    width: parent.width; spacing: 6
                    visible: board.selCard && board.meta(board.selCard).checklist && board.meta(board.selCard).checklist.length > 0
                    Text {
                        text: { var c = board.selCard ? (board.meta(board.selCard).checklist || []) : []; var done = 0; for (var i = 0; i < c.length; i++) if (c[i].done) done++; return "Checklist  " + done + "/" + c.length }
                        color: "#FFE082"; font.pixelSize: 13; font.bold: true
                    }
                    Repeater {
                        model: board.selCard ? (board.meta(board.selCard).checklist || []) : []
                        delegate: Row {
                            width: parent.width; spacing: 8
                            Text { text: modelData.done ? "☑" : "☐"; color: modelData.done ? "#5ad17a" : "#6b5d3f"; font.pixelSize: 14 }
                            Text { width: parent.width - 26; text: modelData.text ? modelData.text : ""; color: modelData.done ? "#6b5d3f" : "#cfc3a6"; font.pixelSize: 13; wrapMode: Text.WordWrap; font.strikeout: modelData.done === true }
                        }
                    }
                }

                // comments
                Column {
                    width: parent.width; spacing: 8
                    visible: board.selCard && board.meta(board.selCard).comments && board.meta(board.selCard).comments.length > 0
                    Text { text: "Comments"; color: "#FFE082"; font.pixelSize: 13; font.bold: true }
                    Repeater {
                        model: board.selCard ? (board.meta(board.selCard).comments || []) : []
                        delegate: Rectangle {
                            width: parent.width; height: cmCol.height + 16; radius: 9; color: "#16110a"; border.color: "#241c12"; border.width: 1
                            Column {
                                id: cmCol
                                anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 8
                                anchors.verticalCenter: parent.verticalCenter; spacing: 3
                                Row {
                                    spacing: 8
                                    Text { text: modelData.author ? modelData.author : "?"; color: "#FFE082"; font.pixelSize: 12; font.bold: true }
                                    Text { text: board.relTime(modelData.createdAt); color: "#6b5d3f"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                }
                                Text { width: parent.width; text: modelData.text ? modelData.text : ""; color: "#cfc3a6"; font.pixelSize: 12; wrapMode: Text.WordWrap }
                            }
                        }
                    }
                }
            }
        }
    }
}
