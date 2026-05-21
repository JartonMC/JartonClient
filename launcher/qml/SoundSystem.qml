pragma Singleton
import QtQuick
import Jarton

// Singleton sound effects. SFX playback is wired but assets are not yet
// bundled; the singleton is a no-op until WAV assets ship under qrc:/jarton/sfx/
// in a follow-up polish pass. The ConfigService.soundEnabled toggle is the
// public switch and is honored from day one.
QtObject {
    id: root

    readonly property bool enabled: ConfigService.soundEnabled

    function playClick() {
        // intentionally empty until SFX assets land
    }

    function playHover() {
        // intentionally empty until SFX assets land
    }
}
