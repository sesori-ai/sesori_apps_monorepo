# Claude Code Authentication

## Capability

Signing the bridge machine's Claude Code CLI into a claude.ai subscription account from the phone or desktop app. The
bridge drives the official `claude auth login --claudeai`: the user opens the sign-in page from the app, approves
access, and pastes the code the page shows. Sesori never performs the token exchange, never reads or writes the CLI's
credential store, and never sets `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY`.

## Required Behavior

- Claude advertises authentication for the PATH binary and an explicit `bin` override alike. The app offers
  `Log in` only while setup reports authentication required. The setup hint reads "Log in from Sesori, or run
  `claude auth login` on this machine.", so older apps keep a working instruction.
- A login spawns `claude auth login --claudeai` through the host process service in the plugin state directory. The
  bridge environment is inherited unchanged except `BROWSER=true`, which the CLI treats as "no browser". `HOME` is
  never overridden, so the credential lands where sessions already read it. The login spawn uses its own process
  factory and never reports into session health.
- The first `https://` token on a stdout line becomes the pasted-code challenge. ANSI CSI and OSC 8 escapes are
  removed first, and lines split across output chunks still parse. A token over 16384 characters or without a
  host fails the start at once. No URL within 90 seconds, or a CLI exit first, also fails the start.
- A pasted code must be exactly `code#state`: both parts non-empty, no whitespace, at most 512 characters. A valid
  code reaches the CLI's stdin as exactly one line. Any other shape stops the CLI and ends the operation with a
  failure, while the submission itself succeeds. The bridge accepts one submission per operation.
- Exit 0 completes the operation. A non-zero exit, or the ten-minute overall budget measured from spawn, fails it.
  Cancel and bridge shutdown settle it as cancelled. An exit counts once both output pipes close, so output written
  just before the exit still reaches the log. Every outcome stops the CLI (graceful signal, forced after five seconds),
  waits for it to exit, and stops reading its pipes; no budget timer outlives the operation. The bridge then
  re-inspects setup, which alone decides readiness.
- Remote failures carry only the bridge's generic text. Local bridge logs keep the cause (exit code, budget, rejected
  shape), the stack, and the last 20 stderr lines with escapes stripped and every `https://` token replaced by
  `<url>`. The authorization URL, its state, and the pasted code never appear in logs, errors, analytics, SSE replay,
  or persistence.
- The shared sheet opens the sign-in page only on an explicit tap and keeps the anti-phishing guidance; see
  [plugin setup and lifecycle](plugin-setup-and-lifecycle.md).

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated: the Claude descriptor advertises authentication, and the shared contract and client mapper round-trip the pasted-code challenge and code request. |
| L2 Routine | Automated: scripted CLI output through the Claude service (fragmented OSC 8 URL, exit before and after the challenge, stderr arriving after the reported exit, both budgets, abort while waiting and while submitting, rejected shape failing even when the stopped CLI exits 0, pipes released and no signal sent when the CLI exited while a descendant holds its pipes open, exact stdin bytes, forced stop, spawn failure, logs free of URLs and codes) and spawn wiring (binary, arguments, state directory, `BROWSER`, `HOME`); a fake pasted-code plugin through the bridge runtime gate, lifecycle service, and code route; sheet widget tests on phone and desktop. The [CLI probe](#cli-probe) when the plugin's minimum or target version changes. Live plugin for the probe. |
| L3 Release | A real login from the iOS app and from the macOS desktop app against a macOS arm64 bridge running the real CLI with a real claude.ai account: no host browser opens, the pasted code completes, `claude auth status` reports logged in, the harness becomes ready, and a Claude session starts from Sesori. An explicit cancel mid-flow leaves no `claude auth login` process. Client end to end. |
| L4 Extended | A Linux headless bridge (credentials file), a well-formed wrong code, a budget expiry on the real CLI, an older app against the new bridge (update required), a bridge restart mid-login, an explicit `bin` override, and a supervised desktop bridge whose Keychain write may fall back to the credentials file. Client end to end. |
| L5 Full | A Windows bridge, where a host sign-in tab is an accepted limitation, and the Android app. Client end to end. |

## CLI Probe

Run against the plugin's minimum and target versions whenever either changes. A specific native binary comes from
`https://downloads.claude.ai/claude-code-releases/<version>/manifest.json`, whose `platforms` entries list each
binary with its sha256 checksum. Use a throwaway config directory so no real credential is read or written, and keep
the printed URL and state out of any recorded evidence:

```sh
dir=$(mktemp -d)
printf 'not-a-code\n' | CLAUDE_CONFIG_DIR="$dir" BROWSER=true claude auth login --claudeai
# The CLI keeps listening after stdin ends; stop it with Ctrl+C, then remove "$dir".
```

Expected, as verified on 2.1.221, 2.1.269, 2.1.272, and 2.1.273: no browser opens. Stdout prints
`Opening browser to sign in…`, then `If the browser didn't open, visit: ` with the URL wrapped in an OSC 8 hyperlink,
then `Paste code here if prompted > ` without a newline. The URL is `https://claude.com/cai/oauth/authorize` with
`code=true`, PKCE, `state`, and a `platform.claude.com` redirect. The malformed line prints
`Invalid code. Please make sure the full code was copied.` on stderr and the CLI keeps running. On 2.1.273 a
well-formed wrong code prints `Login failed: …` on stderr and exits 1 within a second.

## Exploration Guidance

Vary the entry state: an isolated logged-out config directory or a real expired login. Dismiss the sheet and
continue from the harness row. Background the app while the browser is open. Paste with surrounding whitespace, only
the part before `#`, or a truncated code. Cancel before and after opening the sign-in page. Let the budgets run out,
restart the bridge mid-login, and use an explicit `bin` override.

## Failure Signals

- A host browser tab opening on a macOS or Linux bridge.
- An authorization URL, state, code, token, email, or organization in bridge or client logs, errors, analytics, or
  SSE replay.
- A `claude auth login` process still running after completion, failure, cancel, a budget expiry, or bridge shutdown.
- Success reported while `claude auth status` still reports logged out, or a session that cannot start after a
  completed login, for example because `HOME` or `CLAUDE_CONFIG_DIR` differs between login and sessions.
- No challenge although the CLI printed a URL (parser drift after a CLI upgrade), or a start that outlives the
  90-second URL budget.
- A failed or successful login spawn changing Claude's session health or setup status by itself.
- A bridge that cannot exit promptly after a login ended, for example because a budget timer outlived the operation.
- A code of the wrong shape leaving the sheet waiting instead of ending in failure, or an operation that stays open
  after the CLI rejected a wrong code and exited.
- A failure log whose stderr tail lacks the CLI's last line, such as `Login failed: …` after a wrong code.

## Known Limitations

- claude.ai subscription login only. Console, SSO, API key, `setup-token`, and `CLAUDE_CODE_OAUTH_TOKEN` logins are
  not offered, nor are logout, re-login while ready, or account switching.
- A rejected code shape or a wrong code ends the operation; the user starts a new login. Cancel is unavailable until
  the challenge arrives, which the 90-second URL budget bounds.
- Host browser suppression is unverified on Windows bridges, which may open a sign-in tab on the host.
- Remote failures do not distinguish a timeout, a rejected code, or a CLI exit; the cause stays in local bridge logs.
- The wrong-code exit is verified only on 2.1.273; the ten-minute budget bounds other versions.

## Sources

- `bridge/sesori_plugin_claude/lib/src/`: `runtime/claude_plugin_descriptor.dart`,
  `services/claude_authentication_service.dart`, `repositories/claude_authentication_repository.dart`,
  `repositories/parsers/claude_login_output_parser.dart`, `models/claude_pasted_code.dart`,
  `foundation/claude_login_environment.dart`, `api/claude_process_launch.dart`
- Tests: `bridge/sesori_plugin_claude/test/claude_authentication_service_test.dart`,
  `bridge/sesori_plugin_claude/test/runtime/claude_plugin_descriptor_test.dart`,
  `bridge/sesori_plugin_interface/test/lifecycle/plugin_authentication_test.dart`,
  `bridge/app/test/bridge/runtime/plugin_runtime_test.dart`,
  `bridge/app/test/services/plugin_lifecycle_service_test.dart`,
  `bridge/app/test/bridge/routing/plugin_authentication_handlers_test.dart`,
  `shared/sesori_shared/test/models/plugin_management_contract_test.dart`, the `client/module_core` plugin API,
  repository, service, and cubit suites, and the phone and desktop harness settings screen tests
- Plan: `.plan/completed/claude-code-login/PLAN.md`
