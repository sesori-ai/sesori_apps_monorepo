# Step 17 — Session detail: transcript slice

- **Status:** `done`
- **Complexity:** `🚧`
- **User value:** Desktop users can open a session and interact with its live transcript.
- **Dependencies:** Steps 14–16

## Scope

- Move reusable session-detail transcript and interaction presentation into
  `client/module_app_ui`.
- Keep routing, external-link policy, image platform adapters, analytics, and
  bottom controls product-owned.
- Add the typed desktop session-detail route and concrete desktop image actions.
- Preserve mobile transcript, composer, diff, voice, and image behavior.

## Implementation Summary

- Moved the shared message list, Markdown/code rendering, tool and subtask
  parts, queued prompts, permission/question surfaces, image viewer, scrolling,
  and related reusable tests from the mobile shell into `module_app_ui`.
- Added `SessionDetailPresentationScope` as the shell-injection boundary for
  image repositories/adapters, external links, and child-session navigation.
  Image capabilities resolve lazily, and the root-navigator image viewer copies
  the scope so overlays retain the originating product capabilities.
- Kept mobile composition product-owned. Mobile supplies its existing route and
  link policies, connection banner, diff action, and the extracted
  `SessionDetailComposerControls` containing voice, media, background-task, and
  prompt behavior.
- Added the typed desktop session-detail destination, list-to-detail and
  child-session navigation, Back fallback, session activity analytics, and the
  shared interactive transcript. Desktop intentionally injects no composer or
  diff action in this slice, so unsupported controls are absent.
- Added concrete desktop file-save, pasteboard, and system-share adapters for
  image actions and registered them through desktop DI. Generated macOS,
  Windows, and Linux plugin registrants include the required plugins.
- Kept the extracted boundary compatible with the merged
  `claude-inline-subtasks` and `instant-session-launch` work by sharing the
  neutral user-message and image-viewer components rather than introducing a
  competing product-specific layer.
- Updated the session-turn, question/permission, image, inventory, and desktop
  supervision regression contracts to cover the new shared/desktop behavior.

## Architecture Review

- `architecture-implementation-review`: **APPROVED** with no findings.
- The reviewer confirmed that `module_app_ui` remains surface-neutral; product
  shells retain routing, links, composer, analytics, and platform ownership;
  desktop typed routing remains shell-owned; and image adapters do not leak
  platform concerns into pure-Dart modules.
- Review artifact: `/tmp/desktop-step17-architecture-review.md`.

## Verification

- `client/module_app_ui`: `asdf exec dart analyze --fatal-infos` passes; the
  complete suite passes 246 tests. The image/file test changed by the final lazy-provider
  lint cleanup was rerun separately and passes 33 tests.
- `client/app`: `asdf exec dart analyze --fatal-infos` passes; the complete
  mobile suite passes 687 tests after transcript-test ownership moved to `module_app_ui`.
  Focused title hydration and child-session routing pass 18 tests after the
  final capability-provider cleanup.
- `client/desktop`: `asdf exec dart analyze --fatal-infos` passes; the complete
  desktop suite passes 78 tests, including transcript composition, pending-question
  presentation, Back/child navigation, typed route declaration, image adapter,
  and DI registration coverage.
- Dart LSP reports zero diagnostics across 122 relevant files.
- `git diff --check` passes.
- `asdf exec flutter build macos` succeeds (59.9 MB reported by Flutter; 57 MB
  on disk).

## Acceptance

- [x] Shared transcript presentation has no product-shell or service-locator
  dependency.
- [x] Mobile keeps its existing composer, voice/media, diff, navigation, and
  link behavior.
- [x] Desktop opens session detail, renders and interacts with the transcript,
  answers pending prompts, follows child sessions and links, and supports image
  save/copy/share.
- [x] Unsupported desktop composer and diff controls are omitted rather than
  rendered dead.
- [x] Shared, mobile, and desktop verification passes.
