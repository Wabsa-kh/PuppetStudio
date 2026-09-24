# 0.4 editor audit and feature map

The 0.3 action handlers, project format, runtime, output renderer, importer and rig solver are retained. The new shell replaces the visible layout and categorizes the existing inspector controls. This preserves existing project compatibility; it is not a claim of complete competitor parity.

| Existing functionality | New location |
|---|---|
| Open/save/save as, embedded projects, recovery and backups | File; recovery on startup |
| Native single/multiple-image import and export | Artwork tiles; File → Import parts / Export artwork |
| New blank character | File → New character; dedicated Simple / Layered / Advanced setup |
| Original rig example | File → Open rig example |
| Undo/redo, duplicate/remove part | Edit |
| Base placement and scale | Base character → Layout |
| Four expression images, clear/replace | Character → Expression artwork; visual slots |
| Name, focused/background shortcuts, trigger style, timed duration, restart animation | Expression strip → Keys; Character → Expression shortcuts |
| Add/remove expression | Expression strip +; Character menu; removal confirmation |
| Blink timing, body bounce, gravity, costume bounce, motion | Base character → Behavior |
| Part rename/replace image | Selected part → Image |
| Offset, uniform/nonuniform scale, rotate, mirror, lock | Selected part → Layout |
| Move/pivot/rotate/scale, zoom, rest pose, rig guides | Canvas toolbar |
| Parent, pivots, positional/rotational springs | Selected part → Rig |
| Opacity, speech/eye rules, blend, clip children, live toggle, binding | Selected part → Visibility |
| Sine motion, independent axis speeds, phase, drag/limits, stretch, bounce, pointer | Selected part → Motion, with live wave preview |
| Sprite-sheet columns/rows/rate/loop | Selected part → Animation |
| Animated GIF/APNG/WebP import | Artwork tiles, parts import and asset browser |
| Reorder parts and hierarchy selection | Left parts list and arrow controls |
| Costume capture/rename/delete/visibility and shortcuts | Character → Costumes window |
| Motion keyframes, record/replace/delete, easing, loop, duration | Animation → Motion clips window, with seekable timeline |
| Play/pause/stop clips | Animation menu and Motion clips window |
| Mic device, enable/calibration, threshold/hold, mute/PTT, helper | Studio → Microphone and shortcuts window |
| Live input feedback, simulated speech and blink | Below the canvas |
| Clean capture, alpha/color key, size/filter/fps/topmost/close behavior | Studio → Capture settings; Start output |
| Local authenticated WebSocket control | Studio → Local control API window |
| Edit/live layouts | View menu and workspace selector |
| Documentation/OBS guidance/about | Help |
| New editor appearance controls | Edit → Preferences |
| New searchable project/local artwork library | File → Asset browser, left dock and artwork-slot Library buttons |

## Design boundaries

Simple starts with expression image slots. Layered and Advanced start with an empty parts project and an import action. These are focused entry points into shared capabilities, not incompatible formats. Existing projects infer their workflow from their parts. All modes retain access to the menus.

The character is assembled from imported artwork; this is not a drawing program. Mesh/rope deformation, Photoshop import, competitor project imports, multiselection and a full multitrack curve editor remain unimplemented. The separate competitor audit describes parity gaps.

## Validation

The UI suite checks menu actions, state previews, search, artwork assignment/undo, three valid creation modes, contextual routing, five dedicated tool windows and preference persistence. Rendered snapshots cover simple editing, rigging, creation, artwork browser, audio, motion clips and preferences. Core, workspace, advanced and rig regression suites cover the retained functionality. This is automated functional and visual inspection, not a user usability study.
