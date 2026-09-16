# Claude Code Login: Tracker

## Current State

- **Plan slug:** `claude-code-login`
- **Series state:** Step 1/6 merged; Step 2/6 in review
- **Current branch:** `claude-code-login-step-2`
- **Next action:** land Step 2 review fixes; Step 3 proceeds locally until Step 2 merges

## Locked Product Decisions

- [x] Login only while setup reports authentication required; no logout, re-login while ready, or account switching.
- [x] Drive the official `claude auth login --claudeai` over piped stdio; Sesori never touches tokens or the credential store.
- [x] claude.ai subscription login only; console, SSO, API key, setup-token, and `CLAUDE_CODE_OAUTH_TOKEN` excluded.
- [x] Paste-code flow on every platform; external browser opens only on explicit tap; no loopback or same-host auto-completion.
- [x] Host browser suppressed with `BROWSER=true` on every platform (the value the CLI treats as no browser; no filesystem probe, no platform branch); Windows unverified and documented.
- [x] One pasted code per operation; rejected code ends the operation; no retry loop.
- [x] Two bounded waits: 90 seconds for the authorization URL, ten minutes overall from spawn to exit.
- [x] Sheet dismissal keeps the operation; cancel is explicit; one active operation per plugin.
- [x] Ephemeral operation state; no persistence; no new analytics event.
- [x] Managed Claude runtime installation is out of scope.

## Locked Architecture

- [x] Third sealed operation variant `pastedCode(events, submitCode)` with `PluginAuthenticationPastedCodeChallenge(authorizationUri)` in `sesori_plugin_interface`.
- [x] Wire: `PluginAuthenticationChallengeResponse.pastedCode(authorizationUrl)` and `PluginAuthenticationCodeRequest(code)`; existing `unknown` fallback covers older apps.
- [x] Bridge: `submitAuthenticationCode` through runtime, lifecycle repository, and service; shared one-shot continuation gate; `POST /plugin/:id/authentication/code` with neutral validation.
- [x] Claude plugin layers: `ClaudePastedCode`, `ClaudeLoginEnvironment`, `ClaudeLoginOutputParser`, the existing `HostClaudeProcessFactory` generalized around a neutral `ClaudeProcessLaunch` (no second wrapper), `ClaudeAuthenticationRepository`, `ClaudeAuthenticationService`, descriptor composition and capability. The runtime gate is the only owner of the one-submission rule.
- [x] A plugin-rejected code shape ends the operation through the plugin's event stream; no rejection type crosses the plugin boundary; the generic remote failure text is unchanged.
- [x] Client: extend `PluginApi`, `PluginRepository`, `PluginManagementService`, `PluginManagementCubit`; shared sheet gains a harness-neutral pasted-code branch; the start guard rejects retries only while a start is in flight or a challenge is retained, so an uncertain start can be rejoined.
- [x] Wire contract and apps (Step 2) merge before the bridge core (Step 3); bridge core merges before the Claude plugin (Step 4).

## Steps

| Step | Title | Status | PR | Evidence |
|---|---|---|---|---|
| 1/6 | 🌱 Publish the plan | Merged | #1508 | Architecture plan review 2026-09-16: rejected with 4 must-fix and 2 optional findings; all applied, not re-reviewed per repository rules. PR automated review: five waves, 20 findings applied (one superseded by the second wave); CLI login flow verified on 2.1.221, 2.1.269, 2.1.272, and 2.1.273 |
| 2/6 | 🚧 Add pasted-code login to the wire contract and apps | In review | #1516 | Shared, `module_core`, `module_app_ui`, `client/app`, and `client/desktop` analyze and targeted tests pass; divergences (a `codeRetry` state, shared `normalizeCode`, `invalidRedirect` renamed `invalidInput`, no monospace field) recorded in `PLAN.md` |
| 3/6 | 🚧 Route pasted-code login through the bridge | In progress | — | `sesori_plugin_interface` and `bridge/app` analyze clean; interface, runtime gate, lifecycle service, and handler tests pass; architecture implementation review approved, its optional finding (document the code guarantee and error privacy for plugins) applied |
| 4/6 | 🚧 Drive Claude CLI login from the bridge | Not started | — | — |
| 5/6 | 🌱 Reconcile Claude login documentation | Not started | — | — |
| 6/6 | 🌱 Verify and retire the plan | Not started | — | — |

## Retirement Evidence

Recorded at Step 6: level, matrix, plugins, platforms, builds, versions,
privacy-safe evidence, and any user-accepted reduction.
