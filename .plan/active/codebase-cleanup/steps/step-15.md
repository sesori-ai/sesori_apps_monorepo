# Step 15/45 — Share the tracked-work primitive

## Re-verification against `main`

Eleven files hand-rolled the same three lines — a `Set<Future<void>>`, a
`whenComplete` that removes the entry, and a `Future.wait` over a snapshot.
Eight are migrated here; three are deliberately not:

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

Architecture implementation review: **required** for this step — it adds a
production class to a shared package and changes shutdown-drain ownership at
eight call sites.
