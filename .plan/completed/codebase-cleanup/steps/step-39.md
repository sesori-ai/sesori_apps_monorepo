# Step 39 evidence

## Context

- Branch: `codebase-cleanup/step-39-prompt-composer`
- Base: `origin/main` at `e919de274be00e237d9a76dde69b97a517e0a425`.
- Re-verification found every duplicate named by the plan still present in
  `prompt_input.dart`; the overlapping composer PRs noted by the plan had
  already landed in this base.

## What changed

- Routed keyboard and context-menu paste through one state-owned image/text
  fallback path while preserving the original selection and stale-paste rules.
- Merged draft restoration and transcription insertion into `_applyDraft`, with
  explicit notification policy at each call site.
- Routed the recording-limit warning through `_showComposerNotice`.
- Replaced the two voice-pill renderers with `_buildVoicePill` and shared the
  repeated mic/primary action row.
- User-visible behavior, wire contracts, persistence, and dependencies are
  unchanged. No regression-document update is needed for this local refactor.

## Diff size

- Production: one file, `74 insertions, 143 deletions` before this evidence
  file.
- The step remains below the 1,500 changed-line soft cap.

## Verification

- `dart analyze --fatal-infos` from `client/app`: PASS, no issues.
- `flutter test test/features/session_detail test/features/new_session` from
  `client/app`: PASS, 280 tests.
- `git diff --check`: PASS.
- `dart format lib/features/session_detail/widgets/prompt_input.dart` cannot run
  because the pinned formatter crashes on the file's existing Dart 3.13
  enhanced-enum syntax; the touched code was formatted manually and accepted by
  the analyzer.

## Architecture review

Not required. Step 39 is excluded from the tracker's architecture-review list
and changes only widget-local method implementation.
