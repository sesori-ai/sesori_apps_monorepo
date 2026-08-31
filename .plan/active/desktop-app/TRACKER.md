# Desktop App — Tracker

Status values: `pending` / `in-progress` / `done` / `blocked`. Evidence for a
finished step lives in `steps/step-NN.md` (created when the step executes);
this table records state only and never mirrors PR review status. MT gates are
user-run checkpoints, not PRs; only the user marks them passed.

| Step | Title | Status |
|---|---|---|
| 1 | 🌿 Raise plan; supersede + delete old desktop plan | done |
| 2 | 🚧 Bridge process primitives (API, repository, log tracker/storage) | done |
| 3 | 🚧 `BridgeProcessService`: authenticated spawn + control channel live | done |
| 4 | 🚧 Exit-code state machine + prompt-answer seam | done |
| 5 | ⚙️ Status semantics + dead control-protocol removal | done |
| 6 | ⚙️ Tray + `BridgeControlCubit` + windowed fallback | done |
| 7 | ⚙️ Window + Prego theme + v1 contents | done |
| — | MT gate A: first real GUI supervision (user-run) | done |
| 8 | ⚙️ Single instance + last-state restore | done |
| 9 | ⚙️ Autostart + hidden boot | done |
| 10 | 🚧 `module_auth` logout/rejection hardening (R1) | done |
| 11 | 🚧 Logout coordination + offline unregister fallback | done |
| 12 | 🚧 Supervised E2E suite + dev-harness retirement | done |
| — | MT gate B: daily driver (user-run) | pending |
| 13 | ⚙️ Desktop relay-client enablement | done |
| 14 | ⚙️ Create `module_app_ui` + l10n/extensions/theme move | pending |
| 15 | 🚧 Settings + harness management slice (desktop onboarding) | pending |
| 16 | 🚧 Project/session lists slice + desktop offline strategy | pending |
| 17 | 🚧 Session detail: transcript slice | pending |
| 18 | 🚧 Composer slice + voice/media seams (R2) | pending |
| 19 | ⚙️ Diffs + new-session slice | pending |
| 20 | ⚙️ Desktop cockpit composition | pending |
| — | MT gate C: cockpit parity + mobile regression (user-run) | pending |
| 21 | 🌿 Regression documentation reconciliation | pending |
| 22 | 🌿 Coverage run, retirement, `desktop-distribution` handoff | pending |

## MT Gate A — accepted 2026-08-30

The user accepted the macOS manual gate after browser login/session restore,
15-minute token expiry/refresh without supervised-helper `token.json` writes,
helper `kill -9` recovery, curl-triggered supervised restart/exit 86,
signed-out startup, bridge Off/On, phone restart, and the fresh-build window
close → tray Open flow. Tray `Active sessions: 0` while no session has active
work is expected. Phone session round-trip and standalone CLI coexistence were
not separately re-reported in the final check; the user explicitly accepted
the available gate coverage as sufficient.

Step 10 merged in PR #1212 on 2026-08-30. Step 11 merged in PR #1213 on
2026-08-30. Step 12 merged in PR #1215 on 2026-08-30 with 19/19 CI checks
passing, including the native supervised E2E on macOS, Windows, and Linux.
The Step 12 PR also included the post-merge Step 11 stop-mode and token-only
deletion hardening. Step 13 merged in PR #1216 on 2026-08-31 with 13/13 CI
checks passing. The desktop relay client and token-only startup handoff are
complete. MT gate B remains pending; do not begin Step 14 until the user-run
daily-driver checkpoint is recorded.

## Plan divergence — post-Step 13 Gate B findings (2026-08-31)

The first daily-driver checks found that the persisted On intent was lost on
app Quit, the rendered local/relay takeover state had no explicit reclaim
action, and launchd's minimal PATH hid user-installed harnesses. The initial
incomplete-file-permissions hypothesis was not confirmed: the GUI/helper ran
under the same user with executable files, and the observed `gh` failure was
`ENOENT` rather than `EACCES`/`EPERM`. Full Disk Access remains a manual
permission for the process that accesses the protected folder; the desktop does
not grant or persist it.

These findings are a pre-Gate-B hardening divergence, not a new numbered plan
step. During review, the environment lookup was kept below the service layer:
the process API resolves it through the repository, the service rechecks
cancellation before spawn, and the fallback list remains backend-neutral. The
work is intentionally split into two manageable PRs:

| Follow-up | Status | Scope |
|---|---|---|
| `🌿 [desktop-app] Restore supervised harness discovery [step 1/2]` | in-progress | PR #1222 open: macOS-only PATH enrichment at the supervised process boundary, setup diagnostics, and regression coverage |
| `🚧 [desktop-app] Preserve bridge intent and add Take Over [step 2/2]` | in-progress | Successor local: Quit intent semantics, explicit takeover orchestration/UI, and lifecycle coverage |

The helper receives only a login-shell-derived PATH, merged with its inherited
environment; shell variables, secrets, permissions, and entitlements are not
copied. Gate B stays user-owned and Step 14 stays blocked until the user
records the documented gate outcome and explicitly authorizes progression.
