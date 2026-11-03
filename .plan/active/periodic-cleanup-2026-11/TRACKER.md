# Periodic cleanup 2026-11 tracker

Status values: Pending, In progress, PR open, Merged, Blocked.

| Step | Status | PR | Notes |
| --- | --- | --- | --- |
| 1 Raise the plan | Merged | #2310 | Also moves the 2026-09 audit record into the completed periodic-cleanup plan. |
| 2 Plugin-interface members | PR open | #2318 | |
| 3 Project-questions and plugin-setup routes | Pending | | |
| 4 ACP family | Pending | | |
| 5 Claude plugin | Pending | | |
| 6 Codex plugin | Pending | | |
| 7 Pi, OMP and OpenCode plugins | Pending | | The Pi test-flake fix merged as #2311. Also drop the now test-only `OpenCodeV2Api.getServerInfo` and the `server.info` and `project.update` entries in `tool/opencode_v2_surface.json` (found in step 2). |
| 8 OpenCode v1 generated models | Merged | #2312 | Also removes the unused `--with-client` generator mode. |
| 9 Bridge persistence and plugin fakes | Pending | | |
| 10 Push and updater | PR open | #2319, #2320 | Split into 10.a (push) and 10.b (updater). |
| 11 Runtime package and lifecycle | Pending | | BS-25 needs the relay deployment check. |
| 12 Bridge app rule violations | Pending | | |
| 13 module_core APIs | In progress | | |
| 14 Optimistic session rename | Pending | | |
| 15 Prego components | Merged | #2313 | |
| 16 Phone app | Pending | | Includes UI-8 picker removal (Q4). |
| 17 Shared platform adapters | Pending | | |
| 18 sesori_shared dead code | PR open | #2316, #2317 | Split into 18.a (dead code) and 18.b (test-only APIs). |
| 19 Login control prompt and notification routing | Pending | | |
| 20 Lint rules | Pending | | |
| 21 CI leftovers | PR open | #2314 | Also deletes the released-peer MCP runner, which could no longer run on main. |
| 22 Compatibility markers | Pending | | |
| 23 Plans and docs | PR open | #2315 | Retires all eight plans with accepted gaps (Q5) plus path-runtime-authority-split (Q2). |
| 24 Restart route | Pending | | Remove (Q1). |
| 25 Runtime-update seam | Pending | | Remove (Q2). |
| 26 Phone desktop/web runners | Pending | | Delete (Q3). |
| 27 Regression docs | Pending | | Also runs the retired step-timers plan's step-6 reconciliation (Q6). |
| 28 Verify and retire | Pending | | Includes the retired opencode-v2 and step-timers live rows (Q6). |

## Dropped or corrected findings

Findings disproved during a step are recorded here with the reason.

- PN-1 (OpenCode v2 idle): fixed outside the series by #2309.
- PN-2 (step 8): request-body roots could not be dropped outright; v2 imports five of those models, so its surface lists them in `extraSchemas`.
- PN-15 (step 2): dropped. Codex and OpenCode v1/v2 `implements` the managed-API interfaces, so the overrides are required.
