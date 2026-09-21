# Implementation status — 0.2.0 alpha

## Verified by automated tests / inspected rendering

- Detector attack, hysteresis, hold/release, finite silence, stereo energy.
- Embedded artwork save/load, overwrite with backup, undo/redo, invalid-reference/cyclic-parent/malformed-JSON rejection.
- Real PNG accessory import, inspector command application, expression selection/creation.
- Simultaneous mouth and blink behavior.
- Windows helper startup, authenticated heartbeat, stop/reset; action routing into app.
- Native output creation, borderless/alpha request, color-key background control.
- Actual output corner alpha and opaque artwork pixels.
- Main workspace screenshot visually inspected on Intel HD Graphics 530 through ANGLE/D3D11.
- Parent translation/rotation/scale and opacity inheritance, order-independent evaluation, cycle prevention, spring settling.
- Frame timing and transparency composition for generated GIF/APNG/WebP fixtures.
- Layer duplication with independent IDs; animation loop/one-shot timing.

## Implemented, needs further manual verification

- Live microphone capture/calibration and real-world speech response.
- Real keyboard combinations with another application/game focused.
- Grid sprite sheets, pointer tracking, pivots, mirroring, locks, all numerical editing limits and broad spring parameter combinations.
- Autosave/recovery under crash, disk-full and large-file conditions.
- Hide-editor/live-output lifecycle, varied displays/DPI, broad Windows hardware compatibility.

## Environment limitation

Audio enumeration exposed only Default and no usable microphone. The app now rejects that condition instead of presenting it as live input. Actual speech capture and hotplug remain unverified.

## Not implemented / not verified

OBS capture; macOS/Linux packages; decoder conformance across complex disposal/color-profile cases; appendage/mesh rigs; selective transform inheritance; costume system; keyframe editor; clipping/blend modes; general reaction priorities; key rebinding/conflicts; output-resolution controls; click-through; final performance budgets; long-session soak; code signing/installer.

The full replacement plan remains the target. This first executable is an early working alpha.

## Latest build evidence

- 40 core checks passed: detector, persistence, validation, hierarchy, spring motion, clip timing and APNG/WebP fixtures.
- 29 workspace checks passed: real-window commands, GIF fixture, helper communication and output pixels.
- 12 checks passed inside the exported Windows executable, including helper startup, clean output, alpha, save/reload and screenshot capture.
- The exported workspace screenshot was visually inspected.
- The editor import pass completes cleanly. Animated test fixtures are deliberately excluded from the editor's static-image importer.

These 81 automated checks do not replace the outstanding microphone, real foreground-game shortcut, OBS, cross-platform, and long-session manual tests.
