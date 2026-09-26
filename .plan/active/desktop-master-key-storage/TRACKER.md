# Shared client persistence tracker

## Execution

- Status: #1751 and regression reconciliation #1758 merged. Native qualification
  is partial. The user-requested failed-import reset follow-up is verified and
  architecture-approved, ready for PR delivery.
- User approved one Drift backend on both mobile and desktop, with mobile data
  migration in this work. No postponed mobile-native runtime backend.
- Migration must be isolated and explicitly deprecated from its first commit,
  with a retirement condition and deletion checklist.
- Current branch: `sesori/desktop-master-key-storage-reset-recovery`, from fixed
  main `b1d4c57` in the supplied worktree. No additional worktree is allowed.
  Qualification checkpoint `975e286` remains preserved on its published branch;
  no final qualification PR is open.
- #1717 is closed as superseded, not merged. Its published desktop checkpoint
  `4a27888` and the full shared checkpoint `de38951` remain in history.
- One open PR and at most one local successor. Current total: **13 PRs** after
  adding the user-requested reset follow-up before final qualification/retirement.
  Keep published series titles synchronized; no published history is rewritten.
- Source of truth: [PLAN.md](PLAN.md). Original directory slug stays stable.

| Milestone | State | PR / evidence |
|---|---|---|
| 1 — Initial reviewed plan | Merged | #1698; original scope now revised by user direction. |
| 2 — Typed persistence contracts | Merged | #1708; 10 tests, architecture approval, 27 passing CI checks. |
| 3.a — Initial cipher foundation | Merged | #1715; 15 tests, architecture approval, 15 passing CI checks. |
| 3.b — Shared storage foundations | Merged | #1726; 26 shared tests, one Android options test, architecture approval, four clean analyses; 23 checks passed at readiness. |
| 3.c — Shared Drift/primitive persistence | Merged | #1729; 29 tests, architecture approval, clean analysis/generation and 25 passing CI checks. |
| 3.d — Cached shared secrets | Merged | #1734; 46 shared tests, architecture approval, clean analysis/generation and 24 passing CI checks. |
| 4.a — Deprecated mobile import | Merged | #1739; 11 recovery tests, three analyses, architecture approval and 24 passing CI checks; unwired. |
| 4.b — Native capabilities and backup | Merged | #1744; 28 tests, two analyses, architecture approval and 24 passing checks; no native qualification. |
| 4.c — Startup recovery | Merged | #1749; eight tests, three analyses, architecture approval and 22 passing checks; no storage cutover. |
| 4.d — Both-client cutover | Merged | #1751; architecture approved, 24 reconciled shell cases plus retained auth/core evidence, README feedback fixed and 34 passing checks. |
| 5 — Regression reconciliation | Merged | #1758; explicit replacement on all three desktops, 139 authored lines, 7 checks passed at readiness. |
| 5.a — Failed-import reset follow-up | Verified / approved | PR 12; 77 focused cases, four analyses, generated localization, fixture visuals and architecture approval. |
| 6 — Required qualification/retirement | Partial / blocked | PR 13; checkpoint `975e286` retains mobile/signed-macOS evidence. Missing native matrix still blocks retirement. |

## Decisions and code-informed constraints

- Shared schema, crypto, raw APIs, typed repositories and one cached master key
  live in `module_persistence`. Domain keys/serialization remain in auth/core.
- Only native master-item access and a ready persistent directory/backup policy
  vary by shell. Normal repositories contain no migration or backend selector.
- Deprecated mobile import lives under core's
  `migrations/deprecated_native_storage_v1/` and a matching mobile platform area.
  It is awaited before auth, analytics, deep links or other consumers resolve.
- Successful import copies known values, deletes copied native items, then marks
  complete. After process interruption, merge remaining source into committed
  rows. Caught failures instead attempt scoped reset; no legacy fallback reads.
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
- User explicitly requested failed-import reset on 2026-09-26: clear scoped
  secrets/preferences/legacy data, replace the master and continue logged out.
  Normal account/server analytics preferences apply; pending local-only opt-out
  may be lost. No separate consent flag or blocking recovery screen.
- Recovery attempts completion even after cleanup failure to fence stale source
  auth when the marker succeeds. Each failure stays logged. Failed secret reset
  stays cached, preventing partial auth restoration in that process. Permanent
  native/SQL denial can still fail normal persistence; this is not guaranteed
  successful erasure when storage cannot be changed.
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
- #1726 current-head Codex completed without findings; 23 checks were passing
  when readiness triggered its merge. The terminal report showed an additional
  check still running; that later check is not counted as passed here.
- The combined shared backend at unpublished `de38951` passed 46 tests and owning
  analysis. Native calls remained fake; real SQLite used temporary files. Its
  1,611-line diff motivated the SQL/secret split, not a change to the design.
  Each extracted slice needs its own verification and implementation review.
- Extracted SQL slice: 29 tests passed independently without secret-backend
  source, including real SQLite/WAL/reopen, lazy DI and disposal. Owning analysis,
  dependency resolution, generation, formatting and whitespace checks passed.
  No application data or native credentials were accessed.
- SQL implementation review `7ee56961-ed06-48a5-aa30-2cff50d8bbd5` approved exact
  range `af23da2..2e1309b`, all 20 paths, without findings. Cached secrets,
  native adapters and future consumer/migration work were outside that scope.
- #1729 merged with current-head Codex complete and no findings; its terminal
  monitor report recorded 25 passing checks.
- Reconciled cached-secret slice: 46 shared tests pass, including the SQL tests
  from #1729, real temporary DB/WAL/reopen with complete secret DI, concurrent
  initialization, native denial/loss, ciphertext-before-key exclusion and
  rollback. Dependency resolution, generation, formatting and owning analysis
  passed. Native access remains fake; app bindings are unchanged.
- Cached-secret review `51bf34aa-9408-4082-ae7e-7ba5a3a55c39` approved exact
  range `0818f4b..bae788a`, all 13 paths, without findings. Native shell adapters,
  migration and consumer cutover were excluded.
- #1734 merged with current-head Codex complete and no findings; its terminal
  monitor report recorded 24 passing checks.
- Deprecated importer: 11 tests pass through real shared DI/SQLite/crypto and
  fake native source/master stores. They cover the full known inventory,
  unknown retention, absent/empty/false values, scoped identities and opaque
  pending-disable JSON, completion skip, read/parse/key-save/copy/cleanup/marker
  failures, and cold-reopen recovery without replacing committed rows.
  Core/auth/mobile analysis, resolution, generation and formatting passed.
  No native source adapter or startup invocation is present yet.
- Importer review `d885b123-0d8a-49db-982e-be35c37e0413` approved exact range
  `f1f00ee..3b8ac72`, all 25 paths, without findings. Native adapters and the
  future consumer/bootstrap cutover were explicitly outside that scope.
- #1739 merged with current-head Codex complete and no findings; its terminal
  monitor report recorded 24 passing checks. The documented narrow declaration
  suppression retains the required deprecation against internal 0.x lint policy.
- Native capability slice: 14 mobile and 14 desktop focused tests pass, using
  mocked native channels and disposable directories. Both shell analyses,
  dependency resolution, generated DI and formatting pass. XML validation
  confirms manifest bindings and only `file:persistence/` exclusions in old/full
  backup, cloud and device-transfer policies; legacy preferences are unchanged.
  These tests do not invoke the Keychain, Keystore, Credential Manager or libsecret.
- Native-capability review `12180381-83ef-42c8-9963-633f1e74f283` approved exact
  range `d07c69d..b234217`, all 26 paths, without findings. Consumer cutover,
  migration invocation and real native qualification were outside that scope.
- #1744 merged with current-head Codex complete and no findings; its terminal
  monitor report recorded 24 passing checks.
- Complete cutover checkpoint `ea7550e`, based on `064dcf8`: 153 focused cases
  pass (auth 85, core 46, shared UI 2, mobile 17, desktop 3), with five clean
  analyses, regenerated DI/localization and Android XML validation. Real SQL/
  crypto and fake native ports prove startup admission, pre-analytics pending
  disable, local auth/preferences and cold reopen; no native OS proof follows.
  Measure: 1,650 lines, 1,545 authored and 105 generated. The recovery foundation
  and reconciled consumer successor each need independent verification/review.
- Extracted recovery foundation: two standalone light/dark large-text widget
  cases and six mobile bootstrap/notification cases pass without the consumer
  cutover. Shared UI, mobile and desktop analyses pass; localization is generated.
  Two additional font-loaded fixture previews were inspected and published on
  `pr-media` (`a6efba6`), with no account content or real app/service launch.
  Architecture review `324bf4c7-5bc4-4cfe-94b1-c56e5d52401e` approved exact
  `064dcf8..683077f` (12 paths, 274 lines) without findings; successor excluded.
- #1749 merged with current-head Codex complete and no findings; its terminal
  monitor report recorded 22 passing checks. Merged base is `33c7815`.
- Reconciled cutover: 13 mobile and 11 desktop cases pass, including upstream
  shared-email-login consumers, production admission, pending disable, local
  auth/preferences and cold reopen. Both shell analyses and exact Android XML
  exclusions pass. Auth/core source, tests and configs are byte-identical to
  `ea7550e`, so retain their 85/46 passing cases and clean analyses rather than
  rerunning unchanged inputs. Across saved latest-per-suite evidence there are
  163 unique passing cases, not a new full-suite invocation. DI remains the
  generated checkpoint output; no generated conflicts or hand edits occurred.
  Formatting checked 35 handwritten Dart files; obsolete runtime interface and
  adapter symbol searches found no remaining Dart references.
  Architecture review `554a1f9d-c952-4df8-8501-eb9595df2e64` approved exact
  `33c7815..90b20bd` (54 paths, 1,539 lines) without findings.
  Codex identified stale package READMEs; corrected setup/dependency guidance in
  mobile, auth, core, workspace and persistence READMEs. Documentation checks
  cover retired names/phases, public exports, code fences and whitespace;
  production/test inputs remain unchanged, so no suite or architecture rerun.
- Native qualification must replace the authenticated macOS fixture's old
  per-value seeding and retained desktop baseline before using it with this
  cutover. Seed with production Dart storage; do not copy SQL/crypto into Swift
  or Python. The CI-only packaged platform probe already uses shared storage,
  with initial source/unit verification only; later signed-run evidence is below.
- #1751 merged after current-head Codex completed without further findings.
  Its terminal monitor recorded 34 passing checks; the README thread was resolved
  and the narrow deprecated call acknowledgment was justified explicitly.
  Final cutover diff: 1,634 lines (1,548 authored, 86 generated), including 376
  documentation lines. No native storage boundary was exercised by these checks.
- Regression reconciliation validates 17 relative links, code fences, all twelve
  series entries, retained native coverage requirements and whitespace. Only
  Markdown changes; no runtime suites or architecture review are required.
  Automated admission/recovery sits at L2; native L3/L4 requirements match the
  existing plan and are not reduced or represented as passing. Codex identified
  omitted Windows/Linux replacement wording; L3 now explicitly preserves the
  database/master pairing through new-format replacement on all three desktops.
- Later native evidence is preserved on qualification checkpoint `975e286`, not
  replaced or represented as execution of the new reset policy:
  [mobile migration](https://github.com/sesori-ai/sesori_apps_monorepo/blob/975e286/.plan/active/desktop-master-key-storage/MOBILE_MIGRATION.md)
  and [qualification](https://github.com/sesori-ai/sesori_apps_monorepo/blob/975e286/.plan/active/desktop-master-key-storage/QUALIFICATION.md).
  Android retained seed/migrate/reopen passed; iOS import checks passed before a
  bad fixture assertion failed, then corrected separate-process reopen passed.
  The owned iOS runner uninstall incident was disclosed and repaired; no claim
  of a wholly green first iOS invocation or byte-identical sandbox preservation.
- Signed macOS roundtrip/reopen evidence from Actions run `36221737896` is reused
  with source/digest checks. Windows/Linux native execution, all-desktop new-format
  replacement, native denied-access/reset, actual distributed upgrades and hardware
  backup/restore remain missing. No physical devices or coverage waiver exist.
- Reset plan review `18a9a582-7357-41c4-be8f-8085526806ed` approved the scoped
  ownership/startup/cache design, with B-Client in scope and no violations.
  B-Bridge/B-Shared were skipped. This is design approval, not native qualification.
- Reset implementation: 77 focused cases pass (54 persistence, 12 migration,
  11 mobile admission/native-channel/startup). Persistence/core analyses are clean;
  mobile/shared-UI analyses are retained from unchanged shell/UI inputs. Localization
  was regenerated. Successful import and process-interruption merging remain intact.
  Secret reset attempts deletion and key replacement independently, retaining both
  errors: native-key invalidation must not be skipped when SQL deletion fails.
  Fresh-instance tests prove surviving ciphertext cannot restore with the new key.
  No native adverse-state/reset, hardware restore or final qualification is claimed.
- Implementation review `ba733ea6-4935-45fe-8740-ef7632798ebf` approved exact
  `b1d4c57..6a32232` (38 paths, 1,098 lines: 1,079 authored and 19 generated),
  without architectural violations. B-Client applied; B-Bridge/B-Shared skipped.
- Two font-loaded normal-login/email-form previews passed and were inspected in
  light/dark themes. Fixture-only images/GIF are on `pr-media` at `bd7f0d6934`;
  they do not demonstrate native migration or a real authentication request.
- Before resuming qualification, update its retained native fixture's
  `_NoLegacyReads` for the new `clear()` capability without reseeding or erasing
  retained slot data. Required new reset/native adverse-state coverage remains.
