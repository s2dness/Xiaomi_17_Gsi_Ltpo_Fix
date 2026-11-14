## v2.9

### Fixed
- Auto video match picked 30 Hz for 24 fps videos after touching the screen. Video fps is now classified from the lowest of the first readings (UI animations only add frames).
- Touching the screen while locked at 24/30 Hz could keep the display stuck low. The peak refresh rate is now released the moment you touch the screen.

### Improved
- Faster detection: 2 readings instead of 4 (about 2-3 seconds after the video starts).
- Re-locks right away (1 reading) to the same Hz after a touch if you are still watching the same video.
- Settings are written through `cmd settings`, which is much faster than the `settings` tool.

### New
- Auto video match now also detects ~60 fps content and locks it to 60 Hz.
- `hz ovl`: checks the Hz Overlay app (installed, permission, service) and shows a test number on screen.

### Notes
- Reboot after updating.
- If a video still stays at 120 Hz, run `hz now` while it plays. "SF frames" above ~100 means the app redraws the screen constantly and the module can't detect it.
