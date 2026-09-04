# MT Gate C — Agent-Run Manual QA Plan

## Status

- **Parent plan:** `desktop-app`
- **Checkpoint:** MT Gate C — cockpit parity + mobile regression
- **Plan date:** 2026-09-03
- **Execution:** next user-requested working session
- **State:** planned; not yet executed or accepted
- **Approach:** **option (a)** — run and document one complete baseline before
  changing code, then fix confirmed issues together and retest on one final
  build. A blocking failure marks dependent cases `Blocked`; it does not cause a
  mid-run code change while independent cases remain runnable.
- **Gate authority:** the agent records evidence and a Pass/Partial/Fail/Blocked
  recommendation; the user accepts the gate before the tracker changes to done.

## Planning baseline — not test evidence

The worktree was fetched and verified clean against `origin/main` on 2026-09-03:

- source: `d22ffcee46de3e6fb4f8817a307926f951ed2b86`;
- internal release: `v1.8.3-internal.793` at that exact commit;
- Step 20 slice 3: PR #1274, merge commit `3d43ba47f`, already an ancestor of
  the source commit;
- all-or-nothing `Release All Platforms` run
  [#33756321818](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/33756321818):
  passed for that exact commit;
- pinned local toolchain present: Flutter 3.47.2 / Dart 3.13.2, Xcode 26.6,
  Peekaboo 4.2.2, and agent-device 0.20.10;
- macOS host: 26.6.2 arm64; Peekaboo Screen Recording, Accessibility, and event
  synthesis permissions granted.

Execution starts with a fresh fetch and records a new immutable commit/tag/run.
The values above must not be copied into the result if `main` advances.

Two preflight facts currently require an execution-time checkpoint:

1. a standalone `sesori-bridge` process was running; it was only observed and
   was not stopped, taken over, or modified;
2. no physical iOS device was connected. Flutter and Xcode saw only the Mac and
   simulators. A simulator cannot satisfy the real-device mobile or provider
   notification/voice legs.

Codex is currently absent from the interactive PATH and is the preferred live
harness because it can exercise both managed installation and in-app device-code
login. The app's authoritative setup snapshot decides at execution time; no
existing runtime or credential is deleted merely to manufacture a missing or
signed-out state.

## Scope and proof boundary

| Area | Required boundary |
|---|---|
| Desktop cockpit | Fresh macOS debug build from the pinned commit, dev-built supervised helper, production auth/relay, and a live representative plugin |
| Harness management | One genuine managed install and one genuine plugin login; prefer Codex for both when its real setup state permits |
| Desktop attention | Native macOS notification delivery plus relay SSE, live plugin request, focus/route/cancel behavior, and built-artifact proof that desktop is push-free |
| Mobile regression | Latest matching internal build on one physical release-target device (iOS preferred on this host), production auth/relay, and the same bridge/session fixture |
| Release safety | Successful all-or-nothing internal release on the exact source commit plus passing applicable Desktop/Mobile CI for the Step 20 changes; respect path-gated skips and do not publish a redundant build merely to call it a dry run |

The accepted parent-plan reduction remains unchanged: Windows/Linux receive CI
build evidence and are deferred to `desktop-distribution`; this gate does not
claim native QA on those hosts. One representative live plugin proves cockpit
journeys. Harness management uses one plugin per exercised capability when one
plugin cannot honestly expose both states. Distribution, signing/notarization,
installers, self-update, and an every-plugin L3 sweep remain out of scope.

## Safety, privacy, and required handoffs

- Re-run the process inventory before every launch. If a standalone bridge or
  another desktop build is active, pause for explicit user approval before
  stopping it, taking over, changing Bridge On/Off, or replacing its helper.
  Preserve enough state to restore the prior mode afterward.
- The agent may create benign sessions and send benign prompts only in the
  disposable QA project below. It never uses a real source repository as the
  mutation target.
- The user completes OAuth/device-code credentials, MFA, macOS login-password
  prompts, and any provider account choice. The agent never types or records
  those secrets. If proving plugin login would require logging out an existing
  Codex credential, ask first; refusal makes that row Blocked rather than
  destructive.
- Connect, unlock, and trust a physical release-target phone before the mobile
  leg. Seed one intentionally non-sensitive QA image so automation never opens
  or records a personal photo library item.
- Do not disable all host networking while the coding session is active. For
  the relay-loss case, prefer a narrowly scoped, reversible block of
  `relay.sesori.com` that leaves other traffic intact. Any admin credential is
  entered by the user. Install cleanup before applying the fault and remove it
  in `finally`; if neither a scoped fault nor a user-assisted physical outage is
  available, report that case Blocked instead of simulating a pass.
- Store screenshots, recordings, logs, accessibility trees, and network traces
  under a private `mktemp` artifact root. They can contain account data,
  transcripts, paths, and tokens and are never committed. The repository gets
  only a privacy-safe result summary.

## Test fixture and state ledger

Create a private temporary Git repository with a local-only test identity, one
initial commit, harmless files for modify/add/delete diff coverage, and one
small valid raster image. Add that directory through the desktop project UI.
All prompts must be bounded to this fixture and must not request secrets,
account changes, external publication, or writes outside the fixture/worktree.

Before mutation, record in the private ledger:

- desktop account state, desired Bridge On/Off state, launch-at-login setting,
  attention toggle, appearance, window bounds, and active bridge mode;
- enabled state and idle-timeout override for every harness the run will change;
- whether the selected managed runtime and provider login pre-existed;
- mobile account and notification-preference state.

After the run, remove only QA-created sessions/worktrees/project rows and the
fixture. Restore changed preferences and the prior bridge mode. Managed runtime
and provider credential cleanup is never guessed: retain them and report the
change unless the user explicitly asks for removal through the owning tool.

## Execution sequence

### 0. Pin latest source and establish the automated baseline

1. Fetch `origin`, require a clean worktree, update to current `origin/main`, and
   record the full SHA, product versions, nearest internal tag, and merge
   ancestry of Step 20. Do not mix a newer desktop source with an older mobile
   build silently.
2. Verify exact-version QA tooling and run host preflight. Inventory live Sesori,
   helper, and backend processes before launching anything.
3. Verify `Release All Platforms` passed for the exact source SHA and its
   internal tag resolves back to that SHA. Verify the applicable Step 20 Desktop
   and Mobile CI runs passed. A path-gated workflow that legitimately did not
   run on a later unrelated commit is recorded as skipped-by-filter, not failed;
   never invent an exact-SHA check. If the release run is still in progress,
   wait. If it failed, the release-safety row fails.
4. Build the real helper and desktop app and run the owning baseline:

   ```bash
   (cd bridge && dart pub get)
   (cd bridge/app && make build-host)
   (cd client && dart pub get)
   (cd client/module_desktop_core && dart analyze --fatal-infos && dart test)
   (cd client/desktop && dart analyze --fatal-infos && flutter test)
   (cd client/desktop && flutter build macos --debug)
   codesign --verify --deep --strict --verbose=2 \
     client/desktop/build/macos/Build/Products/Debug/Sesori.app
   ```

5. Run the isolated native supervised-helper E2E because this gate exercises
   Bridge Off/Start and real supervision. Its fake services and temporary state
   must not touch production credentials.
6. Create the private artifact root, arm agent-device recording, and use
   Peekaboo for native window/tray/Notification Center evidence. A successful
   build or widget suite is prerequisite evidence, not a substitute for the
   real-app cases below.

### 1. Desktop cockpit and live harness

| ID | Scenario | Required pass signal |
|---|---|---|
| C1 | Launch/auth/restore | The fresh app shows a reachable signed-in cockpit after user-completed browser login when needed; relaunch restores locally without a blank first frame. Supervision and relay status are distinct and truthful. |
| C2 | Navigation and adaptive shell | Bridge, Projects, and Settings remain reachable. Project/session navigation works in narrow one-pane and wide split layouts without losing the selected inventory. Settings children return to Settings, and the single connection banner is not duplicated. |
| C3 | Managed install | From Harnesses, install a genuinely missing install-capable runtime. Progress is visible and non-regressing, terminal state settles, the exact selected version appears, and success re-inspects, enables, and makes the harness selectable. No raw path/output is rendered. Prefer Codex; if it is already installed, choose another naturally missing supported harness rather than deleting state. |
| C4 | Plugin login and controls | For a genuinely authentication-required Codex state, Login opens the anti-phishing/device-code flow only on explicit action; the user completes provider auth; terminal progress closes and setup becomes ready. Exercise only capability-offered refresh/restart, idle override, disable/enable, and catalog scan controls while idle, then restore prior values. If existing credentials prevent a real login, obtain explicit logout approval or mark login Blocked. |
| C5 | Projects and sessions | Add/open the disposable project, browse its session inventory, refresh, and return through typed routes. No desktop surface shows mobile CLI-install or “connect your computer” recovery copy. |
| C6 | New dedicated session | Create from the shared New Session view with the representative plugin, an explicit advertised option where available, a benign first input, and dedicated workspace enabled. Launch status appears immediately, duplicate Send is blocked, success opens the durable session, and displayed branch/worktree facts match Git while the original fixture remains unchanged. |
| C7 | Chat/composer round trip | Send benign text with Enter, verify Shift+Enter inserts a newline, stream output/tool/status to idle, and reopen without loss/duplication. If the plugin declares images, pick the seeded QA image through the native file dialog and verify staged/sent echo. Desktop remains text-first with no voice control. Escape dismisses editing/popup state without navigating away, and transcript text is selectable. |
| C8 | Focused permission | Provoke one harmless live-plugin permission while the window is focused. The shared permission surface appears under the correct session, no macOS attention alert is emitted while focused, the chosen one-time answer reaches the backend without scope escalation, the request retires, and the turn continues. |
| C9 | Diffs | Have the live session add, modify, and delete only fixture files. File Changes opens the typed shared diff, statuses/counts/content agree with Git, source can be selected/copied without headers/gutters, and Back returns to the same session inventory. |
| C10 | Bridge Off → Start the bridge | Explicitly turn Bridge Off, verify the supervised helper/backend exits without an orphan, and confirm Projects reports the offline state while control UI remains usable. Its recovery action says **Start the bridge**, contains no CLI instructions, persists On, restores handshake/relay/data, and does not toggle an already-On intent back Off. |
| C11 | Relay-only outage and recovery | Apply the approved scoped relay fault. The cockpit reports offline/connection loss while local control-channel supervision, tray status, and Bridge controls remain responsive and truthful. Remove the fault and verify automatic relay recovery and fresh project/session data without a duplicate helper. |
| C12 | Window and tray ergonomics | Exercise practical narrow/wide sizes, minimum sizing, move to a distinct on-screen position, Enter/Shift+Enter/Escape, native text selection, close-to-hide, Dock removal, primary and secondary tray menus, and Open/focus. Quit/relaunch must restore usable size/position before first show, without an off-screen frame or visible default-frame flash. |

### 2. Desktop attention and cross-surface behavior

Use separate harmless requests so one answer or “always” grant cannot mask the
next case. Trigger from the disposable session, hide/unfocus the desktop before
the backend asks, and keep the phone app out of the request-generation path for
the first alert.

| ID | Scenario | Required pass signal |
|---|---|---|
| A1 | Hidden/unfocused delivery and open | With Attention enabled, a live permission/question raised after the window is hidden or unfocused produces one native macOS alert. Visible content is only the bounded session title and category copy—never prompt, question, tool, path, or routing payload. Clicking it restores/focuses Sesori and routes to the bound session. |
| A2 | Resolution elsewhere | Raise another request with desktop hidden, observe its alert, then answer from the physical phone. The macOS alert clears without being opened and does not reappear after refocus/relaunch. |
| A3 | Toggle | Disable Attention and confirm any delivered alert clears. While disabled, another request produces no macOS alert; restore the toggle and verify its persisted state across relaunch. Record and restore the pre-run value. |
| A4 | Account/lifecycle isolation | No QA alert survives logout/auth loss or can route into another account. Run a logout transition only with explicit approval and only if it does not duplicate C1/mobile login work; otherwise rely on the already-passing owning automated case and record this manual variation Not run, not Pass. |
| A5 | Desktop remains push-free | Inspect the built app’s entitlements/plugin contents and startup composition: no `aps-environment`, Firebase Messaging desktop plugin, mobile push settings, or `NotificationRegistrationService.start()` path. During the same live request, the registered physical phone receives one—not duplicate—push notification. Local macOS delivery still succeeds through SSE. |

### 3. Physical mobile regression on the matching internal build

Use the exact internal iOS build/tag mapped to the pinned source SHA. A local
simulator may help diagnose a failure but cannot satisfy any row requiring the
microphone, picker, push provider, or real-device lifecycle.

| ID | Scenario | Required pass signal |
|---|---|---|
| M1 | Login and lists | With approval for device-local sign-out if needed, the user completes one real login and relaunch restore. Projects and sessions load the same fixture/session data, and normal navigation remains intact. |
| M2 | Chat, composer, and picker | Send a benign text turn, observe streaming to idle, stage the seeded non-sensitive image from the real picker for a supporting plugin, send it, and verify the transcript echo/reopen behavior. |
| M3 | Voice | On the physical microphone, hold to record a benign spoken/TTS phrase, release to transcribe, verify a non-empty editable insertion rather than exact wording, edit it, and send only after review. Exercise drag-to-cancel once and confirm no stale text lands. |
| M4 | Permission and diffs | Open/answer a pending request for the fixture session, verify it retires on both surfaces, then open File Changes and confirm the live fixture diff renders and navigates back correctly. |
| M5 | New session | Create one additional benign session from mobile, exercise plugin/model/variant and workspace controls that the chosen plugin advertises, and verify launch status, durable navigation, and later listing. |
| M6 | Settings and notifications | Open Settings, Harnesses, Profile, and mobile notification preferences; toggle one category and restore it. Background the app, raise one new live request, observe exactly one provider notification, tap it to the correct session, and verify viewing clears it. Desktop-only Attention is not exposed as a mobile preference. |

### 4. Cleanup, issue handling, and final verdict

1. Close agent-device sessions cleanly. Verify no unintended GUI-owned helper or
   backend remains; preserve one only when restoring the recorded prior On mode.
2. Restore preferences and prior bridge mode, remove only QA-created
   sessions/worktrees/project/fixture, and report any retained managed runtime,
   provider login, notification, route fault, or diagnostic residue.
3. Record each row as `Pass`, `Partial`, `Fail`, `Blocked`, or `Not run`, with the
   exact commit/build, boundary, plugin/version, platform/device, expected versus
   actual behavior, first divergent boundary, and private artifact path. Do not
   commit raw evidence.
4. For every failure, capture one minimal reproduction, relevant local logs and
   stack trace, and the smallest useful screenshot/trace. Continue all
   independent baseline cases before changing source.
5. After the baseline sweep, cluster failures by root cause and implement only
   confirmed, in-scope fixes. Run focused tests/analyzers for each owner; invoke
   architecture review only if a fix is architecture-bearing. Commit, push, and
   open appropriately titled PRs rather than mixing unrelated fixes.
6. Rebuild from the fixed commit and rerun every failed/blocked-dependent case,
   its adjacent lifecycle/navigation cases, and one final compact desktop →
   phone → desktop journey. A shared client/core fix requires affected desktop
   and mobile reruns. If mobile source changed, use a locally signed physical
   build or wait for the post-merge matching internal build; never claim the old
   binary proves the fix.

## Gate completion rule

Recommend **Pass** only when C1–C12, A1–A3/A5, and M1–M6 pass on one final
source/build line, automated baseline and exact-commit release evidence are
green, process cleanup succeeds, and there is no unresolved material failure.
A4 may be explicitly `Not run` because its destructive account transition is
already covered automatically and is not part of the parent Gate C sentence;
if run, it must pass. Any unavailable physical phone, real plugin login,
managed install, native notification, scoped network fault, or live permission
boundary makes the gate Partial/Blocked rather than silently reducing scope.

After reporting the result, wait for user acceptance before marking MT Gate C
`done` or advancing Steps 21–22.
