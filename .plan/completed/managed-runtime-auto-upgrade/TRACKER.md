# Managed Runtime Auto-Upgrade — Tracker

| Step | PR title | Status | PR | Notes |
|---|---|---|---|---|
| 1/5 | 🌱 [managed-runtime-auto-upgrade] docs: plan automatic managed runtime upgrades [step 1/5] | Merged | #1312 | |
| 2/5 | 🚧 [managed-runtime-auto-upgrade] runtime: select supported managed versions and sweep by ownership [step 2/5] | Merged | #1316 | Two plan deviations, both recorded in `PLAN.md`: the upgrade gate is the `install` capability (OpenCode drops it in attach mode), and `RuntimeManifest.parseInstalledVersion` splits directory-name parsing from `--version` token parsing so OMP's `omp/` prefix stops hiding its superseded versions. Two review findings on the in-use signal and the ownership-aware sweep were declined as disproportionate; both replies are on the PR. |
| 3/5 | ⚙️ [managed-runtime-auto-upgrade] bridge: upgrade superseded managed runtimes on startup [step 3/5] | Merged | #1319 | Review found a real gap the plan did not anticipate: an explicit Install joining a running startup upgrade inherited `reinspectOnly` and never started the harness. `InstallCompletion` now lives on the active command and is read both at the terminal event and again after the post-upgrade inspection, so a join is honoured at every arrival time. |
| 4/5 | 🌱 [managed-runtime-auto-upgrade] docs: reconcile runtime upgrade regression coverage [step 4/5] | Merged | #1321 | |
| 5/5 | 🌿 [managed-runtime-auto-upgrade] verify: run runtime upgrade coverage and retire the plan [step 5/5] | This PR | — | L3 executed; results below. |

## L3 Release coverage

Executed 2026-09-05 on the release-target host (macOS arm64) against a natural
fixture: the machine already carried OMP 17.2.13 (exactly `minPathVersion`), Pi
0.84.2, OpenCode 1.17.18, and DeepSeek 0.1.2 (below minimum) from earlier bridge
releases, with no managed directory for Copilot, Codex, or Cursor. No fabricated
version directories were needed.

| Row | Result |
|---|---|
| Bridge (a) older supported managed version | Pass |
| Bridge (b) below-minimum managed version | Pass |
| Bridge (c) pinned version already installed | Pass |
| Bridge (d) no managed directory | Pass |
| Startup returns without waiting on a download | Pass |
| Client: selectable during (a), selectable without restart after (b), progress reads sensibly | Pass |
| Failure: forced download failure, case (a) | Pass, after #1325 |
| Failure: forced download failure, case (b) | Not executed — declined |
| Ownership: live session on the older runtime during its upgrade | Not executed |

Notes:

- The case (a) failure row initially failed and produced #1325: a managed
  runtime install that could not open its download destination terminated the
  bridge process rather than failing the install. Re-run and passed after that
  fix.
- OMP sat exactly on `minPathVersion`, so version-equal-to-minimum is covered as
  a real case rather than a constructed one.
- DeepSeek's obsolete `0.1.2` directory was observably removed before any
  download began, ahead of every other harness's post-install sweep.
- The two unexecuted rows and the reasoning for accepting them are recorded in
  `PLAN.md` under L3 Execution.

## Regression documentation

Reconciled in Step 4 (#1321): `docs/regression/plugin-runtime-installation.md`
gained the startup trigger, obsolete-first cleanup, ownership-aware sweep,
availability without restart, and failure fallbacks, and lost the stale
"refresh of an installed managed runtime is not covered here" limitation;
`docs/regression/plugin-setup-and-lifecycle.md` dropped the "exact managed
release" wording for DeepSeek and Copilot; `docs/HARNESS_CAPABILITIES.md` gained
a Managed runtime section. Step 5 adds the bridge-survival failure signal found
by #1325.
