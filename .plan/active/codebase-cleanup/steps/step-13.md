# Step 13/45 - Publish module_core test support and relocate pure-Dart tests

## Re-verification against `main`

The historical audit counted 16 app-test files that deep-imported
`package:sesori_dart_core/src/...`. Current `main` has 14 because two of the
historical tests were deleted by earlier cleanup steps. Of those 14, 11 are
pure-Dart tests and moved to `client/module_core/test`; the two diff widget
tests and the Flutter app helper remain in `client/app/test`.

The app and module-core helpers had 1,494 lines between them before this step.
The resulting public testing implementation plus package-local and app-local
helpers have 1,042 lines: core/auth-owned mocks, fakes, delegates, fallback
values, and data factories now live in `package:sesori_dart_core/testing.dart`,
while `package:test` teardown support remains in the module-core test helper and
Flutter, Firebase, recording, and app-DI support remains in the app helper.

`mocktail` is now a regular `module_core` dependency because the opt-in public
testing library exposes Mocktail-based test doubles. It is not exported by the
production `sesori_dart_core.dart` barrel.

All 12 exports named by the plan had no production consumer after the moves and
were removed. Existing tests that intentionally exercise those internal types
now import their defining `src/` library directly. No production implementation,
wire contract, persisted data, database schema, or user-visible behavior changed.

## Verification

- `dart pub get` from `client`: passed.
- `dart analyze` in `client/module_core`: clean.
- `dart test` in `client/module_core`: 1,314 passed.
- `dart analyze` in `client/app`: clean.
- `flutter test` in `client/app`: 842 passed.
- `dart analyze` in `client/desktop`: clean.
- `git diff --check`: clean.

The raw diff excluding this evidence file is `+918 / -1,374`.
That exceeds the 1,500 changed-line soft cap because Git counts the 844-line
testing-library extraction as an addition while also counting the consolidated
helper bodies as deletions; the change is deletion- and relocation-heavy rather
than new product logic.

Architecture implementation review not run: Step 13 is excluded by the
tracker's locked architecture-review scope and changes test support, test
location, and production-barrel exposure only.
