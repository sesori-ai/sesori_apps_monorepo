# Step 9.a.2 — Rotating application logs

Execution evidence for the file-output continuation of preserved PR #1509.
The PR body owns the complete publication range and inclusive size, including docs.
The source-free diagnostic foundation is delivered separately by #1514; its
[revision-scoped evidence](step-09a1.md) is not added to this step's test count.

## Delivered boundary

- Desktop/mobile independently persist console-fanned log records in `app.log`
  and one predecessor, capped at 5 MiB per active file with UTF-8-safe truncation.
  Desktop app/helper files use separate package-internal rotation instances;
  POSIX directory/file modes remain 0700/0600. Mobile uses backup-excluded,
  app-private cache storage through the existing temporary-directory client.
  The OS may evict mobile logs; the next append recreates their directory.
- Lazy DI phase-4 desktop and phase-1 mobile bindings remain in their owning
  modules. Only an admitted primary desktop resolves/installs its sink; mobile
  installation is inside the real dependency callback, not the fake bootstrap.
- Both production `flush()` operations await the write tail admitted before the
  call. Desktop serializes its existing tail at admission, as mobile already did.
  Finite appends flush/close their files; no retained handles or new lifecycle owner.
- Successful appends reset each existing failure-warning bit. Failures report
  directly to stderr once per episode, never recursively through the failing sink.
- Open Logs prepares/opens the logs directory via existing storage/repository
  ownership; failure wording now identifies the directory. Helper drains remain bounded.
- Core/auth and their generated outputs are byte-identical to the landed prerequisite.
  Its typed causes, lower-adapter URI protection, console chunking and bounded Quit
  policy remain intact. Incoming mobile link diagnostics now also omit URI payloads
  in the router and its existing app-links service. No wire, database, auth-policy
  or analytics change.

Seven mutable parts belong to these file writers: desktop tail/failure bit and
its rotation instance's tail/two preparation bits; mobile tail/failure bit.
Bridge rotation state moved rather than being duplicated. No retry timer,
drop/batching queue, upload or pending-memory-bound claim is added.

## Immutable checkpoints

Repository: `/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/rose-elephant`.
SDK: `/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/`.
Package cwd below is relative to the repository.

| Point | Commit | Tree |
|---|---|---|
| Preserved publication | `dc1074117b42ad06c268e2d6068a309411d9e3c2` | `b14ac0db4e1c3e46074475910f943b85d9e3a59d` |
| Landed prerequisite/base | `84c034f9eba8ba490109654d8b12384d646f1cd3` | `00bf6ac05fd9cf76936575279a93e70f70ca253b` |
| A: forward integration and fixes | `a882b8dcfe41283a22dc454a02723bf63e7bc5bd` | `7d9e95d9f6342ff2f75ce0911bea8686be51a05c` |
| Continuation publication | `0bb47d28c062b76f5154ae223689b129e31b5c7c` | `146bf4f8a027271e1a949b27106f77ff55ff91e5` |
| B: mobile backup exclusion | `ed9feb31adc8fc26ba2521c67be80870cad1cb70` | `706cbf2db015c3f5127bf471e3c5b88f65cb6d7c` |
| C: incoming-link diagnostics | `bfea7d122bfc1455fd4195fe103265dfbd2ec1c2` | `f7ed9b5a69d6504d33ed9b9250e12858d0072651` |

A is a merge with the preserved publication and landed prerequisite as parents;
no published history was rewritten. The logging/privacy and plan conflicts retain
main's versions; regression prose combines the actual file and foundation behavior.
The continuation publication after A changed only docs. B changes the mobile
sink, its tests and generated DI. C changes three diagnostic messages and their
routing/service tests. Publication edits after each source checkpoint are docs only.
Use the immutable base, not moving `origin/main`: other worktrees can advance that
shared ref while integration is underway.

```sh
git diff --numstat 84c034f9eba8ba490109654d8b12384d646f1cd3 a882b8dcfe41283a22dc454a02723bf63e7bc5bd
```

That review checkpoint has 951 changed lines across 17 paths: 444 production,
339 tests, 15 generated and 153 documentation. This is not the final publication
measurement; the ≤1,300 target includes every subsequent documentation path.

## Focused verification at A

`D` = `dart test --reporter json`; `F` = `flutter test --no-pub --reporter json`.
All commands exited 0. **65 cases across eight suites**, with no failures/skips;
these supersede the relevant historical runs, not additional cumulative cases.

| Cwd | Command files | Cases |
|---|---|---:|
| `client/module_desktop_core` | D `test/api/app_log_storage_test.dart test/api/bridge_process_log_storage_test.dart test/trackers/bridge_process_log_tracker_test.dart test/repositories/bridge_process_log_repository_test.dart test/cubits/bridge_control/bridge_control_cubit_test.dart test/di/injection_test.dart` | 6 + 6 + 6 + 1 + 35 + 1 = 55 |
| `client/app` | F `test/core/platform/io_app_log_sink_test.dart test/main_startup_notification_wiring_test.dart` | 6 + 4 = 10 |
| `client/module_desktop_core`, `client/app`, `client/desktop` | `dart analyze --fatal-infos`, separately in each cwd | Three clean results |

Coverage includes lazy binding/path lookup, console/context retention, ordered
admission/completion, rotation/restart/UTF-8, app/helper independence, permission
sequencing, directory dispatch and fake bootstrap isolation. The real file sink
is composed with the existing Quit owner over an owned temporary directory: its
final cleanup record is read **inside the fake termination callback**. The existing
pending-sink and failed-helper-stop cases preserve wait/refusal ordering.

Both warning-recovery regressions failed before the reset fix: expected two
warnings, observed one. Red index tree `31268186ef76d7101be07e202b2fbbb13f675c63`
already included the `flush()` interface adaptation needed to compile after the
merge, but not warning reset/admission serialization. Each six-case sink suite
had exactly one failing case; those runs are not retained passing evidence.

## Full generation

At A's input/index tree, sequentially ran `dart run build_runner build` without
filters in `client/module_desktop_core` and `client/app`; both exited 0. The runner
reported respectively **30 and 34 builder outputs**. All **ten tracked generated
files** across those packages remained byte-identical before/after; these are
different counts, not an assertion of 64 checked-in generated files. No outputs
were pruned or hand-edited. Core/auth have no net change against the prerequisite,
so their already-landed generated output was retained, not regenerated here.

Mobile generation repeated the existing cross-phase registration warnings for
`TemporaryDirectoryClient` and `AnalyticsRuntimeCapability`. No production
container resolution was attempted; owning analysis and fake bootstrap passed.

## Mobile backup-exclusion follow-up at B

Review identified ordinary OS backups as a real path out of application-support
storage. The sink now reuses `TemporaryDirectoryClient` and the existing mobile
`PathProviderTemporaryDirectoryProvider`; no new directory owner, native backup
configuration or migration was added for this unpublished path. Lazy phase-1 sink
resolution still follows core phase-3 registration. The installed `path_provider`
2.1.6 contract documents `getTemporaryDirectory` as app-private, not backed up and
OS-evictable: `NSCachesDirectory` on iOS, `Context.getCacheDir` on Android.

At B's exact tree, repeated the two mobile suites listed above: **7 + 4 = 11
passes**, no failures/skips. The production-constructor case uses the existing
cached temporary client; a new eviction case deletes only its owned fixture logs
and checks the next append recreates them. Mobile `dart analyze --fatal-infos`
passed. These replace A's ten mobile cases: **55 at A + 11 at B = 66 retained
cases/eight suites**, not 76. Desktop-core/desktop analyzer results remain at A.

Full mobile `dart run build_runner build` exited 0 and wrote **two builder
outputs**. The sole tracked mobile generated file, `injection.config.dart`, changed
as expected; no hand edits or pruning. The source index before generation was
`e4e1f5fc89a3f5c6a4c67f5d362a414e76ba5196`. Existing cross-phase warnings now also
name `IoAppLogSink`'s `TemporaryDirectoryClient` dependency, resolved after core DI.
No production container was activated. Commands/results are recorded in
`/tmp/rose-elephant-app-logs-backup-{generation,verification}.json` and adjacent logs.

## Incoming-link diagnostic follow-up at C

A verified HTTPS link can reach the mobile router's unmatched-route callback.
It logged the full URI at error level; its handled custom-scheme branch and the
existing `DeepLinkService` also logged it at debug level. All three now reuse
`diagnosticOrigin`, retaining scheme/host/port and operation context without URI
payloads. Routing, exception objects, levels and callback results are unchanged;
no new state, class, API or lifecycle behavior was introduced.

Three focused regressions failed before the fix at index tree
`4cacae6c2602c6985b3d2d348d4a1e38f253fcc8`, each exposing the synthetic private
payload. Tests use the actual production router's matcher/exception callback with
a fake context, and the real service over a fake stream; no production DI or
native link dispatch. The callback preserves the prior route configuration.

At C, `F test/core/routing/app_route_test.dart test/core/routing/deep_link_service_test.dart`
in `client/app` passed **40 + 6 = 46 cases**, no failures/skips. Mobile `dart analyze --fatal-infos` passed. An initial
46-case pass preceded an analyzer-requested if-body brace fix; its rerun is not
added again. Combined retained evidence is **55 at A + 11 at B + 46 at C = 112
cases across ten suites**. Mobile's clean analyzer is now at C; the others remain A.
No annotated shape or registration changed, so generation remains B's evidence.
Manifests: `/tmp/rose-elephant-app-logs-routing-{red,verification,final-verification}.json`.

## Architecture and provenance

The approved extraction plan (`e973a005-01ab-43fe-aaf8-eb43ebc854f6`) covers this
file-writer continuation and its completion/recovery ownership. Fresh implementation
review **approved** the exact base-to-A range above: all 17 paths, A1–A13/B-Client,
no findings. Run `eb161a75-12ff-4300-adb7-08d10f4f7c51`; complete bound report
`app-logs-continuation-implementation-architecture.md`, 1,112 bytes, SHA256
`5518790ded0aa29bcc578483b00a5f587b9bb67fdbcc7e76dea56c763fa35443`.
Copy: `/tmp/rose-elephant-app-logs-continuation-architecture.md`. The reviewer ran no
tests/native operations. This verdict excludes later parent documentation edits
and does not establish native/runtime qualification.

The second pass **approved** `0bb47d28c062b76f5154ae223689b129e31b5c7c..ed9feb31adc8fc26ba2521c67be80870cad1cb70`:
all three source/test/generated paths, 40 additions/26 deletions, A1–A13/B-Client,
no findings. Run `da7fcc4c-ad01-406b-a9e9-8ac22d5321a2`; complete bound report
`app-logs-backup-implementation-architecture.md`, 2,576 bytes, SHA256
`bd76e256cf726a7d73adac55e6029debde8a19eb75bc0a38dad91691f66f51da`.
No tests/native operations ran in this review. Parent docs are outside its verdict;
package documentation and static DI review are not a native backup/restore exercise.
Neither verdict includes C's subsequent localized diagnostic-message/test changes;
those change no architecture and did not trigger another architecture review.

Original combined-publication evidence, including the filtered-generation failure
and recovery, remains in Git at
[`dc1074117b42ad06c268e2d6068a309411d9e3c2`](https://github.com/sesori-ai/sesori_apps_monorepo/blob/dc1074117b42ad06c268e2d6068a309411d9e3c2/.plan/active/desktop-ux/steps/step-09a.md).
Its 91 cases and architecture verdict through `f37931dd4ab9b0c6dceb38a18a9907d5fed0c1ed`
are historical, not evidence that these continuation fixes were exercised then.

Local manifests: `/tmp/rose-elephant-app-logs-continuation-{red,generation,verification}.json`;
originally recorded commands and saved logs. Forward-merge conflict artifacts used
`/tmp/rose-elephant-app-logs-forward-merge-conflicts.{json,diff}`. Those pre-restart
`/tmp` files are unavailable after the PC restart; the Git evidence above and bound
architecture reports remain. Historical commands were not rerun to recreate them.

## Required but unexecuted qualification

No live app/helper/bridge, auth/preferences, native registration or protected data
was touched. `client/desktop/test/app_smoke_test.dart` remains isolated-CI-only.
Native orderly termination, actual OS folder opening, packaged primary/secondary
startup, iOS log collection and mobile backup exclusion remain required final
qualification, not host-test claims. No geometry changed; no visual fixture or
relaunch was manufactured.
Abrupt exit, a failed append or an expired completion deadline may lose records;
file-size caps do not bound queued memory, and logs are not uploaded automatically.
