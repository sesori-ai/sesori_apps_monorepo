# Step 35/45 — Delete dead shell code, components, and localization keys

## Re-verification against `main`

Two of the plan's claims were wrong and are **not** acted on:

- **`client/app/lib/core/status_colors.dart` is alive.** It is imported by
  `features/session_list/session_tile.dart:7` and its `kStatusAmber` is used at
  `:364`. The audit — and my own first grep — produced false positives because
  the pattern `kStatus` also matches localization keys such as
  `backgroundTaskStatusBusy`. The analyzer caught the mistaken deletion; the
  file is restored.
- **`PregoSkeletonListTile` is not test-only.** `PregoSkeleton` renders it at
  `prego_skeleton.dart:287`; the tests assert on it with `find.byType` because
  it is what the list variant draws. Kept.
- **`debugGlassEntryHeight`** is a documented `debug*` seam whose doc comment
  states it exists for the test that pins each declaration's height. Kept.

Everything else was confirmed dead before deleting: each removed Prego
component has zero references anywhere in `client/` and is absent from
`module_prego.dart`'s exports, and each removed ARB key has zero `.key`
references in `client/app/lib` or `client/app/test`.

## Verification

`client/app`: `flutter analyze` clean, `flutter test` 980 passed, localization
regenerated with `flutter gen-l10n`. `client/module_prego`: `flutter analyze`
clean, `flutter test` 210 passed. The ARB file was re-parsed as JSON after the
key removal to prove it stayed valid.

Architecture implementation review not run — deletions only, no new or moved
class, no DI change, no contract change.
