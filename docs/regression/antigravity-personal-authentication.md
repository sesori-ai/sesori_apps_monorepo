# Antigravity Personal Authentication

## Status and scope

Registered personal-login operation, boundaries and provider policy. Browser login requires a current mobile/desktop
client, not a bridge-host CLI fallback. Synthetic verification must never execute real Google OAuth or inspect ambient
credentials/token contents.

## Required behavior

- Profile preparation, runtime probing and authentication share one monotonic budget and abort signal. Browser
  preflight and chmod use the remaining budget, including source-mode compilation before the helper reaches its
  silent no-op. Check between mutations, await an in-flight filesystem/atomic-store write, then reject cancellation
  or expired-budget success. Cancellation is checked before and after the bounded preflight; it does not immediately
  interrupt the helper. No instant cancellation of uninterruptible filesystem work is promised.
- The generic client login-start request allows two minutes for preparation and backend challenge creation rather
  than the ordinary 30-second request timeout. Other plugin-management requests retain their existing deadlines.
- Scratch authentication validates the negotiated ACP version and selects only an advertised `oauth-personal`
  method before sending authentication. Incompatible protocols or other-only methods fail without auth dispatch.
  It uses the prepared environment with no
  parent inheritance, the official sibling harness, and the existing ACP process owner. It disposes on success,
  timeout, cancellation, malformed authorization output and process exit; late results cannot report success.
  Both initialize-only probing and authentication await an already-started spawn after disposal so a late child is
  reaped before reporting completion. Callback transport force-closes and awaits its started request too.
- The exact stdout prefix `Open the following link to authenticate the ACP server: ` is intercepted before logging
  or NDJSON parsing, including fragmented lines. Other bytes pass through. OAuth-bearing stderr is selectively
  consumed; useful diagnostics remain. Errors retain typed causes but their presentation never includes OAuth URLs,
  states or codes. Runtime rejection diagnostics retain source, missing/rejected component, pair issue, contract
  violations and runtime paths, or unsupported target rather than only a type name. No callback body is logged.
- Authorization must use `https://accounts.google.com/o/oauth2/v2/auth` with exactly one `response_type=code`, state
  (nonempty, at most 512 characters, no whitespace), and redirect URI. The redirect is exactly an explicit
  `http://127.0.0.1:<port>/` root with port 1024–65535. Reject user-info, fragments, other origins/paths and duplicate
  critical fields. Authorization URLs are bounded to 16384 characters.
- Continuations are bounded to 4096 characters and must match the issued callback endpoint and state exactly, with
  exactly one nonempty non-whitespace code. Reject OAuth error responses, duplicate state/code, user-info, fragments,
  and a non-Google or duplicate optional `iss`. Validation failure performs no HTTP.
- A dedicated injected HTTP client sends only the already-authorized callback GET, uses DIRECT rather than ambient
  proxy settings, never follows redirects, and closes on completion/timeout/abort. The repository normalizes 2xx
  versus rejected statuses before service policy. HTTP delivery alone is not evidence of authenticated ACP completion.
- The operation prepares the isolated profile, resolves/probes the runtime with that same environment and remaining
  budget, subscribes to authorization events, then authenticates. One challenge is exposed; a second fails closed.
  Same-host/already-authenticated completion requires no remote dispatch. A remote callback is claimed once before
  service validation/HTTP; failed dispatch does not permit replay. Callback HTTP success is not ACP login success.
- Event-stream cancellation aborts the attempt and waits for ACP, callback, and peer cleanup. Normal completion also
  waits for a callback already in flight, rather than aborting it when ACP finishes first. Closed attempts reject
  callbacks; their closures cannot dispatch through another attempt's services.
- The existing bridge `PluginLifecycleService` reinspects setup only after operation stream closure/error, including
  cancellation/failure. The plugin operation does not duplicate setup inspection or infer readiness from token
  presence. Registration adds no second lifecycle owner.

## Failure signals and coverage

- Any ambient credential access, authorization payload in logs, callback to a different host/port/path/state,
  redirected/proxied callback, post-cancel callback send, or successful late completion is a security regression.
- `antigravity_authentication_repository_test.dart`: real ACP adapter with synthetic process bytes; exact personal
  handshake, fragmented/malformed authorization, no-challenge completion, cleanup, timeout/abort/exit, safe causes,
  and normalized HTTP status outcomes. No real process or network is used by these tests.
- `antigravity_authentication_service_test.dart`: authorization and continuation attack tables, rejection before HTTP,
  valid Google issuer, response-status context, and expired-budget rejection.
- `antigravity_loopback_client_test.dart`: fake HTTP verifies exact GET, DIRECT, disabled redirects, awaited closure
  on timeout/abort and suppression of late sends, including a timer that wins while the finer-precision monotonic
  budget is still positive. The selected failure fences late connection completion; cleanup retains the original
  failure/stack. A local synthetic HTTP server proves dispatched requests settle
  through real forced client closure. No Google endpoint is contacted.
- `antigravity_profile_service_test.dart`: remaining-budget forwarding, executor timeout identity, no mutation after
  aborted preflight, and awaited atomic write before rejecting late success, in addition to the isolated-profile coverage.
- Client `plugin_api_test.dart`: the generic login-start request forwards its explicit two-minute timeout and retains
  typed challenge/redirect/cancel contracts.
- `antigravity_authentication_operation_test.dart`: shared environment/budget, one-shot continuation, same-host
  completion, runtime rejection, callback/authorization failure, timeout/process exit, cancellation while cleanup or
  callback work is in flight, and isolation from subsequent attempts.
- `antigravity_authentication_composer_test.dart`: full composition with real temporary runtime files,
  shared store scopes, fake host-spawned helper/probe/auth processes, exact personal handshake and complete disposal.
- `antigravity_acp_api_test.dart`: delayed probe/auth spawn cancellation waits for release and reaping without initialize.
- Bridge `plugin_lifecycle_service_test.dart`: representative browser terminal event cannot trigger setup reinspection
  until stream closure; cancelled attempts also refresh setup after settling.
- Real Google OAuth, cross-target native runtime execution and final L5 Full remain unverified.
