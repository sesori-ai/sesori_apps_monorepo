# Feedback Flow

## Capability

The mobile rating sheet that asks whether the user enjoys Sesori. A positive
answer can hand the user to the platform's store review page or, for the
automatic sheet on iOS, to the in-app StoreKit review prompt. A negative answer
collects private feedback, which is sent to the Sesori auth server. The sheet
opens from **Rate Sesori**, the second row of the Account section in mobile
Settings. On phones the automatic rating prompt also fires by itself after
enough cleanly finished agent turns: on iOS it opens the sheet, and on Android
it requests Google Play's In-App Review card directly, with no sheet. Desktop
neither shows the row nor fires the automatic prompt.

## Required Behavior

- **Rate Sesori** has a 40 px heart avatar tile, the subtitle "Tell us how
  Sesori feels", and a chevron. It shares the account row's avatar geometry,
  title position, height, and title-aligned divider.
- The sheet opens as a bottom sheet with a grabber. It asks "Are you enjoying
  Sesori?" and offers **Yes, love it!** and **Could be better**. A close button
  labelled for assistive technology dismisses it without an answer. It sits on
  a dark disc so it stays legible over the celebration artwork.
- An answer is final. After the first tap, both answers are locked, so repeated
  or crossed taps cannot change it.
- **Yes, love it!** plays the 1.5 s celebration. At the tap, the answers lift
  away and "Thanks! Leave a review?" rises into place while the hero keeps celebrating above it. The body does
  not name a store. The actions are **Leave a review** (primary) and
  **Not now** (secondary).
- **Leave a review** closes the sheet. The store opens only after the sheet's
  exit animation has finished:
  - iOS opens the App Store write-review page.
  - Android opens the Play Store app. If that app is missing or fails to open,
    Android falls back to the web listing.
- A failed store launch is logged. The user stays in Sesori and sees no error.
- The automatic sheet asks for the review differently (Settings is
  unchanged). It skips the confirmation. 800 ms into the celebration, once the
  button has settled and the hearts have risen, the sheet closes by itself
  without switching content. The review is committed only at that moment, and
  only after the exit animation has finished does Sesori ask StoreKit for its
  in-app prompt through the `com.sesori.app/app_review` channel. StoreKit may
  skip the prompt silently and never reports whether it appeared. A failed
  request is logged.
- On Android the automatic prompt never opens the sheet. Google Play's In-App
  Review policy forbids asking "do you like the app?" before its card or
  opening it from a button, so when the prompt fires Sesori requests Play
  In-App Review directly through the same channel: no question, no
  confirmation, and no store hand-off. Play's own quota decides whether the
  card appears and never reports it. A build without Google Play (sideloaded,
  or a device without Play services) skips it quietly and logs an error.
  **Rate Sesori** in Settings still opens the sheet, and **Leave a review**
  there opens the Play Store listing.
- **Not now**, the close button, and a swipe down after **Yes** all count as a
  positive answer without a review, and no store or StoreKit prompt opens. This
  includes closing the sheet during the celebration, before the automatic iOS
  sheet closes itself.
- **Could be better** hands over to "What should we improve?" with the same
  step transition: the rating step lifts away and the new step rises into place.
  It shows four issue pills (Hard to navigate, Connection drops, Notifications
  don’t arrive, App feels slow) and a text composer. A quiet line below the
  composer says "Sent privately to the Sesori team."
- The composer stops at 4,000 characters. A counter appears when 200 or fewer
  remain.
- A microphone button sits beside **Send feedback**. Holding it records through
  the shared voice transcription stack, with no project attached. While
  recording, the counter's slot shows a live waveform and a cancel target:
  dragging onto it and releasing, or a hold shorter than 200 ms, discards the
  recording. Releasing elsewhere transcribes, showing "Transcribing..." with a
  cancel button. The transcript is appended to the draft after a space, cut at
  the 4,000-character limit, and never sent automatically. **Send feedback** is
  disabled while recording or transcribing.
- Voice failures keep the draft. A denied microphone shows the permission
  notice; a failed start, a failed or unauthenticated transcription, and a
  network failure show their error, and a network failure discards the saved
  recording so the next hold starts fresh. Closing the sheet discards any
  recording or transcription still running.
- **Send feedback** is always available, including with nothing filled in. It
  posts the ticked issues to `POST /feedback` on the auth server as their wire
  values, with the source (`settings` or `automatic`), platform (`ios` or
  `android`), and app version. The text is trimmed first, and a blank message
  is left out of the request.
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
- When the automatic sheet is due while another screen's keyboard is raised,
  it closes that keyboard first and opens 500 ms later on a settled screen;
  with no keyboard up it opens right away. **Rate Sesori** in Settings opens
  immediately.
- While a keyboard is up, the sheet shrinks to the space above it and stays
  scrollable; dragging it does not close the keyboard.
- The automatic prompt is driven by a per-device counter of points per session
  that survives restarts:
  - A point is an agent turn that finishes without an error while the app is in
    the foreground, in whichever session it ran. A turn finishes when the
    session's `session.status` goes idle after Sesori saw it busy or retrying.
    Sub-agent sessions earn nothing, because their parent's turn is still
    running. Sent messages, created sessions, delivered follow-ups, and answered
    questions or permissions earn nothing themselves.
  - A failure the user felt in a session drops only that session's points: an
    AI error it reported (a message that ended in an error, or a session
    error), or a failed send or reply there. The turn it happened in earns no
    point when it ends. Other sessions keep their points. A session error that
    names no session, and a failed session creation, drop nothing.
  - An app crash drops every session's points. A crash is detected at the next
    launch from Crashlytics' previous-launch report, which needs Firebase.
  - A retrying session and an uncaught error that does not crash the app keep
    the points. After the user stops a response in this app, that session's AI
    errors drop nothing and the stopped turn earns nothing, until the session's
    next turn starts, because some backends report a stop as an error. A stop
    the bridge refuses without changing anything leaves the turn able to earn.
  - The prompt fires right after the finished turn that brings the total across
    sessions to 5 points. On iOS the sheet opens on the root navigator, over
    whatever screen is showing; on Android Play In-App Review is requested.
    Firing clears every point and records the time in the same write.
  - After an iOS answer other than **Yes, love it!**, including a dismissal,
    and after every Android request, the prompt waits at least 14 days before
    it can fire again, however many points are earned. Points keep counting
    during the wait.
  - **Yes, love it!**, from either entry, stops the automatic prompt for good.
    **Rate Sesori** in Settings always works.
  - Firebase Remote Config can change the 5 points
    (`feedback_prompt_interaction_threshold`) and the 14 days
    (`feedback_prompt_cooldown_days`). It is fetched once per launch with a
    short timeout. A missing value or one below 1 uses its default, and a
    failed fetch uses the values activated on an earlier launch. Builds without
    Firebase use the defaults.
  - An unreadable stored counter is discarded with a warning and counting
    starts again from zero. A counter stored by an app that counted one
    device-wide total starts with no points but keeps its last showing and a
    **Yes**.
- Product analytics (account-linked, under the Basic Usage Analytics
  preference; see [analytics](analytics.md)) records two events, each with
  `source` (`automatic` or `settings`) and no text or issues:
  - `feedback_prompt_answered`, once per sheet after it has closed, with
    `answer`: `love_review_requested` (**Leave a review**, the automatic iOS
    sheet closing itself for StoreKit, or, with `automatic` on Android, the
    direct Play In-App Review request, reported when it is made),
    `love_no_review` (**Yes**, then
    **Not now**, the close button, or a swipe down), `could_be_better` (sent or
    not), or `dismissed`.
  - `private_feedback_sent`, only after the auth server accepts a send, with
    `input`: `typed`, `voice_assisted` (a transcript was inserted into the
    draft, whatever was edited afterwards), `issues_only` (blank message), or
    `empty` (blank message, no issues). A failed send reports nothing.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated. The sheet widget suite proves the review takeover at the tap with visible travel, the same travel for **Could be better**, and the confirmation copy; the locked answers; that the outcome resolves only after the sheet has closed; that the automatic iOS sheet closes itself at 800 ms without switching content, and that closing it earlier requests no review; the outcomes for dismiss, **Not now**, a close during the celebration, and **Cancel**; private send with its toast after closing and the recipient line; that nothing dismisses the sheet mid-send; a failed send that keeps the draft and retries; the 4,000-character limit and counter; reduced motion (at open, turned on mid-flight, while writing, and while recording); and the narrow large-text layout. Its voice group proves hold-to-talk with the waveform, the disabled send, and the transcript appended without sending; discard by the cancel target and a quick tap; the permission and network-failure notices keeping the draft; the transcript cut at the limit; and that closing mid-recording discards it. The cubit, repository, API, and store-client suites prove the outcome mapping, send locking, failure, and a stale in-flight send, message trimming and omission, the request's wire values, the store URLs with the Android fallback, and the review request on iOS and Android over a mocked method channel, with its logged failure and no store hand-off; only the on-device rows cover the native StoreKit and Play handlers. The Settings suite proves the row's position, that the store opens only after the confirmed sheet has closed, and a send with the `settings` source. The counter suites prove the stored per-session state's round trip, the read of a counter stored as one total, and discard of unreadable values; the Remote Config fetch, fallbacks, and defaults; that a turn finishing cleanly in the foreground earns its session one point, and that an idle without a busy run, a background finish, and a sub-agent turn earn none; that the prompt fires right after the threshold turn across sessions, clears every point, records the time, and respects the cooldown; that an AI error, session error, or failed send or reply drops only its session's points and spoils its turn; that a crash drops every point; that retries, and AI errors in a stopped session until its next turn, keep the points; that a stopped turn earns nothing unless the stop was refused; that **Yes** stops it for good; that nothing is counted before the counter starts (desktop); and that the session-detail cubit and launch service record failures against their session, withdraw a refused stop, and never award points. The prompt cubit suite proves iOS asks for the sheet and Android requests the review directly with its analytics event. The listener test proves the sheet opens over the current screen, right away without a keyboard and only after 500 ms when one is raised, and that on Android no sheet opens and the review is requested. The event, cubit, and sheet suites prove both analytics events' wire names and values, one answer per closed sheet, `private_feedback_sent` only after a successful send, and `voice_assisted` after a dictated transcript. |
| L2 Routine | Client end to end on the release-target client platform against the dev auth server: Settings shows **Rate Sesori**; **Yes**, then **Leave a review**, opens the store review page after the sheet has closed; **Not now** returns to Settings without leaving the app; **Could be better** sends ticked issues and fixture text (typed, then extended by a held voice recording), closes the sheet, and shows the toast, and the stored document matches (message omitted when blank). |
| L3 Release | Client end to end on the alternate client platform: the same journey opens that platform's store. On a phone with Remote Config setting the threshold to 2 and the cooldown to 1 day, the prompt fires when the second agent turn finishes, not when its message is accepted, and turns in two different sessions count together; an AI retry keeps the points, and a real AI error in one session drops only that session's points. On iOS the sheet opens over the session, **Yes** closes it, and the StoreKit prompt appears only after it has gone. On Android, from an internal-testing Play install, Play In-App Review is requested with no sheet (Play's quota may show no card), and a sideloaded build shows nothing. After an iOS dismissal or an Android request the prompt does not fire again on the next two turns; after **Yes** it never fires by itself. |
| L4 Extended | Client end to end with Reduce Motion or Remove animations enabled and at accessibility text sizes. On Android, a device without the Play Store app falls back to the web listing. Sending offline or past the server's rate limit shows the inline error, keeps the draft, and **Retry** succeeds once the server accepts it. |
| L5 Full | No additional coverage. |

## Failure Signals

- The store or StoreKit prompt opens while the sheet is still visible or
  animating out, or opens after **Not now**, the close button, or a swipe
  down.
- A second tap changes a recorded answer, or reopening resumes a finished step.
- The review question or the private step waits after the tap, or swaps in
  without visible travel when motion is allowed.
- An automatic sheet on iOS shows the review confirmation, switches content
  while it closes, closes before the celebration has read, or asks StoreKit
  after the user closed it first.
- On Android the automatic prompt opens the sheet, asks anything before Play
  In-App Review, or hands the user to the store; or a build without Google Play
  shows an error instead of skipping quietly.
- **Leave a review** from Settings on Android shows nothing when the Play Store
  app is unavailable.
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
- **Rate Sesori** appears in desktop Settings, outside the mobile Account
  section, or misaligned with the account row.
- The automatic prompt fires on desktop, before the threshold, inside the
  cooldown, after **Yes**, twice for one threshold crossing, or when a prompt is
  accepted instead of after the finished turn.
- A sent message, created session, delivered follow-up, answered question or
  permission, sub-agent turn, a turn that finished in the background, or a
  stopped or failed turn earns a point.
- A retry, a stopped response, or an uncaught error that does not crash the app
  drops points.
- A failed send or reply or an AI error in one session drops another session's
  points, or does not drop its own; or a crash does not drop every point.
- The points or cooldown are lost on restart, or a stored **Yes** is lost on
  upgrade.
- `private_feedback_sent` is reported for a failed send, or either feedback
  event carries the message, the issues, or an answer the sheet did not end
  with.

## Sources

- `client/module_app_ui/lib/src/features/feedback/`
- `client/module_app_ui/lib/src/features/settings/settings_view.dart`
- `client/module_core/lib/src/cubits/feedback_sheet/`
- `client/module_core/lib/src/cubits/feedback_prompt/`
- `client/module_core/lib/src/services/feedback_prompt_service.dart`
- `client/module_core/lib/src/repositories/feedback_prompt_repository.dart`
- `client/module_core/lib/src/repositories/feedback_repository.dart`
- `client/module_core/lib/src/api/feedback_api.dart`
- `client/module_core/lib/src/api/feedback_prompt_config_api.dart`
- `client/module_core/lib/src/api/storage/feedback_prompt_storage.dart`
- `client/module_core/lib/src/platform/app_review_client.dart`
- `client/module_core/lib/src/foundation/models/product_analytics/product_analytics_event.dart`
- `client/module_core/lib/src/cubits/session_detail/session_detail_cubit.dart`
- `client/module_core/lib/src/services/session_launch_service.dart`
- `client/app/lib/main.dart`
- `client/app/lib/core/platform/firebase_feedback_prompt_config_source.dart`
- `client/app/lib/core/platform/firebase_remote_config_client.dart`
- `client/app/lib/core/platform/flutter_app_review_client.dart`
- `client/app/ios/Runner/AppDelegate.swift`
- `client/app/android/app/src/main/kotlin/com/sesori/app/AppReviewService.kt`
- `client/app/lib/features/settings/settings_screen.dart`
- `client/app/lib/core/widgets/feedback_voice_input_scope.dart`
- `client/module_app_ui/test/features/feedback/feedback_sheet_test.dart`
- `client/module_app_ui/test/features/feedback/feedback_prompt_listener_test.dart`
- `client/module_core/test/cubits/feedback_sheet/feedback_sheet_cubit_test.dart`
- `client/module_core/test/cubits/feedback_prompt/feedback_prompt_cubit_test.dart`
- `client/module_core/test/services/feedback_prompt_service_test.dart`
- `client/module_core/test/repositories/feedback_prompt_repository_test.dart`
- `client/module_core/test/repositories/feedback_repository_test.dart`
- `client/module_core/test/api/feedback_prompt_storage_test.dart`
- `client/module_core/test/api/feedback_api_test.dart`
- `client/module_core/test/foundation/product_analytics_event_test.dart`
- `client/module_core/test/cubits/session_detail/session_detail_cubit_test.dart`
- `client/module_core/test/cubits/session_detail/session_detail_cubit_permission_test.dart`
- `client/module_core/test/cubits/new_session/new_session_cubit_test.dart`
- `client/module_core/test/services/session_launch_service_test.dart`
- `client/app/test/core/platform/firebase_feedback_prompt_config_source_test.dart`
- `client/app/test/core/platform/flutter_app_review_client_test.dart`
- `client/app/test/features/settings/settings_screen_test.dart`
- `.plan/completed/feedback-flow/PLAN.md`
