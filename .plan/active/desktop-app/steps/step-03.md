# Step 3 — Bridge process service

Date: 2026-08-28.

## Delivered

- Added Layer-3 `BridgeProcessService` over the process repository, log tracker,
  control server, auth session, and executable-path seam.
- Added authenticated spawn gating and typed stopped, login-required, starting,
  running, and stopping states.
- Made spawn transactional: every attempt starts a fresh loopback server,
  resolves the helper, passes only `--control-url` in argv, attaches both raw
  pipes, writes the per-spawn secret through stdin, and observes repository exit
  events. Bind, spawn, attach, stdin, and early-exit failures tear down acquired
  resources, preserve the original failure, and allow retry after cleanup.
- Kept clean stop at the repository's atomic expected-stop boundary, including
  retryable stop failures and server cleanup after expected or unexpected exit.
- Added the shell `BridgeExecutablePathResolver`: development uses
  `SESORI_DESKTOP_BRIDGE_PATH` when present and otherwise resolves the
  repository host bundle produced by `bridge/app/make build-host`. Packaged
  layout remains distribution-plan scope.
- Started the single `ControlMessageDispatcher` from desktop `main()` after all
  four DI phases and before any process-service consumer can spawn a helper.
- Registered and exported the new foundation/service boundaries and documented
  the supported spawn/handshake/failure behavior.

No user-visible or database behavior changes in this step. Exit-code policy and
manual desired-state orchestration remain step 4.

## Architecture implementation review

Approved 2026-08-28 with B-Client applied and no findings. The reviewer
confirmed downward dependencies, repository ownership of all process actions,
shell ownership of executable-path policy, reverse-order transactional cleanup,
serialized lifecycle state, and dispatcher-before-spawn bootstrap ordering.

## Verification

- `client/module_desktop_core`: `dart analyze --fatal-infos` — clean.
- `client/module_desktop_core`: `dart test` — 87 tests passed, including 10
  focused service tests and a real authenticated WebSocket/token handshake
  through the production control server + dispatcher.
- `client/desktop`: `dart analyze --fatal-infos` — clean.
- `client/desktop`: `flutter test` — 22 tests passed, including executable-path
  resolution and four-phase DI resolution.
- Regenerated desktop-core and desktop Injectable outputs with `build_runner`.
- Manual integration: the production process API/service launched the built
  host bridge through a temporary dev wrapper, completed the real
  helper→GUI `token_request` / GUI→helper `token_response` handshake, and shut
  down without leaving the helper running.
