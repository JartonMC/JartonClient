# Jarton Client

Custom Minecraft launcher for [JartonMC](https://mc.jarton.me). Fork of [Prism Launcher](https://github.com/PrismLauncher/PrismLauncher), cross-platform (Windows, macOS, Linux), licensed GPLv3.

## What it is

A polished launcher with JartonMC pinned to the home tab: one-click Play to `mc.jarton.me`, live server status, news, Discord activity, and an admin-rotated wallpaper layer. Instances are curated: pick a Minecraft version and the launcher provisions it with the Jarton mod set, then keeps stock instances updated automatically — anything you customize is yours and never touched. Prism's per-instance tooling (mod management, Modrinth + CurseForge browsers, Microsoft account auth) is preserved underneath.

## Download

Latest builds: https://jarton.me/download · also at https://github.com/JartonMC/JartonClient/releases

- **macOS** — `.dmg`. Drag to `/Applications`. First launch: right-click → Open if Gatekeeper warns.
- **Windows** — `Setup.exe`. SmartScreen warns on first launch ("More info" → "Run anyway") until we have an EV cert.
- **Linux** — `.AppImage`. `chmod +x` and run.

## Build from source

See [`BUILD.md`](BUILD.md).

Quick version on macOS with vcpkg + Homebrew Qt6:

```
cmake --preset macos
cmake --build build --config Release
cmake --install build --config Release
```

## Contributing

Run the cross-platform smoke checklist in [`SMOKE_TEST.md`](SMOKE_TEST.md) before opening a PR that touches the launcher's main flows.

## Attribution

Built on the work of the Prism Launcher contributors. Upstream: https://github.com/PrismLauncher/PrismLauncher.

## License

GPLv3, inherited from Prism Launcher. See [`LICENSE`](LICENSE).
