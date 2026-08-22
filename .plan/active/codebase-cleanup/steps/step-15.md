# Step 15/45 — Share the tracked-work primitive

## Re-verification against `main`

Eleven files hand-rolled the same three lines — a `Set<Future<void>>`, a
`whenComplete` that removes the entry, and a `Future.wait` over a snapshot.
Eight of those files are migrated here, carrying **nine** tracked-work sites
(the orchestrator holds two). Three files are deliberately not migrated:

| Site | Action |
|---|---|
| 5 listeners, `debug_server`, `orchestrator` (×2), `session_creation_service` | migrated |
| `session_operation_dispatcher` (`_pluginSettlements` **keyed by plugin** plus `_inFlightSettlements`) | deferred to Step 21, which owns the keyed-lane work |
| `claude_session_service` (×2), `pi_session_service` | deferred to Step 28, which owns the plugin-package helpers |

`drain()` keeps `Future.wait`'s default non-eager behaviour, matching every
copy it replaces: it waits for all captured operations to settle before
completing, then reports the first error. Failing fast would let disposal close
a database or stream while a tracked write is still running, which is the exact
situation the hand-rolled copies existed to prevent.

The primitive lives in `sesori_bridge_foundation` rather than under the app,
because the deferred Claude and Pi copies make it a bridge-and-plugin audience
per `bridge/AGENTS.md`.

Two call sites needed more than a mechanical swap and are worth review
attention: the orchestrator's relay-completion tracking used a
`late final` self-reference to remove itself, and
`viewed_project_pr_refresh_listener` did the same; both collapse to a plain
`track(operation:)` because the primitive owns the removal.

## Verification

`bridge/app`: `dart analyze --fatal-infos` clean, `dart test` 2,684 passed.
`sesori_bridge_foundation`: analyze clean.

## Architecture implementation review

Run for this step (it adds a production class to a shared package and changes
shutdown-drain ownership at eight call sites). **Rejected on one finding, which
was a real defect, now fixed.**

`track` originally did `unawaited(operation.whenComplete(() => remove))`.
`whenComplete` returns a *new* future that also completes with the source's
error, and `unawaited` is a lint no-op that registers no error handler — so that
derived future was left dangling with an error. The bridge entrypoint runs in
the root zone with no `runZonedGuarded`, so an unhandled async error terminates
the process.

That was faithful to six of the eight migrated sites, which already dangled the
same way, but it **regressed `DebugServer`**: previously `operation` *was* the
`whenComplete`-derived future and `catchError` attached to it, so nothing
dangled. A debug-server request that fails during shutdown — reachable via the
`routeToDrain` path, whose `await` sits outside `_handleHTTP`'s `try` — would
have killed the bridge process instead of logging a warning. It also silently
voided the orchestrator's `.ignore()`, which only covers the future it is called
on, not the one `track` derives.

Fixed by ignoring the bookkeeping future inside `track`
(`operation.whenComplete(...).ignore()`), with the ownership boundary documented
on the method: `track` owns its bookkeeping future's errors, the caller still
owns the operation's own. `drain()` is unaffected — the set holds `operation`,
whose error still propagates through `Future.wait`.

The review separately confirmed the four things this step most needed checked:
`sesori_bridge_foundation` is the correct home under the audience rule (the
deferred Claude and Pi copies already depend on it); `drain()` is non-eager and
every `Future.wait` was replaced in place with no ordering change; both
`late final` self-reference rewrites are equivalent, including the orchestrator's
`routeLabel` bookkeeping; and tracking an already-ignored future is safe once
the fix above is in.
