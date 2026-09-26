# Feedback Flow

## Capability

The mobile rating sheet that asks whether the user enjoys Sesori. A positive
answer can hand the user to the platform's store review page. A negative answer
collects private feedback, which is sent to the Sesori auth server. The sheet
opens from **Rate Sesori**, the second row of the Account section in mobile
Settings. Desktop Settings does not show the row. On phones, the sheet also
opens by itself after enough good interactions. Desktop never opens it by
itself.

## Required Behavior

- The sheet opens as a bottom sheet with a grabber. It asks "Are you enjoying
  Sesori?" and offers **Yes, love it!** and **Could be better**. A close button
  labelled for assistive technology dismisses it without an answer. It sits on
  a dark disc so it stays legible over the celebration artwork.
- An answer is final. After the first tap, both answers are locked, so repeated
  or crossed taps cannot change it.
- **Yes, love it!** plays the 1.5 s celebration. The hero stays in place while
  the answers cross-fade into "Thanks! Leave a review?". The body does not name
  a store. The actions are **Leave a review** (primary) and **Not now**
  (secondary).
- **Leave a review** closes the sheet. The store opens only after the sheet's
  exit animation has finished:
  - iOS opens the App Store write-review page.
  - Android opens the Play Store app. If that app is missing or fails to open,
    Android falls back to the web listing.
- A failed store launch is logged. The user stays in Sesori and sees no error.
- The automatic sheet is driven by a per-device counter that survives
  restarts:
  - Each of these adds a point: a message sent in session detail, a new
    session started with a message, a question answered or rejected, and a
    permission request answered. Only an accepted request counts.
  - The count restarts from zero after an AI error reported by any session
    (a message that ended in an error, a retrying session, or a session
    error), after a failed send or reply, and after an app crash. A crash is
    detected by the global error handlers or, at the next launch, from
    Crashlytics' previous-launch report. Crash detection needs Firebase.
  - At 10 points the sheet opens right away over whatever screen is showing.
    Opening it restarts the count and records the time.
  - After an answer other than **Yes, love it!**, including a dismissal, the
    sheet waits at least 14 days before it can open by itself again, however
    many points are earned.
  - **Yes, love it!**, from either entry, stops the automatic sheet for good.
    **Rate Sesori** in Settings always works.
  - Firebase Remote Config can change the 10 points
    (`feedback_prompt_interaction_threshold`) and the 14 days
    (`feedback_prompt_cooldown_days`). It is fetched once per launch. A missing
    value or one below 1 uses the default, and a failed fetch uses the last
    fetched values. Builds without Firebase use the defaults.
  - An unreadable stored counter is discarded with a warning and counting
    starts again from zero.
- The automatic sheet asks for the review differently (Settings is
  unchanged):
  - iOS skips the confirmation. The sheet closes on the celebration's last
    frame, and only after its exit animation has finished does Sesori ask
    StoreKit for its in-app review prompt through the `com.sesori.app/app_review`
    channel. StoreKit may skip the prompt silently and never reports whether it
    appeared. A failed request is logged.
  - Android keeps the confirmation, and **Leave a review** opens the Play Store
    listing. Android never uses Play In-App Review, because Play policy forbids
    it after Sesori's own question.
- **Not now**, the close button, and a swipe down after **Yes** all count as a
  positive answer without a review, and no store opens.
- **Could be better** replaces the rating step with "What should we improve?".
  It shows four issue pills (Hard to navigate, Connection drops, Notifications
  don’t arrive, App feels slow) and a text composer. A quiet line below the
  composer says "Sent privately to the Sesori team."
- The composer stops at 4,000 characters. A counter appears when 200 or fewer
  remain.
- A microphone button sits beside **Send**. Holding it records through the
  shared voice transcription stack, with no project attached. While recording,
  the counter's slot shows a live waveform and a cancel target: dragging onto
  it and releasing, or a hold shorter than 200 ms, discards the recording.
  Releasing elsewhere transcribes, showing "Transcribing..." with a cancel
  button. The transcript is appended to the draft after a space, cut at the
  4,000-character limit, and never sent automatically. **Send** is disabled
  while recording or transcribing.
- Voice failures keep the draft. A denied microphone shows the permission
  notice; a failed start, a failed or unauthenticated transcription, and a
  network failure show their error, and a network failure discards the saved
  recording so the next hold starts fresh. Closing the sheet discards any
  recording or transcription still running.
- **Send** is always available, including with nothing filled in. It posts the
  ticked issues to `POST /feedback` on the auth server as their wire values,
  with the source (`settings` or `automatic`), platform (`ios` or `android`), and app version.
  The text is trimmed first, and a blank message is left out of the request.
- The composer and pills are locked while sending. The sheet cannot be
  dismissed until the send finishes: **Cancel** is disabled, and the back
  gesture, a barrier tap, and a swipe down do nothing. On success the sheet
  closes, and "Feedback sent. Thank you!" appears once it has gone.
- A failed send keeps the sheet, the ticked issues, and the draft. It shows
  "Couldn’t send feedback. Your draft is still here." with **Retry**. The
  failure is logged without the message text.
- Before sending or after a failure, **Cancel**, the close button, or a swipe
  down leaves without sending.
- Reopening the sheet always starts from the first question.
- Android Remove animations and iOS Reduce Motion remove the sheet travel and
  skip the celebration. Turning either on during the celebration finishes it
  promptly, and turning either on while writing or recording keeps the draft
  and the recording.
- The sheet fits a 320 x 568 screen at 1.5x text without overflow.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated: the sheet widget suite proves the celebration timing, the confirmation copy, the locked answers, that the outcome resolves only after the sheet has closed, the outcomes for dismiss, Not now, close during the celebration and Cancel, private Send with its toast after closing, the recipient line, that Cancel, back, a barrier tap, and a swipe down cannot dismiss the sheet mid-send, a failed send that keeps the draft and retries, the 4,000-character limit and counter, reduced motion (at open, turned on mid-flight, while writing, and while recording), and the narrow large-text layout. Its voice group proves hold-to-talk with the waveform, the disabled Send, the draft staying in place, and the transcript appended without sending; that the cancel target and a quick tap discard the recording; the permission and network-failure notices keeping the draft; the transcript cut at the character limit; and that closing the sheet mid-recording discards it. The cubit, repository, API, store-client, and Settings suites prove the outcome mapping, send locking and failure, message trimming and omission, the request's wire values, the store URLs with the Android fallback, the automatic source's StoreKit request on iOS (no confirmation, the sheet closes itself first) and store listing on Android, that Settings opens the store only after the sheet has closed, and that Settings sends with the `settings` source. The counter suites prove the stored state's round trip and discard of unreadable values, the Remote Config defaults and fallbacks, that points below the threshold or inside the cooldown do not open the sheet, that opening it restarts the count and records the time, that each AI-error event and a failure restart the count, that **Yes** stops it for good, that nothing is counted before the counter starts (desktop), and that the session-detail and new-session cubits count accepted sends and replies and restart on failures. A widget test proves the app-root listener opens the sheet over the current screen. |
| L2 Routine | Client end to end on the release-target client platform against the dev auth server: Settings shows **Rate Sesori**; **Yes**, then **Leave a review**, opens the store review page after the sheet has closed; **Not now** returns to Settings without leaving the app; **Could be better** sends ticked issues and fixture text (typed, then extended by a held voice recording), closes the sheet, and shows the toast, and the stored document matches (message omitted when blank). |
| L3 Release | Client end to end on the alternate client platform: the same journey opens that platform's store. On a phone with Remote Config setting the threshold to 2, two sent messages open the automatic sheet over the session; on iOS **Yes** closes it and asks StoreKit; on Android **Yes** shows the confirmation. After **Not now** the sheet does not reopen by itself on the next two sends. |
| L4 Extended | Client end to end with Reduce Motion or Remove animations enabled and at accessibility text sizes. On Android, a device without the Play Store app falls back to the web listing. Sending offline or past the server's rate limit shows the inline error, keeps the draft, and Retry succeeds once the server accepts it. |
| L5 Full | No additional coverage. |

## Failure Signals

- The store opens while the sheet is still visible or animating out, or opens
  after **Not now**, the close button, or a swipe down.
- A second tap changes a recorded answer, or reopening resumes a finished step.
- Closing the sheet as the celebration ends switches it to the review step
  while it animates out.
- Android shows nothing when the Play Store app is unavailable.
- An automatic sheet on iOS shows the review confirmation, switches content
  while it closes, or requests the StoreKit prompt before it has gone.
- Android requests Play In-App Review.
- A send failure clears the draft or issues, closes the sheet, or shows the
  success toast.
- The sheet closes while a send is in flight, so a successful send shows no
  toast and a retry could duplicate it.
- A blank or whitespace-only message is sent as text, so the server rejects it
  with a 400.
- The message text appears in a log.
- A transcript replaces the draft, sends itself, or lands after the sheet has
  closed; a voice failure clears the draft; or the draft jumps when recording
  starts.
- Scrolling or swiping on the microphone scrolls or dismisses the sheet instead
  of recording.
- With reduced motion enabled, the celebration or sheet travel still animates.
- The sheet clips or overflows on a small screen or at large text sizes.
- **Rate Sesori** appears in desktop Settings, or outside the mobile Account
  section.
- The automatic sheet opens on desktop, before the threshold, inside the
  cooldown, after **Yes**, or twice for one threshold crossing.
- A failed send, an AI error, or a crash does not restart the count, or a
  rejected request still earns a point.
- The count or cooldown is lost on restart.

## Sources

- `client/module_app_ui/lib/src/features/feedback/`
- `client/module_core/lib/src/cubits/feedback_sheet/`
- `client/module_core/lib/src/cubits/feedback_prompt/`
- `client/module_core/lib/src/services/feedback_prompt_service.dart`
- `client/module_core/lib/src/repositories/feedback_prompt_repository.dart`
- `client/module_core/lib/src/api/storage/feedback_prompt_storage.dart`
- `client/module_core/lib/src/api/feedback_prompt_config_api.dart`
- `client/app/lib/core/platform/firebase_feedback_prompt_config_source.dart`
- `client/app/lib/main.dart`
- `client/module_core/lib/src/repositories/feedback_repository.dart`
- `client/module_core/lib/src/api/feedback_api.dart`
- `client/app/lib/core/platform/flutter_app_review_client.dart`
- `client/app/ios/Runner/AppDelegate.swift`
- `client/app/lib/features/settings/settings_screen.dart`
- `client/app/lib/core/widgets/feedback_voice_input_scope.dart`
- `client/module_app_ui/test/features/feedback/feedback_sheet_test.dart`
- `client/module_core/test/cubits/feedback_sheet/feedback_sheet_cubit_test.dart`
- `client/module_core/test/cubits/feedback_prompt/feedback_prompt_cubit_test.dart`
- `client/module_core/test/services/feedback_prompt_service_test.dart`
- `client/module_core/test/repositories/feedback_prompt_repository_test.dart`
- `client/module_core/test/api/feedback_prompt_storage_test.dart`
- `client/module_app_ui/test/features/feedback/feedback_prompt_listener_test.dart`
- `client/module_core/test/repositories/feedback_repository_test.dart`
- `client/module_core/test/api/feedback_api_test.dart`
- `client/app/test/core/platform/flutter_app_review_client_test.dart`
- `client/app/test/features/settings/settings_screen_test.dart`
- `.plan/active/feedback-flow/PLAN.md`
