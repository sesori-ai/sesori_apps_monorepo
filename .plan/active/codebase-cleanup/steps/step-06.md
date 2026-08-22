# Step 6/45 — Close CI gaps, prune dependencies, refresh docs

**PR:** [#1023](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1023)

## Re-verification against `main`

Every unused-dependency claim held except `cryptography` in `client/app`, used
by one test, so it moves to `dev_dependencies`. `no_slop_linter` passes
`--fatal-infos` (an earlier count of 1,356 issues was an unresolved package).
`module_app_ui` is documented as planned for Phase 4, so the diagram marks it
planned rather than deleting the concept.

## Verification

The new CI loops simulated locally: all 12 bridge packages and both shared
packages pass `--fatal-infos`; `make analyze`/`make test` pass from `shared/`;
`flutter analyze` and 987 `client/app` tests pass after pruning.
