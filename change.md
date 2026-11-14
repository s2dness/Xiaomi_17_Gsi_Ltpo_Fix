## v2.8

### New
- **Auto video match (on by default):** when a video plays at ~24 or ~30 fps, the display locks to 24 Hz / 30 Hz, like YouTube does. Works for apps that don't report their frame rate (many anime players). Touching the screen unlocks it instantly. Turn off/on with `hz autovideo`.
- **Real panel Hz indicator:** shows the panel's actual refresh rate (down to 1-9 Hz on LTPO) when a panel node is found, otherwise the SurfaceFlinger frame rate. Available in the module's WebUI page and with `hz now` / `hz watch`.
- **Optional Hz Overlay app:** adds the 3rd on-screen number (Xiaomi stock style) below the SF numbers. Build instructions: see `hz-overlay-build.yml`.
- **Refresh profiles:** `hz profile saver | balanced | smooth` to trade power saving against fewer Hz transitions.
- **New `hz` commands:** `now`, `watch`, `scan` (finds the panel Hz node), `profile`, `autovideo`, `pos`.

### Fixed
- Gray flicker on the status bar and video player controls (SurfaceFlinger layer caching is now disabled).
- Hz indicator no longer wakes the panel to 120 Hz on every update (WebUI redraws only when a value changes).
- The Hz indicator is always off after a reboot (no more inverted on/off state).

### Changed
- Removed the status bar notification of the Hz indicator.
- Idle/touch timers are now applied before SurfaceFlinger starts and follow the selected profile.
- All module texts are in English. Author: @Lifeispoop.

### Notes
- Reboot after updating.
- Auto video match is experimental: other apps that draw at 20-31 fps (30 fps games, some live wallpapers) may trigger the lock too.
- Keyboard-open refresh rate (stays at 60 Hz) is not fixed yet.
