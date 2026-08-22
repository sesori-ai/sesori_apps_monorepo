# Step 5/45 — Delete dead bridge production code

**PR:** [#1021](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1021)

## Re-verification against `main`

Every symbol had zero production callers, but the plan under-counted test
coupling. Deferred to Steps 9/10, which already rewrite those test files:
`insertStoredSession` (21 test call sites), `insertSessionsIfMissing` (29),
`getHiddenProjectIds` (14), `unhideProject` (7) — the fixtures tests use as
their write and observation API. Also deferred: `takeChildren`,
`takeTranslations`, `takeReady`, which read private tracker state, so no other
public method lets their tests assert per-plugin child isolation and generation
supersession. `sesoriPostUpdateRestartEnvVar` still has three production
consumers, so it stays for Step 42.

## Verification

`bridge/app`: analyze clean, 2,684 tests (down from 2,693 in Step 3 because this
step deletes the `PortRepository` and host-factory test files).

Size, self-inclusive of this record, measured with
`git diff --numstat "$(git merge-base HEAD origin/main)"...HEAD` against
merge-base `00cc03563`: `+101 / -580` = 681 changed lines, within the
700–1,000 target.
