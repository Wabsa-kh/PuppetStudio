# Current status — 0.5.0 alpha

The redesigned Windows editor has save/quit/recovery hardening, a diagnostic window, checked staged builds and a repeated-use test. See [VALIDATION.md](VALIDATION.md) for test evidence and [LAUNCH_READINESS.md](LAUNCH_READINESS.md) for release blockers.

# 0.4 UI update

The editor now uses conventional menus, contextual pages, visual artwork slots and dedicated windows. See [UI_REDESIGN.md](UI_REDESIGN.md) for the current feature map. The following earlier implementation inventory remains applicable to the underlying features.

# Implementation status — 0.3.0 alpha

The current build adds a usable layered character/rigging workflow, native file selection, independent costumes and expression reactions, motion-key editing and local control. It is not a complete replacement release.

## Verified

- Original 40 core checks and 29 real-window workspace checks retained.
- Advanced suite: 36 checks for expression priorities/releases, clips, costumes, persistence, 1024 output pixels and pixel-art filtering.
- Rig suite: 29 checks for rest-preserving parenting/pivots, independent visibility rules and sine axes, limits, actual clipping/add/multiply pixels, hit testing, shortcut conflicts/configured-helper heartbeat, and authenticated real WebSocket commands.
- Native OS import: one real Windows file-dialog test selecting a known Unicode/space-containing path and importing the image.
- Exported executable: 18 smoke checks, including bundled nine-part rig, costumes and configured-helper startup.
- UI screenshots are generated from the running app and inspected.

Evidence files are in the deliverable's `evidence` folder. Test counts must be confirmed against the final logs; failures are not replaced by feature claims.

## Known limits

No usable microphone was exposed, so live capture/calibration/reconnect remain unverified. OBS capture, foreground-game physical shortcuts, macOS/Linux packages, long-session soak, final performance budgets and code signing remain unverified or unfinished. High-resolution mode is optional, not a lightweight-performance claim.

Clipping supports one mask level. Child layers form a clipping group. Canvas picking uses image bounds. Clips have a numeric playhead/key list rather than multitrack curves. Rest pose should be used while adjusting pivots/parents. Shortcut conflict detection covers this app's bindings only. Generic WebSocket control is not an existing Stream Deck plugin integration.

Large-project memory handling, malformed animated-container fuzzing, extended color profiles and production crash recovery need further work. Imported PNGTuber Plus, Remix and veadotube file formats are not supported. Mesh/rope/appendage rigs, normal-map lights, throwables, multiselect, MIDI/gamepad/mouse binding, arbitrary background colors and a complete novice workflow remain open.

See PNGTUBER_PLUS_AUDIT.md for the source-based comparison and FEATURE_PARITY.md for the broader target.
