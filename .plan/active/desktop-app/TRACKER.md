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
| — | MT gate A: first real GUI supervision (user-run) | pending |
| 8 | ⚙️ Single instance + last-state restore | pending |
| 9 | ⚙️ Autostart + hidden boot | pending |
| 10 | 🚧 `module_auth` logout/rejection hardening (R1) | pending |
| 11 | ⚙️ Logout coordination + offline unregister fallback | pending |
| 12 | ⚙️ Supervised E2E suite + dev-harness retirement | pending |
| — | MT gate B: daily driver (user-run) | pending |
| 13 | ⚙️ Desktop relay-client enablement | pending |
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
