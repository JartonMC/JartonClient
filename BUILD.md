# Building Jarton Client

Fork of Prism Launcher; same CMake-based build system.

## Prerequisites

All platforms:
- CMake >= 3.20
- Qt 6.5+ (Core, Widgets, Network, Concurrent, Xml, NetworkAuth)
- A C++17-capable compiler
- Git with submodule support

### macOS
- Xcode 15+ and Command Line Tools
- `brew install qt@6 cmake ninja`

### Windows
- Visual Studio 2022 with "Desktop development with C++"
- Qt 6 from the official online installer into `C:\Qt`
- CMake and Ninja (bundled with VS)

### Linux (Debian/Ubuntu)
- GCC 12+ or Clang 15+
- `apt install qt6-base-dev qt6-tools-dev libgl1-mesa-dev libqt6networkauth6-dev cmake ninja-build`

## Quick build

```bash
git clone --recurse-submodules https://github.com/JartonMC/JartonClient.git
cd JartonClient
cmake --preset linux         # or macos_universal, windows_msvc
cmake --build --preset linux
```

Resulting binary:
- macOS: `build/Jarton Client.app`
- Windows: `build\install\jartonclient.exe`
- Linux: `build/jartonclient`

## Running tests

```bash
ctest --preset linux
```

## CI

GitHub Actions builds every commit on `main` for macOS, Linux, and Windows. Tagging a commit with `v*` triggers `release.yml` which produces a draft GitHub Release with installers for all three platforms.

See `.github/workflows/` and `.github/actions/package/` for the pipeline.

## Code signing

Phase 0 ships unsigned / ad-hoc-signed builds. macOS DMG is ad-hoc signed (Gatekeeper warning on first launch, workaround documented in `README.md`). Windows artifacts are unsigned (SmartScreen warning). Linux AppImages are unsigned.

Full Apple Developer ID signing and notarization will be added when warranted by user volume.

## Project structure

Upstream Prism layout, mostly unchanged. Jarton-specific work lands in later phases:
- `launcher/qml/` (Phase 1+): QML for new AppShell and Home tab
- `launcher/services/jarton/` (Phase 2+): C++ services for manifest, status, news, wallpaper, Discord
- `resources/jarton/` (Phase 1+): branding assets, sounds, fonts, QSS theme
