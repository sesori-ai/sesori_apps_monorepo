# Step 9.a — Rotating application logs

## Delivered scope

Pure core record/sink/console seam; lazy desktop/mobile file sinks; independent
5 MiB active-plus-predecessor files; prepared logs-directory launch; selective
source-free JSON parsing diagnostics. Existing helper draining, typed error data,
wire/auth outcomes and release info+ default remain intact. No database change.
The package-internal rotation extraction replaces duplication, not the bridge facade.
Latest sidebar/tooltip feedback is planned as 9.b/9.c, not implemented here.

## Immutable checkpoints

Repository cwd: `/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/rose-elephant`.
SDK prefix: `/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/`.
Package cwd below is relative to the repository; commands use that SDK's executables.

| Checkpoint | Commit | Tree / purpose |
|---|---|---|
| Base | `69d6803daba48c9bf3a8a9e48e00c2d862f7aca0` | Post-step-8 main |
| A | `21b25292bf598875452ca360cc38d58f0eac8a6a` | `fdebc2497fac9ee2bb3875c1a11269a83f8cb844`; implementation, initially missing generated auth dependencies |
| B | `12bc64bba57df24c0dc5b2a13b42b46f7806ad8d` | `8ff8afe48a01dcaed2081c66c2c3eae1ffd21a63`; full auth generation restored three files byte-for-byte against base |
| C | `f37931dd4ab9b0c6dceb38a18a9907d5fed0c1ed` | `4227f4a6a0bf05f8707a7c8d3d8633a5064d5b4c`; explicit string conversion, primary constructor and awaited forwarding |

C is the frozen implementation-review endpoint. Later publication edits are
planning/regression/evidence only. Whole-publication size belongs in the PR body;
`git diff --numstat <base> <accepted-head>` includes every authored/generated path.
C's production/test/generated diff is 1,059 lines (805 added + 254 deleted):
629 production, 387 tests, 43 generated. The revised 1,450-line target also includes
proof records and the newly requested sidebar plan; the original 700 estimate was too low.

## Commands and retained evidence

`D` below means `dart test --reporter json`; `F` means
`flutter test --no-pub --reporter json`. Append the listed files verbatim.
All B/C test commands exited 0. Retain **91 distinct cases across 11 suites**,
not the sum of reruns: C's 27 supersede those suites' A/B passes; B contributes 64.
B's retained tests and desktop source did not change in C, but six dependency
implementation files received mechanical edits. These are revision-scoped results,
not a claim that all 91 were rerun on C; affected writer/logger/error suites were.

| Revision | Cwd | Command files | Cases |
|---|---|---|---|
| B | `client/module_auth` | D `test/client/api_error_test.dart` | 2, superseded by C |
| B | `client/module_core` | D `test/api/client/relay_http_client_test.dart` | 19 |
| B | `client/module_desktop_core` | D `test/api/app_log_storage_test.dart test/api/bridge_process_log_storage_test.dart test/trackers/bridge_process_log_tracker_test.dart test/repositories/bridge_process_log_repository_test.dart test/cubits/bridge_control/bridge_control_cubit_test.dart test/di/injection_test.dart` | 52; retain tracker 6, repository 1, controls 33, DI 1 |
| B | `client/app` | F `test/main_startup_notification_wiring_test.dart` | 4 |
| C | `client/module_auth` | D `test/client/api_error_test.dart` | 2 |
| C | `client/module_core` | D `test/logging/logging_test.dart` | 9 |
| C | `client/module_desktop_core` | D `test/api/app_log_storage_test.dart test/api/bridge_process_log_storage_test.dart` | 5 + 6 |
| C | `client/app` | F `test/core/platform/io_app_log_sink_test.dart` | 5 |

Coverage includes level gating/UTC/context/chunking/throwing-sink fallback,
console fan-out, lazy directory lookup, ordered writes/restart/rotation/UTF-8,
independent app/helper files, permission sequencing/failure recovery, directory
URI dispatch, bootstrap isolation and omitted parsing bodies with typed data retained.
Tests use fake capabilities and owned temporary paths. No production DI smoke ran.

Analysis command: `dart analyze --fatal-infos`. At B, `client/desktop` passed;
`client/{module_auth,module_core,module_desktop_core,app}` reported respectively
1/2/4/2 lint infos. C fixed those and all four owning analyzers passed. Thus five
clean package results are retained; the desktop result is explicitly from B.

Initial A commands: auth as B; core D with both `test/logging/logging_test.dart`
and `test/api/client/relay_http_client_test.dart`; desktop-core as B; mobile F with
both C's sink suite and B's startup suite. All four commands exited 1 because the
filtered generator had pruned `api_response.freezed.dart`, `injection.config.dart`
and `auth_state.freezed.dart` in auth. Logger 9 and mobile sink 5 cases passed,
but are superseded by C. Load failures are not passing cases. The command wrapper
reported a context-mode disk-I/O error after saving the logs; saved results were
inspected before recovery, not blindly rerun.

## Generation

All commands exited 0; outputs were generated, never hand-edited.

| Cwd | Command after `dart run build_runner build` | Captured index tree before → after |
|---|---|---|
| `client/module_auth` | `--build-filter=lib/src/client/api_error.*.dart` | `8a14f0a118f7d93d9265e0037a18d24867d12c05` → `cdbb26ae028aa3581bea6dd0a548c8e8fcb0f5c7` |
| `client/module_desktop_core` | `--build-filter=lib/src/di/injection.config.dart` | `cdbb26ae028aa3581bea6dd0a548c8e8fcb0f5c7` → `977b26f1b923c1b2dd3b6f305eb13631c4d59a0c` |
| `client/app` | `--build-filter=lib/core/di/injection.config.dart` | `977b26f1b923c1b2dd3b6f305eb13631c4d59a0c` → A's tree |
| `client/module_auth` | No filter, at A | Restored the three pruned files; committed as B, zero net diff against base for them |
| `client/module_auth` | No filter, after C's source edits | C's tree → same tree; generated bytes unchanged |

External/cross-phase registration warnings named HTTP Client/device descriptor/
SecureStorage in auth and TemporaryDirectoryClient/AnalyticsRuntimeCapability in
mobile. Generation and subsequent analysis passed; no production resolution was attempted.

## Architecture and limits

The initial D10 plan review rejected underspecified rotation ownership, DI timing
and diagnostic representation. Findings were applied directly; revised-plan approval
is not claimed. Fresh implementation review **approved** the exact Base..C range,
all 25 changed files, A1–A13/B-Client, with no findings. Bridge/shared were out of scope.
Run `65a7b10c-a452-4ecd-9ec8-90e4c9270361`; complete bound report
`app-logs-implementation-architecture.md`, 4,494 bytes, SHA-256
`d23e13f94f750aa1804fa42c0ec46e68a522487956b28efdb83b4e2137e35468`.
No reviewer tests or native work were run. Future sidebar work was excluded.

Local manifests/logs use `/tmp/rose-elephant-app-logs-`: `generation.json`,
`auth-generation-recovery.json`, `final-generation.json`, `tests.json`,
`recovered-verification.json`, `final-verification.json`; each names its saved logs.
The report copy is `/tmp/rose-elephant-app-logs-implementation-architecture.md`.

No live app/helper/bridge, authentication, native registration or protected data
was touched. Actual OS folder opening, packaged primary/secondary startup and iOS
log collection remain required final qualification, not inferred from host tests.
No rendering changed, so no new visual fixture was manufactured. Persistence is
best effort: abrupt exit can lose queued records; logs are not uploaded automatically.
