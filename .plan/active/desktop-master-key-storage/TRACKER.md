# Shared client persistence tracker

## Execution

- Status: shared-client plan findings applied without another approval round.
  Shared foundations verified and architecture-approved for replacement PR 4.
- User approved one Drift backend on both mobile and desktop, with mobile data
  migration in this work. No postponed mobile-native runtime backend.
- Migration must be isolated and explicitly deprecated from its first commit,
  with a retirement condition and deletion checklist.
- Current branch: `sesori/desktop-master-key-storage-shared-foundation`, based on
  main in the supplied worktree. No additional worktree is allowed.
- #1717 is closed as superseded, not merged. Its published backend checkpoint is
  preserved at `4a27888` on `sesori/desktop-master-key-storage-drift`; carry that
  implementation into shared-backend PR 5 without rewriting published history.
- One open PR and at most one local successor. Current total: **10 PRs**;
  published series titles are synchronized.
- Source of truth: [PLAN.md](PLAN.md). Original directory slug stays stable.

| Milestone | State | PR / evidence |
|---|---|---|
| 1 — Initial reviewed plan | Merged | #1698; original scope now revised by user direction. |
| 2 — Typed persistence contracts | Merged | #1708; 10 tests, architecture approval, 27 passing CI checks. |
| 3.a — Initial cipher foundation | Merged | #1715; 15 tests, architecture approval, 15 passing CI checks. |
| 3.b — Shared storage foundations | Architecture approved | Replacement PR 4; 26 shared tests, one Android options test, four clean package analyses. |
| 3.c — Shared encrypted Drift backend | Checkpoint preserved | Replacement PR 5; reuse tested backend and fold primitive delegation. Unused secure interface removed in PR 4. |
| 4.a — Deprecated mobile import | Not started | PR 6; isolated module, explicit deprecation, domain keys and recovery tests. |
| 4.b — Native capabilities and backup | Not started | PR 7; narrow platform adapters and actual mobile backup boundary. |
| 4.c — Both-client cutover | Not started | PR 8; lockstep consumers, migration/failure startup gate and runtime adapter removal. |
| 5 — Regression reconciliation | Not started | PR 9; behavior docs also accompany their implementation. |
| 6 — Required qualification/retirement | Not started | PR 10; plan remains active until recorded mobile + desktop matrix passes. |

## Decisions and code-informed constraints

- Shared schema, crypto, raw APIs, typed repositories and one cached master key
  live in `module_persistence`. Domain keys/serialization remain in auth/core.
- Only native master-item access and a ready persistent directory/backup policy
  vary by shell. Normal repositories contain no migration or backend selector.
- Deprecated mobile import lives under core's
  `migrations/deprecated_native_storage_v1/` and a matching mobile platform area.
  It is awaited before auth, analytics, deep links or other consumers resolve.
- Copy every present known value, then remove copied native items, then mark
  complete. Retry by merging remaining source values into committed destination
  rows; never replace/clear a partial snapshot or run legacy fallback reads.
- Mobile production data includes all auth/OAuth fields, the relay room key,
  scoped plugin preferences and pending analytics opt-out JSON.
- iOS currently shares its bundle ID between build modes. Only production scope
  imports its legacy namespace; development must not steal production data.
- Disable Android native `resetOnError` on the active legacy instance in PR 4,
  then retain it on the protected master/legacy adapters. Delay exclusions for
  old credential preferences until the migration/cutover PR.
  Exclude DB/native credential files from Android backup; retain and qualify
  paired iOS database/master-key encrypted backup instead of adding needless
  exclusion machinery. Copied ciphertext without its master fails explicitly.
- Keep the new native master namespace separate from the deprecated source.
  iOS legacy enumeration omits the accessibility query filter without changing
  stored ACLs; native legacy-envelope completeness/error behavior needs proof.
- Mobile import failure must preserve data and present a startup failure state;
  it must not silently boot logged out or start analytics with default consent.
- Native cleanup completes before the marker. Current-device logout is local,
  so leaving usable old auth items as a parallel source is not an acceptable
  successful migration outcome. Failure/relaunch recovery is explicitly tested.
- Desktop is unpublished: sign out in the old build before cutover, then sign in
  once. No legacy desktop migration, automatic old-Keychain cleanup or claims
  that new local logout revokes old internal builds' separate sessions.
- One-time mobile import may require native access; normal plaintext operations
  do not. One master-item lookup does not promise zero OS authorization dialogs.
- No running app/helper launches, personal credential reads/Keychain changes or
  wallet modifications are authorized by fixture tests or plan editing.

## Evidence retained, not overclaimed

- Read-only wallet inspection informed typed primitives/selective encryption.
  The discarded unwired file-store prototype established no compatibility data.
- Original and revised plan reviews supplied concrete layering, DI, package,
  public-export and stable-key inventory corrections. The second full report
  was recovered after its acknowledgement overwrote the saved artifact:
  SHA256 `7e550c2e1629b4bffbb9af8c7dca6df17c621efb713590526173f8e79d876bfc`.
- Shared-contract review `240d3ac4-7970-4398-9917-2ee9b58e2a79` approved
  `origin/main..fc8b270`. Its tests, analysis, generation and workflow validation
  passed; app bindings were not switched.
- Cipher review `dd2c7b27-5c57-4ab7-b051-7b915aa39be3` approved
  `3ffe4a1..634f109`. Fifteen cipher tests and analysis passed; no storage I/O.
- Preserved backend review `94992f10-0bb1-4d18-8a90-9703e659e2e5` approved
  `ee30870..bd6e7a4`, with 20 backend tests, clean analysis and regenerated
  Drift/Injectable output. The final published diff was 1,459 lines: 743 authored,
  660 generated Dart and 56 lockfile. #1717 Codex completed without findings.
- Combined original fixture coverage: 35 tests across cipher/database/repository,
  including real SQLite/WAL/reopen, key failure/concurrency, rollback, scope and
  disposal. Native access was fake; real user/application state was untouched.
- Shared-plan review `96c6ea95-da0d-475e-8729-68a8f24d74b8` passed its pre-review
  gate and rejected six concrete details. All were corrected: canonical auth
  model/export, backup/reset rollout, exact production guard, typed bootstrap
  failure/disposal/rendering seam, nested deprecated layers and cutover guidance.
  No repeat approval is claimed or required for these fixes.
- Shared-foundation slice: moved cipher/scope/errors and tests to persistence,
  added native master/directory contracts, removed the unused shared secure
  interface, and disabled Android destructive native reset. Generation and
  formatting passed; 26 shared tests plus one mobile native-options test passed.
  Analysis is clean in persistence, desktop-core, mobile app and desktop shell.
  Native calls were not exercised; no database or app binding was switched.
- Shared-foundation review `4d74e149-75fb-486c-919e-e5124b39a3a8` approved exact
  range `66db48e..f38a2f7`, all 24 changed paths, without findings. No future
  migration/cutover implementation or unrelated architecture was reviewed.
- None of this evidence establishes released-mobile migration, mobile
  backup/restore, real credential behavior, packaged replacement or actual
  prompt counts. Those gates remain.
