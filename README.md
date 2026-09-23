# Puppet Studio 0.5.0-alpha

A standalone Windows avatar editor and performer built with Godot. Extract the ZIP and run `PuppetStudio.exe`. No Godot installation is required. Keep both helper EXEs beside it.

![Puppet Studio layered character editor](docs/images/editor.png)

## New editor layout

The menu bar organizes File, Edit, Character, Rig, Animation, Studio, View and Help. The canvas stays central; parts and project artwork sit on the left, and the selected item has focused categories on the right. Simple characters hide the empty parts list. Settings include context descriptions and tooltips.

**File → New character** opens a dedicated setup window with three starting workflows. They share the same portable format and underlying rig capabilities; Advanced is not a separate mesh-deformation engine. **Edit → Preferences** changes the editor scheme, text size and accent.

**File → Asset browser** searches embedded artwork or browses a chosen local folder, with thumbnails, a larger preview and an explicit assignment target. Click any expression image tile to use the operating system's picker. Native Open/Save/Import/Export dialogs are retained. Local folder results are limited to 250 files; GIF/APNG folder tiles use an animation icon until imported.

## Try the layered character

Choose **File → Open rig example**. It contains nine editable parts: body, head, two spring ears, open/closed eyes, silent/talking mouths, and scarf. Use Test voice and Blink. In Character → Costumes, choose the Without scarf costume. Open `Advanced-Mochi.puppet` for a three-key motion-clip example.

To build your own character, choose **File → New character**, select Simple, Layered or Advanced, then create it. Simple characters use the four visual Artwork slots. Layered characters use **File → Import parts**. The Windows file picker supports selecting multiple files. Open, Save, and Export art also use native dialogs. Artwork folders are remembered. PNG/JPEG/WebP and animated GIF/APNG/WebP import remain available.

## Rigging and editing

- Select parts in the layer list or click them on the canvas. Move, Pivot, Rotate and Scale are canvas tools. Pivot movement keeps the picture stationary. Arrow keys nudge; Shift increases the step. Ctrl+D duplicates.
- Enable Rest pose while assembling a character. Rig shows attachment links, selection bounds and pivots; these guides never appear in the clean output.
- Set Parent in the Rig category to attach a part. Linking and unlinking preserve its rest placement, including non-uniform transforms. Reordering affects draw order without changing attachments.
- Use separate speaking and blinking visibility rules for eye/mouth combinations. The older combined condition remains for existing projects; choosing either new rule clears it.
- Independent width/height, X/Y sine speeds, positional/rotational spring switches, spring frequency/damping, rotation limits/drag, squash/stretch, speech bounce/gravity, ignore-bounce, opacity, mirroring and pointer-follow controls are available.
- A parent can clip linked artwork to its alpha. Clipped descendants form a draw group. Nested masks are rejected; use a single mask level. Normal, additive, subtractive and multiply blending are available.
- Background keyboard shortcuts can toggle individual sprites. These are live overrides; switching costumes resets them.
- Visibility includes an RGBA tint for each part. Capture supports transparent, green, magenta or a custom background color and 20/30/60/120 fps modes.

## Expressions, costumes and motion

Expression trigger behavior is in **Character → Expression settings**. Costumes and motion clips have dedicated windows under **Character → Costumes** and **Animation → Motion clips**.

Expression buttons choose the editing/base expression. Number-key triggers can select, hold, toggle back to expression 1, or play a timed reaction. The newest held expression takes priority over timed reactions; releasing it restores the underlying state. Blinking and talking remain independent. Focus loss or a stopped helper clears held states.

Costumes capture layer visibility independently of expressions. Create one, rename it and tick the parts that belong to it. F1–F9 selects the first nine costumes; pressing the same key returns to default visibility. Up to 32 costumes are supported.

For a motion clip, select a part and choose **Animation → Motion clips**. The visual playhead supports click-to-seek. Set a duration, place the playhead, edit Key X/Y/rotation/scale/opacity and Record. Repeat at another time. A key's Linear, Smooth or Hold setting controls the transition to the following key. Click a key to edit it, record again to replace it, or × to delete it. Play clips runs enabled layer clips together; Pause holds the current result; Stop restores editable transforms. Loop and final-frame hold are supported, with up to 128 keys per layer. This is a compact keyframe-list editor, not a full multitrack curve editor.

## Microphone and shortcuts

Choose **Studio → Microphone and shortcuts** (or the Audio toolbar button), select your device and Enable mic. Calibration measures quiet then speech; Restart reconnects capture after a device or operating-system change. Avatar mute only affects this app's mouth state, not your microphone in OBS. PTT gates detected speech.

Focused defaults: 1–9 expression triggers, F1–F9 costumes, B blink, Space PTT, Ctrl+S save, Ctrl+Z undo, Ctrl+Shift+Z redo, Ctrl+D duplicate.

Optional Windows background defaults: Ctrl+Alt+1–9 expressions, Ctrl+Alt+F1–F9 costumes, Ctrl+Alt+M mute, Ctrl+Alt+B blink, Ctrl+Alt+Space PTT. Costume and sprite bindings support letters, digits, F1–F12, Space, modifier combinations and Disabled. Duplicate bindings within this app are detected. Expression/mute/blink/PTT background keys remain fixed. Detection of keys reserved by other programs, mouse/gamepad/MIDI binding and macOS/Linux global input remain unfinished.

## Capture and integrations

Start output opens a clean borderless avatar window. Drag it to move; right-click to reopen the editor. Output supports transparent/green/magenta/custom backgrounds, topmost, 20/30/60/120 fps, pixel-art filtering, and 256/512/1024/2048-square render targets. Higher resolution and frame rates use more memory/GPU time.

OBS capture is still unverified on this machine. Application alpha pixels were tested; that does not certify OBS compatibility. Try Game Capture with Allow Transparency, or a solid background with Color Key.

**Studio → Local control API** contains an optional local WebSocket control server, disabled by default. Start it and copy connection details. It only listens on 127.0.0.1 and uses a fresh token each start. See `CONTROL_API.md` for the authentication and commands. This is an original API; existing veadotube/Stream Deck plugins are not automatically compatible.

## Troubleshooting and launch status

Open **Help → System status** to inspect microphone, shortcut and capture status. Copy report copies only the displayed diagnostic summary; nothing is sent automatically. Background shortcuts may take up to 30 seconds to connect on a slow first start.

See `LAUNCH_READINESS.md` in the Windows package (or `docs/LAUNCH_READINESS.md` in the source) for the remaining release gates. This is a testing alpha, not a final cross-platform launch.

## Files and safety of edits

`.puppet` projects embed artwork. Save retains a `.bak`, and local recovery snapshots are made while editing. Closing unsaved work offers Save and quit, Discard changes, or Keep editing. Failed saves keep the editor open. Successful saves clear stale recovery snapshots; restored sessions remain marked unsaved until explicitly saved. Writes are checked before the previous project is replaced. Export art writes embedded PNG files plus an animation/layer map into a new subfolder. The source PNG files are not modified. Plus `.save`, `.veado`, PSD and Remix import are not implemented.

Limits: 32 expressions, 32 costumes, 64 layers, 4096-pixel static image dimension, 16 MB per import, 48 MB project, 256 animated frames and 48 million decoded animated pixels. Complex decoder cases, extreme projects and crash/disk-full recovery need broader testing.

## Verification and remaining work

The release evidence includes core tests, real-window tests, rig/clipping/blend pixel tests, a real native-file-dialog import with a Unicode path, local WebSocket authentication/commands, and tests inside the exported executable. See the source's `docs/IMPLEMENTATION_STATUS.md` and `docs/PNGTUBER_PLUS_AUDIT.md` for exact coverage.

This remains an alpha. Live microphone/calibration, real foreground-game shortcuts, OBS, long-session stability and macOS/Linux packages are not verified. Deformable mesh/rope rigs, multiselect, advanced timeline curves, broad importer compatibility and every feature from every reference app are not complete. No claim of complete replacement parity or final low-resource performance is made.

Source: `source/project.godot`, Godot 4.7.2. Product/runtime code and sample artwork are original. Competitor source was inspected to understand requirements; it is not bundled.
