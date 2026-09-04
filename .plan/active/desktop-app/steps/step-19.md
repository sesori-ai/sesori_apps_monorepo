# Step 19 — Diffs + new-session slice

- **Status:** `done`
- **Complexity:** `⚙️`
- **User value:** Desktop users can create sessions with the same declared options and worktree policy as mobile, then inspect a root session's file changes.
- **Dependencies:** Steps 14–18

## Scope

- Move reusable new-session and diff presentation out of the mobile product shell and into `client/module_app_ui`.
- Keep cubit construction, typed routing, connection-banner ownership, voice policy, and platform attachment capabilities in each product shell.
- Add desktop new-session and diff routes without absorbing the later cockpit, notifications, or distribution work.

## Implementation Summary

- Extracted `NewSessionView`, its plugin chooser, no-harness notice, and options skeleton into `module_app_ui`. The view accepts explicit callbacks and a composer-scope builder instead of importing mobile routing, DI, keyboard visibility, voice construction, or image-picker code.
- Kept the mobile wrapper responsible for `NewSessionCubit`, `VoiceInputCubit`, `MobileComposerPresentationScope`, split-navigation subtitle/banner policy, and typed route replacement.
- Added a desktop wrapper that constructs `NewSessionCubit`, composes `DesktopComposerPresentationScope`, remains effectively text-first with voice omitted, and preserves plugin/model/command, attachment, draft-restoration, launch-status, and dedicated-workspace behavior.
- Moved the diff view model, highlighting, widgets, and stateful presentation into `module_app_ui`. Mobile and desktop wrappers independently construct `DiffCubit` with the existing connection and loaded-state analytics collaborators.
- Added typed desktop new-session and session-diff routes, wired **New task** from the session list, and exposed file changes only through the shared session-detail policy for root, non-archived sessions. Desktop Back behavior falls back to the owning typed session route when no route can pop.
- Preserved one desktop root connection banner by passing no local banner into the new routed views.
- Moved reusable diff widget tests with their source, retained the mobile wrapper/integration coverage, and added desktop route, text-first new-session, dedicated-workspace, and file-changes callback coverage.
- Preserved the existing authoritative analytics events emitted by `NewSessionCubit` and `DiffCubit`; no new UI-proxy event or sensitive parameter was added.

## Architecture Review

- The first review used a moving `origin/main` after the branch was created and therefore rejected an upstream scoped-abort change that was not part of Step 19. No Step 19 finding was reported.
- Fast-forwarded the branch to that main commit, regenerated an authoritative tracked-plus-untracked worktree diff, and reran the review with HEAD and `origin/main` equal and the upstream commit explicitly excluded.
- The corrected `architecture-implementation-review` result was **APPROVED** with no findings. It confirmed shared presentation ownership, shell-owned DI/routing/banner/capability composition, shell-constructed cubits, and the absence of desktop dependencies in `module_app_ui`.

## Verification

- `client/module_app_ui`: `asdf exec dart analyze --fatal-infos` passes; the complete suite passes 276 tests, including the moved diff model/highlighting/widget coverage.
- `client/app`: `asdf exec dart analyze --fatal-infos` passes; the complete mobile suite passes 660 tests, including new-session voice/restoration/navigation and diff refresh/collapse behavior.
- `client/desktop`: `asdf exec dart analyze --fatal-infos` passes; the complete desktop suite passes 93 tests, including typed route decoding, text-first new-session composition, dedicated-workspace presentation, and session-detail file-changes dispatch.
- Dart LSP reports zero diagnostics across 32 changed Dart files.
- A clean `asdf exec flutter build macos --release` succeeds (65.7 MB reported by Flutter), and `codesign --verify --deep --strict` accepts the resulting app bundle.
- Real-account/live-plugin desktop interaction was intentionally not automated in this step. Gate C remains user-run after Step 20 cockpit composition.

## Acceptance

- [x] Reusable new-session and diff presentation lives in `module_app_ui` without product-shell dependencies.
- [x] Mobile retains voice, keyboard, routing, banner, and attachment composition.
- [x] Desktop supports typed new-session and diff routes with text-first/no-voice capability truthfulness.
- [x] Dedicated-workspace creation and existing draft/launch semantics are preserved.
- [x] Existing creation and diff analytics remain wired at authoritative outcomes.
- [x] Affected analyzers, full suites, LSP diagnostics, macOS release build, and architecture review pass.
