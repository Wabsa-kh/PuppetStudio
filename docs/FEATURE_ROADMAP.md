# Feature roadmap after 0.6.0 alpha

Puppet Studio 0.6.0 supports quick and layered PNGTuber characters. The remaining work is grouped into releases that can each ship with a complete workflow and useful test coverage.

## 0.6 — authoring productivity

- Multiselect, hierarchy drag/drop, folders and reusable rig/motion presets.
- Crop-to-content import, replace-shared-image workflow and model optimizer with undo and preview.
- Mouse, gamepad and MIDI binding UI.
- Costume overrides for image, transform and tint in addition to visibility.
- Fade-in/fade-out transitions and richer state effects.

## 0.7 — advanced rigging

- Appendage/rope objects with editable control points, stiffness, damping, gravity, length constraints, anchors, looping and tiled/stretch texture modes.
- Deformable mesh generation/editing, multiple deformation layers and tested physics/motion modes.
- Normal maps and configurable model lighting.
- Multitrack animation timeline with curves, selection and reusable clips.

## 0.8 — interoperability and performance control

- PSD/layered-art importer.
- Importers for formats that can be implemented lawfully and validated with user-owned fixture files.
- Expanded WebSocket commands for state, part/group visibility, clips and models, with protocol versioning.
- Throwables and safe external-event triggering.

## 1.0 gates

- Real microphone, OBS and foreground-input acceptance matrix.
- Multi-hour soak and low-end-PC performance budgets.
- Keyboard navigation, display scaling and first-time-user usability pass.
- Signed Windows distribution and tested Linux/macOS packages.

Feature names describe intended outcomes, not current support. See `docs/FEATURE_PARITY.md` for the current ledger and `docs/LAUNCH_READINESS.md` for release gates.
