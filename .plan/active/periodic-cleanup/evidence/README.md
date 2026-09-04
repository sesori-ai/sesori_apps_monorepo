# Executed diagnostic evidence

Date: 2026-09-04. Production baseline: `480d82f090`. Host: macOS; pinned Dart
3.13.2 / Flutter 3.47.2-stable. These are targeted test results, not a full-suite
or live-product result. Diagnostic source files were restored after execution.
The patches contain synthetic fixture values only.

## Reproduce

From repository root, apply `refresh-reproduction.patch` with `git apply`.
In `client/module_core`, run:

```sh
dart test test/cubits/session_detail/session_detail_event_buffer_test.dart --name 'AUDIT:|refresh supersedes older deferred parts'
```

The tests use existing fake connection/load services and held reload completion.
The existing deferred-parts test passed. The diagnostic for an already-loaded
message failed: the expected `(part-during-refresh, live)` was missing after
refresh. Separately executing `--name 'AUDIT: delta'` failed with expected
`before-after`, actual `after`. It awaits the initial streaming flush before
refresh; an earlier draft timed out because zero-duration polling did not await
that timer and was corrected before recording this result.

The finalized patch includes both diagnostics. They were run in separate
focused invocations during investigation; do not interpret the combined
reproduction command as a claimed single recorded all-tests run.

Apply `cache-reproduction.patch` from repository root. In `bridge/app`, run:

```sh
dart test test/bridge/repositories/session_options_repository_test.dart --name 'AUDIT:'
```

This uses real in-memory SQLite, SessionOptionsRepository, and
SessionOptionsService with a fake runtime. It changes one persisted completeness
value to `unknown`, then performs explicit refresh. The plugin capture count
assertion passed (one call); outcome failed with expected
`SessionOptionsAvailable`, actual `SessionOptionsRefreshFailedUnavailable`.
The service logged undecodable-cache recovery three times, then two commit
conflicts. This is injected corruption, not proof of production incidence.

Reverse each patch with `git apply -R` after use. Do not merge these failing
probes into an implementation test suite unchanged: promote the relevant
behavior cases as fixes land. The cache implementation test belongs on upgrading
an old malformed row, since the proposed new schema removes that column.

## What was and was not established

- Proven: stale refresh drops a live part on an already-loaded message; clearing
  the accumulator loses the prefix on the next delta; the composed cache path
  cannot repair a row with malformed persisted completeness.
- Source evidence: cached completeness has no policy reader; insertion helper
  and three pending-event APIs have only test callers; child index has no live
  reader; typed-message/status round trips and unneeded row projections.
- Release evidence: local public tag v1.8.2 contains the options table and the
  same no-op client consumers for the 15 event variants. Release metadata was
  checked: v1.8.2 is production, v1.8.3-internal.802 is prerelease. Older supported
  public event-consumer baselines remain an implementation compatibility check.
- Not established: frequency in user sessions, measurable UI latency benefit,
  complete snapshot consistency, arbitrary database-corruption recovery, or
  full plugin/platform regression pass.
