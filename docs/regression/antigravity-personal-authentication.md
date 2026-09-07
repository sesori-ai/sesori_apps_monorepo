# Antigravity Personal Authentication Boundaries

## Status and scope

Internal, unregistered boundaries and provider policy. This does not supply an executable composed login operation.
Operation-scoped challenge lifetime, one-shot dispatch, terminal setup reinspection and product activation are separate
steps. Never execute real Google OAuth or inspect ambient credentials/token contents to validate these foundations.

## Required behavior

- Profile preparation, runtime probing and authentication share one monotonic budget and abort signal. Browser
  preflight retains a five-second sub-limit; chmod uses the remaining budget. Check between mutations, await an
  in-flight filesystem/atomic-store write, then reject cancellation or expired-budget success. No instant cancellation
  of uninterruptible filesystem work is promised.
- Scratch authentication validates the negotiated ACP version and selects only an advertised `oauth-personal`
  method before sending authentication. Incompatible protocols or other-only methods fail without auth dispatch.
  It uses the prepared environment with no
  parent inheritance, the official sibling harness, and the existing ACP process owner. It disposes on success,
  timeout, cancellation, malformed authorization output and process exit; late results cannot report success.
- The exact stdout prefix `Open the following link to authenticate the ACP server: ` is intercepted before logging
  or NDJSON parsing, including fragmented lines. Other bytes pass through. OAuth-bearing stderr is selectively
  consumed; useful diagnostics remain. Errors retain typed causes but their presentation never includes OAuth URLs,
  states or codes. No request or response body is logged by callback transport.
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
- Subscribe to repository/service authorization events before starting authentication. These peers are scoped to one
  attempt; the future composed operation must own cancellation, await authentication cleanup, then dispose them.

## Failure signals and coverage

- Any ambient credential access, authorization payload in logs, callback to a different host/port/path/state,
  redirected/proxied callback, post-cancel callback send, or successful late completion is a security regression.
- `antigravity_authentication_repository_test.dart`: real ACP adapter with synthetic process bytes; exact personal
  handshake, fragmented/malformed authorization, no-challenge completion, cleanup, timeout/abort/exit, safe causes,
  and normalized HTTP status outcomes. No real process or network is used by these tests.
- `antigravity_authentication_service_test.dart`: authorization and continuation attack tables, rejection before HTTP,
  valid Google issuer, response-status context, and expired-budget rejection.
- `antigravity_loopback_client_test.dart`: injected fake HTTP client verifies exact GET, DIRECT, disabled redirects,
  closure on timeout/abort and suppression of late request sends.
- `antigravity_profile_service_test.dart`: executor timeout identity, no mutation after aborted preflight, and awaited
  atomic write before rejecting late success, in addition to the isolated-profile coverage.
- Evidence: owning Antigravity analyzer and package tests pass locally. Real Google OAuth, full composed operations,
  cross-target runtime execution and final L5 Full remain unverified; this document does not claim those capabilities.
