# Step 45 — Release Matrix And Plan Retirement

## Status

The L3 release matrix was executed on 2026-08-25 and the plan was retired after
Step 29 PR #1115 merged with all 14 checks passing. The owner accepted Hermes's
provider-authentication blocker and live narrow iOS coverage backed by the
passing wide-layout and cancel/limit widget suites; that acceptance is recorded
in `PLAN.md`.

## Automated And Tooling

- `make analyze` passed from `bridge/`, `client/`, and `shared/`, including
  fatal-info parity across their owning packages.
- `make test` passed from all three workspaces. Bridge completed 2,693 tests
  with two expected PowerShell skips; shared completed 376 package tests and
  208 linter tests; every client package suite passed.
- PR #1115's Bridge CI passed its test, build-smoke, and offline OpenCode SSE
  codegen-freshness jobs. All 14 checks passed and the PR merged.
- `git diff --check` passed after the Step 29 review fixes. The working tree was
  clean before this evidence file was added.

## Plugin Matrix

The production `knownPlugins` composition contained seven plugins. A slot-1
headless bridge inspected all seven. Six setup-ready plugins started, completed
a fresh tool turn in this worktree, and returned their exact marker:

| Plugin | Setup and runtime | Fresh prompt evidence | Approval evidence |
| --- | --- | --- | --- |
| Claude Code | ready `2.1.237`; active/idle | `ses_8a768d3c34c3959d0170dcf604197767`, `STEP45_CLAUDE_FRESH_OK` | isolated follow-up completed as `STEP45_CLAUDE_APPROVAL_OK`; auto-approved `br-1` at log line 202 |
| Codex | ready `0.148.0`; active/idle | `ses_23991b76a9a7846bcadd607de8625bbd`, `STEP45_CODEX_FRESH_OK` | isolated escalated-shell follow-up completed as `STEP45_CODEX_APPROVAL_OK`; auto-approved `br-1` at line 199 |
| Cursor | ready `2026.07.23-e383d2b`; active/idle | `ses_ee1230f9389965b7ec777beabfcdfd8f`, `STEP45_CURSOR_FRESH_OK` | isolated follow-up completed as `STEP45_CURSOR_APPROVAL_OK`; auto-approved `br-1` at line 200 |
| Hermes Agent | `authenticationRequired` at ACP `0.20.4`; blocked/unknown | blocked before runtime start | blocked before approval; provider credentials are unavailable |
| Oh My Pi | ready `18.0.3`; active/idle | `ses_cb7f1efc488a54513a36635e42b90269`, `STEP45_OMP_FRESH_OK` | isolated follow-up completed as `STEP45_OMP_APPROVAL_OK`; auto-approved `br-3` at line 204 |
| OpenCode | ready `1.18.22`; active/idle after a force restart | `ses_c56f9f494ecd8172aa07681e165e37fd`, `STEP45_OPENCODE_FRESH_OK` | external-file read completed as `STEP45_OPENCODE_APPROVAL_OK`; auto-approved `per_039aebe1a001xgHZoTR1ve4BAb` at line 205 |
| Pi | ready; active/idle | `ses_51b3a5ef771b5b88a3e8f39e2dbeacb3`, `STEP45_PI_FRESH_OK` | unsupported: the production plugin returns no pending permissions and rejects permission replies as not found |

Each successful fresh prompt contained a tool part as well as its marker. The
five permission-capable setup-ready plugins were exercised sequentially after
the initial run so each new auto-approval line was attributable. OpenCode's
plugin-wide work state remained busy after its completed transcript; a force
restart settled it to active/idle and re-proved runtime startup. Hermes remains
the only registered plugin without setup, start, prompt, and approval coverage.

## Client Matrix

- Built and launched the current app on the slot-1 iOS 26.5 `iPhone 17`
  simulator. The authenticated client connected to the bridge and rendered the
  project list, Settings, Harnesses, session list, and six live transcripts.
- In the narrow phone layout, exercised the session rename sheet, swipe archive
  confirmation, swipe delete confirmation, settings rows, and the question
  modal. The live OpenCode question offered Stable and Beta; selecting Stable
  submitted and retired the pending question.
- Exercised transcript detachment until `Jump to latest` appeared, returned to
  follow mode, opened the keyboard composer without an overflow, and rendered
  live tool parts and assistant results.
- Granted simulator microphone access and exercised hold/release through the
  transcription boundary. Silent simulator audio produced an observable 504
  transcription error rather than a crash or stuck interaction.
- The full client suite passed narrow/wide adaptive routing, rename/archive/
  delete sheets, question choices, hold-to-talk/cancel/maximum-duration state,
  and transcript follow/detach/prepend/keyboard behavior. The app is
  portrait-only on the attached phone simulator, so a wide phone layout was not
  exercised live. Cancel/limit and physical microphone/haptic behavior also
  remain automated-only; the owner accepted this reduction on 2026-08-25.
- No Sesori crash report was produced during the run.

## Compatibility Matrix

The matrix permits equivalent wire fixtures. Exact public `v1.4.0` source
shapes were checked from the release tag, and the full shared, bridge, and client
suites exercised the retained compatibility contracts:

- Health: current `/global/health` returned the required
  `filesystemAccessDegraded` boolean, which the v1.4.0 nullable field decodes.
- Agents: the current bridge accepted the exact v1.4.0 `POST /agent` body with
  only `projectId`; the missing plugin identity selected OpenCode and returned
  eight agents. Current-client fallback coverage exercises the old per-route
  agent/provider/command path when aggregate options are unavailable.
- Question rejection: v1.4.0 sends a non-null owning `sessionId`; current client
  serialization and current bridge route tests exercise that exact request.
  The live current-client question answer also crossed the same pending-
  interaction boundary successfully.
- Settings: current `/settings` and retained
  `/settings/pull-request-refresh` both returned valid snapshots. Current-client
  repository coverage proves aggregate-first loading, legacy fallback only on
  404, and graceful unsupported handling when both routes are absent.

## Accepted Gaps

- Hermes needs a configured model/provider before its setup, runtime start,
  prompt, and approval rows can execute. The temporary ACP wrapper proves the
  required `0.20.4` runtime but cannot supply provider credentials.
- Live wide-phone and physical cancel/limit voice checks were not executable on
  the portrait-only simulator. Their adaptive/widget suites passed.
- The owner accepted both reductions on 2026-08-25; no other matrix row is
  waived.

## Retirement

- Merged current `origin/main` after PR #1115 landed; the already-tested Step 29
  content matched without a code conflict.
- Moved `.plan/active/codebase-cleanup/` to
  `.plan/completed/codebase-cleanup/` after every required row passed or had its
  reduction explicitly accepted.
