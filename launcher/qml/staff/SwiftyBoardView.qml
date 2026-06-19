import QtQuick
import Jarton

// One Swifty board: horizontal columns (lists) of cards; click a card for its detail.
// Full write parity with the app — add lists/cards, move cards, toggle complete,
// edit title/description, checklist add/toggle, and comments. Card meta (labels,
// members, checklist, comments) is a JSON string we mutate and PATCH back whole.
Item {
    id: board
    property string boardId: ""
    property string boardName: ""
    signal back()

    property var lists: []
    property bool loading: false
    property int reqLists: -1
    property int reqMe: -1
    property var pendingWrites: []
    property string meName: "You"
    property string meAvatar: ""

    property var selCard: null      // resolved card object when a card is open
    property string selCardId: ""

    // card-detail edit state
    property bool editTitle: false
    property bool editDesc: false

    Component.onCompleted: load()
    onBoardIdChanged: load()

    function load() {
        if (!boardId.length) return
        loading = true; selCard = null; selCardId = ""
        reqMe = SwiftyApi.send("GET", "/users/me")
        reqLists = SwiftyApi.send("GET", "/boards/" + boardId + "/lists")
    }
    function reload() { reqLists = SwiftyApi.send("GET", "/boards/" + boardId + "/lists") }
    function meta(card) { try { return card && card.meta ? JSON.parse(card.meta) : {} } catch (e) { return {} } }
    function relTime(iso) {
        if (!iso) return ""
        var t = Date.parse(iso); if (isNaN(t)) return ""
        var d = Date.now() - t
        var days = Math.floor(d / 86400000); if (days > 0) return days + "d ago"
        var h = Math.floor(d / 3600000); if (h > 0) return h + "h ago"
        return Math.max(1, Math.floor(d / 60000)) + "m ago"
    }
    function resolveSel() {
        for (var i = 0; i < lists.length; i++) {
            var cs = lists[i].cards || []
            for (var j = 0; j < cs.length; j++) if (cs[j].id === selCardId) { selCard = cs[j]; return }
        }
    }
    function listOf(cardId) {
        for (var i = 0; i < lists.length; i++) {
            var cs = lists[i].cards || []
            for (var j = 0; j < cs.length; j++) if (cs[j].id === cardId) return lists[i].id
        }
        return ""
    }

    // ---- write helpers ----
    function uuid() {
        function h(n) { var s = ""; for (var i = 0; i < n; i++) s += Math.floor(Math.random() * 16).toString(16); return s }
        return h(8) + "-" + h(4) + "-4" + h(3) + "-" + h(4) + "-" + h(12)
    }
    function track(reqId) { var p = pendingWrites; p.push(reqId); pendingWrites = p }
    function commitMeta(card, m) { track(SwiftyApi.send("PATCH", "/cards/" + card.id, JSON.stringify({ meta: JSON.stringify(m) }))) }
    function patchField(card, obj) { track(SwiftyApi.send("PATCH", "/cards/" + card.id, JSON.stringify(obj))) }
    function toggleComplete(card) { track(SwiftyApi.send("PATCH", "/cards/" + card.id + "/toggle", "{}")) }
    function addCard(listId, title) { if (!title || !title.length) return; track(SwiftyApi.send("POST", "/lists/" + listId + "/cards", JSON.stringify({ title: title }))) }
    function addList(name) { if (!name || !name.length) return; track(SwiftyApi.send("POST", "/boards/" + boardId + "/lists", JSON.stringify({ name: name }))) }
    function deleteCard(card) { track(SwiftyApi.send("DELETE", "/cards/" + card.id, "")); selCard = null; selCardId = "" }
    function moveCard(card, destListId) {
        var src = card.listId || listOf(card.id)
        if (src === destListId) return
        track(SwiftyApi.send("POST", "/cards/move", JSON.stringify({
            boardId: boardId, sourceListId: src, destListId: destListId, cardId: card.id, destIndex: 0
        })))
    }
    function addComment(card, text) {
        if (!text || !text.length) return
        var m = meta(card); if (!m.comments) m.comments = []
        m.comments.push({ id: uuid(), author: meName, avatarUrl: meAvatar, text: text, createdAt: new Date().toISOString() })
        commitMeta(card, m)
    }
    function toggleChecklist(card, itemId) {
        var m = meta(card); var items = m.checklist || []
        for (var i = 0; i < items.length; i++) if (items[i].id === itemId) items[i].done = !items[i].done
        m.checklist = items; commitMeta(card, m)
    }
    function addChecklistItem(card, text) {
        if (!text || !text.length) return
        var m = meta(card); if (!m.checklist) m.checklist = []
        m.checklist.push({ id: uuid(), text: text, done: false })
        commitMeta(card, m)
    }

    Connections {
        target: SwiftyApi
        function onResponse(id, ok, status, body) {
            if (id === board.reqMe) {
                if (ok) { try { var u = JSON.parse(body); board.meName = u.name || u.email || "You"; board.meAvatar = u.avatarUrl || "" } catch (e) {} }
                return
            }
            if (id === board.reqLists) {
                board.loading = false
                if (ok) { try { board.lists = JSON.parse(body) || [] } catch (e) { board.lists = [] } }
                if (board.selCardId.length) board.resolveSel()
                return
            }
            var idx = board.pendingWrites.indexOf(id)
            if (idx !== -1) { board.pendingWrites.splice(idx, 1); board.reload() }
        }
    }

    Rectangle { anchors.fill: parent; color: "#0f0a06" }

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
                    id: col
                    required property var modelData
                    property bool adding: false
                    width: 270; height: colRow.height; radius: 13
                    color: "#14100a"; border.color: "#241c12"; border.width: 1
                    Column {
                        anchors.fill: parent; anchors.margins: 10; spacing: 8
                        Row {
                            width: parent.width; spacing: 6
                            Text { text: col.modelData.name; color: "#F2E8D0"; font.pixelSize: 14; font.bold: true }
                            Text { text: col.modelData.cards ? col.modelData.cards.length : 0; color: "#6b5d3f"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        }
                        ListView {
                            width: parent.width; height: parent.height - 64; clip: true; spacing: 6
                            model: col.modelData.cards
                            delegate: Rectangle {
                                id: cardItem
                                required property var modelData
                                width: ListView.view.width; height: cardCol.height + 18; radius: 9
                                color: cMa.containsMouse ? "#241c10" : "#1b150e"
                                border.color: cMa.containsMouse ? "#3a2f1c" : "#241c12"; border.width: 1
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Column {
                                    id: cardCol
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 9
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 5
                                    Row {
                                        spacing: 4; visible: board.meta(cardItem.modelData).labels && board.meta(cardItem.modelData).labels.length > 0
                                        Repeater {
                                            model: board.meta(cardItem.modelData).labels || []
                                            delegate: Rectangle { required property var modelData; width: 22; height: 6; radius: 3; color: modelData.color ? modelData.color : "#FFB81C" }
                                        }
                                    }
                                    Text {
                                        width: parent.width; text: cardItem.modelData.title; color: cardItem.modelData.completed ? "#6b5d3f" : "#F2E8D0"
                                        font.pixelSize: 13; wrapMode: Text.WordWrap
                                        font.strikeout: cardItem.modelData.completed === true
                                    }
                                }
                                MouseArea {
                                    id: cMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { board.selCardId = cardItem.modelData.id; board.selCard = cardItem.modelData; board.editTitle = false; board.editDesc = false }
                                }
                            }
                        }
                        // add-card footer
                        Item {
                            width: parent.width; height: 28
                            SButton {
                                anchors.fill: parent; visible: !col.adding; text: "Add a card"; glyph: "＋"; variant: "ghost"
                                onClicked: { col.adding = true; addCardIn.forceActiveFocus() }
                            }
                            Rectangle {
                                anchors.fill: parent; visible: col.adding; radius: 8; color: "#0f0a06"; border.color: "#FFB81C"; border.width: 1
                                TextInput {
                                    id: addCardIn; anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter; color: "#F2E8D0"; font.pixelSize: 12; clip: true
                                    onAccepted: { board.addCard(col.modelData.id, text); text = ""; col.adding = false }
                                    Keys.onEscapePressed: { text = ""; col.adding = false }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "card title, ↵ to add"; color: "#6b5d3f"; font.pixelSize: 12; visible: addCardIn.text.length === 0 }
                                }
                            }
                        }
                    }
                }
            }
            // trailing add-list column
            Rectangle {
                width: 270; height: 96; radius: 13; color: "#120d07"; border.color: "#241c12"; border.width: 1
                Column {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                    Text { text: "New list"; color: "#FFE082"; font.pixelSize: 13; font.bold: true }
                    Rectangle {
                        width: parent.width; height: 30; radius: 8; color: "#0f0a06"; border.color: "#2a2114"; border.width: 1
                        TextInput {
                            id: addListIn; anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter; color: "#F2E8D0"; font.pixelSize: 12; clip: true
                            onAccepted: { board.addList(text); text = "" }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "list name, ↵ to add"; color: "#6b5d3f"; font.pixelSize: 12; visible: addListIn.text.length === 0 }
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
            SButton {
                text: (board.selCard && board.selCard.completed) ? "Completed" : "Mark done"
                variant: (board.selCard && board.selCard.completed) ? "secondary" : "primary"
                onClicked: if (board.selCard) board.toggleComplete(board.selCard)
            }
            SButton { text: "Delete"; variant: "danger"; onClicked: if (board.selCard) board.deleteCard(board.selCard) }
        }

        Flickable {
            anchors.top: cdHead.bottom; anchors.topMargin: 10
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.leftMargin: 18; anchors.rightMargin: 18; anchors.bottomMargin: 18
            contentWidth: width; contentHeight: cdCol.height; clip: true

            Column {
                id: cdCol
                width: parent.width; spacing: 14

                // title (click to edit)
                Item {
                    width: parent.width; height: titleEdit.visible ? 36 : titleText.height
                    Text {
                        id: titleText; visible: !board.editTitle; width: parent.width
                        text: board.selCard ? board.selCard.title : ""; color: "#F2E8D0"; font.pixelSize: 18; font.bold: true; wrapMode: Text.WordWrap
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { titleEdit.text = titleText.text; board.editTitle = true; titleEdit.forceActiveFocus() } }
                    }
                    Rectangle {
                        anchors.fill: parent; visible: board.editTitle; radius: 8; color: "#0f0a06"; border.color: "#FFB81C"; border.width: 1
                        TextInput {
                            id: titleEdit; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter; color: "#F2E8D0"; font.pixelSize: 16; font.bold: true; clip: true
                            onAccepted: { if (board.selCard) board.patchField(board.selCard, { title: text }); board.editTitle = false }
                            Keys.onEscapePressed: board.editTitle = false
                        }
                    }
                }

                // labels
                Flow {
                    width: parent.width; spacing: 6
                    visible: board.selCard && board.meta(board.selCard).labels && board.meta(board.selCard).labels.length > 0
                    Repeater {
                        model: board.selCard ? (board.meta(board.selCard).labels || []) : []
                        delegate: Rectangle {
                            required property var modelData
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
                            required property var modelData
                            width: mT.width + 16; height: 22; radius: 11; color: "#2a2114"; anchors.verticalCenter: parent.verticalCenter
                            Text { id: mT; anchors.centerIn: parent; text: modelData.name ? modelData.name : "?"; color: "#FFE082"; font.pixelSize: 11 }
                        }
                    }
                }

                // move to list
                Column {
                    width: parent.width; spacing: 5
                    visible: board.lists.length > 1
                    Text { text: "Move to"; color: "#FFE082"; font.pixelSize: 13; font.bold: true }
                    Flow {
                        width: parent.width; spacing: 6
                        Repeater {
                            model: board.lists
                            delegate: SButton {
                                required property var modelData
                                visible: board.selCard && modelData.id !== (board.selCard.listId || board.listOf(board.selCard.id))
                                text: modelData.name; variant: "secondary"
                                onClicked: if (board.selCard) board.moveCard(board.selCard, modelData.id)
                            }
                        }
                    }
                }

                // description (click to edit)
                Column {
                    width: parent.width; spacing: 5
                    Text { text: "Description"; color: "#FFE082"; font.pixelSize: 13; font.bold: true }
                    Text {
                        visible: !board.editDesc; width: parent.width
                        text: board.selCard && board.selCard.description && board.selCard.description.length ? board.selCard.description : "Add a description…"
                        color: board.selCard && board.selCard.description && board.selCard.description.length ? "#cfc3a6" : "#6b5d3f"
                        font.pixelSize: 13; wrapMode: Text.WordWrap
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { descEdit.text = (board.selCard && board.selCard.description) ? board.selCard.description : ""; board.editDesc = true; descEdit.forceActiveFocus() } }
                    }
                    Rectangle {
                        width: parent.width; height: 90; visible: board.editDesc; radius: 8; color: "#0f0a06"; border.color: "#FFB81C"; border.width: 1
                        TextEdit {
                            id: descEdit; anchors.fill: parent; anchors.margins: 8
                            color: "#cfc3a6"; font.pixelSize: 13; wrapMode: TextEdit.Wrap; selectByMouse: true; clip: true
                        }
                    }
                    Row {
                        spacing: 8; visible: board.editDesc
                        SButton { text: "Save"; variant: "primary"; onClicked: { if (board.selCard) board.patchField(board.selCard, { description: descEdit.text }); board.editDesc = false } }
                        SButton { text: "Cancel"; variant: "ghost"; onClicked: board.editDesc = false }
                    }
                }

                // checklist
                Column {
                    width: parent.width; spacing: 6
                    Text {
                        text: { var c = board.selCard ? (board.meta(board.selCard).checklist || []) : []; var done = 0; for (var i = 0; i < c.length; i++) if (c[i].done) done++; return "Checklist  " + done + "/" + c.length }
                        color: "#FFE082"; font.pixelSize: 13; font.bold: true
                    }
                    Repeater {
                        model: board.selCard ? (board.meta(board.selCard).checklist || []) : []
                        delegate: Row {
                            required property var modelData
                            width: parent.width; spacing: 8
                            Text {
                                text: modelData.done ? "☑" : "☐"; color: modelData.done ? "#5ad17a" : "#6b5d3f"; font.pixelSize: 14
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (board.selCard) board.toggleChecklist(board.selCard, modelData.id) }
                            }
                            Text {
                                width: parent.width - 26; text: modelData.text ? modelData.text : ""; color: modelData.done ? "#6b5d3f" : "#cfc3a6"; font.pixelSize: 13; wrapMode: Text.WordWrap; font.strikeout: modelData.done === true
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (board.selCard) board.toggleChecklist(board.selCard, modelData.id) }
                            }
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 30; radius: 8; color: "#0f0a06"; border.color: "#2a2114"; border.width: 1
                        TextInput {
                            id: checkIn; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter; color: "#F2E8D0"; font.pixelSize: 13; clip: true
                            onAccepted: { if (board.selCard) board.addChecklistItem(board.selCard, text); text = "" }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "add an item, ↵ to add"; color: "#6b5d3f"; font.pixelSize: 13; visible: checkIn.text.length === 0 }
                        }
                    }
                }

                // comments
                Column {
                    width: parent.width; spacing: 8
                    Text { text: "Comments"; color: "#FFE082"; font.pixelSize: 13; font.bold: true }
                    Rectangle {
                        width: parent.width; height: 34; radius: 9; color: "#0f0a06"; border.color: "#2a2114"; border.width: 1
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 6; spacing: 6
                            TextInput {
                                id: commentIn; width: parent.width - 70; height: parent.height
                                verticalAlignment: TextInput.AlignVCenter; color: "#F2E8D0"; font.pixelSize: 12; clip: true
                                onAccepted: { if (board.selCard) board.addComment(board.selCard, text); text = "" }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "write a comment…"; color: "#6b5d3f"; font.pixelSize: 12; visible: commentIn.text.length === 0 }
                            }
                            SButton { anchors.verticalCenter: parent.verticalCenter; text: "Send"; variant: "primary"; onClicked: { if (board.selCard) board.addComment(board.selCard, commentIn.text); commentIn.text = "" } }
                        }
                    }
                    Repeater {
                        model: board.selCard ? (board.meta(board.selCard).comments || []) : []
                        delegate: Rectangle {
                            required property var modelData
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
