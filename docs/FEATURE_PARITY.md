# Reference feature ledger

Reviewed 21 September 2026. This tracks product work; it does not claim full parity.

Primary reference pages:
- [veadotube mini usage](https://veado.tube/docs/usage/mini/)
- [PNGTuber Plus features](https://kaiakairos.itch.io/pngtuber-plus)
- [PNGTuber Remix manual](https://github.com/MudkipWorld/PNGTuber-Remix/blob/1.4.x/OnlineDoc/README.md)

| Feature family | Current implementation | Remaining replacement work |
|---|---|---|
| Image switching and independent blinking | Four slots per expression; fallback images | More configurable eye/mouth poses |
| Multiple expressions | Add/select/duplicate/rename/delete, 1–9 shortcuts | Reorder, temporary expression stack and costume channels |
| Microphone response | Sample-window RMS, hysteresis, hold/release, calibration UI | Real-device calibration, reconnect, permission matrix |
| Animated art | GIF on Windows, APNG and animated WebP frame composition; grid sheets, frame durations, loop/one-shot | Broader decoder conformance and fuzzing, restart controls, independent animation tracks |
| Sprite layers | Add/delete/reorder/duplicate; transforms; drag; numeric pivots; canvas lock; mirroring | Multi-select, pivot handles, grouping, clipping and blend modes |
| Attachment motion | Full position/rotation/scale inheritance; translation/rotation springs; any valid parent order | Rope/appendage rigs, selective inheritance and artist presets |
| Procedural motion | X/Y sine motion, rotation sway, speech bounce, pointer-follow range | Per-state presets, squash/stretch and clip blending |
| Conditional appearance | Talk/silent/blink/open-eye visibility | Expression/costume-specific layer overrides |
| Portable sharing | Embedded-artwork project, backup and local recovery | Migration adapters and production large-file handling |
| Global controls | Optional fixed Windows helper and authenticated local channel | Rebinding, conflicts, real foreground-game testing, macOS/Linux |
| Capture | Shared alpha render target and clean native window | Actual OBS certification, native output alternatives if necessary |
| Professional workspace | Native charcoal editor, resizable panels, inspector tabs | Complete workflow/accessibility polish and novice testing |
| Motion/keyframes | Not implemented | Compact animation-clip editor |

Remix-specific requirements now in the backlog: asset toggles/cycles, clipping, appendages, normal-map lighting, PSD import, mesh deformation, throwables, and WebSocket control. Experimental features will be labelled separately from stable capabilities. The current Remix license restricts commercial reuse, so no Remix source code or art has been copied into this project.

Animated-container implementation references: [W3C PNG specification](https://www.w3.org/TR/png-3/) and [WebP RIFF specification](https://developers.google.com/speed/webp/docs/riff_container). The parser/compositor code is original; native pixel decompression uses Godot. Extended color-profile handling and exhaustive malformed-file testing remain unfinished.

The reference apps inform feature requirements. Their branding, interface assets and implementation are not copied.
