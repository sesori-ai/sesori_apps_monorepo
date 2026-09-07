# Antigravity Isolated Profiles

## Status and scope

Internal, unregistered profile foundations. No user-visible Antigravity capability or database change yet.
Composed personal OAuth operations, registration, and managed activation are separate delivery steps.
[Personal-authentication boundaries](antigravity-personal-authentication.md) cover callback policy and the shared
preparation/authentication budget; they do not yet supply a composed operation.

## Required behavior

- Inert inspection checks only `<plugin state>/profile/antigravity-acp/acp_token.json` existence. Presence is a
  readiness hint, never proof of valid authentication. No token contents, ambient credentials, or Google history
  are read, copied, parsed, or deleted.
- Preparation preflights browser suppression before creating files. POSIX profile and `antigravity-acp` directories
  are hardened to `700` before settings writes; permission failure blocks launch. POSIX `chmod` resolves through
  the sanitized environment's PATH rather than assuming `/bin/chmod`. Windows uses user-profile ACLs.
- Typed generated settings serialize exactly `{"auth":{"type":"oauth-personal"}}`. Storage receives the child
  `HostJsonStore` derived from the live host root via `profile` then `antigravity-acp`; atomic writes and shared
  per-file update ownership remain in the host store. A failed write surfaces with its original cause.
- Service filters injected host environment case-insensitively: Google/Gemini/GCloud/CloudSDK/AGY/Antigravity,
  Python overrides, BROWSER, Electron Node mode, and GCP project/location overrides do not survive. Normal PATH,
  HOME, proxy and other diagnostic/runtime environment remain. The service adds GEMINI_HOME, forced file storage,
  Python unbuffered output and its verified BROWSER command. Launch builder adds only the validated sibling harness
  path and sets `includeParentEnvironment: false`; no OS or host-factory inheritance restores filtered variables.
  The profile's injected `HostProcessCommandExecutor` must also use `includeParentEnvironment: false`, so preflight
  and directory commands cannot restore ambient credentials. Existing other-plugin executors retain inheritance.
- The backend-neutral `--internal-browser-noop` mode returns before CLI/config/DI/logging. It does not inspect,
  open, fetch, or print its URL argument. It exits successfully with empty stdout/stderr, including after cancellation.
  The plugin requires an exact injected native or source invocation, quotes it for Python shlex (not a shell),
  rejects path-separator/control/placeholder ambiguity and preflights exit/output before preparing the profile.
  The repository maps exit/output facts; the service alone decides that success requires zero exit and no output.
  Rejected preflights retain the original command result as the exception cause, while the safe presentation
  identifies the executable and exit code without echoing captured output.
- Every composed Antigravity stderr interceptor uses the plugin mapper before logging: OAuth authorization/token
  endpoint URLs with queries, callback query URLs, state/code/token/PKCE/secret assignments and bearer values are consumed.
  Bare endpoint mentions and DNS/TLS/proxy/HTTP errors without payloads remain visible, alongside paths, stack frames,
  permission failures and non-secret auth lifecycle messages.
  Shared ACP bounds complete/partial lines; consumed bytes and over-limit payloads never enter logs.

## Failure signals

- A helper opens a browser, bootstraps bridge services, writes config, outputs the supplied URL, or exits nonzero.
- Assuming `dart -e`, a Node runtime, or a native invocation when the bridge actually runs through Dart source.
- Missing `700`, settings written before hardening, ignored preflight errors, or token contents read during inspection.
- Parent inheritance reintroduces filtered credentials; auth/live/replay/probe use different profile policy.
- OAuth-bearing stderr escapes in split/unterminated lines, or the implementation drains all useful diagnostics.

## Coverage and evidence

- `antigravity_profile_service_test.dart`: inert token-presence inspection, mode/order, generated serialization,
  exact native/source/Windows invocation shapes, environment aliases, immutable outputs and surfaced failures.
  Its real host-executor composition test verifies preflight and directory calls disable parent inheritance.
- `antigravity_stderr_mapper_test.dart`: selective OAuth consumption, retained diagnostics, byte-split CRLF/EOF,
  sanitized bounds. `antigravity_acp_api_test.dart` exercises the injected scratch-process interceptor composition.
- `browser_noop_test.dart`: actual source entrypoint subprocess, synthetic HOME, empty output and no created files.
- Existing `bridge_host_json_store_test.dart`: real nested child stores, interrupted atomic update, shared exclusion.
- Native proof on macOS arm64, 2026-09-05: `cd bridge/app && dart build cli -o /tmp/step6b-native-build`;
  the resulting `bundle/bin/bridge --internal-browser-noop https://example.invalid/sesori-browser-preflight`
  exits 0 with empty stdout/stderr. The actual Dart source invocation does too. Both were invoked through the
  pinned archive's extracted Python `webbrowser.open`, with OS fallback replaced by a failing sentinel: both return
  `True`, no fallback. Native bundle path included spaces and an apostrophe; synthetic HOME remained untouched.
- Pinned archive `agy_acp_server.par` embeds Python 3.14 `webbrowser.py` (SHA-256
  `893c86950a76b187b6a84e65bde03572e4179733f667b32880f866ce9a1a92f3`): `get` shlex-splits commands containing
  `%s`; `GenericBrowser.open` invokes `Popen` without a shell and returns success on exit 0; BROWSER choices split
  on `os.pathsep`. Credential-manager bytecode calls `webbrowser.open` before printing the challenge. Inspection
  executed no agent/OAuth code and accessed no credentials. No proprietary source is committed.
- Public corroboration: `pingdotgg/t3code@fff33f9e851912363c5b1f3ac65598be35eb5f0d`,
  `antigravityAuthSupport.ts` lines 217–294 (Node-specific helper), 249–253/318 (paths), 458 (sensitive stderr).
- Windows/Linux native execution is not claimed by the macOS proof. Windows command/ACL policy has synthetic
  coverage; each actual host must pass the no-op preflight. Pinned agent updates require rechecking stderr shapes
  and browser semantics. No real OAuth/browser/network experiment was performed.
