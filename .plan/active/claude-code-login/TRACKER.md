# Claude Code Login: Tracker

## Current State

- **Plan slug:** `claude-code-login`
- **Series state:** Step 1/6 open; implementation not started
- **Current branch:** `code-harness-login-enhancement`
- **Next action:** merge the plan PR, then open Step 2

## Locked Product Decisions

- [x] Login only while setup reports authentication required; no logout, re-login while ready, or account switching.
- [x] Drive the official `claude auth login --claudeai` over piped stdio; Sesori never touches tokens or the credential store.
- [x] claude.ai subscription login only; console, SSO, API key, setup-token, and `CLAUDE_CODE_OAUTH_TOKEN` excluded.
- [x] Paste-code flow on every platform; external browser opens only on explicit tap; no loopback or same-host auto-completion.
- [x] Host browser suppressed with a no-op `BROWSER` on macOS and Linux; Windows stray tab accepted and documented.
- [x] One pasted code per operation; rejected code ends the operation; no retry loop.
- [x] One ten-minute budget from spawn to exit.
- [x] Sheet dismissal keeps the operation; cancel is explicit; one active operation per plugin.
- [x] Ephemeral operation state; no persistence; no new analytics event.
- [x] Managed Claude runtime installation is out of scope.

## Locked Architecture

- [x] Third sealed operation variant `pastedCode(events, submitCode)` with `PluginAuthenticationPastedCodeChallenge(authorizationUri)` in `sesori_plugin_interface`.
- [x] Wire: `PluginAuthenticationChallengeResponse.pastedCode(authorizationUrl)` and `PluginAuthenticationCodeRequest(code)`; existing `unknown` fallback covers older apps.
- [x] Bridge: `submitAuthenticationCode` through runtime, lifecycle repository, and service; shared one-shot continuation gate; `POST /plugin/:id/authentication/code` with neutral validation.
- [x] Claude plugin layers: `ClaudePastedCode`, `ClaudeLoginEnvironment`, `ClaudeLoginOutputParser`, `ClaudeAuthLoginApi`, `ClaudeAuthenticationRepository`, `ClaudeAuthenticationService`, descriptor composition and capability.
- [x] A plugin-rejected code shape ends the operation through the plugin's event stream; no rejection type crosses the plugin boundary; the generic remote failure text is unchanged.
- [x] Client: extend `PluginApi`, `PluginRepository`, `PluginManagementService`, `PluginManagementCubit`; shared sheet gains a harness-neutral pasted-code branch.
- [x] Wire contract and apps (Step 2) merge before the bridge core (Step 3); bridge core merges before the Claude plugin (Step 4).

## Steps

| Step | Title | Status | PR | Evidence |
|---|---|---|---|---|
| 1/6 | 🌱 Publish the plan | In review | #1508 | Architecture plan review 2026-09-16: rejected with 4 must-fix and 2 optional findings; all applied, not re-reviewed per repository rules. PR automated review: two waves, 9 findings applied (one superseded by the second wave) |
| 2/6 | 🚧 Add pasted-code login to the wire contract and apps | Not started | — | — |
| 3/6 | 🚧 Route pasted-code login through the bridge | Not started | — | — |
| 4/6 | 🚧 Drive Claude CLI login from the bridge | Not started | — | — |
| 5/6 | 🌱 Reconcile Claude login documentation | Not started | — | — |
| 6/6 | 🌱 Verify and retire the plan | Not started | — | — |

## Retirement Evidence

Recorded at Step 6: level, matrix, plugins, platforms, builds, versions,
privacy-safe evidence, and any user-accepted reduction.
