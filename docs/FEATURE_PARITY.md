# Feature parity — 0.6.0 alpha

The editor now uses conventional menus, contextual pages, visual artwork slots and dedicated windows. See [UI_REDESIGN.md](UI_REDESIGN.md) for the current feature map. The following earlier implementation inventory remains applicable to the underlying features.

# Reference feature ledger — 0.3 alpha

References: [veadotube mini](https://veado.tube/docs/usage/mini/), [PNGTuber Plus](https://kaiakairos.itch.io/pngtuber-plus), [Remix manual](https://github.com/MudkipWorld/PNGTuber-Remix/blob/1.4.x/OnlineDoc/README.md). A source-level Plus comparison is in PNGTUBER_PLUS_AUDIT.md.

| Area | Implemented | Remaining |
|---|---|---|
| Expressions | Four images, independent blink/talk, visible configurable focused/background keys, hold/toggle/timed states | General transition graph, MIDI/gamepad/mouse bindings |
| Layered character creation | Blank character, batch native import, parent rig, pivots and tools, original example | Multiselect, PSD, deformable mesh/appendage rig |
| Motion | Axis sine, springs, inertia rotation/limits, squash/stretch, bounce, pointer follow | Artist-tested presets, selective inheritance, rope dynamics |
| Visuals | Static/animated art, grid sheets, single-level alpha clipping, four blend modes, per-part RGBA tint | Normal-map lighting, deform shaders, nested masks |
| Costumes | Independent named visibility channel, configurable shortcuts | Artwork/transform costume overrides |
| Animation editor | Keyframe list, playhead, record/replace/delete, easing, loop/one-shot | Curve editor and multitrack timeline |
| Files | Portable save/load, embedded artwork, backups, export art, native OS dialog | Other apps' formats, robust migration and extreme-asset handling |
| Capture | Shared alpha, clean window, transparent/key/custom color, 256–2048 output, nearest/linear, 20/30/60/120 fps, topmost | OBS certification, click-through, alternative capture transports |
| Controls | Windows helper, configurable expression/costume/sprite keys, internal conflicts, authenticated local API | External key conflicts, existing Stream Deck protocols, other OS helpers |
| Release quality | Windows alpha and automated evidence | Live mic/OBS/game testing, cross-platform packages, soak/performance/signing |

Code and sample artwork are original. Remix code/assets were not reused. Broad feature parity remains an active development target, not a property of this alpha.
