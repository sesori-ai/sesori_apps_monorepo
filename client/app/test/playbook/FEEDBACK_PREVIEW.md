# Feedback UI preview

An interactive Flutter prototype of the [Figma feedback flow](https://www.figma.com/design/NILKXLD9cwuWHhLnGqPqeJ/Sesori?node-id=4616-40748).
This is a design and engineering handoff. Voice and private submission are
simulated; 4–5 stars requests Apple's actual native rating UI in iOS debug builds.

## Simulator screenshots

Captured from the preview on an iPhone 17 Pro simulator running iOS 26.5:

| Rating · dark | Keyboard · dark | Apple native rating |
| --- | --- | --- |
| ![Rating sheet](feedback_preview/rating-dark.png) | ![Private feedback with the iOS keyboard](feedback_preview/keyboard-dark.png) | ![Apple StoreKit rating prompt](feedback_preview/native-ios.png) |

## Run locally

Use the Flutter version pinned in the repository's `.tool-versions` (currently
3.47.2-stable). From `client/`, run `flutter pub get`, then from `client/app/`:

```sh
flutter devices
flutter run -d <ios-simulator-id> -t test/playbook/feedback_flow_playbook.dart
```

The preview opens directly into the rating sheet. Dismiss it to access the
scenario selector and the sun/moon theme button, then tap **Open feedback** to
restart. No sign-in, bridge, connected coding harness, microphone permission,
or feedback backend is needed. A real software keyboard is used for typing.

## What to try

| Action | Expected preview behavior |
| --- | --- |
| Select 1, 2, or 3 stars | Open private feedback with issue choices and voice/keyboard input. |
| Select 4 or 5 stars | Wait for the rating sheet to close completely, then request Apple's native rating prompt through StoreKit. |
| Tap any star | Bounce only the tapped star without a circular press highlight, then advance after it settles. Reduced motion keeps the selection feedback without movement. |
| Tap Not now, Cancel, the scrim, or swipe the sheet down | Dismiss without submission; reopening starts a fresh draft. |
| Select one or several issues | Toggle selection; category-only feedback can be submitted. |
| Switch to keyboard | Edit multiline text; show the annotated blue focus ring. |
| Hold the voice area, then release | Show the existing Prego waveform, simulated transcription, then editable sample text. |
| Tap the voice area twice | Accessible preview shortcut: start, then finish the simulated recording. |
| Submit feedback | Show loading, close the sheet, and show the Figma confirmation toast. No content leaves the preview. |
| Select Submission fails once | First submission preserves the draft and shows Retry; retry succeeds. |
| Select Microphone permission denied | Show the permission error with a working keyboard alternative. No OS permission dialog is requested. |
| Select Transcription fails once | First transcription fails; Retry transcription inserts sample text. |
| Open the preview outside an iOS debug build | The native-rating request reports that it is available in the iOS debug preview; no custom review dialog is substituted. |

Check dark/light themes, larger text, a narrow phone, keyboard appearance and
dismissal, category wrapping, long feedback, cancellation during a simulated
operation, and repeating the flow. Private-feedback success must never open the
native-rating prompt.

Apple owns the native prompt's copy, appearance, star selection, and dismissal.
StoreKit does not report whether a rating was submitted. Its development-mode
prompt lets us verify the native UI; this is not proof of a published review.
[Apple documents development and TestFlight behavior here](https://developer.apple.com/documentation/storekit/appstore/requestreview%28in%3A%29-1q8qs).
The private-feedback success toast remains simulated.

## Implementation boundaries

- The alternative entry point is `feedback_flow_playbook.dart`; production
  `lib/main.dart`, routes, settings, DI, and services are unchanged.
- All prototype state, fake delays, scenarios, and copy live under
  `test/playbook/`. Private feedback has no backend calls, real recording or
  transcription, analytics events, storage, or automatic prompting.
- A small `#if DEBUG` hook in `ios/Runner/AppDelegate.swift` registers
  `com.sesori.app/feedback_preview`. Its `requestReview` method calls StoreKit
  using the foreground `UIWindowScene`, after the Dart sheet's `completed`
  future resolves. It uses `AppStore.requestReview(in:)` on iOS 16+ and
  `SKStoreReviewController.requestReview(in:)` on the app's supported iOS 15.
  There are no new dependencies. Release builds exclude this hook, and the
  normal product entry point does not call it.
  The Runner Debug build configuration explicitly enables Swift's `DEBUG`
  compilation condition so the preview hook is available in simulator builds.
- Prego supplies the themes, icons, solid/glass buttons, composer decoration,
  waveform, scaffold, and success toast. The grabber-only sheet, issue pills,
  and stars are private prototype widgets.
- The exact artwork was exported from Figma node `4954:13069` at 3× resolution
  (1110 × 570). `assets/images/feedback_preview_hero.png` is included by the
  app's existing image-asset declaration; this adds approximately 376 KiB to
  that bundle even when the preview entry point is not used.
- The Figma label `Notifications don’t arirve` is preserved intentionally.
  Confirm the correction to `Notifications don’t arrive` before production.
- Figma comment #151 asks for voice and quick issue choices; both are included.
  Comment #150 questions the intermediate state: no extra thank-you sheet is
  inserted before native rating. The annotated blue focus ring is
  retained on the feedback editor.

## Motion behavior

The selected-star-only 280 ms bounce and its no-splash treatment are preserved.
The remaining flow now uses coordinated motion:

- Sheet: 250 ms entrance with `Cubic(0.32, 0.72, 0, 1)`, and a 200 ms
  fast-start exit using the flipped `Cubic(0.23, 1, 0.32, 1)`.
- Content: 220 ms fade with a small vertical offset; outgoing content loses
  pointer access and semantics. The rating handoff resizes the existing sheet
  during that same transition. Voice, failures, and the bottom confirmation
  share this treatment.
- Chips: pointer-down feedback, synchronized 160 ms border/checkbox/text
  selection, and 100 ms press release. Composer actions reveal over 160 ms,
  with neighboring content adjusting alongside them.
- Typing: the editor reserves three visible lines and scrolls longer drafts.
  Keyboard insets follow the platform directly, with no extra padding tween.
- Reduced motion: sheet travel is removed, including when the preference
  changes while it is open; content retains fades, press scaling is suppressed,
  and changing the preference preserves the private draft. Shared Prego iOS
  buttons also stop ongoing press motion.
- Loading: shared iOS buttons retain their press wrapper while disabled, so
  release finishes smoothly. Existing iOS timing and haptics are preserved.

## Engineering follow-up

After reviewing the experience, extract the agreed presentation into shared
`module_app_ui` widgets and put business state in `module_core` with shell-owned
composition. Do not copy prototype delays or scenario switches into the
production flow.

Production work still needs:

1. A confirmed feedback destination and authenticated submission contract, with
   typed failure/retry handling and truthful delivery acknowledgement.
2. Existing `VoiceInputCubit` / `VoiceTranscriptionService` integration, scoped
   recording cleanup, editable transcription, and real-device validation.
3. The agreed prompting rule (proposed: two minutes of foreground use, then a
   quiet return to the task list), cooldown persistence, and manual entry.
4. A production native-review adapter and platform testing. The current iOS
   hook is debug-only; Android is not implemented or exercised. Keep Apple’s
   actual UI and wait for sheet dismissal. OS suppression is not a failed review.
5. Store-policy resolution for the requested positive-rating-only native
   prompt. The UI prototype preserves the user's selected 1–3/private and
   4–5/native split; this is not an assertion of store compliance. See
   [Google's guidance](https://developer.android.com/guide/playcore/in-app-review)
   and [Apple's guidelines](https://developer.apple.com/app-store/review/guidelines/#app-store-reviews).
6. Production localization, relevant regression documentation, and required
   client/service/native verification before release.

## Verification

```sh
# From client/app
flutter test test/playbook/feedback_flow_playbook_test.dart test/playbook/feedback_star_animation_test.dart test/playbook/feedback_motion_test.dart
dart analyze
```

Verified locally on 2026-09-08 with Flutter 3.47.2 / Dart 3.13.2:

- Twenty-three focused widget tests pass: all five rating branches, category-only
  private submission, dismiss/reopen, draft-preserving retry, editable simulated
  transcription without automatic submission, and a 320 × 568 viewport with
  1.5× text and keyboard insets. Native-channel tests verify exactly one request
  for 4/5 stars after full sheet removal, none for 1–3, and explicit handling
  of missing-plugin/platform failures.
  Three animation checks cover the tapped-star bounce, a second tap during the
  transition, and both reduced-motion accessibility settings.
  Nine additional motion checks cover the sheet handoff, chip press feedback,
  action movement and reversal, stationary typing, voice transitions, and
  reduced-motion behavior including preservation of an open draft and immediate
  dismissal, microphone denial, and transcription retry.
- Shared Prego button checks pass: seven native widget tests, two Chrome tests,
  and the owning module analyzer. See `docs/regression/prego-button-interactions.md`.
- The app analyzer passes. Formatting and the final playbook analyzer pass.
- The iOS simulator build passes, including the Swift StoreKit hook.
- Manual simulator coverage: dark/light rating sheets, private issue selection,
  typing with the software keyboard, focus ring and keyboard avoidance,
  simulated recording/transcription, private success toast, category-preserving
  submission failure and retry, and Apple's actual native rating prompt.
- Star, issue, and composer actions expose single labeled accessibility
  controls. Full VoiceOver navigation remains a team review item.

The current request intentionally limits verification to the local UI and iOS
simulator. StoreKit presentation is exercised in a debug build. Play Review,
Android, microphone, backend delivery, and production prompt/cooldown behavior
are not exercised by this handoff.
