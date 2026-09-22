# Validation — 0.4.1 alpha

| Suite | Passing checks | Evidence |
|---|---:|---|
| Core | 40 | evidence/build/core.log |
| Save safety | 11 | evidence/build/save-safety.log |
| Workspace | 29 | evidence/build/workspace.log |
| Advanced runtime | 36 | evidence/build/advanced.log |
| Rig and control API | 29 | evidence/build/rig.log |
| UI, creation, asset assignment, preferences and quit/recovery | 93 | evidence/build/editor_ui.log |
| Repeated editor lifecycle | 5 | evidence/build/lifecycle.log |
| Exported executable | 18 | evidence/build/exported.log |
| Native Windows file picker | 1 | evidence/build/native-dialog.log |
| Build rejection gates | 3 | evidence/build-gates/result.log |
| Total | 265 | |

The lifecycle suite repeats 24 edit/undo/redo/save/reopen cycles while creating and closing settings, asset and output windows. Its node counts check for accumulated UI objects. It does not establish multi-hour memory/GPU stability.

The three build-gate tests deliberately inject a zero-exit script error, omit a completion marker and stall a child process. Their fixture logs intentionally contain errors; the gate test passes only when the build runner rejects them.

Screenshots from the running app were inspected for the simple editor, rig editor, creation wizard, asset browser, Audio, Motion clips and Preferences. Runtime alpha-pixel checks are separate from real OBS capture, which remains unverified. Real microphone/calibration and physical background shortcuts are also pending.

Read LAUNCH_READINESS.md for the remaining launch gates and feature roadmap. This count is functional regression evidence, not a completeness or release-certification claim.
