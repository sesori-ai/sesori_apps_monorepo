# Account And Onboarding

## Capability

Signing into a Sesori account from the app, restoring or ending that session, and
the first-run guidance that reaches a working bridge: the empty-Projects
onboarding and the bridge's standalone install/open-app prompt. No coding plugin
participates.

## Required Behavior

- Every sign-in option the build offers reaches an authenticated session; failure
  gives a typed recoverable reason, and leaving the app mid sign-in is not terminal.
- A browser sign-in waiting for the user can always be cancelled, on the phone
  and the desktop. Cancel returns to idle at once, and a later confirmation of
  that browser page can never save tokens here; a sign-in started right after
  Cancel is unaffected. A browser that fails to open keeps the attempt waiting
  and says so instead of failing. A declined page fails as declined and a
  server-expired session ends as timed out.
- Email sign-in uses one shared form on every shell that offers it: it
  validates before submitting, shows a failure inline next to the fields, and
  marks no field with a required asterisk. Every shell shows the same message
  for each login failure reason, except a declined browser page, which the
  desktop words as a call to choose another way.
- The desktop offers GitHub, Apple and Google through the browser and email
  inline, with the Terms and Privacy sentence opening in the browser. From 820
  points wide a brand panel sits beside the sign-in column; narrower, it folds
  away and the logo tops the column, which keeps what was typed across the
  change and scrolls at the 560×480 minimum. Switching between the providers
  and the email form clears a pending failure, so a provider failure never shows
  inside the form and an email failure never outlives it.
- On the desktop, a browser sign-in replaces the buttons with a card that names
  the provider and the device the page will ask to confirm, counts down to the
  link's expiry, and offers Open again, Copy link, and Cancel and choose another
  way. A browser that fails to open turns the card into Copy link and Try again.
  An expired, declined or failed sign-in shows its notice in the heading's place
  above the re-enabled buttons, which stay put as it appears and clears.
- Startup routing uses local session state only, with no network work at splash.
- Client tokens are encrypted rows in shared persistence with an OS-protected
  master; auth owns runtime mutations. Tokens refresh before expiry and are
  cleared on logout; the connection follows logout. Startup reads stored tokens
  once before deciding whether validation or a fresh login is needed. Logout
  fences in-flight login, refresh, and restore results, so none can re-save
  credentials or emit authenticated after local sign-out. The auth server's
  definitive `/auth/refresh` 401 invalid/revoked response clears persisted
  tokens and user data before emitting unauthenticated; non-definitive 4xx,
  transport, and other server failures leave credentials intact. Standalone
  bridge logout remains clean and idempotent when tokens are
  already absent or the saved authentication session has expired. Non-sandboxed
  macOS desktop builds protect the master through flutter_secure_storage's classic
  Keychain mode, without a provisioned Data Protection Keychain access group.
  Android native failures never automatically reset persisted data.
- Production mobile imports released native auth/OAuth state before restoration,
  preserving encodings and cleaning only successfully copied items after all
  copies commit. Import failure disposes startup and shows close/reopen recovery,
  not a false fresh-login state. Development leaves that source untouched. See
  [client persistence](client-persistence.md) for the complete upgrade/restore matrix.
  Desktop is unpublished: sign out in the old per-value build before replacing it,
  then sign in once; new-store logout does not revoke the old build's session.
- Log out asks first on both apps; only its confirmation starts logout, and
  Cancel or dismissal leaves the session untouched.
- The desktop marks the method this device last signed in with: a "Last used"
  chip on that provider's button, or a quiet marker on the email link. Only the
  provider key is stored, on this device, and it survives logout. Signing in
  brings the desktop window forward; a startup restore never does, so a
  `--hidden` launch with a restored session stays hidden.
- Auth-server URLs behave identically with or without trailing slashes, and
  deadline expiry actively aborts registration and token-refresh transport,
  including response-body consumption.
- With no bridge, mobile Projects shows install/start commands, the explainer and support links; copy/share
  hand off the command unchanged. Desktop home instead offers supervised local bridge recovery.
  Connected with no projects shows the add-project call to action on either surface.
- With a registered bridge offline, mobile Projects names the computer once, in
  the bar's bridge line when the name is known, under a "Bridge offline" heading
  with when it was last seen when that is known, and keeps the start command above
  quiet explainer, install and help links.
- Desktop first-run startup preferences and optional macOS file-access guidance follow the
  [cockpit contract](desktop-cockpit-shell.md) and [supervision contract](desktop-bridge-supervision.md).
  Dismissing guidance does not grant permission or block ordinary project navigation.
- Copying install or start commands on onboarding or bridge-disconnected pages
  shows the informational "Command copied to clipboard" popup, not the success
  variant.
- An account that never registered a bridge parks offline silently; the
  bridge-offline banner is reserved for accounts that have one.
- A persisted registered-bridge read that completes after logout cannot restore
  the signed-out account's latch or leak it to the next account.
- The bridge prompt appears only once the bridge is locally ready to serve, never
  after a failed or cancelled start, and never for an account known to have the app.
- The prompt costs one immediate registration check and never polls; push
  registration and an unavailable status endpoint never gate relay readiness.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Signed-in launch restores the local session and reaches Projects with no network work at splash; the macOS desktop restores a shared-store token using its classic-Keychain master; a bridge start reaches readiness. Client end to end plus headless bridge; no plugin. |
| L2 Routine | One provider through sign-in and logout on the release-target client platform, including an in-flight restore/refresh race and definitive refresh rejection, plus the prompt decision for marker-present, already-registered, and absent accounts. Client end to end plus headless bridge; no plugin. |
| L3 Release | Every sign-in option on the release-target client platform, both empty-Projects states, and prompt ordering proved by a real client joining, completing key exchange, and issuing a request while the prompt shows. Client end to end plus relay integration; no plugin. |
| L4 Extended | Android native storage failure without an automatic data reset, background/resume mid sign-in, unreachable or rejecting auth server, expiry refresh, logout while connected, logout during restore/login persistence, refresh rejection followed by relaunch, withheld push registration, delayed status check, second mobile platform. Client end to end where the app observes it, headless where the bridge owns it. |
| L5 Full | Store builds: native Apple sign-in on a real device, email flow, legal and analytics-preference surfaces, marker rewrite after a fresh install, and the status-endpoint-unavailable path against an older auth deployment. Packaged or external; no plugin. |

## Exploration Guidance

Vary the provider, whether the account is new or already marked, whether app or
bridge is set up first, and where sign-in is interrupted. Vary copy versus share,
OS group, and install method. Prefer a fresh bridge data directory when testing
the prompt and a reused one when testing suppression.

## Failure Signals

- Splash doing network work, or routing a valid session to sign-in.
- A recoverable interruption surfacing as terminal, or a real failure as silent.
- A waiting browser sign-in without Cancel, a cancelled attempt later signing in,
  or Cancel clearing a sign-in started after it.
- Tokens surviving logout, an in-flight login/refresh/restore re-saving tokens or
  emitting authenticated after logout, a malformed or non-2xx login response
  persisting tokens, a rejected refresh leaving credentials
  restorable after relaunch, a transport failure clearing a usable session, or
  macOS OAuth completion failing with a missing Keychain entitlement (`-34018`),
  or an Android storage error silently resetting credentials/preferences.
- Migration losing auth/OAuth fields, starting restoration before copy/cleanup
  completes, or presenting ordinary sign-in after a failed import.
- A delayed persisted registered-bridge read restoring the previous account's
  offline banner or recovery flow after logout.
- The prompt appearing before readiness, after a failed start, on an account that
  already has the app, or driving repeated status requests.
- Relay availability or key exchange waiting on push registration or the check.
- The bridge-offline banner alarming an account with no registered bridge.
- One tap on Log out signing the user out without the confirmation.
- The "Last used" marker on a method other than this device's last sign-in or
  gone after logout, a desktop sign-in leaving the window behind, or a startup
  restore showing a `--hidden` launch.

## Known Limitations

- Readiness is local; the relay never acknowledges bridge auth, so a pass does not
  prove relay acceptance.
- The prompt's QR and link are account-generic and cannot prove pairing with one bridge.
- An app installed during a bridge run is marked only at a later start.
- Supervised desktop starts do not show the standalone bridge's install/open-app prompt.

## Sources

- Client auth, login, splash, registered-bridge, and project onboarding code and tests.
- Bridge app-client onboarding service and runtime runner, plus their owning tests.
- Historical: `.plan/completed/bridge-ready-onboarding/`
