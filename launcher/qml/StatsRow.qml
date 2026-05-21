import QtQuick
import Jarton

Row {
    spacing: 14

    StatsTile {
        label: qsTr("Top Player")
        value: "—"
        subtitle: qsTr("Coming with JartonAPI")
    }

    StatsTile {
        label: qsTr("Discord")
        value: DiscordWidgetService.available ? DiscordWidgetService.presenceCount.toString() : "—"
        subtitle: DiscordWidgetService.available ? qsTr("online now") : qsTr("Status unknown")
        visible: DiscordWidgetService.available
    }

    StatsTile {
        label: qsTr("Your Rank")
        value: "—"
        subtitle: qsTr("Connect on the server")
    }
}
