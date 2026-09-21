# PNGTuber Plus implementation audit

Reviewed the author's public repository at commit `3173b213681152eb7fca55c63e757cfc42d2eb44` and the 1.4/1.4.5 release notes on 21 September 2026. Review focused on `spriteObject.gd`, `sprite_viewer.gd`, `settings_menu.gd`, `main.gd`, and `saving.gd`. The repository declares the Unlicense. We used it as a behavioral reference and wrote independent implementation code; no competitor code/art is shipped.

Sources: [repository](https://github.com/kaiakairos/PNGTuber-Plus/tree/3173b213681152eb7fca55c63e757cfc42d2eb44), [feature overview](https://kaiakairos.itch.io/pngtuber-plus), [1.4 notes](https://kaiakairos.itch.io/pngtuber-plus/devlog/663635/v-14), [1.4.5 notes](https://kaiakairos.itch.io/pngtuber-plus/devlog/704463/v-145).

| Reference capability | Puppet Studio 0.3 | Qualification / remaining work |
|---|---|---|
| Build a character from separate images | Blank layered character, multi-image import, nine-part example | PNG drawing/painting is outside the editor; PSD import pending |
| Native file browsing | OS dialogs for import/open/save/folder export | Real Windows import verified; other OS dialogs untested |
| Select/move/scale/rotate artwork | Canvas picking, tools, numeric controls, keyboard nudging | Picking uses bounds; no alpha-perfect selection or multiselect |
| Move origin/pivot | Pivot tool preserves artwork placement | With moving spring/clip poses, use Rest pose while rigging |
| Link/unlink parts | Parent hierarchy, cycle checks, rest-transform preservation | Different simulation math from Plus; no exact physics parity claim |
| Draw ordering | Layer order independent of attachments | Clipped children form a group; no separate numeric Z UI |
| X and Y sine frequency/amplitude | Independent speeds and amplitudes, phase in schema | Full phase UI and preset library pending |
| Positional drag | Stable spring follow-through, frequency/damping, independent switch | Spring response is an alternative to Plus's drag formula |
| Rotational drag and limits | Inertial rotation, min/max, angular spring | Parent/root impulse propagation still needs artist testing |
| Squash/stretch | Inertia-driven bounded deformation | Not a mesh/deformable-bone system |
| Ignore bounce; bounce force/gravity | Per-layer opt-out, speech impulse, force/gravity, costume bounce | Tuning differs from Plus |
| Independent speaking/blinking rules | Both can constrain each part at once | Tested both channels together |
| Sprite sheets | Columns/rows, fps, loop/final-frame hold | High-fps/large-sheet edge cases need wider testing |
| Replace/duplicate/delete sprites | Available with undo/redo | Layer duplicate copies costume membership and clears its shortcut |
| Costume membership | Up to 32 named independent visibility costumes | Visibility snapshots, not full transform/artwork variants |
| Costume background keys | Configurable keyboard/modifier chord or Disabled | First nine have defaults; no mouse/gamepad capture |
| Per-sprite visibility hotkey | Configurable live visibility toggle | Resets on costume switch; external application conflicts not detected |
| Clip linked sprites | Parent alpha mask | One mask level only; nested masks rejected |
| Texture filtering | Smooth / nearest pixel-art mode | Available globally |
| Background color | Transparent, green, magenta | Arbitrary color picker and blue preset still pending |
| Frame cap | 30/60 | Arbitrary and unlimited caps not exposed |
| Microphone/device/threshold/blink | Device selector, RMS gate, calibration, blink timing | Live microphone hardware not available here |
| Save/share/extract art | Portable embedded project, backup, export art/map | Plus .save import/export pending; not file-format compatible |
| Stream Deck support | Original authenticated local WebSocket API | Existing Plus plugin protocol not implemented |
| Windows/macOS/Linux | Windows portable executable | macOS/Linux exports and platform validation pending |

Additional implemented capabilities include four-slot expression art, GIF/APNG/animated WebP, hold/toggle/timed expression triggers, keyframe-list motion clips, blend modes, output resolution controls, authenticated local control, undo/redo and recovery snapshots.

This audit is a feature map, not a completed parity certificate. Advanced Remix mesh/appendage/normal-map/throwable features and veadotube MIDI/gamepad/mouse input are separate remaining work.
