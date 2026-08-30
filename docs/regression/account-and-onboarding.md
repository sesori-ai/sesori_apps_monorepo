# Account And Onboarding

## Capability

Signing into a Sesori account from the app, restoring or ending that session, and
the first-run guidance that reaches a working bridge: the empty-Projects
onboarding and the bridge's standalone install/open-app prompt. No coding plugin
participates.

## Required Behavior

- Every sign-in option the build offers reaches an authenticated session; failure
  gives a typed recoverable reason, and leaving the app mid sign-in is not terminal.
- Startup routing uses local session state only, with no network work at splash.
- Tokens live in secure storage with one writer, refresh before expiry, and are
  cleared on logout; the connection follows logout. Startup reads stored tokens
  once before deciding whether validation or a fresh login is needed. Logout
  fences in-flight login, refresh, and restore results, so none can re-save
  credentials or emit authenticated after local sign-out. A definitive
  `/auth/refresh` 4xx rejection clears persisted tokens and user data before
  emitting unauthenticated, while transport/server failures leave credentials
  intact. Standalone bridge logout remains clean and idempotent when tokens are
  already absent or the saved authentication session has expired. Non-sandboxed
  macOS desktop builds use the classic default Keychain without requiring a
  provisioned Data Protection Keychain access group.
- Auth-server URLs behave identically with or without trailing slashes, and
  deadline expiry actively aborts registration and token-refresh transport,
  including response-body consumption.
- With no bridge, Projects shows install and start commands, the explainer, and
  support links, and copy/share hand off the command unchanged; connected with no
  projects shows the add-project call to action instead.
- An account that never registered a bridge parks offline silently; the
  bridge-offline banner is reserved for accounts that have one.
- The bridge prompt appears only once the bridge is locally ready to serve, never
  after a failed or cancelled start, and never for an account known to have the app.
- The prompt costs one immediate registration check and never polls; push
  registration and an unavailable status endpoint never gate relay readiness.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Signed-in launch restores the local session and reaches Projects with no network work at splash; the macOS desktop adapter routes secure storage through its classic-Keychain client; a bridge start reaches readiness. Client end to end plus headless bridge; no plugin. |
| L2 Routine | One provider through sign-in and logout on the release-target client platform, including an in-flight restore/refresh race and definitive refresh rejection, plus the prompt decision for marker-present, already-registered, and absent accounts. Client end to end plus headless bridge; no plugin. |
| L3 Release | Every sign-in option on the release-target client platform, both empty-Projects states, and prompt ordering proved by a real client joining, completing key exchange, and issuing a request while the prompt shows. Client end to end plus relay integration; no plugin. |
| L4 Extended | Background/resume mid sign-in, unreachable or rejecting auth server, expiry refresh, logout while connected, logout during restore/login persistence, refresh rejection followed by relaunch, withheld push registration, delayed status check, second mobile platform. Client end to end where the app observes it, headless where the bridge owns it. |
| L5 Full | Store builds: native Apple sign-in on a real device, email flow, legal and analytics-preference surfaces, marker rewrite after a fresh install, and the status-endpoint-unavailable path against an older auth deployment. Packaged or external; no plugin. |

## Exploration Guidance

Vary the provider, whether the account is new or already marked, whether app or
bridge is set up first, and where sign-in is interrupted. Vary copy versus share,
OS group, and install method. Prefer a fresh bridge data directory when testing
the prompt and a reused one when testing suppression.

## Failure Signals

- Splash doing network work, or routing a valid session to sign-in.
- A recoverable interruption surfacing as terminal, or a real failure as silent.
- Tokens surviving logout, an in-flight login/refresh/restore re-saving tokens or
  emitting authenticated after logout, a rejected refresh leaving credentials
  restorable after relaunch, a transport failure clearing a usable session, or
  macOS OAuth completion failing with a missing Keychain entitlement (`-34018`).
- The prompt appearing before readiness, after a failed start, on an account that
  already has the app, or driving repeated status requests.
- Relay availability or key exchange waiting on push registration or the check.
- The bridge-offline banner alarming an account with no registered bridge.

## Known Limitations

- Readiness is local; the relay never acknowledges bridge auth, so a pass does not
  prove relay acceptance.
- The prompt's QR and link are account-generic and cannot prove pairing with one bridge.
- An app installed during a bridge run is marked only at a later start.
- The desktop shell is not shipped; supervised starts never show this prompt.

## Sources

- Client auth, login, splash, registered-bridge, and project onboarding code and tests.
- Bridge app-client onboarding service and runtime runner, plus their owning tests.
- Historical: `.plan/completed/bridge-ready-onboarding/`
