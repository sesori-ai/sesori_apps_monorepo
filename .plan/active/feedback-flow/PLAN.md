# Feedback Flow: Production Rating Sheet, Private Feedback And Automatic Prompt

## Status

- **Plan slug:** `feedback-flow`
- **Created:** 2026-09-26
- **Tracks:** issue #1362. The approved design is the preview merged in #1361
  (`client/app/test/playbook/feedback_*`, UX signed off by the user on
  2026-09-26), with the shared Prego fixes from #1776 and #1777.
- **Series:** nine PRs, titles fixed in [TRACKER](TRACKER.md#fixed-pr-titles).
  Step 2 lands in `sesori-ai/sesori_auth_server`; every other step lands here.

## Goal

Users can rate Sesori or tell us privately what is wrong:

- **Settings → Rate Sesori** opens the rating sheet at any time.
- **Yes, love it!** plays the approved celebration, then asks for a store
  review.
- **Could be better** opens private feedback (issue chips, typing or voice).
  Sending it stores the feedback in the auth server's MongoDB.
- The sheet also opens by itself after enough good experiences in a row.

## Decisions

User decisions (2026-09-26):

- **D1 — Private feedback goes to our backend.** A new authenticated
  `POST /feedback` route on the auth server stores one document per
  submission in a new `feedback` collection. The team reads it from MongoDB
  directly; no admin UI or notifications for now.
- **D2 — Settings entry.** The sheet is reachable from Settings.
- **D3 — Automatic prompt rule.**
  - A persisted counter gains one point per big successful interaction:
    sending a message, creating a session with a message, answering a
    question, answering a permission request.
  - Any meaningful error resets it to zero: an AI error (including transient
    retries), a failed send or reply, or an app crash seen by the global
    handlers.
  - At 10 points the sheet shows. If the answer is not **Yes**, it may show
    again at most every 14 days (lowered from 30 in the user's round 1
    answers).
  - Both numbers come from Firebase Remote Config, with 10 and 14 as the
    defaults.

User decisions from the round 1 question page (2026-09-26; page on the
`pr-media` branch at `feedback-flow/round1/index.html`):

- **D4 — Yes retires the automatic prompt.** After **Yes** (from either
  entry), the sheet never opens by itself again; Settings still opens it.
  Dismissing the sheet counts as "not yes" and starts the cooldown.
- **D5 — Showing resets the counter.** Each automatic showing sets the counter
  to zero, so the next one needs 10 new good interactions *and* the cooldown.
- **D6 — It appears right away.** The sheet opens as soon as the good
  interaction that reaches the threshold succeeds, over whatever screen is
  showing (including a session), from an app-root presenter.
- **D7 — Store review split.**
  - Automatic prompt on iOS: **Yes** asks StoreKit for its review prompt.
    Apple guideline 5.6.1 requires the system API and does not forbid a
    preceding question. The prompt stays inside the app.
  - Every jump to a store page (Android from both entries, iOS from Settings)
    goes through the D10 confirmation step first, because the OS prompt may
    silently not appear and leaving the app must never be a surprise.
  - The review call or store jump starts only after the sheet's route has
    finished closing, as in the preview.
- **D10 — Android and Play policy (user decision, 2026-09-26).** Google's
  In-App Review guidance says the app "shouldn't ask the user any questions
  before or while presenting the rating button or card, including questions
  about their opinion (such as 'Do you like the app?')". The approved sheet is
  exactly that question, so Android never calls the In-App Review API and the
  app ships no Play Review dependency. Instead:
  - After the **Yes** celebration, the sheet shows a confirmation step asking
    whether the user would leave a review on the store, with **Leave a
    review** and **Not now**.
  - **Leave a review** closes the sheet, then opens the store page
    (`market://details?id=com.sesori.app`, or the App Store write-review page
    for the iOS Settings entry). **Not now** closes the sheet.
  - The step has no Figma design yet; step 3 builds it from the sheet's
    existing parts (title, body, the solid button pair) and the PR shows it.
  - Either answer counts as **Yes** for D4: the user said they like the app.
- **D8 — Mobile only.** iOS and Android. The desktop app has no Firebase and
  is not distributed through a store; desktop private feedback is a later
  phase (see [Later Phases](#later-phases-rough-intent-only)).
- **D9 — Device-scoped prompt state.** The counter and cooldown belong to the
  device, not the account. Signing in with another account does not reset
  them.

Implementation decisions (2026-09-26, step 3 review):

- The sheet's outcome is read from `FeedbackSheetCubit` state once the route
  has closed, not from the route's pop result.
- `FeedbackSheetCubit` is created per Settings screen with
  `BlocProvider(create:)` and outlives each sheet route; every presentation
  restarts it at the first question.
- Desktop has no `InstalledAppBuildSource` implementation, because desktop
  never resolves it.
- The private draft text lives in the composer's `TextEditingController`, not
  in the cubit.
- Step 5: `AppReviewClient.requestReviewOpensStore` tells `FeedbackSheetCubit`
  whether the automatic sheet needs the D10 confirmation. When it does not
  (iOS), the celebration ends in `reviewPromptPending`, and the sheet closes
  itself on that state. `requestStoreReview()` calls `requestReview()` for the
  automatic source and `openStoreReviewPage()` for Settings. The OS prompt is
  not gated by build mode: StoreKit shows it in debug builds and applies its
  quota in release.

## Current Behavior (origin/main after #1361, 2026-09-26)

- Nothing in the app opens a rating or feedback flow. Settings has Support
  (Email, Discord, X) and Legal rows only
  (`client/module_app_ui/lib/src/features/settings/settings_view.dart`).
- The preview lives in `client/app/test/playbook/`:
  - `feedback_rating_motion.dart`: `FeedbackRatingHero`, `FeedbackLoveButton`,
    the 31 Figma tracks. Reusable as-is.
  - `feedback_flow_playbook.dart`: sheet, rating step, private step, pills,
    composer, simulated recording/transcription/submission, and the launcher.
  - Tests: `feedback_celebration_test.dart`, `feedback_flow_playbook_test.dart`,
    `feedback_motion_test.dart`, `feedback_voice_states_test.dart`, and the
    `FEEDBACK_PREVIEW.md` handoff.
  - Artwork in `client/app/assets/images/feedback_rating_*` (2 WebP, 8 SVG).
- Debug-only native hooks on channel `com.sesori.app/feedback_preview`:
  `AppDelegate.swift` (`#if DEBUG`), Android `src/debug/.../FeedbackPreviewActivity.kt`
  selected through the `mainActivityName` manifest placeholder, and
  `debugImplementation("com.google.android.play:review:2.0.2")`.
- Firebase Remote Config is used once, for the analytics release cutoff:
  `AnalyticsReleaseCutoffSource` (module_core platform interface) →
  `FirebaseAnalyticsReleaseCutoffSource` (app) with a no-op fallback when
  Firebase is off (web, Linux, Windows, Android profile builds).
- Local state: `PersisterRepository` stores string and bool keys
  (`persistence_keys.dart`). Versioned JSON in a string key has a precedent in
  `api/storage/product_analytics_preference_storage.dart`.
- Global errors: `client/app/lib/main.dart` routes `FlutterError.onError` and
  `PlatformDispatcher.onError` to Crashlytics when Firebase is supported.
- Success seams, all in module_core cubits:
  - `SessionDetailCubit`: `sendMessage` success branch; `_submitReply` for
    question reply, question reject and permission reply.
  - `NewSessionCubit.createSession` success branch.
- AI errors arrive on `ConnectionService.events`:
  `SesoriMessageUpdated` with `Message.error`, `SesoriSessionStatus` with
  `SessionStatusRetry`, and `SesoriSessionError`.
- Voice: `VoiceTranscriptionService.createSession(projectId: null)` works
  without a project; `VoiceInputCubit` drives the composer's recorder.
- Authenticated auth-server calls: `NotificationApi` pattern
  (`AuthenticatedHttpApiClient.post`, `$authBaseUrl/...`).
- Store ids: App Store `id6760642500`, Play `com.sesori.app`.
- Auth server (`sesori_auth_server`, Fastify + raw MongoDB + zod): routes →
  services → repositories; `requireAuth` preHandler supplies
  `request.user.userId`; per-route `rateLimit` keyed by user. No feedback
  collection exists.

## Design

### Auth server (step 2)

- `POST /feedback`, `requireAuth`, rate limit 10 per hour per user.
- Body (zod, `safeParse`):
  - `issues`: array of the closed set `hard_to_navigate`, `connection_drops`,
    `notifications_missing`, `app_slow`; unique, may be empty.
  - `message`: trimmed string, 1–4000 characters, or absent.
  - Both may be empty: the approved sheet keeps **Send** available with
    nothing filled in, and an empty "could be better" is still a signal.
  - `source`: `automatic` | `settings`.
  - `platform`: `ios` | `android`.
  - `appVersion`: semver-like string, max 32 characters.
- Document: `{ userId: ObjectId, issues, message?, source, platform,
  appVersion, createdAt }` in collection `feedback`, index `{ createdAt: -1 }`.
- Response `201` with no body fields the client needs.
- Route, service, repository, `AuthDbCollection.feedback`, zod model, and
  `node:test` coverage following the settings route.
- Account deletion also deletes the user's `feedback` documents, with test
  coverage, because a message may contain pasted code or secrets. Step 3
  updates the storage and deletion disclosure in `docs/SECURITY.md` ("we do
  not store message history" no longer covers everything we store).

### Client layers (module_core)

Foundation:
- `FeedbackIssue` enum (wire values above) and `FeedbackSource` enum.
- `FeedbackPromptState`, sealed:
  - `FeedbackPromptCounting(positiveCount, lastShownAt: DateTime?)`
  - `FeedbackPromptRetired()` — the user answered **Yes**.
- `FeedbackPromptConfig(interactionThreshold, cooldown)`.

Platform interfaces:
- `FeedbackPromptConfigSource` (`foundation/platform/`) returns raw `int?`
  values for Remote Config keys `feedback_prompt_interaction_threshold` and
  `feedback_prompt_cooldown_days`, like `AnalyticsReleaseCutoffSource`.
  Implementations: Firebase in `client/app`; a no-op returning `null` in
  `client/app` (Firebase off) and in `client/desktop/lib/core/platform/`
  (desktop resolves the shared cubits, see below).
- `AppReviewClient` (`platform/`, next to `url_launcher.dart`), implemented in
  `client/app`: `openStoreReviewPage()` in step 3 (url_launcher:
  `itms-apps://itunes.apple.com/app/id6760642500?action=write-review`,
  `market://details?id=com.sesori.app` with an `https://play.google.com/...`
  fallback) and `requestReview()` (OS prompt) in step 5.
- `InstalledAppBuildSource` gains `readVersion()` and `devicePlatform`,
  implemented in `client/app` only and exposed through the existing
  `api/installed_app_build_api.dart`, so feedback does not depend on the push
  capability for its platform.

API → Repository → Service:
- `FeedbackApi` (`POST $authBaseUrl/feedback`, Freezed
  `FeedbackSubmitRequest` in `capabilities/feedback/`, following
  `register_token_request.dart`) → `FeedbackRepository.submit`, which combines
  `FeedbackApi`, `InstalledAppBuildApi` and the device platform.
- `FeedbackPromptConfigApi` wraps the config source.
  `FeedbackPromptStorage` (`api/storage/`, one versioned JSON
  `StringPreferenceKey.feedbackPrompt`) holds the state.
  `FeedbackPromptRepository` combines both and owns the 10/14 defaults and the
  below-1 fallback when it builds `FeedbackPromptConfig`.
- `FeedbackPromptService` (`@lazySingleton`), the single owner of D3–D6:
  - `recordPositiveInteraction()` increments the counter, then runs the due
    check below; when it passes, it emits on a broadcast `prompts` stream.
  - `recordFailure()`.
  - `start()` subscribes once to `ConnectionService.events` and calls
    `recordFailure()` for the three AI-error events. Only the mobile
    `bootstrapSesoriApp` wiring calls it, next to the product-analytics start;
    desktop never does. Resetting is idempotent, so replayed events need no
    dedupe.
  - Due check (private): when counting, count ≥ threshold and the cooldown
    has elapsed since `lastShownAt`, it sets count → 0 and `lastShownAt` → now
    in the same write that decides to emit, so D5 stays in the service.
  - `recordYes()` (→ retired).
  - An idempotent `@disposeMethod` cancels the subscription.

Consumers:
- `SessionDetailCubit` and `NewSessionCubit` receive the service through
  `module_core/lib/src/di/cubit_composition.dart` and call
  `recordPositiveInteraction()` in their existing success branches and
  `recordFailure()` in their `ErrorResponse` branches. Desktop builds these
  cubits through the same composition; with no presenter and no `start()`,
  its counting is inert (desktop's local state is never shown or synced).
- `client/app/lib/main.dart` wraps the two global error handlers to call
  `recordFailure()` before forwarding to Crashlytics, and calls it at startup
  when `FirebaseCrashlytics.didCrashOnPreviousExecution()` is true (native
  crashes).
- `FeedbackPromptCubit` (`cubits/feedback_prompt/`), dependency
  `FeedbackPromptService`: listens to `prompts` and emits a one-shot "show"
  state (D6).
- `FeedbackSheetCubit` (`cubits/feedback_sheet/`) drives the sheet: step
  (rating, private), selected issues, submission state, source. The draft
  text stays in the composer. The sheet ends with a typed
  `FeedbackSheetOutcome` (`love`, `couldBeBetter`, `dismissed`) read from the
  cubit's state. The shell awaits the sheet route, and only after its exit
  animation has completed calls
  `FeedbackSheetCubit.requestStoreReview()`, which uses `AppReviewClient`.
  Dependencies grow per step: `FeedbackRepository` and `AppReviewClient`
  (step 3), `FeedbackPromptService` for `recordYes()` from either entry
  (step 6), `ProductAnalyticsService` (step 7).
- The cubits are created with `BlocProvider(create:)` in `client/app`:
  `FeedbackSheetCubit` per entry (one per Settings screen, reused by each
  sheet it opens, and one for the app-root presenter),
  `FeedbackPromptCubit` once at the app root; the `module_app_ui` sheet reads
  `FeedbackSheetCubit` from context. Step 4 builds its `VoiceInputCubit` in the
  app shell the same way.
- The composer enforces the server's 4,000-character limit with a visible
  counter near the limit; an inserted transcript is cut at the limit.
- UI in `client/module_app_ui/lib/src/features/feedback/`: the sheet, rating
  step, private step, pills and composer from the preview, plus the motion
  file. Artwork moves to `module_app_ui/assets/images/`, and the motion file's
  `Image.asset` / `SvgPicture.asset` calls gain the `sesori_app_ui` package
  name so they resolve from the module. Copy moves into the localization
  files.
- Settings: `SettingsView` gains a required `onOpenRateSesori` callback (it is
  mobile-only, so desktop is unaffected).
- App-root presenter (D6): in `client/app/lib/main.dart`, next to
  `SseToastListener`, a `BlocProvider` for `FeedbackPromptCubit` wraps a
  `FeedbackPromptListener(navigatorKey: appRootNavigatorKey)` that opens the
  sheet with `FeedbackSource.automatic` on the root navigator, over whatever
  screen is showing.

### Native (step 5)

Per D10:
- iOS production channel `com.sesori.app/app_review` with one method,
  `requestReview`, registered next to the recorder-prewarm channel in
  `AppDelegate.swift`.
- Android has no review channel: `AppReviewClient.requestReview()` opens the
  Play Store listing on Android (after the D10 confirmation).
- The debug-only preview hooks (`FeedbackPreviewActivity`, the
  `mainActivityName` placeholder, the `debugImplementation` Play Review
  dependency and the iOS `#if DEBUG` block) were already removed in step 3.a.

## Steps

Fixed titles live in [TRACKER](TRACKER.md#fixed-pr-titles).

1. **Plan** — this document.
2. **Auth server `POST /feedback`** — [Auth server](#auth-server-step-2),
   including deletion with the account.
3. **Rating sheet in the app, opened from Settings**
   - Move the motion file and artwork into module_app_ui; turn the preview's
     sheet, steps, pills and composer into production widgets driven by
     `FeedbackSheetCubit`.
   - Add `FeedbackApi`, `FeedbackSubmitRequest`, `FeedbackRepository`,
     `FeedbackIssue`, `FeedbackSource`, `InstalledAppBuildSource.readVersion()`
     and `AppReviewClient` (store page only in this step).
   - Settings: a **Rate Sesori** row, second in the Account section of the
     mobile `SettingsView`. Yes → celebration → store write-review page. Could be
     better → private step (typing only; the voice button arrives in step 4)
     → submit to `/feedback` → top toast. Errors keep the draft.
   - Delete the preview launcher, simulated states, `FEEDBACK_PREVIEW.md`,
     tests the production tests replace, and the debug-only native preview
     hooks.
   - Add `docs/regression/feedback-flow.md`.
   - Size: expected near the cap. Use `git mv` for the motion file and assets;
     if the authored diff exceeds ~1,500 lines, split into 3.a (sheet + Settings
     + Yes path) and 3.b (private step + submission).
4. **Voice in the feedback composer** — reuse `VoiceInputCubit` with
   `projectId: null`; hold-to-talk, transcript into the draft, permission
   recovery from the real voice stack.
5. **OS review prompt in release builds** — [Native](#native-step-5); add
   `requestReview()` to `AppReviewClient`.
6. **Automatic prompt** — config source (Firebase, app no-op, desktop no-op),
   config API, prompt state storage and repository, `FeedbackPromptService`
   with `start()` from mobile bootstrap, the `cubit_composition.dart` wiring,
   global-handler hooks, `FeedbackPromptCubit` and the app-root presenter
   (D3–D6).
7. **Analytics** — load `.opencode/skills/add-analytics/SKILL.md`. Proposed
   events: `feedback_prompt_answered` with `answer` (`love`,
   `could_be_better`, `dismissed`) and `source` (`automatic`, `settings`);
   `private_feedback_sent` with `source` and `input` (`typed`, `voice`,
   `issues_only`). No text, no issue lists beyond closed enums.
8. **Regression docs** — reconcile `docs/regression/feedback-flow.md` and the
   README index.
9. **Retire** — run the recorded coverage and move the plan to
   `.plan/completed/feedback-flow/`.

## Complexity Budget

New mutable parts:
- **Persistent (client):** one JSON string key holding `FeedbackPromptState`.
  Needed: the counter must survive restarts and the cooldown spans 14 days.
- **Persistent (server):** the `feedback` collection (D1).
- **In memory:** `FeedbackPromptService` keeps one SSE subscription (mobile
  only) and reads state through its repository; `FeedbackPromptCubit` holds one
  `prompts` subscription; `FeedbackSheetCubit` holds one sheet's step, issues
  and submission state.

Deliberately not added:
- No dedupe of error events (reset is idempotent) and no per-session
  bookkeeping.
- No server-side prompt state, per-account counters or cross-device sync (D9).
- No "is another modal open" or route-visibility coordination; D6 presents
  immediately on the root navigator, as the user chose.
- No retry queue for failed submissions: the draft stays and the user retries.
- No generic feature-flag layer; one config source for two values, like the
  analytics cutoff.

## Cleanup Assessment

- Step 3 deletes the preview scaffolding and the preview handoff; the motion
  file, artwork and approved widgets move rather than duplicate.
- Step 5 deletes the debug-only activity, manifest placeholder, iOS debug
  block and the `debugImplementation` dependency, replaced by the production
  channel.
- No other cleanup found.

## Compatibility

- `POST /feedback` is client → auth server only. Older apps never call it, and
  the route ships (step 2) before any client uses it. No bridge wire contract
  changes.
- No database migration on the client; the new key starts absent (treated as
  `FeedbackPromptCounting(0, null)`).

## Verification And Coverage

- Per step: owning-package analyze (`dart analyze --fatal-infos`) and focused
  tests (cubit, service rules with a fake clock, widget tests for the sheet
  steps; `node:test` on the server).
- Step 6 also launches the desktop app and opens a session and a new session,
  proving desktop DI resolves the new dependencies.
- Architecture plan review (2026-09-26): rejected with seven blocking findings
  (screen calling a service, desktop DI for shared cubits, SSE start ownership,
  config layering, app version/platform source, sheet cubit wiring, the
  `AppReviewPlatform` name) and one accepted risk. All were applied to this
  version, which has not been re-reviewed.
- Regression document: `docs/regression/feedback-flow.md` (new).
- **Retirement coverage: L3** on iOS and Android:
  - Settings → Yes → store page opens; Settings → Could be better → typed and
    voice feedback stored in MongoDB (dev auth server) with the right fields.
  - Automatic prompt with Remote Config lowered to threshold 2 / cooldown 1:
    the second send opens it over the session; an AI retry in between resets it;
    Yes retires it; dismiss respects the cooldown.
  - iOS StoreKit prompt appears (debug build) only after the sheet has
    closed. Android **Yes** shows the confirmation step; **Leave a review**
    opens the Play Store listing and **Not now** only closes (D10).
  - Deleting the account removes its feedback documents (dev auth server).
- Codex plan review (2026-09-26, 10 findings): applied route-visible claiming
  (later superseded by the user's D6: show right away), feedback deletion with the account, package asset namespace, the
  4,000-character client limit, empty submissions, subscription disposal,
  review after the sheet exit, the platform via `InstalledAppBuildApi`, and
  the Play policy question (D10, decided by the user). Declined one: separate Firebase and
  no-op config adapters in `client/app` follow the existing
  `AnalyticsReleaseCutoffSource` precedent.

## Risks

- **OS review quotas** (evidence: platform docs). StoreKit shows at most three
  prompts a year and may skip silently; the automatic path therefore never
  claims a prompt appeared.
- **Store policy** (evidence: Google's In-App Review guidance, quoted in D10).
  Asking "do you like it" before the Play review card violates that guidance;
  D10 keeps Android away from the In-App Review API.
- **Spurious resets** (theoretical). A replayed old AI error resets the
  counter and only delays the prompt. Accepted.
- **Resets from other surfaces** (ordinary flow). `ConnectionService.events`
  carries every session on the active bridge, including sessions driven from
  desktop or another device and sub-agent sessions, so an AI error the phone
  never showed also resets the counter. It only delays the prompt; accepted
  under D3.
- **Prompt interrupts** (ordinary flow). Accepted by the user's D6: the sheet
  may cover a session right after a successful send or reply.
- **Feedback text privacy** (ordinary flow). Users may paste code or secrets.
  The private step says the text goes to the Sesori team; logs never include
  the text.

## Later Phases (Rough Intent Only)

- Desktop private feedback from the desktop Settings modal (no store review).
- Notify the team (Discord or email) per submission if volume justifies it.
