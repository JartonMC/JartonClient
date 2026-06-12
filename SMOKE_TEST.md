# Jarton Client smoke test checklist

Run this checklist on a clean machine before promoting a `beta` tag to `stable`. Roughly 20 minutes per platform.

## Per platform: macOS, Windows, Linux

### Cold launch (no cache, online)

- [ ] App starts within 5 seconds of double-click / `open`
- [ ] Splash shows the JartonMC wordmark + honey progress bar
- [ ] Main window opens to the Home tab (wallpaper visible, hero bar with Play button)
- [ ] Sidebar shows brand mark + 4 tabs (Home, Instances, Marketplace, Settings)
- [ ] Status pill shows "Online · N / M players" within 10 seconds (real ping to `mc.jarton.me`)
- [ ] Wallpaper image visible (one of the 10 manifest entries)

### Cold launch (no cache, offline)

- [ ] Disconnect network
- [ ] Delete `~/Library/Application Support/JartonClient/manifest.cache.json` (macOS) or equivalent
- [ ] Launch app
- [ ] Modal appears: "Can't reach jarton.me / Retry / Continue offline"
- [ ] Clicking Continue: app proceeds; wallpaper shows the bundled fallback; status pill greys to "Status unknown"

### Warm launch (cache exists)

- [ ] Quit app
- [ ] Disconnect network
- [ ] Relaunch
- [ ] App loads with cached manifest (no modal); status pill shows "Status unknown" within 30 seconds
- [ ] After 3 failed pings (~90 seconds), "Working offline" pill appears next to status

### Sidebar navigation

- [ ] Click Home: stack switches to Home tab
- [ ] Click Instances: stack switches to Prism's instance list
- [ ] Click Marketplace: stack switches to instance list (placeholder for now)
- [ ] Click Settings: settings dialog opens; "Jarton Client" page is the first entry
- [ ] Click brand mark: About dialog opens; shows "Jarton Client, built on Prism Launcher"

### Settings page

- [ ] Toggle "Rotate wallpapers" off → save → wallpaper stops rotating
- [ ] Toggle "Play sound effects" off → save → setting persists across restart
- [ ] Enter a custom manifest URL → save → next refresh hits the new URL (check logs)
- [ ] Click "Reset to default" → field repopulates with the bundled URL
- [ ] Click "Clear offline cache" → `manifest.cache.json` and `wallpapers/` removed

### Play action

- [ ] First launch: PlayButton shows "Set up JartonMC"; click opens NewInstanceDialog with name pre-filled
- [ ] Once instance exists: PlayButton shows "Play"; click launches Minecraft via Prism's flow
- [ ] During launch: PlayButton shows "Launching…" until Minecraft process is up

### Live data

- [ ] News feed shows entries from manifest (or empty-state message if none)
- [ ] Click a news entry → opens URL in system browser
- [ ] Discord stat tile shows online count (refreshes every 60 seconds) when `discord.gg/drxVduxqYz` widget is reachable
- [ ] Featured card visible when manifest has `featured_card`; collapses otherwise

### Crash handler

- [ ] Trigger a controlled crash (`kill -SIGSEGV <pid>`)
- [ ] Verify `~/Library/Application Support/JartonClient/crashes/crash-<ts>.log` is created
- [ ] Verify the file contains the signal name and a stack trace

### Cleanup

- [ ] Quit app
- [ ] Verify no stuck processes (`pgrep jartonclient`)

## Cross-cutting

- [ ] App icon matches the new honey-J on macOS dock, Windows taskbar, and Linux app drawer
- [ ] Theme renders correctly: honey accents, dark backgrounds, no white flash on theme switch
- [ ] No QML warnings in stdout during normal operation (font fallback warning is OK)
- [ ] No "Failed to load" warnings for QML modules

## Notes for the tester

- Log location: `~/Library/Application Support/JartonClient/` (macOS), `%APPDATA%/JartonClient/` (Windows), `~/.local/share/JartonClient/` (Linux)
- Cache files to clear when testing first-launch: `manifest.cache.json`, `wallpapers/`
- The 30-s status ping is a real MC server-list request — needs `mc.jarton.me:25565` reachable
