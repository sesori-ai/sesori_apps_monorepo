# Step 30 — Failed sends

## What changed

- `PromptSendQueue` holds a failed head in its own `failed` slot
  (`holdFailedSend`). `beginSend` returns nothing while it is set, so later
  messages wait behind it. `retryFailedSend` puts the same submission back at
  the head, so the resend carries the same `promptId` and the bridge's dedup
  can never run it twice. `removeFailedSend` drops it. Bridge settlement
  (`removeByPromptId`) and `clear` release it too.
- `SessionDetailCubit` marks a send failed only when it fails on the
  connection generation it started on: a non-stale error response or a thrown
  failure. A failure after the connection dropped still goes through
  `failSend` and is re-sent after reconnect. The stale-options recovery is
  unchanged. The warning log stays. `retryFailedSend` and `removeFailedSend`
  are the user actions.
- `SessionDetailLoaded.failedSubmission` carries the failed head. The message
  list renders it as its own row with "Couldn’t send", Retry and Remove; a
  read-only surface shows the label without actions.
- `QueuedMessageBubble` is now stateful and owns the delay timer (D17). A send
  still in flight after two seconds reads "Sending to <harness>…"; before that,
  or while the harness name is unknown, it reads "Sending". The name comes from
  the new `SessionInteractionState.harnessDisplayName`, which replaces the
  private `_harnessName` helper in `session_detail_body.dart`. Bridge-dispatched
  prompts use the same sending presentation.
- The message list's two transient booleans became one private
  `_TransientStage` enum, so a row is exactly one of awaiting bridge, sending,
  failed or pending.
- Both apps mount this list, so the change covers phone and desktop.

## Deviations

- The plan says only the two failure kinds "within the same connection
  generation" mark a send failed. The check applies to both kinds. A failure
  that lands before the disconnect event arrives still shows "Couldn’t send";
  Retry recovers it.
- The delay is two seconds. The plan said "a short delay" without a number.

## Verification

- module_core `test/cubits/session_detail` passes (242 tests). New queue tests
  cover hold, same-id Retry and removal/settlement. A new cubit test fails a
  send, checks a later message waits, retries, and checks the same prompt id
  and the drain behind it. The existing reconnect ("a send failed after
  reconnect is retried on the replacement connection") and stale-options
  tests pass unchanged. Four existing tests that used a failed send to keep a
  message staged now use the failed slot or Retry.
- module_app_ui `test/features/session_detail` and `test/widgets` pass (320
  tests), including new widget tests for the failed row with Retry and the
  delayed "Sending to OpenCode…".
- The app `test/features/session_detail` (161) and desktop
  `desktop_session_detail_screen_test` (9) pass.
- `dart analyze --fatal-infos` is clean in module_core and module_app_ui, and
  in the touched app and desktop paths.
- No architecture review: no production class was added or moved, and no DI,
  wire or persisted contract changed. The new state field and queue slot are
  the ones the plan's state table already names.
- `docs/regression/session-turns.md` records the behaviour, a failure signal
  and the L2 coverage.
