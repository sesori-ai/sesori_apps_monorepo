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
  Image capabilities resolve lazily, the root-navigator image viewer copies the
  scope, and bottom-sheet routes receive the captured link opener explicitly so
  overlays retain the originating product capabilities.
- Kept mobile composition product-owned. Mobile supplies its existing route and
  link policies, connection banner, diff action, and the extracted
  `SessionDetailComposerControls` containing voice, media, background-task, and
  prompt behavior.
- Added the typed desktop session-detail destination, list-to-detail and
  child-session navigation, Back fallback, session activity analytics, and the
  shared interactive transcript. Desktop intentionally injects no composer or
  diff action in this slice, so unsupported controls are absent.
- Added concrete desktop file-save, pasteboard, and system-share adapters for
  image actions, plus app-private thumbnail storage, and registered the complete
  lazy image graph through desktop DI. macOS and Windows expose Share; Linux
  omits it because the current share plugin has no Linux implementation.
- Moved the reusable copy/check/haptic control into `module_prego` while callers
  retain clipboard operations and failure logging.
- Restored the parent session's viewing claim when a pushed child route is
  removed, and keyed desktop detail screens by project/session identity so one
  route never retains another route's Cubit.
- Kept the extracted boundary compatible with the merged
  `claude-inline-subtasks` and `instant-session-launch` work by sharing the
  neutral user-message and image-viewer components rather than introducing a
  competing product-specific layer.
- Updated the session-turn, question/permission, image, inventory, and desktop
  supervision regression contracts to cover the new shared/desktop behavior.

## Architecture Review

- `architecture-implementation-review`: **APPROVED** with no findings after
  rebasing and applying the complete review-remediation commit.
- The reviewer confirmed that `module_app_ui` remains surface-neutral; product
  shells retain routing, links, composer, analytics, and platform ownership;
  desktop thumbnail/image adapters remain shell-owned; nullable notification
  cancellation and viewing restoration stay surface-neutral in `module_core`;
  and the reusable copy interaction belongs to `module_prego`.
- Review artifact: `/tmp/desktop-step17-architecture-review.md`.

## Verification

- `client/module_prego`: `asdf exec dart analyze --fatal-infos` passes; the
  complete suite passes 262 tests, including the shared copy confirmation.
- `client/module_core`: `asdf exec dart analyze --fatal-infos` passes; the
  complete suite passes 1,477 tests, including optional notification cancellation
  and parent-session viewing restoration.
- `client/module_app_ui`: `asdf exec dart analyze --fatal-infos` passes; the
  complete suite passes 248 tests, including captured bottom-sheet links and
  unsupported Share omission.
- `client/app`: `asdf exec dart analyze --fatal-infos` passes; the complete
  mobile suite passes 689 tests after transcript-test ownership moved to
  `module_app_ui` and parent-route restoration was added.
- `client/desktop`: `asdf exec dart analyze --fatal-infos` passes; the complete
  desktop suite passes 84 tests, including transcript composition, lazy image
  capabilities, app-private thumbnail storage, typed routing, image adapters,
  and DI graph resolution.
- `client/module_desktop_core`: `asdf exec dart analyze --fatal-infos` passes;
  the complete suite passes 201 tests.
- Dart LSP reports zero diagnostics across 174 relevant files.
- `git diff --check` passes.
- `asdf exec flutter build macos --release` succeeds (64.7 MB reported by
  Flutter; 62 MB on disk).

## Acceptance

- [x] Shared transcript presentation has no product-shell or service-locator
  dependency.
- [x] Mobile keeps its existing composer, voice/media, diff, navigation, and
  link behavior.
- [x] Desktop opens session detail, renders and interacts with the transcript,
  answers pending prompts, follows child sessions and links, and supports image
  save/copy plus Share on platforms with a registered implementation.
- [x] Unsupported desktop composer and diff controls are omitted rather than
  rendered dead.
- [x] Shared, mobile, and desktop verification passes.
