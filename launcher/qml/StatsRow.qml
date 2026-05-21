import QtQuick
import Jarton

Row {
    spacing: 14

    StatsTile {
        label: qsTr("Players Online")
        value: ServerStatusService.state === 1
            ? ServerStatusService.playersOnline + " / " + ServerStatusService.playersMax
            : "—"
        subtitle: ServerStatusService.state === 1
            ? qsTr("on mc.jarton.me")
            : ServerStatusService.state === 0
                ? qsTr("Status unknown")
                : qsTr("Server offline")
    }

    StatsTile {
        label: qsTr("Discord")
        value: DiscordWidgetService.available ? DiscordWidgetService.presenceCount.toString() : "—"
        subtitle: DiscordWidgetService.available ? qsTr("online now") : qsTr("Status unknown")
        visible: DiscordWidgetService.available
    }
}
