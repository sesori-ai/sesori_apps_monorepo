# Step 15 — Run The L3 Matrix And Retire

Branch `transcript-history/retire`. Plan documents and one regression-doc
link only. No code, wire, store or database change, and no user-visible
change.

## Result

**Partial**, at L3 Release, retired with the user's explicit acceptance.
Steps 2–14b are merged on `origin/main` at `5dd2d6be85`; the last is 14b
(#1906). The user answered L2 on 2026-10-08: "Accept the unexecuted L3 cells
and retire now". The acceptance is recorded in
[PLAN](../PLAN.md#regression-coverage).

## Unexecuted Cells

None of these ran, and none is recorded as passed. Device tools were
unavailable.

| Cell | Boundary | Status |
|---|---|---|
| iOS: the full Prompts list, far tap, pin over unloaded turns, merged search, tool expand | Client end to end | Not run |
| macOS desktop: the same behaviors | Client end to end | Not run |
| Android: deflated responses and the far tap | Client smoke | Not run |
| New app with a v1.9.0 bridge | Compatibility | Not run |
| v1.9.0 app with the new bridge | Compatibility | Not run |
| W1 across the three app and bridge pairings | Relay integration | Not run |

The recordings the plan's Verification section asks of steps 9, 9b, 10, 11b
and 13 were not made either. The same acceptance covers them.

## Coverage That Exists

Each step's PR ran its directly relevant tests and the analyzer, and CI ran
the full matrix before it merged. The logic is covered by:

- **Cubit:** `session_detail_paging_test.dart` (load-through, the cursor and
  count pair, refresh races), `prompt_search_cubit_test.dart`.
- **Widget:** `session_prompts_view_test.dart`, `session_detail_body_test.dart`,
  `tool_part_widget_test.dart`, `desktop_session_detail_screen_test.dart`.
- **Bridge route:** `get_session_prompt_index_handler_test.dart`,
  `search_session_prompts_handler_test.dart`,
  `get_session_messages_through_handler_test.dart`,
  `chat_history_prompt_index_test.dart`, `chat_history_archive_test.dart`,
  `chat_history_pagination_test.dart`.
- **Parity:** `transcript_turns_test.dart` and
  `transcript_prompt_list_test.dart` for the shared prompt-turn rule (step 6).
- **Transport:** `relay_plaintext_codec_test.dart` and
  `relay_http_client_test.dart` for the deflate in both directions (steps 3,
  4 and 9b).

No Dart suite ran in this step; it changes no code.

## Bookkeeping

- `TRACKER.md` splits step 11 into its two merged rows, 11a (#1900) and 11b
  (#1903), and records the merged titles of 11a, 11b and 14 (#1905, merged as
  "Reconcile regression docs").
- The 404 wording: in `PLAN.md`, `TRACKER.md` and the regression docs only
  the prompt-index route reads a 404 as an older bridge. The search and
  load-through routes treat any error, a 404 included, as an ordinary
  failure. `steps/step-08.md` and `steps/step-09.md` still describe the
  load-through `Unsupported` result those steps shipped; they are evidence of
  their own PRs, and 14b (#1906) removed that path.
- The plan moves to `.plan/completed/transcript-history/`, and
  `docs/regression/transcript-turn-navigation.md` links the new path.
- The four affected regression docs (`bridge-connectivity.md`,
  `tools-and-file-changes.md`, `transcript-turn-navigation.md`,
  `session-history-and-recovery.md`) match `origin/main` after 14b and hold
  no tombstones: no "Update the bridge" notice and no load-through or search
  `Unsupported`.
