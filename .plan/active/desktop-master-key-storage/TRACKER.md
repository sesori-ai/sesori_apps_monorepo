# Desktop master-key storage tracker

## Execution

- Status: scoped-cipher slice (3.a) verified and architecture-approved; publishing PR 3/7.
- Plan PR: [#1698](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1698), merged.
- Branch: `sesori/desktop-master-key-storage-cipher`.
- One local successor: `sesori/desktop-master-key-storage-drift` preserves the
  combined tested backend checkpoint; sync it with 3.a before publication.
- Use the supplied worktree only; one open PR and at most one local successor.
- Current total: **7 PRs**. Original Step 3 is split into 3.a (PR 3) and 3.b (PR 4);
  integration/documentation/qualification retain milestone IDs 4/5/6 (PRs 5/6/7).
- Source of truth: [PLAN.md](PLAN.md).

| Step | State | PR / evidence |
|---|---|---|
| 1 — Reviewed Drift plan | Merged | #1698; both reviews' concrete findings applied without a third review. |
| 2 — Shared typed persistence contracts | Merged | #1708; 10 local tests, architecture approval and 27 passing CI checks. |
| 3.a — Scoped secret encryption | Ready for PR | 15 tests, clean analysis and architecture approval; no storage I/O. |
| 3.b — Encrypted Drift desktop boundary | Local successor | Database, raw APIs and key-owning repository; still unwired. |
| 4 — Consumer and platform integration | Not started | Mobile native format preserved; desktop adopts Drift. |
| 5 — Regression/distribution reconciliation | Not started | Behavior-specific docs also change with Step 4. |
| 6 — Required qualification and retirement | Not started | Keep active until all recorded gates pass. |

## Decisions

- Unchanged app relaunches do not prompt after Always Allow. First-run native
  authorization fan-out is the target; zero system prompts is not promised.
- User selected Drift + typed keys after comparison with the wallet reference:
  plaintext typed primitives, separately encrypted secret rows, a persister
  repository, and one lazily cached desktop master key.
- Only secrets unlock the key. Plain preferences remain usable while unlocking
  is pending or denied. SQLite owns atomic writes and connection lifecycle.
- Shared enum-keyed consumers and the lower persistence module are approved.
  Mobile keeps exact native item names/encodings, including pending opt-out data;
  no mobile Drift rollout or storage migration.
- Desktop is unpublished: sign out in the old build before cutover, then sign in
  once in the new store. No automatic old-item reads, migrations or deletions.
- Every implementation-time behavior change updates its regression statements;
  the penultimate step completes the catalog/evidence reconciliation.
- No user app/helper launches, personal Keychain changes, real secret reads, or
  wallet source modifications are authorized by these fixture checks.

## Evidence and review

- Initial architecture review `2359dc5a-26c5-4e8a-a2d4-195b638c8e70` produced
  concrete repository/API, DI-order, scope and export findings; these informed
  the revision. Its reporter failed after the review completed; report recovered.
- Read-only wallet inspection confirmed typed primitive tables, enum-keyed
  `PersisterRepository -> Persister -> PrimitivesDao -> Drift`, and encryption
  of secret values before insertion rather than full-database encryption.
- The obsolete file-store prototype was uncommitted, unwired and untested. It
  has been removed; it creates no persisted-format compatibility obligation.
- PR #1698 merged automatically after its eight then-registered checks settled.
  All three initial threads have explicit prefixed dispositions; they were not
  dismissed merely because the storage technology changed. Latest-head Codex
  review was still running at the startup assessment; no completed result from
  that review is claimed.
- Revised review `52fff904-c1da-49bd-9c99-f06e30d1d21f`: four concrete omissions
  corrected (workspace dependencies, exact DI calls, canonical type ownership,
  and the full stable-key matrix). No repeat approval is claimed.
- Full second review recovered from the original write at session line 202,
  SHA256 `7e550c2e1629b4bffbb9af8c7dca6df17c621efb713590526173f8e79d876bfc`;
  the short overwritten acknowledgement was not treated as complete evidence.
- Step 2: `dart pub get` and Injectable generation passed. The final package has
  10 passing tests and clean `dart analyze --fatal-infos`; changed workflows pass
  `actionlint`. No native backend, app storage or platform bootstrap is switched.
- Step 2 architecture review `240d3ac4-7970-4398-9917-2ee9b58e2a79` approved
  `origin/main..fc8b270` with no findings. The full final response was captured;
  no report recovery or repeat review was needed.
- Independent 3.a slice: 15 cipher tests pass after extraction, owning-package
  analysis is clean, and DI generation succeeds without any Drift/native backend
  dependency. Architecture review `dd2c7b27-5c57-4ab7-b051-7b915aa39be3`
  approved the exact `3ffe4a1..634f109` scope with no findings. This slice adds no
  storage I/O; broader backend and integration gates remain pending.
- Combined Step 3 checkpoint: 35 focused cipher, repository and real SQLite tests
  passed, including file/WAL inspection, reopen, pending/failed key initialization,
  independent writes/deletes, SQL rollback, scope isolation and GetIt disposal.
  These are fixture checks, not packaged/native credential or prompt-count proof.
- Measured the combined Step 3 diff at about 1,700 changed lines (667 generated).
  Split the independent cipher/scope foundation before publication; the three
  tables and their generated schema stay together in 3.b. No extra feature scope.
- The new package is included in workspace discovery, local Makefile commands,
  shared mobile/client test coverage, and desktop change detection. Existing
  consumers and the original auth-owned interface remain in use until Step 4,
  where that interface and the native-per-value desktop adapter are removed.
