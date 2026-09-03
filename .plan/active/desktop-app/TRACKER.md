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
| — | MT gate B: daily driver (user-run) | done |
| 13 | ⚙️ Desktop relay-client enablement | done |
| 14 | ⚙️ Create `module_app_ui` + l10n/extensions/theme move | done |
| 15 | 🚧 Settings + harness management slice (desktop onboarding) | done |
| 16 | 🚧 Project/session lists slice + desktop offline strategy | done |
| 17 | 🚧 Session detail: transcript slice | done |
| 18 | 🚧 Composer slice + voice/media seams (R2) | done |
| 19 | ⚙️ Diffs + new-session slice | done |
| 20 | 🚧 Desktop cockpit composition + attention notifications | in-progress |
| — | MT gate C: cockpit parity + mobile regression (user-run) | pending |
| 21 | 🌿 Regression documentation reconciliation | pending |
| 22 | 🌿 Coverage run, retirement, `desktop-distribution` handoff | pending |

## Step 20 replacement series

PR #1265 was closed unmerged on 2026-09-02 because its 5,611-line scope was too
broad for efficient review. Its implementation remains the source for this
fixed, sequential replacement series; only one PR is opened at a time.

| Slice | Fixed PR title | Status |
|---|---|---|
| 1/3 | ⚙️ `[desktop-app] Restore desktop window bounds [step 1/3]` | done |
| 2/3 | 🚧 `[desktop-app] Compose the desktop cockpit [step 2/3]` | pending |
| 3/3 | 🚧 `[desktop-app] Add desktop attention notifications [step 3/3]` | pending |

MT Gate C remains after all three slices. The top-level Step 20 row stays
`in-progress` until the replacement series is complete.

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
complete. MT gate B was later accepted below.

## MT Gate B — accepted 2026-09-01

The user reported every macOS-primary daily-driver check passed on the final
merged build after PRs #1222 and #1230: autostart reboot restored a hidden
last-On bridge and disabling autostart stuck; a second launch focused the first
instance; GUI `kill -9` led to bounded helper teardown and last-On restoration;
live- and dead-helper logout removed the active bridge while preserving the
phone session and clearing local tokens; 10+ minute sleep/wake recovered
without a duplicate helper; and explicit cross-machine Take Over reclaimed
ownership without a flip-flop restart war. The user accepted the desktop app as
the terminal bridge replacement for daily use.

Gate B acceptance removed the gate blocker. The user explicitly authorized
Step 14 on 2026-09-01; Steps 14 and 15 are now implemented and verified.

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
the repository resolves it through the process API, the service rechecks
cancellation before spawn, each supervised start refreshes PATH while
concurrent callers share one probe, and a failed probe preserves the inherited
environment unchanged. The work is intentionally split into two manageable
PRs:

| Follow-up | Status | Scope |
|---|---|---|
| `🌿 [desktop-app] Restore supervised harness discovery [step 1/2]` | done | PR #1222 merged: macOS-only PATH enrichment at the supervised process boundary, setup diagnostics, and regression coverage |
| `🚧 [desktop-app] Preserve bridge intent and add Take Over [step 2/2]` | done | PR #1230 merged: Quit intent semantics, explicit takeover orchestration/UI, and lifecycle coverage |

The helper receives only a login-shell-derived PATH, merged with its inherited
environment; shell variables, secrets, permissions, and entitlements are not
copied. The user accepted Gate B and explicitly authorized Step 14 on
2026-09-01; Step 14 is complete.

## Verification Log

- **Step 18:** changed lines (informational, not a pass/fail check):
  `git diff --numstat --find-renames "$(git merge-base origin/main HEAD)"..HEAD | awk
  '{ additions += $1; deletions += $2 } END { print additions, deletions,
  additions + deletions }'` = `1331 additions / 598 deletions / 1929 total`.
  This is 429 lines over the 1,500-line soft target; accepted deviation from
  moving the existing composer and its tests into shared presentation while
  adding both shell capability composition and regression coverage.
- **Step 19:** rename-aware changed lines against the stable pre-step HEAD:
  `git diff --numstat --find-renames "$(git merge-base origin/main HEAD)"..HEAD | awk
  '{ additions += $1; deletions += $2 } END { print additions, deletions,
  additions + deletions }'` = `1333 additions / 760 deletions / 2093 total`.
  The extraction splits the existing 626-line mobile new-session screen into a
  thin shell wrapper plus a shared view, so Git reports that source twice. The
  review-representative copy-aware command is
  `git diff --numstat --find-renames --find-copies-harder "$(git merge-base
  origin/main HEAD)"..HEAD | awk '{ additions += $1; deletions += $2 } END {
  print additions, deletions, additions + deletions }'` =
  `825 additions / 898 deletions / 1723 total`. This is 523 lines over the
  1,200-line soft target; accepted deviation for the two shared presentation
  moves, two desktop routes, shell composition, tests, review fixes, and
  required regression/evidence updates.
