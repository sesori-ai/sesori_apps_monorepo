# Desktop Sign-In Rebuild

## Status

- **Plan slug:** `desktop-sign-in`
- **Created:** 2026-09-25
- **Origin:** visual-hierarchy step 38 (review D12): "Scope the sign-in rebuild
  with the user, including Apple sign-in, and raise it as its own plan." This
  plan's first PR is that step, so it carries the visual-hierarchy title
  `🌿 [visual-hierarchy] Plan the desktop sign-in rebuild [step 38/50]`.
  Every later PR uses the `desktop-sign-in` slug.
- **Series:** eight PRs in one phase; titles are fixed in
  [TRACKER](TRACKER.md#fixed-pr-titles). Later phases are rough intent only.
- **Sources:** the user's review of the local page
  `/tmp/sesori-ux/desktop-sign-in/index.html` on 2026-09-25. The page, its
  mockups and its screenshots stay local; nothing from them is committed.

## Goal

Rebuild the signed-out desktop window so that anyone with a Sesori account can
sign in, whichever method they used on the phone, and so that a browser
sign-in can never trap the window. Today the desktop offers GitHub and Google
only, disables both buttons for up to five minutes while it waits for the
browser, and reports every failure as one red line.

## Current Behavior (origin/main, 2026-09-25)

- `client/desktop/lib/features/login/login_screen.dart` (135 lines) builds the
  shared `LoginCubit` and shows two Material buttons (GitHub filled, Google
  outlined), a plain "Sesori" title and a status line. Copy is hard-coded
  English. The status line changes the column height, so the content jumps
  about 16 px when an attempt starts. Its doc comment says Apple is
  "native-iOS-only".
- `LoginCubit` (`client/module_core/lib/src/cubits/login/`) drives every
  provider. For GitHub, Google and Apple it calls
  `OAuthFlowProvider.startOAuthFlow`, launches `AuthInitResponse.authUrl` in
  the system browser, then `pollForResult`. `LoginPolling` carries no data.
  A failed launch is terminal: `LoginFailed(browserOpenFailed)`, and the poll
  never starts. There is no way to cancel or reopen an attempt.
- `AuthManager` (`client/module_auth/lib/src/auth_manager.dart`) posts
  `/auth/{provider}/init` with the desktop descriptor from
  `DesktopOAuthDeviceDescriptorProvider` (`app_macos` / `app_windows` /
  `app_linux` plus the machine name), then polls `/auth/session/status` every
  250 ms until the server's expiry (five minutes). Ownership of the flow is the
  in-memory session token and generation; token persistence already requires
  that ownership. Denied and server-expired sessions end as `StateError`, which
  the cubit reports as `LoginFailed(unknown)`.
- The phone (`client/app/lib/features/login/`) offers GitHub, Apple (native,
  iOS only), Google and a sign-in-only email sheet, with the aurora background,
  logo and the `loginAgreementText` legal sentence. Its strings already live in
  `module_app_ui`'s `app_en.arb`.
- The bridge CLI (`bridge/app/lib/src/runtime/bridge_runtime_auth.dart`)
  offers GitHub, Google, Apple and email, remembers `lastProvider`, and signs in
  to Apple through the same browser flow (`/auth/apple/init`).
- The desktop auth gate (`client/desktop/lib/features/auth_gate/auth_gate.dart`)
  swaps the login screen for the cockpit as soon as `AuthGateCubit` reports
  signed in. The supervised bridge follows the desktop session.
- The window's minimum size is 560×480 (`WindowBoundsService.minimumSize`).
  The top 54 px band drags the window on every screen, including sign-in
  (`docs/regression/desktop-cockpit-shell.md`).

## Prerequisite: Apple Through The Browser From Desktop

Confirmed from code, with one live check left for step 4.

- `sesori_auth_server/src/routes/auth/apple.ts` (local checkout, read
  2026-09-25): `POST /auth/apple/init` uses the same
  `parseOAuthPendingInitBody` as GitHub and Google, and `init.ts` documents
  that `clientType` is validated against the enum (which includes `app_macos`,
  `app_windows` and `app_linux`) and recorded for display, "NOT used for any
  security decision". The redirect is the server's own
  `/auth/apple/callback` (form post), the same one the CLI's
  `bridge_*` client types already use, so no Apple Services ID change is needed.
- Client side, `AppleAuthProvider` is already an `OAuthProvider`, so
  `LoginCubit.loginWithProvider(AuthProvider.apple)` compiles and reaches
  `/auth/apple/init` today.
- **Live check (gate for step 4):** before the Apple button ships, complete one
  real Apple sign-in from a macOS desktop dev build against the deployed auth
  server, and record it in `steps/step-04.md`. If the deployed server rejects
  it, stop step 4's Apple button and ask the user; the rest of step 4 proceeds.
  *Step 4 outcome:* the gate was narrowed to an unauthenticated
  `/auth/apple/init` probe for `app_macos`, which returned an Apple authorize
  URL, so the button shipped. The full sign-in waits for the user's Apple ID
  and is covered by the step 8 macOS row ([step 4](steps/step-04.md)).

## Decisions

User decisions of 2026-09-25 (the user approved directions A and C together
and said no further review is needed):

- **D1 Direction A.** A provider-first split window. A brand panel on the left
  (aurora background, logo, one-line pitch). The sign-in column on the right:
  GitHub, Apple and Google as equal `PregoButtonsSolid` primaryAlt xl buttons
  with provider logos and a "Last used" chip; a quiet tertiary "Sign in with
  email" that opens an inline form in the same column; the legal sentence. A
  waiting card shows the provider, the device name the browser page will ask to
  confirm, an expiry countdown, and Open again / Copy link / Cancel. Expired,
  declined and browser-failed states appear inline.
- **D2 Responsive rule (approved verbatim).** Below about 820 pt wide the brand
  panel folds away and the layout becomes direction C's single centred column:
  logo on top, then providers, email, legal. The minimum window stays 560×480;
  on short windows the column scrolls. The waiting card replaces the provider
  buttons in place. Across the breakpoint the form keeps its position while the
  brand panel fades and slides away.

Defaults adopted from the review page's recommendations. The user did not
answer these one by one; **each is a default the user may override**:

- **D3 Apple on macOS, Windows and Linux** through the browser flow
  (`/auth/apple/init`). No native macOS Sign in with Apple.
- **D4 Email and password stay** as the last, quiet option, sign-in only (no
  sign-up or reset in the app).
- **D5 Keep the polling handoff.** No loopback server, no `sesori://` deep link.
  The window comes to the front after an interactive sign-in instead.
- **D6 Cancel, Open again, Copy link and a countdown** on the waiting card.
  Copy link covers a hidden browser and Linux without a working opener. The
  CLI already prints the same URL and the server's confirmation page names the
  device, so the copied link adds no new exposure.
- **D7 Account linking is out of scope.** Server behaviour is unchanged.
- **D8 Keep the desktop/bridge login split.** The supervised bridge follows the
  desktop session; a standalone CLI bridge keeps its own token and is never
  imported.
- **D9 "Last used" is local only**: one provider value on this computer,
  kept across sign-out, like the CLI's `lastProvider`.
- **D10 Terms and Privacy on desktop**: the phone's `loginAgreementText`
  sentence; the links open in the browser because the desktop has no in-app
  legal sheet.
- **D11 No new analytics events.** The existing login funnel covers it (see
  Analytics).
- **D12 Share the email form and error copy with the phone**; layouts stay per
  shell and logic stays in `LoginCubit`.

Planning decisions:

- **D13 No held success card.** Direction A's mock shows "You're signed in"
  for about a second. The auth gate swaps to the cockpit as soon as the token
  is saved, which disposes the login screen, so showing it would need a hold
  timer in the gate. The window comes forward and the cockpit appears
  instead. The user may ask for the hold; it would be one small addition to
  step 6.
- **D14 A failed browser launch keeps waiting.** Instead of a terminal
  failure, the attempt keeps polling and the card offers Copy link and Try
  again (mock 2b). This replaces `LoginFailedReason.browserOpenFailed`. The
  phone gets a Cancel link in its waiting line (below) because it shares the
  cubit.
- **D15 Phone Apple stays native on iOS and absent on Android** in this plan.

## Explicitly Excluded

Native macOS Apple sign-in; Apple on Android; account linking; sign-up or
password reset; loopback or deep-link handoff; a server-side cancel endpoint
(the pending session expires on its own); importing CLI bridge tokens; changes
to the phone login layout beyond the shared email form and the lockstep
waiting-line change in step 2; the account pages' duplicated sign-in method
(review ST2).

## Architecture

Dependencies keep the existing direction: `module_auth` (API/repository) →
`module_core` `LoginCubit` (service/consumer logic) → `module_app_ui` shared
widgets → desktop and phone shells.

### 1. `module_auth`: describe, cancel and classify a browser flow (step 2)

- `OAuthFlowProvider.startOAuthFlow` returns a new client model
  `OAuthHandoff({required Uri authUrl, required DateTime expiresAt, required
  String deviceName})` (`module_auth/lib/src/models/oauth_handoff.dart`,
  exported from `sesori_auth.dart`) instead of the wire `AuthInitResponse`.
  `AuthManager` already computes `expiresAt` and has the descriptor's
  `device.name`. The only consumer is `LoginCubit`.
- `OAuthFlowProvider.cancelOAuthFlow()` captures the current
  `_oAuthSessionToken` and `_oAuthSessionGeneration` and **releases
  ownership synchronously**, before awaiting anything. A completion already
  inside `_persistAuthenticatedResult` re-checks ownership after each of its
  awaits, so it fails its next check, clears the tokens it wrote and returns
  false; the only completion that still wins is one that emitted
  authenticated before Cancel ran, and by then the gate has already replaced
  the login screen. Afterwards, under the mutation lock, it clears the pending
  OAuth storage only while no newer flow owns the manager (the in-memory token
  is still unset) and the stored session token equals the captured one, so a
  cancel never clears a flow the user started meanwhile. The in-flight
  `pollForResult` ends at its next ownership check with the existing
  superseded error. No server call: the pending session expires server-side,
  and nobody else holds its session token.
- Denied and server-expired statuses throw typed `OAuthFlowDenied` and
  `OAuthFlowExpired` exceptions (`module_auth/lib/src/models/oauth_flow_errors.dart`,
  exported) instead of `StateError`; each keeps the status context in its
  message. Other status errors are unchanged.
- Step 6, its only consumer, adds this with "Last used" (moved out of step 2
  by its implementation review, since nothing reads it earlier).
  `startOAuthFlow` also records the flow's provider in memory, keyed by its
  session token. Releasing ownership keeps that record, so a flow resumed after
  its in-memory ownership was released still finds its provider; that happens
  on the phone when a backgrounded poll is interrupted and `_onAppResumed`
  resumes it (`_releaseOAuthSessionIfOwned` runs in the interrupted poll's
  `finally`). A fresh process never resumes a flow: a new `LoginCubit` has no
  attempt. Step 6 deviation: memory alone covers that one in-process resume, so
  the provider is not written to `OAuthStorageService`'s `oauth_provider` slot,
  which saves a storage write and its cleanup. Step 6 uses the provider to
  record "Last used".

### 2. `module_core`: `LoginCubit` owns the handoff (step 2)

- New immutable `LoginHandoff({required OAuthProvider provider, required
  OAuthHandoff oauth, required LoginBrowserLaunch browser})` with
  `enum LoginBrowserLaunch { opened, failed }`, both under
  `module_core/lib/src/cubits/login/` and exported through `sesori_dart_core`.
  It composes the auth model rather than copying its fields.
- `LoginState.polling({required LoginHandoff handoff})`. Every polling
  emission, including the phone's resume and interruption paths, carries it.
  The cubit's attempt is sealed: a pending variant (email, native Apple, or
  a browser sign-in before init returns) and a browser variant that owns a
  non-null handoff and replaces the pending one once init returns. Only the
  browser variant polls, reopens or cancels.
- `cancel()`: ends the current OAuth attempt, reports its terminal failure
  cause (rule below), calls `cancelOAuthFlow()` (a failure there is logged and
  still ends in idle), and emits idle at once.
- `reopenBrowser()`: launches the handoff URL again and re-emits polling with
  the new launch result, only while the same attempt still owns the flow, so
  a launch that returns after Cancel is discarded. The server accepts the same URL until the provider
  callback consumes its state; after that the provider shows its own error
  page and the poll still ends normally.
- A failed launch emits polling with `browser: failed` and keeps polling
  (D14).
- **One terminal-cause rule.** The OAuth attempt records whether any launch
  (first or reopen) ever succeeded. A cancel or timeout of an attempt whose
  browser never opened reports `launch`; otherwise a cancel reports
  `cancelled` and a timeout `timeout`. The cause is chosen once, from that
  attempt state, before the single terminal report, so it never depends on
  call order. The funnel keeps meaning "the browser never opened and the
  user did not recover".
- `OAuthFlowExpired` → `LoginTimeout`; `OAuthFlowDenied` → new
  `LoginFailedReason.declined`. `LoginFailedReason.browserOpenFailed` is
  removed.
- Lockstep consumers: the phone login screen and `login_failed_reason_x.dart`
  drop `browserOpenFailed` and map `declined`. The phone's waiting line shows
  a Cancel link in every `LoginPolling` state, because the phone disables its
  provider buttons while polling and would otherwise trap a user who returns
  without finishing; the existing "couldn't open the browser" copy appears
  only when `browser == failed`. The current desktop screen compiles against
  the new state and is replaced in steps 4–5.

### 3. `module_app_ui`: shared email form (step 3)

- Move the form body of `client/app/lib/features/login/email_login_sheet.dart`
  into `module_app_ui/lib/src/features/login/email_login_form.dart`
  (`EmailLoginForm`). It reads `LoginCubit` from context, owns its
  controllers and inline failure, and hands a success to its host through
  `onSignedIn`. The phone sheet keeps its modal wrapper, stale-error clearing
  and pop after success, and hosts the shared form. Step 4 adds the `onBack`
  callback for the desktop's "Other ways to sign in" together with its only
  consumer.
- Review LG2 (no blue required asterisks, readable placeholder) was already
  fixed by visual-hierarchy step 8; step 3 verified it and changes no styling.
- Shared error copy: one `LoginFailedReason` → localized message extension in
  `module_app_ui`, used by both shells (replaces the phone-only extension).

### 4. Desktop shell (steps 4–6)

- `LoginView` becomes a `LayoutBuilder` split: brand panel plus sign-in
  column at 820 pt and wider, the centred single column below it. The brand
  panel animates out with the visual-hierarchy motion tokens while the form
  keeps its position. Both layouts wrap the column in a scroll view so 480 pt
  tall windows work. The 54 px drag band stays live.
- Provider buttons are desktop widgets (layouts stay per shell, D12) using
  `PregoButtonsSolid` primaryAlt xl with logos; email is tertiary. Choosing
  email swaps the provider list for `EmailLoginForm` in the same column.
  Switching either way clears a pending `LoginFailed` through
  `onDismissedLoginFailureError()`, so a provider failure never shows as an
  email failure and an email failure never outlives the form.
- The legal sentence renders `loginAgreementText`; links open through the
  existing `UrlLauncher`.
- `_DesktopHandoffCard` renders `LoginPolling.handoff` in place of the provider
  list: provider, device name, countdown, Open again, Copy link, Cancel. The
  countdown is a one-second ticker inside the card's own state; Copy link uses
  the clipboard directly. Browser-failed shows the copy under
  [Approved copy](#approved-copy) with Copy link and Try again
  (`reopenBrowser`). Timeout and failure show an inline notice
  above the re-enabled buttons with a fixed-height slot, so nothing jumps.
- All copy moves to `app_en.arb` in `module_app_ui` (English is the only
  locale today).
- **Last used (step 6).** `AuthManager` records the provider of each
  interactive login it persists. Both `_persistAuthenticatedResult` callers are
  interactive: the OAuth path passes the provider recorded at
  `startOAuthFlow` (section 1), and `_completeInteractiveLogin` passes email
  or Apple explicitly. The one storage owner is a new Layer-1
  `module_auth/lib/src/storage/last_sign_in_storage.dart`, used by
  `AuthManager` like `TokenStorageService` and `OAuthStorageService`; the
  write is best effort and logged on failure. `_clearLocalAuthState`
  deliberately leaves the key alone, so it survives logout. `AuthSession`
  exposes `lastSignedInProvider()`. A small `LastSignInProviderCubit`
  (`Cubit<AuthProvider?>`) in `module_desktop_core` loads it once for the
  login screen. `LoginScreen` constructs it next to `LoginCubit`, in a
  `BlocProvider(create:)` with `authSession: getIt()`, matching how the screen
  builds `LoginCubit` today; `LoginView` reads both from context. The chip
  sits on the matching provider button; when the last method was email, the
  "Sign in with email" link carries a quiet "Last used" marker instead, since
  email is a supported method and the value is recorded anyway. Step 6 records at its start which storage backend the new
  class sits on: today's `SecureStorage`, or the typed replacement if
  `desktop-master-key-storage` has cut storage over by then.
- **Window forward (step 6).** `AuthGateCubit` gains a `WindowHost`
  dependency and calls `show()` (as `BridgeControlCubit.showWindow` does,
  failures logged) on the signed-out → signed-in transition only. Startup
  restore goes checking → signed-in and must not un-hide a window launched
  hidden at login. The construction site in
  `client/desktop/lib/features/auth_gate/auth_gate.dart` adds
  `windowHost: getIt()`, and the gate's test fakes follow; `WindowHost` is
  already registered in DI.

## Approved Copy

Literal English copy from the reviewed direction A mocks, recorded here
because the review page stays local. `{provider}` is GitHub, Apple or Google;
`{device}` is `OAuthHandoff.deviceName`; `{m:ss}` counts down to
`OAuthHandoff.expiresAt`. Steps 4–5 add these to `app_en.arb`; wording may be
polished in review, but not the meaning.

| State | Copy |
|---|---|
| Brand panel | "Sesori" · "Watch and steer your coding sessions from your desk or your phone." |
| Idle (`LoginIdle`) | Title "Sign in" · subtitle "Use the same account as on your phone." · buttons "Continue with GitHub", "Continue with Apple", "Continue with Google" · quiet "Sign in with email" · chip "Last used" |
| Legal (every state but success) | the existing `loginAgreementText`: "By signing in, you accept our Terms of Use and Privacy Policy." |
| Email form | Title "Sign in with email" · "For accounts created with an email and password." · fields "Email", "Password" · button "Sign in" · link "← Other ways to sign in" |
| Waiting (`LoginPolling`, `browser: opened`) | Title "Continue in your browser" · "We opened {provider} sign-in in your browser. The page will ask you to confirm “{device}”. Come back here when it is done." · "The link expires in {m:ss}" · "Open again", "Copy link" · "Cancel and choose another way" |
| Browser failed (`LoginPolling`, `browser: failed`) | Title "Couldn’t open your browser" · "Copy the link, open it in any browser on this computer, and finish signing in there. We are still waiting." · "The link expires in {m:ss}" · "Copy link", "Try again" · "Cancel and choose another way" |
| Expired (`LoginTimeout`) | Notice "The sign-in link expired" · "Nothing was confirmed in the browser within 5 minutes. Choose a way to sign in again." Provider buttons return below it. |
| Declined (`LoginFailed(declined)`) | Not drawn in the mocks, which paired it with the expired notice; new copy: "Sign-in was declined" · "The browser page did not confirm this sign-in. Choose a way to sign in again." |
| Other failures (`LoginFailed`) | The shared `LoginFailedReason` copy from step 3 (for `unknown`, the existing `loginError`). |

## Analytics

Checked against `.opencode/skills/add-analytics/SKILL.md`: account-less login
belongs to `InstallationAnalyticsService`'s started/completed/failed funnel,
which `LoginCubit` already reports per `AuthProvider` (Apple and email
included) with the causes `authentication`, `launch`, `cancelled`, `timeout`
and `unknown`. Open again, Copy link and the "Last used" chip are UI
details, not product decisions. No new events or parameters.

The desktop sends no analytics today: its registered `AnalyticsClient` is
`NoOpAnalyticsClient` (asserted in `client/desktop/test/core/di/injection_test.dart`).
This plan accepts that desktop sign-in adoption, cancels and launch failures
are not observable; wiring desktop analytics delivery is a separate decision
outside this plan. The cubit's cause changes still reach the phone's funnel.

## Security And Privacy

- The copied link is the same URL the CLI prints. Tokens reach only the holder
  of the session token (this process), and the server's confirmation page names
  the requesting device, so completing a copied link elsewhere cannot hand
  tokens to another machine.
- Cancel is final on the client: it discards the session token, so a later
  browser confirmation cannot deliver tokens here.
- "Last used" stores only a provider key, no email or account data. The
  device name shown on the card is the local machine name already sent at init.
- Logs keep existing detail; no auth URL or password is added to logs.

## Complexity Budget

New mutable parts:

1. The OAuth attempt's handoff slot in `LoginCubit` (set once init returns,
   replaced on reopen). Needed so resume, reopen and cancel act on the right URL.
2. One persisted provider key for "Last used". Needed to survive sign-out.
   The in-flight flow's provider is one in-memory record keyed by its session
   token, replaced by the next `startOAuthFlow` (step 6 deviation, section 1).
3. `LastSignInProviderCubit` state (one nullable value, loaded once).
4. The card's countdown ticker (UI only, disposed with the card).

Deliberately not added: a hold timer for a success card (D13), a server
cancel call, a loopback server or URL scheme, a native Apple path, a separate
desktop login cubit, retries or backoff beyond today's poll, a stored
last-used email, and any coordination between the login cubit and the gate
beyond the existing auth state.

## Cleanup Assessment

In the owning steps: `LoginFailedReason.browserOpenFailed` and its copy
(step 2); the phone-only failure-message extension and the phone-only email
form body (step 3); the desktop `_LoginStatus`, `_StatusRow`, hard-coded
strings and the "native-iOS-only" comment (steps 4–5). No other obsolete code
was found. The phone `LoginProviderButtons` stays: layouts stay per shell.

## Proportionality And Accepted Risk

- Evidence: the trap, missing providers and weak errors are observed on
  origin/main (review page screenshots, 2026-09-25).
- Accepted: a cancelled attempt's pending server session lingers until its
  five-minute expiry; reopening a consumed link shows the provider's error page;
  "Last used" may name a provider from an account that has since changed.
- Accepted: the countdown uses the client clock from init time, like the poll.

## Regression Coverage

Affected feature document: `docs/regression/account-and-onboarding.md`
(required behavior, levels, failure signals). `desktop-cockpit-shell.md` is
touched only if the drag-band sentence about the login screen changes.

**Highest level: L3 Release** (every sign-in option on the release-target
client platform, per the account document).

Required matrix, recorded now; any reduction needs the user's acceptance in
this file before retirement:

| Platform | Coverage |
|---|---|
| macOS desktop (release target) | GitHub, Apple, Google and email to the cockpit; Cancel then another provider; Open again; Copy link completed in another browser; declined; expiry at five minutes; browser-failed path (launcher stubbed in a dev build); last-used chip after sign-out; window comes forward; split and folded layouts at 820 pt and at 560×480; drag band. |
| Windows desktop | Apple and one other provider through the browser; Copy link; folded layout. |
| Linux desktop | Apple and one other provider through the browser; Copy link, including without a working opener. |
| iOS phone | Email sign-in through the shared form; one browser provider; native Apple unchanged. |
| Android phone | Email sign-in through the shared form; one browser provider. |

Automated coverage in the steps: `AuthManager` cancel and typed-error tests,
`LoginCubit` tests for cancel, reopen, launch failure and resume, and widget
tests for both desktop layouts, the handoff card and the phone waiting line.

## Delivery Rules

- Steps run in order, one open PR at a time. Step 3 depends on step 2: both
  touch the phone's `LoginFailedReason` copy, which step 2 edits and step 3
  moves into `module_app_ui`.
- Each step verifies the plan's claims before editing, writes its evidence to
  `steps/step-NN.md` in its own PR, and updates `account-and-onboarding.md`
  for the behavior it ships. Step 7 reconciles the document as a whole.
- Before and after screenshots with fixture accounts only, per AGENTS.md.
- Architecture implementation review for steps 2, 3 and 6 (new classes,
  shared contracts, DI).
- Size targets are in the tracker; step 2 is the largest risk and should stay
  well under the soft cap.

## Steps

**Step 1 — this plan.** Published as visual-hierarchy step 38.

**Step 2 — cancellable, described browser sign-in.** Architecture sections 1
and 2 plus the phone waiting-line change. Verify: `module_auth` and
`module_core` tests (cancel during a pending poll, cancel racing a complete
response saves nothing, cancel then an immediate new start keeps the new
flow, a completion already persisting when Cancel runs saves nothing, the
terminal-cause rule, reopen, launch failure keeps polling and reports
`launch` on cancel/timeout, the phone Cancel link in every waiting state, expired → timeout, denied → declined, resume
paths carry the handoff), phone login widget test, analyze the three packages.

**Step 3 — shared email form.** Architecture section 3. Verify: moved and new
widget tests for the form on both shells, phone email sign-in by hand once.

**Step 4 — desktop layout with Apple and email.** Run the Apple live check
first (Prerequisite). Build D1's idle layout and D2's responsive rule, the
Apple/GitHub/Google buttons, the inline email form, the legal sentence and
the localized strings. Waiting still uses a minimal status line until step 5.
Verify: widget tests at 1,200×800, 819×800 and 560×480; a provider failure
followed by switching to email shows no error in the form; drag band; before
and after screenshots, both themes.

**Step 5 — handoff card and inline errors.** The waiting card, mock 2a and 2b
states, fixed-height notice slot. Verify: widget tests for each state and the
countdown; a real GitHub cancel, reopen and copy-link run on macOS.

**Step 6 — last used and window forward.** Verify: `AuthManager` records on
both interactive paths and keeps the key through logout; the OAuth flow's
provider survives an interrupted-poll resume (section 1); the gate shows the
window only on signed-out → signed-in; widget tests for the chip on a
provider button and the marker on the email link; a `LoginScreen` composition
test with fakes registered in `getIt` (as the new-session screen test does)
showing the stored provider's chip.

**Step 7 — regression docs.** Reconcile `account-and-onboarding.md`: desktop
sign-in options, handoff controls, failure signals (a trapped waiting state, a
cancelled attempt later signing in, the chip leaking account data) and the
matrix above.

**Step 8 — verify and retire.** Run L3 over the recorded matrix, record the
result in `steps/step-08.md`, and move the plan to `.plan/completed/`.

## Later Phases (rough intent only)

- **Apple on Android** through the same browser flow, so Android users who
  signed up with Apple can sign in. Separate shell work.
- **Phone waiting card**: bring Open again and Copy link to the phone's
  waiting state if phone users hit the same trap.
- **Native macOS Apple sign-in**, only if the browser flow proves clumsy;
  needs an entitlement, signing setup and a second code path.
- **Account linking** across providers; server-side, with its own security
  review.

## Open Questions

- The adopted defaults D3–D12 and the planning decisions D13–D14 stand until
  the user overrides them. D13 (no held success card) departs from mock 3.
- Who has email accounts today? If only reviewers and testers, D4 could make
  email even quieter.
- Can the Windows and Linux rows of the matrix run on real machines, or does
  the user accept a smaller matrix there?

## Plan Review Record

`architecture-plan-review`, 2026-09-25: **rejected** with six concrete,
non-vague findings, all applied directly without re-review (per AGENTS.md):

1. The OAuth path had no provider for "Last used": `startOAuthFlow` now
   records it in memory and in the existing `oauth_provider` storage slot.
2. The "Last used" storage owner was ambiguous and skipped a layer: one new
   Layer-1 `LastSignInStorage`, untouched by `_clearLocalAuthState`; step 6
   records its backend.
3. `cancelOAuthFlow()` could clear a newer flow: it now captures the token and
   generation synchronously and acts only if they still own the flow, with a
   test.
4. New types lacked locations and exports: paths and exports named.
5. `LoginHandoff` duplicated fields: it now composes `OAuthHandoff`.
6. The `AuthGateCubit` wiring change was unlisted: construction site and test
   fakes listed.

The revised plan has not been re-reviewed; this record does not claim it
passed.

Codex review of PR #1740, 2026-09-25 (seven threads), applied to the plan:
cancel releases ownership synchronously (P1); the desktop's no-op analytics
is recorded as accepted; one terminal-cause rule; the phone Cancel link shows
in every waiting state; step 3 now depends on step 2; the stored provider is
justified by the in-process interrupted-poll resume, not a relaunch; the
approved copy is recorded above.
