# Step 6/45 — Close CI gaps, prune dependencies, refresh docs

## Re-verification against `main`

Every unused-dependency claim held except that `cryptography` in `client/app` is
used by one test, so it moves to `dev_dependencies` rather than being deleted.
`no_slop_linter` passes `--fatal-infos` (an earlier count of 1,356 issues was an
unresolved package, not real findings), so both Makefiles and CI can use the
strict flag. `module_app_ui` in `client/AGENTS.md` is not stale-by-deletion: the
README documents it as planned for Phase 4, so the diagram marks it planned
instead of showing it as an existing edge.

## Verification

The new CI loops were simulated locally — all 12 bridge packages and both shared
packages pass `dart analyze --fatal-infos`; `make analyze` and `make test` pass
from `shared/`; `flutter analyze` and 987 `client/app` tests pass after the
dependency pruning, including the crypto test that now relies on the dev
dependency.

Architecture implementation review not run — CI configuration, pubspec entries,
and documentation only.

## Review follow-ups applied

Cursor's dependency list gains `sesori_shared`; the app README drops the
accelerated-relay-encryption row for the removed `cryptography_flutter`;
`module_core`'s `platform/` is described as abstract interfaces again; the
`no_slop_linter` note says `sesori_shared` enables it as an analyzer plugin by
path rather than declaring it as a dev dependency.
