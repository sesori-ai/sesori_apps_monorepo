# Creator Recording

## Capability

The iOS mobile app records its own screen together with a movable circular front-camera preview and microphone narration. Capture remains local to the device. A completed recording persists as a composited movie plus clean screen, camera, audio, movement-timeline, and manifest layers that the user can explicitly share or delete. No bridge or coding plugin participates.

## Required Behavior

- The settings entry is available on iOS only. Camera setup requires camera permission, and recording requires microphone permission and ReplayKit availability; denial or unavailable capture produces a specific recoverable failure.
- Capture starts only in portrait. A landscape attempt asks the user to rotate rather than creating dimensionally inconsistent tracks.
- The front-camera preview floats above every in-app route in a circle, remains draggable during capture, and exposes a stop-and-save control without blocking interaction with the rest of the app.
- Screen, front camera, and microphone are written as separately synchronized tracks. The movement file records the camera circle's changed frame positions against the same recording timeline.
- `screen.mov` is a clean app-screen layer without the native preview or stop control; `camera.mov` is front-camera video-only; `microphone.m4a` is narration audio-only; `movement.json` declares its coordinate system and timestamped circle frames.
- `final.mov` composites the camera circle over the screen according to the movement timeline and includes narration audio. It remains synchronized through the end of the shorter video source.
- A recording becomes visible in the saved library only after every raw layer, final movie, and atomic manifest exists. Incomplete or malformed directories never appear as successful recordings.
- Video export shares only `final.mov`. Layer export shares `screen.mov`, `camera.mov`, `microphone.m4a`, `movement.json`, and `manifest.json`. Delete removes the selected recording and all of those local files.
- Recordings remain in Application Support and are never uploaded automatically. No captured pixels, audio, source code, prompts, paths, or recording identifiers enter analytics.
- A native capture interruption or stop/export failure leaves the failure observable, releases camera/recording resources, and does not publish an incomplete artifact.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included because ReplayKit and simultaneous camera capture require physical-device setup. |
| L2 Routine | Automated, iOS client with fake/native storage boundaries: capture state transitions, native stop-event reconciliation, permission/failure mapping, persisted-manifest listing and deletion, movement timeline lookup, settings entry and saved-library presentation, and final-versus-layer share dispatch. |
| L3 Release | Client end to end on a physical release-target iPhone in portrait: grant permissions, navigate across several Sesori pages while moving the circle, stop from the native control, verify all six persisted files, inspect A/V sync and camera movement in `final.mov`, prove `screen.mov` excludes the native overlay, and exercise both share modes plus delete. |
| L4 Extended | Client end to end on a physical iPhone: deny then grant each permission, ReplayKit unavailable while mirroring/another recorder is active, interruption during capture, low-storage/export failure, repeated recordings, app relaunch with saved artifacts, and malformed/incomplete local recording directories. |
| L5 Full | Physical iPhone matrix across the oldest and newest supported iOS versions: several-minute thermal/storage capture, rapid movement, source-layer import into a representative video editor, final render inspection at beginning/end, and cleanup after every outcome. |

## Exploration Guidance

Vary how soon the preview moves relative to ReplayKit startup, move it continuously and between opposite corners, navigate through sheets and nested session routes, and stop both shortly after startup and after several minutes. Compare the raw screen and final movie frame-by-frame around movement boundaries. Exercise share destinations that accept one movie and multiple heterogeneous files.

## Failure Signals

- The camera preview disappears on route changes, blocks unrelated controls, cannot be dragged, or remains active after stop/failure.
- The preview or stop control is baked into `screen.mov`, causing a duplicate camera in `final.mov`.
- Any track starts late, drifts, freezes, ends materially early, has the wrong orientation, or narration is absent from the final movie.
- Movement metadata uses a different origin/scale/timeline than the final compositor, or a moved circle jumps to stale positions.
- A saved row appears before all files and manifest exist, survives deletion, vanishes after relaunch, or exports the wrong file set.
- Permission, ReplayKit, storage, writer, or compositor failure leaves the cubit/native recorder stuck or is silently swallowed.
- Capture data is uploaded or reported through analytics without an explicit future privacy decision.

## Known Limitations

- iPhone portrait capture is the supported initial scope. Android, landscape/rotation during recording, background continuation, and editing are not implemented.
- ReplayKit and simultaneous physical camera/microphone behavior cannot be proven in a simulator. Simulator builds and native unit tests establish integration and deterministic persistence/timeline behavior only.
- App audio is not captured; the audio layer is microphone narration.

## Sources

Production code under `client/app/ios/Runner/CreatorRecording*.swift`, `client/app/lib/{capabilities,core/platform,features/creator_recording}/`, and `client/module_core/lib/src/{cubits,foundation/platform,repositories,services}/`; automated coverage under `client/app/ios/RunnerTests/`, `client/app/test/features/settings/`, and `client/module_core/test/cubits/creator_recording/`.
