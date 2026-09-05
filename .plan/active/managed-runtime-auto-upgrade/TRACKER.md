# Managed Runtime Auto-Upgrade — Tracker

| Step | PR title | Status | PR | Notes |
|---|---|---|---|---|
| 1/5 | 🌱 [managed-runtime-auto-upgrade] docs: plan automatic managed runtime upgrades [step 1/5] | Merged | #1312 | |
| 2/5 | 🚧 [managed-runtime-auto-upgrade] runtime: select supported managed versions and sweep by ownership [step 2/5] | Merged | #1316 | Two plan deviations, both recorded in `PLAN.md`: the upgrade gate is the `install` capability (OpenCode drops it in attach mode), and `RuntimeManifest.parseInstalledVersion` splits directory-name parsing from `--version` token parsing so OMP's `omp/` prefix stops hiding its superseded versions. Two review findings on the in-use signal and the ownership-aware sweep were declined as disproportionate; both replies are on the PR. |
| 3/5 | ⚙️ [managed-runtime-auto-upgrade] bridge: upgrade superseded managed runtimes on startup [step 3/5] | Merged | #1319 | Review found a real gap the plan did not anticipate: an explicit Install joining a running startup upgrade inherited `reinspectOnly` and never started the harness. `InstallCompletion` now lives on the active command and is read both at the terminal event and again after the post-upgrade inspection, so a join is honoured at every arrival time. |
| 4/5 | 🌱 [managed-runtime-auto-upgrade] docs: reconcile runtime upgrade regression coverage [step 4/5] | This PR | — | |
| 5/5 | 🌿 [managed-runtime-auto-upgrade] verify: run runtime upgrade coverage and retire the plan [step 5/5] | Planned | — | |

Record regression-document deltas here as implementation steps merge; Step 4
reconciles them and Step 5 records the coverage run.
