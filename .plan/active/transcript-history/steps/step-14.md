# Step 14 — Reconcile The Regression Docs

Branch `transcript-history/regression-docs`. Docs only. No code, wire, store or
database change, and no user-visible change.

## Scope Delivered

Every claim in the regression docs that steps 2–13 touched was checked against
`origin/main` at `ef8c52f4a1` (after 11b, #1903). The prompt index, prompts
list, far tap, unloaded pin, load-through, full and summary tool parts,
`/session/tool-output` and the on-expand fetch already matched the code. The
changes:

- **`bridge-connectivity.md`:** step 9b (#1895) changed no doc. The deflate
  bullet now says the app decrypts every response on the calling isolate and
  inflates and parses a large one (2 KB deflated, 256 KB plain, per
  `relayPlaintextDecodesInBackground`) on a short-lived isolate. A failure
  signal covers a large response decoding on the UI isolate.
- **`transcript-turn-navigation.md`:**
  - Known Limitations no longer claims the relay envelope of a whole-session
    response decodes on the UI isolate; 9b moved it.
  - The "Update the bridge" limitation now names the only bridge that shows
    the notice: one that sends the index without the load-through route.
    `LoadThroughUnsupported` still exists in the code; no public release has
    the index, so no released bridge reaches it.
  - L2 covers the search response decoding off the calling isolate, as the
    load-through's does (`SessionApi.searchPrompts` uses
    `postDecodedInBackground`).
  - L3 adds the bridge's search on the long session; Failure Signals add the
    bridge search's and limit the match-count signal to the loaded-only case.
- **`session-history-and-recovery.md`:** the search route no longer says a 404
  means an older bridge. 11b removed search's `Unsupported`: the app asks only
  a bridge that sent the index, so a v1.9.0 bridge is never asked, and any
  error, a 404 included, is a Failure with Retry
  (`SessionRepository.searchPrompts`). The failure signal matches.
- **`tools-and-file-changes.md`:** L3 adds the reloaded summary tool's expand
  (store, load-through and archive) and both v1.9.0 pairings, as the plan's
  regression coverage requires.
- **`TRACKER.md`:** the 404 guardrail now holds only for the index route.

`HARNESS_CAPABILITIES.md` already matched; it needs no change.

## Evidence

- Code read on `origin/main`: `session_repository.dart` (`_isMissingRoute`
  only for the index and load-through), `session_api.dart`,
  `relay_client.dart`, `summarized_tool_output_mapper.dart`,
  `get_session_tool_output_handler.dart`, `session_detail_message_list.dart`,
  `session_prompts_view.dart` and the English ARB strings the docs quote.
- `git grep userMessagesBefore v1.9.0` finds nothing, so "an older bridge
  sends no user message count" stays.
- Docs only: no Dart suites, per the plan's Verification section.
