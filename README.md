# Puppet Studio 0.3.0-alpha

A standalone Windows avatar editor and performer built with Godot. Extract the ZIP and run `PuppetStudio.exe`. No Godot installation is required. Keep both helper EXEs beside it.

## Try the layered character

Click **Rig example**. It contains nine editable parts: body, head, two spring ears, open/closed eyes, silent/talking mouths, and scarf. Use Test talking and Blink. In Perform, choose the Without scarf costume. Open `Advanced-Mochi.puppet` for a three-key motion-clip example.

To build your own character, select **New layered character**, then **+ Image**. The Windows file picker supports selecting multiple files. Open, Save, and Export art also use native dialogs. Artwork folders are remembered. PNG/JPEG/WebP and animated GIF/APNG/WebP import remain available.

## Rigging and editing

- Select parts in the layer list or click them on the canvas. Move, Pivot, Rotate and Scale are canvas tools. Pivot movement keeps the picture stationary. Arrow keys nudge; Shift increases the step. Ctrl+D duplicates.
- Enable Rest pose while assembling a character. Rig shows attachment links, selection bounds and pivots; these guides never appear in the clean output.
- Set Parent in Edit to attach a part. Linking and unlinking preserve its rest placement, including non-uniform transforms. Reordering affects draw order without changing attachments.
- Use separate speaking and blinking visibility rules for eye/mouth combinations. The older combined condition remains for existing projects; choosing either new rule clears it.
- Independent width/height, X/Y sine speeds, positional/rotational spring switches, spring frequency/damping, rotation limits/drag, squash/stretch, speech bounce/gravity, ignore-bounce, opacity, mirroring and pointer-follow controls are available.
- A parent can clip linked artwork to its alpha. Clipped descendants form a draw group. Nested masks are rejected; use a single mask level. Normal, additive, subtractive and multiply blending are available.
- Background keyboard shortcuts can toggle individual sprites. These are live overrides; switching costumes resets them.

## Expressions, costumes and motion

The **Perform** inspector contains expression trigger behavior, costumes and layer motion clips.

Expression buttons choose the editing/base expression. Number-key triggers can select, hold, toggle back to expression 1, or play a timed reaction. The newest held expression takes priority over timed reactions; releasing it restores the underlying state. Blinking and talking remain independent. Focus loss or a stopped helper clears held states.

Costumes capture layer visibility independently of expressions. Create one, rename it and tick the parts that belong to it. F1–F9 selects the first nine costumes; pressing the same key returns to default visibility. Up to 32 costumes are supported.

For a motion clip, select a layer and open Perform. Set a duration, place the playhead, edit Key X/Y/rotation/scale/opacity and Record. Repeat at another time. A key's Linear, Smooth or Hold setting controls the transition to the following key. Click a key to edit it, record again to replace it, or × to delete it. Play clips runs enabled layer clips together; Pause holds the current result; Stop restores editable transforms. Loop and final-frame hold are supported, with up to 128 keys per layer. This is a compact keyframe-list editor, not a full multitrack curve editor.

## Microphone and shortcuts

Choose Audio, select your device and Enable mic. Calibration measures quiet then speech. Avatar mute only affects this app's mouth state, not your microphone in OBS. PTT gates detected speech.

Focused defaults: 1–9 expression triggers, F1–F9 costumes, B blink, Space PTT, Ctrl+S save, Ctrl+Z undo, Ctrl+Shift+Z redo, Ctrl+D duplicate.

Optional Windows background defaults: Ctrl+Alt+1–9 expressions, Ctrl+Alt+F1–F9 costumes, Ctrl+Alt+M mute, Ctrl+Alt+B blink, Ctrl+Alt+Space PTT. Costume and sprite bindings support letters, digits, F1–F12, Space, modifier combinations and Disabled. Duplicate bindings within this app are detected. Expression/mute/blink/PTT background keys remain fixed. Detection of keys reserved by other programs, mouse/gamepad/MIDI binding and macOS/Linux global input remain unfinished.

## Capture and integrations

Start output opens a clean borderless avatar window. Drag it to move; right-click to reopen the editor. Output supports transparent/green/magenta backgrounds, topmost, 30/60 fps, pixel-art filtering, and 256/512/1024/2048-square render targets. Higher resolution uses more memory/GPU time.

OBS capture is still unverified on this machine. Application alpha pixels were tested; that does not certify OBS compatibility. Try Game Capture with Allow Transparency, or a solid background with Color Key.

Output also has an optional local WebSocket control server, disabled by default. Start it and copy connection details. It only listens on 127.0.0.1 and uses a fresh token each start. See `CONTROL_API.md` for the authentication and commands. This is an original API; existing veadotube/Stream Deck plugins are not automatically compatible.

## Files and safety of edits

`.puppet` projects embed artwork. Save retains a `.bak`, and local recovery snapshots are made while editing. Export art writes embedded PNG files plus an animation/layer map into a new subfolder. The source PNG files are not modified. Plus `.save`, `.veado`, PSD and Remix import are not implemented.

Limits: 32 expressions, 32 costumes, 64 layers, 4096-pixel static image dimension, 16 MB per import, 48 MB project, 256 animated frames and 48 million decoded animated pixels. Complex decoder cases, extreme projects and crash/disk-full recovery need broader testing.

## Verification and remaining work

The release evidence includes core tests, real-window tests, rig/clipping/blend pixel tests, a real native-file-dialog import with a Unicode path, local WebSocket authentication/commands, and tests inside the exported executable. See the source's `docs/IMPLEMENTATION_STATUS.md` and `docs/PNGTUBER_PLUS_AUDIT.md` for exact coverage.

This remains an alpha. Live microphone/calibration, real foreground-game shortcuts, OBS, long-session stability and macOS/Linux packages are not verified. Deformable mesh/rope rigs, multiselect, advanced timeline curves, broad importer compatibility and every feature from every reference app are not complete. No claim of complete replacement parity or final low-resource performance is made.

Source: `source/project.godot`, Godot 4.7.2. Product/runtime code and sample artwork are original. Competitor source was inspected to understand requirements; it is not bundled.
