# Step 18 — Composer slice + voice/media seams

- **Status:** `done`
- **Complexity:** `🚧`
- **User value:** Desktop users can send text, commands, and supported image attachments from an existing session without exposing unavailable voice controls.
- **Dependencies:** Steps 14–17

## Scope

- Move reusable composer presentation from the mobile shell into
  `client/module_app_ui` without importing product DI, routing, keyboard, or
  picker implementations.
- Reuse the already-shared voice stack in `client/module_core`; keep recorder,
  file, wake-lock, and keyboard behavior mobile-owned.
- Add a pure-Dart media-picking seam and shared validation, with real mobile and
  desktop adapters.
- Compose the shared controls into desktop session detail while preserving
  mobile new-session and existing-session behavior.

## Implementation Summary

- The planned voice relocation had already landed before this step:
  `VoiceApi` → `VoiceRepository` → `VoiceTranscriptionService`, with
  `VoiceCapture`/`VoiceCaptureSession` as pure-Dart platform contracts and
  mobile-owned recorder/file/wake-lock implementations. This step reuses that
  graph instead of duplicating or moving it again.
- Moved prompt input, agent/model/command pickers, background-task controls,
  composer surface policy, editor sheet, and voice presentation widgets into
  `module_app_ui`.
- Added `ComposerPresentationScope` as the product boundary for voice support,
  effective input mode, keyboard visibility, validated attachment picking, and
  clipboard access. Shared composer source no longer imports GetIt,
  `flutter_keyboard_visibility`, `image_picker`, or product routing.
- Kept `VoiceInputCubit` shell-constructed. Mobile wraps both new-session and
  session-detail composers with its real voice service, persisted input-mode
  Cubit, keyboard visibility, picker, and clipboard capabilities.
- Desktop explicitly supplies `voiceSupport: unsupported` and an effective
  text-first mode, so a persisted mobile `voiceFirst` preference cannot expose
  dead voice UI. Desktop does not construct or register a fake voice Cubit.
- Added the pure-Dart `ComposerImagePicker` foundation-platform contract and
  `ComposerAttachmentDispatcher`, which centralizes filename normalization and
  outbound size enforcement for picker and clipboard bytes. A shared supported-
  raster format helper now owns MIME/signature matching for both staging and
  transcript image loading. The role-named dispatcher is deliberately not
  presented as a repository-backed domain service.
- Adapted mobile `image_picker` to the raw-byte contract and added a real desktop
  `file_selector` adapter filtered to supported raster extensions. The desktop
  adapter owns its external-function test seam directly rather than depending
  on another shell platform implementation, and preflights file length before
  materializing bytes. Registered the desktop picker and shared dispatcher in
  generated DI.
- Added the shared composer to interactive desktop session detail. Read-only and
  archived sessions retain the existing omission behavior; diff controls remain
  Step 19 scope.
- Updated session-turn and attachment regression contracts for shared composer
  ownership, desktop text/image input, mobile-only voice, and capability-driven
  omission.

## Architecture Review

- First `architecture-implementation-review`: **REJECTED** with three valid
  findings: a transformation-only class used the `Service` suffix, the new
  platform contract used the legacy `src/platform` directory, and the desktop
  adapter depended on a same-layer platform wrapper.
- Applied all findings: renamed the role to `ComposerAttachmentDispatcher`,
  moved `ComposerImagePicker` to `src/foundation/platform`, and folded the
  injectable `file_selector.openFile` seam directly into
  `DesktopComposerImagePicker`.
- Second review: **REJECTED** with one valid remaining location finding:
  the changed mobile platform implementation still lived under the legacy
  `capabilities/media` path.
- Applied that finding by moving `FlutterComposerImagePicker` and its test under
  `client/app/lib/core/platform`. After the configured two-pass limit was
  reached, the user explicitly chose on 2026-09-02 to proceed without a third
  review because every concrete finding had been remediated.

## Verification

- `client/module_core`: `asdf exec dart analyze --fatal-infos` passes; the
  complete suite passes 1,484 tests, including the shared picker/clipboard
  attachment dispatcher and shared raster validation.
- `client/module_app_ui`: `asdf exec dart analyze --fatal-infos` passes; the
  complete suite passes 250 tests, including unsupported-voice text-first
  fallback without a `VoiceInputCubit`.
- `client/app`: `asdf exec dart analyze --fatal-infos` passes; the complete
  mobile suite passes 686 tests, including picker adaptation, voice lifecycle,
  keyboard behavior, new-session restoration, and existing-session composition.
- `client/desktop`: `asdf exec dart analyze --fatal-infos` passes; the complete
  desktop suite passes 89 tests, including picker filtering/cancellation and
  size preflight, complete image DI, explicit text-first capability composition,
  and text send.
- Dart LSP reports zero diagnostics across 48 changed Dart files.
- `git diff --check` passes.
- `asdf exec flutter build macos --release` succeeds (65.1 MB reported by
  Flutter).
- The user accepted the remediated architecture disposition without a third
  review after the configured two-pass cap.

## Acceptance

- [x] Shared composer presentation has no product-shell, service-locator,
  keyboard-plugin, or picker-plugin dependency.
- [x] Mobile retains real voice capture, keyboard behavior, image picking,
  new-session composition, and existing-session composition.
- [x] Desktop renders a text-first composer, hides voice entry, and uses a real
  file picker for declared image attachments.
- [x] Shared core validates picker and clipboard bytes consistently.
- [x] Complete affected verification passes.
- [x] Architecture review disposition is resolved after the configured
  two-pass cap.
