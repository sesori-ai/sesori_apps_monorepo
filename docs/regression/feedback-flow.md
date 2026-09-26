# Feedback Flow

## Capability

The mobile rating sheet that asks whether the user enjoys Sesori. A positive
answer can hand the user to the platform's store review page. A negative answer
collects private feedback, which is sent to the Sesori auth server. The sheet
opens from **Rate Sesori**, the second row of the Account section in mobile
Settings. Desktop Settings does not show the row.

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
- **Not now**, the close button, and a swipe down after **Yes** all count as a
  positive answer without a review, and no store opens.
- **Could be better** replaces the rating step with "What should we improve?".
  It shows four issue pills (Hard to navigate, Connection drops, Notifications
  don’t arrive, App feels slow) and a text composer. A quiet line below the
  composer says "Sent privately to the Sesori team." Voice input is not part of
  this build.
- The composer is typing-only and stops at 4,000 characters. A counter appears
  when 200 or fewer remain.
- **Send** is always available, including with nothing filled in. It posts the
  ticked issues to `POST /feedback` on the auth server as their wire values,
  with the source (`settings`), platform (`ios` or `android`), and app version.
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
  promptly, and turning either on while writing keeps the draft.
- The sheet fits a 320 x 568 screen at 1.5x text without overflow.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated: the sheet widget suite proves the celebration timing, the confirmation copy, the locked answers, that the outcome resolves only after the sheet has closed, the outcomes for dismiss, Not now, close during the celebration and Cancel, private Send with its toast after closing, the recipient line, that Cancel, back, a barrier tap, and a swipe down cannot dismiss the sheet mid-send, a failed send that keeps the draft and retries, the 4,000-character limit and counter, reduced motion (at open, turned on mid-flight, and while writing), and the narrow large-text layout. The cubit, repository, API, store-client, and Settings suites prove the outcome mapping, send locking and failure, message trimming and omission, the request's wire values, the store URLs with the Android fallback, that Settings opens the store only after the sheet has closed, and that Settings sends with the `settings` source. |
| L2 Routine | Client end to end on the release-target client platform against the dev auth server: Settings shows **Rate Sesori**; **Yes**, then **Leave a review**, opens the store review page after the sheet has closed; **Not now** returns to Settings without leaving the app; **Could be better** sends ticked issues and fixture text, closes the sheet, and shows the toast, and the stored document matches (message omitted when blank). |
| L3 Release | Client end to end on the alternate client platform: the same journey opens that platform's store. |
| L4 Extended | Client end to end with Reduce Motion or Remove animations enabled and at accessibility text sizes. On Android, a device without the Play Store app falls back to the web listing. Sending offline or past the server's rate limit shows the inline error, keeps the draft, and Retry succeeds once the server accepts it. |
| L5 Full | No additional coverage. |

## Failure Signals

- The store opens while the sheet is still visible or animating out, or opens
  after **Not now**, the close button, or a swipe down.
- A second tap changes a recorded answer, or reopening resumes a finished step.
- Android shows nothing when the Play Store app is unavailable.
- A send failure clears the draft or issues, closes the sheet, or shows the
  success toast.
- The sheet closes while a send is in flight, so a successful send shows no
  toast and a retry could duplicate it.
- A blank or whitespace-only message is sent as text, so the server rejects it
  with a 400.
- The message text appears in a log.
- With reduced motion enabled, the celebration or sheet travel still animates.
- The sheet clips or overflows on a small screen or at large text sizes.
- **Rate Sesori** appears in desktop Settings, or outside the mobile Account
  section.

## Sources

- `client/module_app_ui/lib/src/features/feedback/`
- `client/module_core/lib/src/cubits/feedback_sheet/`
- `client/module_core/lib/src/repositories/feedback_repository.dart`
- `client/module_core/lib/src/api/feedback_api.dart`
- `client/app/lib/core/platform/flutter_app_review_client.dart`
- `client/app/lib/features/settings/settings_screen.dart`
- `client/module_app_ui/test/features/feedback/feedback_sheet_test.dart`
- `client/module_core/test/cubits/feedback_sheet/feedback_sheet_cubit_test.dart`
- `client/module_core/test/repositories/feedback_repository_test.dart`
- `client/module_core/test/api/feedback_api_test.dart`
- `client/app/test/core/platform/flutter_app_review_client_test.dart`
- `client/app/test/features/settings/settings_screen_test.dart`
- `.plan/active/feedback-flow/PLAN.md`
