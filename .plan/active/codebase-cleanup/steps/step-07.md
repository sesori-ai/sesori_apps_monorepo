# Step 7/45 — Flatten the duplicated bridge layer tree

**PR:** _pending_

## Re-verification against `main`

No file-level collisions between the two trees; the only directory overlap,
`repositories/models`, has disjoint filenames. 161 files moved, 309 files
referenced them.

One plan deviation: the plan said to assign the mixed `runtime/` directory a
layer, but it holds two roles that cannot share one. `plugin_runtime.dart` is
the below-repository plugin access seam repositories call through, so it moves
to `api/`; the rest (`bridge_cli_*`, `bridge_runtime*`, logout runner, shutdown
coordinator, plugin registry/generation factory/CLI options mapper, provision
formatter) stays in `runtime/` as a composition subsystem beside `server/`,
`updater/`, `auth/`, `push/` and `control/`.

`control/` was deliberately not touched: `docs/desktop/PLAN.md` records
`ControlChannelServer`, `ControlMessageDispatcher` and the trackers as shipped
Phase-2 deliverables of the paused desktop workstream.

## Verification

`bridge/app`: `dart analyze --fatal-infos` clean, `dart test` 2,684 passed.
Codegen regenerated; `dart fix --code=directives_ordering` applied to 70 files.
Renames plus their imports only — no logic change.
