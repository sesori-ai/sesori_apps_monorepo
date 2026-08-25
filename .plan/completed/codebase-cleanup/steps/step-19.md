# Step 19/45 - Deduplicate request-handler error mapping and guards

## Re-verification against merged Step 18

`GetRequestHandler` and `BodyRequestHandler` still repeated the same exception
mapping, and the router had a third generic-failure fallback with a different
status. `RequestHandlerBase` now owns one guarded route boundary for ordinary
responses and special routed outcomes such as restart handoff. The router keeps
unmatched and invalid-target handling plus a last-resort catch for failures
outside that boundary.

Generic handler and router failures now consistently return 500. Explicit
plugin-operation statuses are preserved, and a statusless
`PluginOperationException` remains a 502 upstream failure. Client transport and
repositories were checked for a 502-specific branch; they map it like every
other non-success status, so the planned 500 unification does not alter a
client decision path.

Handler contracts now carry one `RequestTargetParams` record containing only
path and query parameters. GET handlers receive no unused target arguments,
ordinary body handlers receive only their typed body, and specialized handlers
retain target values only for plugin-authentication paths, plugin-lifecycle
commands, and the session-options refresh query. The unused fragment value and
unused per-handler query/path declarations are gone.

Repeated non-empty identifier checks now use `requireNonEmpty`, and structured
400/409 responses use one `buildJsonErrorResponse`. Tests invoke handlers
through one `routeForTest` seam so exception mapping is exercised at the same
boundary as production. Duplicated per-handler tests for shared parsing and
error behavior were removed while route-specific behavior remains covered.

There is no persisted-data or database-schema change. The only wire-visible
change is the declared generic-failure status unification from 502 to 500;
unmatched routes remain 404 and upstream plugin failures retain their existing
status behavior. `docs/regression/bridge-connectivity.md` records this boundary.

## Verification

- `dart analyze --fatal-infos` in `bridge/app`: clean.
- `dart test -j1 test/bridge/routing test/routing`: 461 tests passed.
- `git diff --check`: clean.
- `dart format` formatted or confirmed supported touched files. The pinned
  formatter crashes while building existing enhanced enum bodies in
  `bridge_restart_dispatcher.dart` and `post_session_options_handler_test.dart`;
  analyzer parsing is clean and their edited sections retain existing
  formatting.
- Searches confirmed no client production branch on status 502 and no remaining
  routing-handler fragment argument or unused target-parameter declaration.

The merged Step 18 parent used for scope measurement is
`aa92bc5f8754c5662d07f620d4d45a2d47918b5a`. The production routing diff is
`+188 / -459`; the routing-test diff is `+137 / -1132`. This evidence file and
the regression-document update are excluded from those totals.

## Architecture implementation review

Step 19 is not architecture-review scoped by the plan. An independent production
review found that the restart handler bypassed the shared guard and that one
project-id guard remained duplicated; both findings were fixed before final
verification.
