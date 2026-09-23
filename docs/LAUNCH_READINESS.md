# Launch readiness — 0.5.0 alpha

This is a Windows testing build, not a production-ready cross-platform replacement. The redesigned editor and existing avatar features work in automated tests. The following gates define what remains before broader release.

## Completed in this pass

- Conventional menus, contextual part settings, four image previews, project/folder artwork browser, dedicated creation and settings windows.
- Simple, Layered and Advanced starting workflows with guided assembly steps.
- Save / Discard / Keep editing on close. Failed saves cancel quitting; successful saves clear stale recovery snapshots. Recovered sessions remain unsaved until explicitly saved.
- Save size uses UTF-8 bytes. Writes are flushed and checked for error/length before replacing the previous project; backups remain supported.
- Help → System status provides a user-copyable diagnostic report without artwork, project paths or API tokens.
- Builds reject script errors, failed exports, timeouts and missing test-completion results. The exported app is tested in a staging folder before replacing the last build.
- Automated tests use separate recovery files.
- Parts support RGBA tinting; capture supports custom colors and 20/30/60/120 fps; Audio includes an explicit restart action.

## Gates before a public Windows beta

| Gate | Current status | Acceptance evidence needed |
|---|---|---|
| Real microphone and calibration | Not verified; this machine exposes no usable input device | Quiet/speech calibration, alternate device, unplug/reconnect, PTT and no feedback |
| OBS capture | App alpha pixels pass; actual OBS unverified | Record transparent and color-key captures; verify resizing, minimize, focus changes and reopening |
| Background input | Helper authentication and bindings pass; physical foreground-game input unverified | Trigger each binding while another application has focus; verify release/focus-loss behavior |
| Sustained reliability | Short lifecycle test provided; multi-hour soak pending | Several hours with animated artwork, capture and mic active; track memory, CPU and recovery |
| Performance budget | No final budget certified | Measure idle/active CPU, working-set RAM, GPU load and input latency on low-end PCs across 20–120 fps modes |
| Data resilience | Save/load/recovery and failure-path tests added | Actual disk-full/read-only targets, interrupted writes, recovery after forced termination, larger malformed-image corpus |
| Usability/accessibility | Layout inspected; no independent usability study | First-time users build a simple and layered character; test keyboard navigation, 100–200% display scaling and smaller screens |
| Distribution | Portable ZIP available; executable unsigned | Branding metadata review, signed package if pursuing trusted Windows distribution, clean-machine antivirus/startup tests and release notes |

Do not describe a short automated lifecycle run as a multi-hour stability test. Do not describe an internal alpha-pixel test as OBS certification.

## Remaining cross-platform work

- Build and run Linux and macOS packages on those operating systems.
- Replace or port Windows-only GIF decoding and global-input helpers.
- Verify native file dialogs, microphone permissions, transparent capture and shortcuts per OS/window system.
- macOS signing/notarization and package/update/distribution decisions.

## Remaining feature work toward the broader replacement goal

1. Character authoring: multiselect, stronger hierarchy tools, reusable rig presets, deformable meshes and rope/appendage rigs.
2. Animation: multitrack timeline/curves and richer animation editing; current clips use a key list and seekable ruler.
3. Interoperability: verified importers for competitor projects and PSD/layered artwork. Existing competitor plugins are not automatically compatible with the local API.
4. Performance controls: broader configurable expression bindings, mouse/gamepad/MIDI input and external binding-conflict feedback.
5. Rendering features from the reference-app audit: normal-map lighting, throwables and other advanced effects. These are not implied by choosing Advanced in the creation window.

See PNGTUBER_PLUS_AUDIT.md and FEATURE_PARITY.md for the earlier comparison. Launch a clearly scoped, useful product before claiming every competitor feature is supported.

The implementation milestones are tracked in [FEATURE_ROADMAP.md](FEATURE_ROADMAP.md). The advanced roadmap includes appendage/rope physics, deformable meshes, normal-map lighting, throwables, PSD import, expanded input support and richer protocol compatibility. These are not present in 0.5.0.

## Suggested next release sequence

1. Complete the real microphone/OBS/foreground-input acceptance run.
2. Run long-session and low-end-PC profiling; fix the measured issues.
3. Conduct a small first-time-user beta and close navigation/accessibility problems.
4. Package a Windows beta with exact supported features and known limits.
5. Build/test platform ports, then deliver advanced authoring and importers in explicit milestones.
